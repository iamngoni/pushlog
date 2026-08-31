//! Owns the `notification_events` inbox and lead-change detection: when a
//! stored workout snapshot pushes a user's today-count past a friend's,
//! this module records the event and hands it to `push` for delivery.
//!
//! Delivery failure never fails the triggering request — `notify_friends_passed`
//! runs from `workout::put_workout_snapshot`'s `ctx.wait_until`, after the
//! response has already been sent.

use chrono::{DateTime, Duration, SecondsFormat, Utc};
use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Env, Request};

use crate::db::{now_iso, opt_text};
use crate::env::{AppConfig, AuthenticatedUser};
use crate::error::{json_body, ApiError, ApiResult};
use crate::lead_change_copy::{
    build_lead_change_copy, generate_lead_change_copy, random_variant_index, LeadChangeInput,
};
use crate::push;

const LEAD_CHANGE_TTL_SECONDS: i64 = 60;
const LEAD_CHANGE_COOLDOWN_SECONDS: i64 = 60;

#[derive(Debug, Deserialize)]
struct FriendScoreRow {
    uid: String,
    today_count: i64,
    today_key: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ActorRow {
    display_name: Option<String>,
    username: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq)]
struct CurrentLeadState {
    actor_sync_id: String,
    actor_count: i64,
    friend_count: i64,
    actor_rank: i64,
    recipient_rank: i64,
}

#[derive(Debug, Deserialize)]
struct NotificationRow {
    notification_id: String,
    #[serde(rename = "type")]
    kind: String,
    title: Option<String>,
    body: Option<String>,
    actor_uid: Option<String>,
    competitor_uid: Option<String>,
    day_key: Option<String>,
    payload_json: String,
    created_at: Option<String>,
}

/// A non-empty, bounded collection of notification IDs parsed at the HTTP boundary.
struct NotificationIds(Vec<String>);

impl NotificationIds {
    fn parse(body: &serde_json::Value) -> ApiResult<Self> {
        let raw_ids = body
            .get("notificationIds")
            .and_then(serde_json::Value::as_array)
            .ok_or_else(invalid_notification_ids)?;
        if raw_ids.is_empty() || raw_ids.len() > 100 {
            return Err(invalid_notification_ids());
        }

        let ids = raw_ids
            .iter()
            .map(|value| {
                value
                    .as_str()
                    .filter(|id| !id.is_empty() && id.len() <= 128)
                    .map(str::to_string)
                    .ok_or_else(invalid_notification_ids)
            })
            .collect::<ApiResult<Vec<_>>>()?;
        Ok(Self(ids))
    }

    fn as_slice(&self) -> &[String] {
        &self.0
    }
}

fn invalid_notification_ids() -> ApiError {
    ApiError::new(
        422,
        "invalid_notifications",
        "notificationIds must contain between 1 and 100 notification IDs.",
    )
}

fn clamp_limit(raw: Option<&str>) -> i64 {
    raw.and_then(|v| v.parse::<i64>().ok())
        .map(|n| n.clamp(1, 100))
        .unwrap_or(25)
}

fn lead_change_is_expired(triggered_at: &str, now: DateTime<Utc>) -> bool {
    DateTime::parse_from_rfc3339(triggered_at)
        .map(|triggered| {
            now.signed_duration_since(triggered).num_seconds() > LEAD_CHANGE_TTL_SECONDS
        })
        .unwrap_or(true)
}

