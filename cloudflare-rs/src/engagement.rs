//! Scheduled, state-aware reminders. A UTC cron scans users with registered
//! devices, evaluates their preferences in their own IANA timezone, and sends
//! at most one deduplicated reminder for each factual engagement event.

use chrono::{DateTime, Datelike, NaiveDate, Timelike, Utc};
use chrono_tz::Tz;
use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Env};

use crate::db::{now_iso, opt_text};
use crate::engagement_copy::{generate_engagement_copy, EngagementKind};
use crate::env::AppConfig;
use crate::push;

const STREAK_WARNING_HOUR: u32 = 21;

#[derive(Debug, Clone, Deserialize)]
struct EngagementCandidate {
    uid: String,
    time_zone: String,
    last_active_at: Option<String>,
    snapshot_json: String,
    streak: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct DueReminder {
    kind: EngagementKind,
    source_key: String,
    local_day_key: String,
    smart_copy_enabled: bool,
}

pub async fn deliver_due_reminders(env: &Env) -> worker::Result<()> {
    let db = AppConfig::db(env)?;
    let now = Utc::now();
    let candidates = load_candidates(&db).await?;
    for candidate in candidates {
        let Some(due) = due_reminder(&candidate, now) else {
            continue;
        };
        if reminder_exists(&db, &candidate.uid, &due.source_key).await? {
            continue;
        }

        let copy = generate_engagement_copy(env, &due.kind, due.smart_copy_enabled).await;

        // AI inference can outlive the state that made a reminder true. Load
        // the candidate again and require the exact same event before writing
        // or delivering anything.
        let Some(fresh_candidate) = load_candidate(&db, &candidate.uid).await? else {
            continue;
        };
        if due_reminder(&fresh_candidate, Utc::now()).as_ref() != Some(&due) {
            continue;
        }

        let notification_id = uuid::Uuid::new_v4().to_string();
        let created_at = now_iso();
        let payload_json = serde_json::json!({
            "kind": due.kind.code(),
            "sourceKey": due.source_key,
        })
        .to_string();
        let inserted = db
            .prepare(
                "INSERT OR IGNORE INTO notification_events (
                   uid, notification_id, type, title, body, day_key,
                   source_sync_id, delivery_status, payload_json, created_at, read_at
                 ) VALUES (?, ?, 'engagement_reminder', ?, ?, ?, ?, 'pending', ?, ?, ?)",
            )
            .bind_refs(&[
                D1Type::Text(&candidate.uid),
                D1Type::Text(&notification_id),
                D1Type::Text(&copy.title),
                D1Type::Text(&copy.body),
                D1Type::Text(&due.local_day_key),
                D1Type::Text(&due.source_key),
                D1Type::Text(&payload_json),
                D1Type::Text(&created_at),
                // Scheduled reminders are push-only. Marking the audit row
                // read prevents the foreground inbox poll from showing it a
                // second time after FCM already put it on the lock screen.
                D1Type::Text(&created_at),
            ])?
            .run()
            .await?;
        let inserted = inserted
            .meta()?
            .and_then(|meta| meta.changes.or(meta.rows_written))
            .is_some_and(|changes| changes > 0);
        if !inserted {
            continue;
        }

        let fresh_before_delivery = load_candidate(&db, &candidate.uid).await?;
        if fresh_before_delivery
            .as_ref()
            .and_then(|candidate| due_reminder(candidate, Utc::now()))
            .as_ref()
            != Some(&due)
        {
            mark_delivery(&db, &candidate.uid, &notification_id, "stale", None).await?;
            continue;
        }

        let data = [
            ("type".to_string(), "engagement_reminder".to_string()),
            ("notificationId".to_string(), notification_id.clone()),
            ("kind".to_string(), due.kind.code().to_string()),
            ("dayKey".to_string(), due.local_day_key),
        ]
        .into_iter()
        .collect();
        let delivery = push::deliver_to_user(
            env,
            &db,
            &candidate.uid,
            &push::PushNotification {
                title: copy.title,
                body: copy.body,
                data,
                channel_id: "pushlog_daily_reminders",
                thread_id: "pushlog_reminders",
                collapse_key: Some("pushlog-engagement".to_string()),
            },
        )
        .await;
        let delivered_at = delivery.delivered().then(now_iso);
        mark_delivery(
            &db,
            &candidate.uid,
            &notification_id,
            delivery.as_code(),
            delivered_at.as_deref(),
        )
        .await?;
    }
    Ok(())
}