async fn current_lead_state(
    db: &D1Database,
    actor_uid: &str,
    friend_uid: &str,
    day_key: &str,
) -> worker::Result<Option<CurrentLeadState>> {
    db.prepare(
        "WITH current_scores AS (
           SELECT snapshots.sync_id AS actor_sync_id,
                  CASE WHEN actor.today_key = ? THEN actor.today_count ELSE 0 END AS actor_count,
                  CASE WHEN recipient.today_key = ? THEN recipient.today_count ELSE 0 END AS friend_count
           FROM workout_snapshots snapshots
           JOIN friend_stats actor ON actor.uid = snapshots.uid
           JOIN friend_stats recipient ON recipient.uid = ?
           WHERE snapshots.uid = ?
         ),
         leaderboard AS (
           SELECT circle.uid,
                  CASE WHEN stats.today_key = ? THEN stats.today_count ELSE 0 END AS score
           FROM (
             SELECT ? AS uid
             UNION
             SELECT friend_uid AS uid FROM friend_links WHERE owner_uid = ?
           ) circle
           LEFT JOIN friend_stats stats ON stats.uid = circle.uid
         )
         SELECT current_scores.actor_sync_id,
                current_scores.actor_count,
                current_scores.friend_count,
                1 + (SELECT COUNT(*) FROM leaderboard
                     WHERE score > current_scores.actor_count) AS actor_rank,
                1 + (SELECT COUNT(*) FROM leaderboard
                     WHERE score > current_scores.friend_count) AS recipient_rank
         FROM current_scores",
    )
    .bind_refs(&[
        D1Type::Text(day_key),
        D1Type::Text(day_key),
        D1Type::Text(friend_uid),
        D1Type::Text(actor_uid),
        D1Type::Text(day_key),
        D1Type::Text(friend_uid),
        D1Type::Text(friend_uid),
    ])?
    .first::<CurrentLeadState>(None)
    .await
}

fn lead_change_input(actor: String, state: &CurrentLeadState) -> Option<LeadChangeInput> {
    LeadChangeInput::new(
        actor,
        state.actor_count.checked_sub(state.friend_count)?,
        state.actor_rank,
        state.recipient_rank,
    )
}

async fn lead_change_cooldown_active(
    db: &D1Database,
    friend_uid: &str,
    actor_uid: &str,
) -> worker::Result<bool> {
    let now = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
    Ok(db
        .prepare(
            "SELECT 1 AS active
             FROM notification_cooldowns
             WHERE uid = ? AND type = 'lead_change' AND actor_uid = ?
               AND cooldown_until > ?",
        )
        .bind_refs(&[
            D1Type::Text(friend_uid),
            D1Type::Text(actor_uid),
            D1Type::Text(&now),
        ])?
        .first::<serde_json::Value>(None)
        .await?
        .is_some())
}

async fn claim_lead_change_cooldown(
    db: &D1Database,
    friend_uid: &str,
    actor_uid: &str,
) -> worker::Result<Option<String>> {
    let claimed_at = Utc::now();
    let now = claimed_at.to_rfc3339_opts(SecondsFormat::Millis, true);
    let cooldown_until = (claimed_at + Duration::seconds(LEAD_CHANGE_COOLDOWN_SECONDS))
        .to_rfc3339_opts(SecondsFormat::Millis, true);
    let result = db
        .prepare(
            "INSERT INTO notification_cooldowns (
               uid, type, actor_uid, cooldown_until, updated_at
             ) VALUES (?, 'lead_change', ?, ?, ?)
             ON CONFLICT(uid, type, actor_uid) DO UPDATE SET
               cooldown_until = excluded.cooldown_until,
               updated_at = excluded.updated_at
             WHERE notification_cooldowns.cooldown_until <= ?",
        )
        .bind_refs(&[
            D1Type::Text(friend_uid),
            D1Type::Text(actor_uid),
            D1Type::Text(&cooldown_until),
            D1Type::Text(&now),
            D1Type::Text(&now),
        ])?
        .run()
        .await?;
    let claimed = result
        .meta()?
        .and_then(|meta| meta.changes.or(meta.rows_written))
        .is_some_and(|changes| changes > 0);
    Ok(claimed.then_some(now))
}

async fn release_lead_change_cooldown(
    db: &D1Database,
    friend_uid: &str,
    actor_uid: &str,
    claimed_at: &str,
) -> worker::Result<()> {
    db.prepare(
        "DELETE FROM notification_cooldowns
         WHERE uid = ? AND type = 'lead_change' AND actor_uid = ?
           AND updated_at = ?",
    )
    .bind_refs(&[
        D1Type::Text(friend_uid),
        D1Type::Text(actor_uid),
        D1Type::Text(claimed_at),
    ])?
    .run()
    .await?;
    Ok(())
}