async fn load_candidates(db: &D1Database) -> worker::Result<Vec<EngagementCandidate>> {
    db.prepare(
        "SELECT users.uid, users.time_zone, users.last_active_at,
                snapshots.snapshot_json, stats.streak
         FROM users
         JOIN workout_snapshots snapshots ON snapshots.uid = users.uid
         JOIN friend_stats stats ON stats.uid = users.uid
         WHERE users.last_active_at IS NOT NULL
           AND EXISTS (SELECT 1 FROM devices WHERE devices.uid = users.uid)
           AND (
             json_extract(snapshots.snapshot_json, '$.preferences.remindersEnabled') = 1
             OR json_extract(
               snapshots.snapshot_json,
               '$.preferences.streakRemindersEnabled'
             ) = 1
             OR json_extract(
               snapshots.snapshot_json,
               '$.preferences.comebackRemindersEnabled'
             ) = 1
           )
         ORDER BY users.last_active_at ASC
        ",
    )
    .all()
    .await?
    .results::<EngagementCandidate>()
}

async fn load_candidate(db: &D1Database, uid: &str) -> worker::Result<Option<EngagementCandidate>> {
    db.prepare(
        "SELECT users.uid, users.time_zone, users.last_active_at,
                snapshots.snapshot_json, stats.streak
         FROM users
         JOIN workout_snapshots snapshots ON snapshots.uid = users.uid
         JOIN friend_stats stats ON stats.uid = users.uid
         WHERE users.uid = ?
           AND EXISTS (SELECT 1 FROM devices WHERE devices.uid = users.uid)",
    )
    .bind_refs(&[D1Type::Text(uid)])?
    .first::<EngagementCandidate>(None)
    .await
}

async fn reminder_exists(db: &D1Database, uid: &str, source_key: &str) -> worker::Result<bool> {
    Ok(db
        .prepare(
            "SELECT 1 AS present
             FROM notification_events
             WHERE uid = ? AND type = 'engagement_reminder' AND source_sync_id = ?",
        )
        .bind_refs(&[D1Type::Text(uid), D1Type::Text(source_key)])?
        .first::<serde_json::Value>(None)
        .await?
        .is_some())
}

async fn mark_delivery(
    db: &D1Database,
    uid: &str,
    notification_id: &str,
    status: &str,
    delivered_at: Option<&str>,
) -> worker::Result<()> {
    db.prepare(
        "UPDATE notification_events
         SET delivery_status = ?, delivered_at = ?
         WHERE uid = ? AND notification_id = ?",
    )
    .bind_refs(&[
        D1Type::Text(status),
        opt_text(delivered_at),
        D1Type::Text(uid),
        D1Type::Text(notification_id),
    ])?
    .run()
    .await?;
    Ok(())
}