pub async fn get_notifications(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let url = request.url()?;
    let limit = clamp_limit(
        url.query_pairs()
            .find(|(k, _)| k == "limit")
            .map(|(_, v)| v.into_owned())
            .as_deref(),
    );

    let rows = db
        .prepare(
            "SELECT notification_id, type, title, body, actor_uid, competitor_uid,
                    day_key, payload_json, created_at
             FROM notification_events
             WHERE uid = ? AND read_at IS NULL
               AND (
                 type <> 'lead_change'
                 OR EXISTS (
                   SELECT 1
                   FROM friend_stats actor
                   JOIN friend_stats recipient ON recipient.uid = notification_events.uid
                   WHERE actor.uid = notification_events.actor_uid
                     AND actor.today_key = notification_events.day_key
                     AND actor.today_count > CASE
                       WHEN recipient.today_key = notification_events.day_key
                       THEN recipient.today_count ELSE 0 END
                     AND actor.today_count =
                       json_extract(notification_events.payload_json, '$.score')
                     AND CASE
                       WHEN recipient.today_key = notification_events.day_key
                       THEN recipient.today_count ELSE 0 END =
                       json_extract(notification_events.payload_json, '$.previousLead')
                 )
               )
             ORDER BY created_at ASC
             LIMIT ?",
        )
        .bind_refs(&[D1Type::Text(user.uid()), D1Type::Integer(limit as i32)])?
        .all()
        .await?
        .results::<NotificationRow>()?;

    let notifications = rows
        .iter()
        .map(|row| {
            let payload =
                serde_json::from_str::<serde_json::Value>(&row.payload_json).map_err(|error| {
                    log::error!("stored notification payload is invalid: {error}");
                    ApiError::internal()
                })?;
            Ok(serde_json::json!({
                "notificationId": row.notification_id,
                "type": row.kind,
                "title": row.title,
                "body": row.body,
                "actorUid": row.actor_uid,
                "competitorUid": row.competitor_uid,
                "dayKey": row.day_key,
                "payload": payload,
                "createdAt": row.created_at,
            }))
        })
        .collect::<ApiResult<Vec<_>>>()?;
    Ok(serde_json::json!({"notifications": notifications}))
}

pub async fn mark_notifications_read(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let body: serde_json::Value = json_body(request).await?;
    let ids = NotificationIds::parse(&body)?;

    let placeholders = std::iter::repeat_n("?", ids.as_slice().len())
        .collect::<Vec<_>>()
        .join(", ");
    let now = now_iso();
    let mut params = vec![D1Type::Text(&now), D1Type::Text(user.uid())];
    params.extend(ids.as_slice().iter().map(|id| D1Type::Text(id)));
    db.prepare(format!(
        "UPDATE notification_events
         SET read_at = COALESCE(read_at, ?)
         WHERE uid = ? AND notification_id IN ({placeholders})"
    ))
    .bind_refs(&params)?
    .run()
    .await?;
    Ok(serde_json::json!({"status": "read"}))
}