fn due_reminder(candidate: &EngagementCandidate, now: DateTime<Utc>) -> Option<DueReminder> {
    let snapshot: serde_json::Value = serde_json::from_str(&candidate.snapshot_json).ok()?;
    let preferences = snapshot.get("preferences")?;
    let time_zone = candidate.time_zone.parse::<Tz>().unwrap_or(chrono_tz::UTC);
    let local_now = now.with_timezone(&time_zone);
    let today = local_now.date_naive();
    let yesterday = today.pred_opt()?;
    let today_key = today.format("%Y-%m-%d").to_string();
    let yesterday_key = yesterday.format("%Y-%m-%d").to_string();
    let day_totals = snapshot
        .get("dayTotals")
        .and_then(|value| value.as_object());
    let reps_for = |key: &str| {
        day_totals
            .and_then(|totals| totals.get(key))
            .and_then(|value| value.as_i64())
            .unwrap_or(0)
    };

    let streak_enabled = preference_bool(preferences, "streakRemindersEnabled");
    let smart_copy_enabled = preferences
        .get("smartReminderCopyEnabled")
        .and_then(|value| value.as_bool())
        .unwrap_or(true);
    if streak_enabled
        && local_now.hour() >= STREAK_WARNING_HOUR
        && candidate.streak > 0
        && reps_for(&today_key) == 0
        && reps_for(&yesterday_key) > 0
    {
        return Some(DueReminder {
            kind: EngagementKind::StreakAtRisk {
                streak: candidate.streak,
            },
            source_key: format!("streak:{today_key}"),
            local_day_key: today_key,
            smart_copy_enabled,
        });
    }

    let reminder_hour = preference_i64(preferences, "reminderHour", 19).clamp(0, 23) as u32;
    let reminder_minute = preference_i64(preferences, "reminderMinute", 0).clamp(0, 59) as u32;
    let past_reminder_time =
        (local_now.hour(), local_now.minute()) >= (reminder_hour, reminder_minute);
    if preference_bool(preferences, "remindersEnabled")
        && past_reminder_time
        && is_planned_training_day(preferences, yesterday)
        && reps_for(&yesterday_key) == 0
        && reps_for(&today_key) == 0
    {
        return Some(DueReminder {
            kind: EngagementKind::MissedSession,
            source_key: format!("missed:{yesterday_key}"),
            local_day_key: today_key,
            smart_copy_enabled,
        });
    }

    if preference_bool(preferences, "comebackRemindersEnabled") && past_reminder_time {
        let last_active = candidate
            .last_active_at
            .as_deref()
            .and_then(|value| DateTime::parse_from_rfc3339(value).ok())?
            .with_timezone(&time_zone)
            .date_naive();
        let inactive_days = today.signed_duration_since(last_active).num_days();
        let stage = if inactive_days >= 14 {
            14
        } else if inactive_days >= 7 {
            7
        } else if inactive_days >= 3 {
            3
        } else {
            return None;
        };
        return Some(DueReminder {
            kind: EngagementKind::Inactive { days: stage },
            source_key: format!(
                "inactive:{stage}:{}",
                candidate.last_active_at.as_deref().unwrap_or_default()
            ),
            local_day_key: today_key,
            smart_copy_enabled,
        });
    }

    None
}