/// Compares `previous_count` and `current_count` against every friend's
/// cached today-score and fires one lead-change notification per friend
/// the actor's new count just overtook. A no-op unless the count actually
/// increased — a manual downward correction never generates a push.
pub async fn notify_friends_passed(
    env: &Env,
    actor_uid: &str,
    previous_count: i64,
    current_count: i64,
    day_key: &str,
    triggered_at: &str,
) -> ApiResult<()> {
    if current_count <= previous_count || lead_change_is_expired(triggered_at, Utc::now()) {
        return Ok(());
    }
    let db = AppConfig::db(env)?;

    let scores = db
        .prepare(
            "SELECT stats.uid, stats.today_count, stats.today_key
             FROM friend_links links
             JOIN friend_stats stats ON stats.uid = links.friend_uid
             WHERE links.owner_uid = ?",
        )
        .bind_refs(&[D1Type::Text(actor_uid)])?
        .all()
        .await?
        .results::<FriendScoreRow>()?;

    let passed = scores.into_iter().filter(|friend| {
        let friend_count = if friend.today_key.as_deref() == Some(day_key) {
            friend.today_count
        } else {
            0
        };
        previous_count <= friend_count && current_count > friend_count
    });

    let mut passed = passed.peekable();
    if passed.peek().is_none() {
        return Ok(());
    }

    let actor = db
        .prepare("SELECT display_name, username FROM users WHERE uid = ?")
        .bind_refs(&[D1Type::Text(actor_uid)])?
        .first::<ActorRow>(None)
        .await?;
    let actor_name = actor
        .and_then(|a| a.username.or(a.display_name))
        .unwrap_or_else(|| "A friend".to_string());

    for friend in passed {
        if lead_change_is_expired(triggered_at, Utc::now()) {
            log::info!("skipping expired lead-change notification for actor_uid={actor_uid}");
            break;
        }

        let Some(before_generation) =
            current_lead_state(&db, actor_uid, &friend.uid, day_key).await?
        else {
            continue;
        };
        let Some(copy_input) = lead_change_input(actor_name.clone(), &before_generation) else {
            continue;
        };
        if lead_change_cooldown_active(&db, &friend.uid, actor_uid).await? {
            log::info!(
                "suppressing lead-change notification during cooldown actor_uid={actor_uid} friend_uid={}",
                friend.uid
            );
            continue;
        }

        let notification_id = uuid::Uuid::new_v4().to_string();
        let generated_copy =
            generate_lead_change_copy(env, &copy_input, random_variant_index()).await;

        if lead_change_is_expired(triggered_at, Utc::now()) {
            log::info!("discarding expired lead-change copy for actor_uid={actor_uid}");
            continue;
        }

        // Inference adds an external await between detection and delivery.
        // Re-read both scores afterward so copy generated from an old gap is
        // never sent. If the lead still exists but changed, use immediate
        // curated copy rather than paying for a second inference.
        let Some(after_generation) =
            current_lead_state(&db, actor_uid, &friend.uid, day_key).await?
        else {
            continue;
        };
        let Some(fresh_input) = lead_change_input(actor_name.clone(), &after_generation) else {
            continue;
        };
        let copy = if after_generation == before_generation {
            generated_copy
        } else {
            build_lead_change_copy(&fresh_input, random_variant_index())
        };
        let now = now_iso();
        let payload_json = serde_json::json!({
            "score": after_generation.actor_count,
            "previousLead": after_generation.friend_count,
            "actorRank": after_generation.actor_rank,
            "recipientRank": after_generation.recipient_rank,
            "sourceSyncId": after_generation.actor_sync_id,
        })
        .to_string();

        let Some(cooldown_claimed_at) =
            claim_lead_change_cooldown(&db, &friend.uid, actor_uid).await?
        else {
            log::info!(
                "suppressing concurrent lead-change notification actor_uid={actor_uid} friend_uid={}",
                friend.uid
            );
            continue;
        };

        let insert = db
            .prepare(
                "INSERT OR IGNORE INTO notification_events (
              uid, notification_id, type, title, body, actor_uid,
              competitor_uid, day_key, source_sync_id, delivery_status,
              payload_json, created_at
            ) VALUES (?, ?, 'lead_change', ?, ?, ?, ?, ?, ?, 'pending', ?, ?)",
            )
            .bind_refs(&[
                D1Type::Text(&friend.uid),
                D1Type::Text(&notification_id),
                D1Type::Text(&copy.title),
                D1Type::Text(&copy.body),
                D1Type::Text(actor_uid),
                D1Type::Text(actor_uid),
                D1Type::Text(day_key),
                D1Type::Text(&after_generation.actor_sync_id),
                D1Type::Text(&payload_json),
                D1Type::Text(&now),
            ])?
            .run()
            .await?;
        let inserted = insert
            .meta()?
            .and_then(|meta| meta.changes)
            .is_some_and(|changes| changes > 0);
        if !inserted {
            log::info!(
                "skipping duplicate lead-change notification actor_uid={actor_uid} friend_uid={}",
                friend.uid
            );
            continue;
        }

        // Keep the final read as close to FCM delivery as possible. If either
        // score changed while the event row was being reserved, hide the row
        // from the inbox and do not put obsolete copy on the lock screen.
        let final_state = current_lead_state(&db, actor_uid, &friend.uid, day_key).await?;
        if final_state.as_ref() != Some(&after_generation)
            || lead_change_is_expired(triggered_at, Utc::now())
        {
            db.prepare(
                "UPDATE notification_events
                 SET delivery_status = 'stale', read_at = COALESCE(read_at, ?)
                 WHERE uid = ? AND notification_id = ?",
            )
            .bind_refs(&[
                D1Type::Text(&now),
                D1Type::Text(&friend.uid),
                D1Type::Text(&notification_id),
            ])?
            .run()
            .await?;
            release_lead_change_cooldown(&db, &friend.uid, actor_uid, &cooldown_claimed_at).await?;
            continue;
        }

        let data = [
            ("type", "lead_change".to_string()),
            ("notificationId", notification_id.clone()),
            ("actorUid", actor_uid.to_string()),
            ("competitorUid", actor_uid.to_string()),
            ("dayKey", day_key.to_string()),
            ("score", after_generation.actor_count.to_string()),
            ("sourceSyncId", after_generation.actor_sync_id),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect();
        let delivery_status = push::deliver_to_user(
            env,
            &db,
            &friend.uid,
            &push::PushNotification {
                title: copy.title,
                body: copy.body,
                data,
                channel_id: "pushlog_competition",
                thread_id: "pushlog_competition",
                collapse_key: Some("pushlog-lead-change".to_string()),
            },
        )
        .await;

        let delivered_at = delivery_status.delivered().then(now_iso);
        db.prepare(
            "UPDATE notification_events
             SET delivery_status = ?, delivered_at = ?
             WHERE uid = ? AND notification_id = ?",
        )
        .bind_refs(&[
            D1Type::Text(delivery_status.as_code()),
            opt_text(delivered_at.as_deref()),
            D1Type::Text(&friend.uid),
            D1Type::Text(&notification_id),
        ])?
        .run()
        .await?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clamp_limit_defaults_and_bounds() {
        assert_eq!(clamp_limit(None), 25);
        assert_eq!(clamp_limit(Some("not-a-number")), 25);
        assert_eq!(clamp_limit(Some("0")), 1);
        assert_eq!(clamp_limit(Some("500")), 100);
        assert_eq!(clamp_limit(Some("40")), 40);
    }

    #[test]
    fn lead_change_ttl_rejects_old_and_malformed_events() {
        let now = DateTime::parse_from_rfc3339("2026-01-01T00:01:01.000Z")
            .unwrap()
            .with_timezone(&Utc);
        assert!(lead_change_is_expired("2026-01-01T00:00:00.000Z", now));
        assert!(!lead_change_is_expired("2026-01-01T00:00:01.000Z", now));
        assert!(lead_change_is_expired("not-a-timestamp", now));
    }

    #[test]
    fn lead_change_input_requires_a_real_pass_and_rank_drop() {
        let state = CurrentLeadState {
            actor_sync_id: "sync-1".to_string(),
            actor_count: 12,
            friend_count: 8,
            actor_rank: 2,
            recipient_rank: 3,
        };
        assert!(lead_change_input("ana".to_string(), &state).is_some());

        let tied = CurrentLeadState {
            friend_count: 12,
            ..state.clone()
        };
        assert!(lead_change_input("ana".to_string(), &tied).is_none());

        let impossible_rank = CurrentLeadState {
            recipient_rank: 2,
            ..state
        };
        assert!(lead_change_input("ana".to_string(), &impossible_rank).is_none());
    }

    #[test]
    fn notification_ids_parse_only_non_empty_bounded_strings() {
        let parsed = NotificationIds::parse(&serde_json::json!({
            "notificationIds": ["first", "second"]
        }))
        .expect("valid IDs parse");
        assert_eq!(parsed.as_slice(), ["first", "second"]);

        for invalid in [
            serde_json::json!({}),
            serde_json::json!({"notificationIds": []}),
            serde_json::json!({"notificationIds": [""]}),
            serde_json::json!({"notificationIds": [7]}),
            serde_json::json!({"notificationIds": ["x".repeat(129)]}),
        ] {
            assert!(NotificationIds::parse(&invalid).is_err());
        }
    }
}