fn preference_bool(preferences: &serde_json::Value, key: &str) -> bool {
    preferences
        .get(key)
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn preference_i64(preferences: &serde_json::Value, key: &str, fallback: i64) -> i64 {
    preferences
        .get(key)
        .and_then(|value| value.as_i64())
        .unwrap_or(fallback)
}

fn is_planned_training_day(preferences: &serde_json::Value, date: NaiveDate) -> bool {
    let Some(plan) = preferences.get("trainingPlan") else {
        return false;
    };
    let Some(profile) = plan.get("profile") else {
        return false;
    };
    let preferred = profile
        .get("preferredWeekdays")
        .and_then(|value| value.as_array());
    let is_preferred = preferred.is_some_and(|days| {
        days.iter().any(|day| {
            day.as_u64()
                .is_some_and(|day| day == u64::from(date.weekday().number_from_monday()))
        })
    });
    if !is_preferred {
        return false;
    }

    let Some(start) = plan
        .get("startDate")
        .and_then(|value| value.as_str())
        .and_then(|value| value.get(..10))
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
    else {
        return false;
    };
    let duration_weeks = profile
        .get("durationWeeks")
        .and_then(|value| value.as_i64())
        .unwrap_or(12)
        .clamp(1, 52);
    let end = start
        .checked_add_days(chrono::Days::new(
            (duration_weeks as u64 * 7).saturating_sub(1),
        ))
        .unwrap_or(start);
    (start..=end).contains(&date)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn candidate(snapshot: serde_json::Value) -> EngagementCandidate {
        EngagementCandidate {
            uid: "user-1".to_string(),
            time_zone: "UTC".to_string(),
            last_active_at: Some("2026-08-01T12:00:00.000Z".to_string()),
            snapshot_json: snapshot.to_string(),
            streak: 6,
        }
    }

    fn now(value: &str) -> DateTime<Utc> {
        DateTime::parse_from_rfc3339(value)
            .unwrap()
            .with_timezone(&Utc)
    }

    #[test]
    fn streak_warning_requires_yesterday_activity_and_no_reps_today() {
        let snapshot = serde_json::json!({
            "dayTotals": {"2026-08-05": 10},
            "preferences": {"streakRemindersEnabled": true}
        });
        let due = due_reminder(&candidate(snapshot), now("2026-08-06T21:00:00Z")).unwrap();
        assert_eq!(due.kind, EngagementKind::StreakAtRisk { streak: 6 });

        let completed = serde_json::json!({
            "dayTotals": {"2026-08-05": 10, "2026-08-06": 1},
            "preferences": {"streakRemindersEnabled": true}
        });
        assert!(due_reminder(&candidate(completed), now("2026-08-06T21:00:00Z")).is_none());
    }

    #[test]
    fn missed_session_requires_a_planned_day_inside_the_plan() {
        let snapshot = serde_json::json!({
            "dayTotals": {},
            "preferences": {
                "remindersEnabled": true,
                "reminderHour": 10,
                "reminderMinute": 0,
                "trainingPlan": {
                    "startDate": "2026-08-03T00:00:00.000",
                    "profile": {
                        "preferredWeekdays": [1, 3, 5],
                        "durationWeeks": 12
                    }
                }
            }
        });
        let due = due_reminder(&candidate(snapshot), now("2026-08-06T10:00:00Z")).unwrap();
        assert_eq!(due.kind, EngagementKind::MissedSession);
        assert_eq!(due.source_key, "missed:2026-08-05");

        let made_up_today = serde_json::json!({
            "dayTotals": {"2026-08-06": 5},
            "preferences": {
                "remindersEnabled": true,
                "reminderHour": 10,
                "reminderMinute": 0,
                "trainingPlan": {
                    "startDate": "2026-08-03T00:00:00.000",
                    "profile": {
                        "preferredWeekdays": [1, 3, 5],
                        "durationWeeks": 12
                    }
                }
            }
        });
        assert!(due_reminder(&candidate(made_up_today), now("2026-08-06T10:00:00Z")).is_none());
    }

    #[test]
    fn inactivity_uses_three_seven_fourteen_then_stops_repeating() {
        let snapshot = serde_json::json!({
            "dayTotals": {},
            "preferences": {
                "comebackRemindersEnabled": true,
                "reminderHour": 12,
                "reminderMinute": 0
            }
        });
        let user = candidate(snapshot);
        for (timestamp, expected) in [
            ("2026-08-04T12:00:00Z", 3),
            ("2026-08-08T12:00:00Z", 7),
            ("2026-08-15T12:00:00Z", 14),
            ("2026-08-30T12:00:00Z", 14),
        ] {
            let due = due_reminder(&user, now(timestamp)).unwrap();
            assert_eq!(due.kind, EngagementKind::Inactive { days: expected });
            assert!(due.source_key.contains(&format!("inactive:{expected}:")));
        }
    }

    #[test]
    fn invalid_timezone_falls_back_to_utc() {
        let snapshot = serde_json::json!({
            "dayTotals": {"2026-08-05": 4},
            "preferences": {"streakRemindersEnabled": true}
        });
        let mut user = candidate(snapshot);
        user.time_zone = "Not/AZone".to_string();
        assert!(due_reminder(&user, now("2026-08-06T21:00:00Z")).is_some());
    }
}
