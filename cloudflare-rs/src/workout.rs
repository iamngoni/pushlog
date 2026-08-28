//! Owns workout snapshot sync: `workout_snapshots`, `workout_sessions`,
//! `daily_scores`, and the derived `friend_stats` row that feeds
//! leaderboards and lead-change detection.
//!
//! A snapshot PUT is content-addressed: the client's whole snapshot is
//! hashed, and a byte-identical resync is a no-op (`status: "unchanged"`)
//! rather than a rewrite. `dayTotals` keys are validated by shape only
//! (`^\d{4}-\d{2}-\d{2}$`), not calendar validity — matching the
//! TypeScript worker exactly — so streak arithmetic (`shift_day_key`)
//! must tolerate a calendar-invalid key without panicking.

use std::collections::BTreeMap;

use chrono::{DateTime, NaiveDate, NaiveDateTime};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use worker::d1::D1Type;
use worker::{Context, D1Database, Env, Request};

use crate::db::{now_iso, opt_text, shift_day_key, today_key, week_start, CalendarDayKey};
use crate::env::{AppConfig, AuthenticatedUser};
use crate::error::{json_body, ApiError, ApiResult};
use crate::notifications::notify_friends_passed;
use crate::profile::ensure_profile;

const MAXIMUM_SNAPSHOT_BYTES: usize = 900_000;
const MAXIMUM_SESSIONS: usize = 5_000;
const MAXIMUM_DAY_TOTALS: usize = 5_000;
const STATEMENT_BATCH_SIZE: usize = 100;
const MAX_SAFE_INTEGER: i64 = 9_007_199_254_740_991;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct WorkoutSessionPayload {
    id: String,
    date: String,
    reps: i64,
    source: SessionSource,
    duration: Option<i64>,
    average_rep_duration: Option<i64>,
    manual_adjustments: i64,
    effort_score: Option<i64>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum SessionSource {
    Manual,
    Live,
}

impl SessionSource {
    fn parse(value: Option<&str>) -> ApiResult<Self> {
        match value {
            Some("manual") => Ok(Self::Manual),
            Some("live") => Ok(Self::Live),
            _ => Err(invalid_snapshot("A session has an invalid source.")),
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Manual => "manual",
            Self::Live => "live",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct WorkoutSnapshotPayload {
    day_totals: BTreeMap<String, i64>,
    sessions: Vec<WorkoutSessionPayload>,
    preferences: serde_json::Value,
    updated_at: Option<String>,
    last_synced_at: Option<String>,
}

struct WorkoutRequestPayload {
    snapshot: WorkoutSnapshotPayload,
    day_key: CalendarDayKey,
    week_key: CalendarDayKey,
}

#[derive(Debug, Deserialize)]
struct StoredSnapshotIdentity {
    sync_id: String,
    content_hash: String,
}

#[derive(Debug, Deserialize)]
struct StoredSnapshot {
    sync_id: String,
    snapshot_json: String,
    content_hash: String,
    updated_at: String,
}

#[derive(Debug, Deserialize)]
struct FriendStatsToday {
    today_count: i64,
    today_key: Option<String>,
}

fn invalid_snapshot(message: impl Into<String>) -> ApiError {
    ApiError::new(422, "invalid_snapshot", message)
}

fn is_count(value: &serde_json::Value) -> Option<i64> {
    let number = value.as_i64()?;
    (0..=1_000_000).contains(&number).then_some(number)
}

/// Accepts anything `chrono` can parse as an RFC3339 timestamp, a naive
/// (timezone-less) ISO-8601 timestamp, or a bare calendar date — covering
/// both `DateTime.now().toIso8601String()` (no offset) and
/// `DateTime.now().toUtc().toIso8601String()` (trailing `Z`) from the Dart
/// client, without adopting the browser `Date.parse` grammar wholesale.
fn looks_like_a_timestamp(value: &str) -> bool {
    DateTime::parse_from_rfc3339(value).is_ok()
        || NaiveDateTime::parse_from_str(value, "%Y-%m-%dT%H:%M:%S%.f").is_ok()
        || NaiveDate::parse_from_str(value, "%Y-%m-%d").is_ok()
}

fn optional_iso_date(value: Option<&serde_json::Value>, field: &str) -> ApiResult<Option<String>> {
    let Some(value) = value.filter(|v| !v.is_null()) else {
        return Ok(None);
    };
    let text = value
        .as_str()
        .filter(|s| looks_like_a_timestamp(s))
        .ok_or_else(|| invalid_snapshot(format!("{field} must be an ISO-8601 date.")))?;
    Ok(Some(text.to_string()))
}

fn bounded_integer(value: &serde_json::Value, min: i64, max: i64, field: &str) -> ApiResult<i64> {
    value
        .as_i64()
        .filter(|n| (min..=max).contains(n))
        .ok_or_else(|| invalid_snapshot(format!("{field} must be a valid integer.")))
}

fn optional_non_negative_integer(
    value: Option<&serde_json::Value>,
    field: &str,
) -> ApiResult<Option<i64>> {
    match value.filter(|v| !v.is_null()) {
        None => Ok(None),
        Some(value) => Ok(Some(bounded_integer(value, 0, MAX_SAFE_INTEGER, field)?)),
    }
}

fn parse_day_totals(value: Option<&serde_json::Value>) -> ApiResult<BTreeMap<String, i64>> {
    let object = value
        .and_then(|v| v.as_object())
        .ok_or_else(|| invalid_snapshot("dayTotals must be an object."))?;
    if object.len() > MAXIMUM_DAY_TOTALS {
        return Err(invalid_snapshot("dayTotals contains too many days."));
    }
    let mut result = BTreeMap::new();
    for (day_key, reps) in object {
        let shape_valid = day_key.len() == 10
            && day_key.as_bytes()[4] == b'-'
            && day_key.as_bytes()[7] == b'-'
            && day_key
                .bytes()
                .enumerate()
                .all(|(i, b)| i == 4 || i == 7 || b.is_ascii_digit());
        let reps = is_count(reps);
        match (shape_valid, reps) {
            (true, Some(reps)) => {
                result.insert(day_key.clone(), reps);
            }
            _ => {
                return Err(invalid_snapshot(
                    "dayTotals contains an invalid day or rep count.",
                ))
            }
        }
    }
    Ok(result)
}

fn parse_sessions(value: Option<&serde_json::Value>) -> ApiResult<Vec<WorkoutSessionPayload>> {
    let array = value
        .and_then(|v| v.as_array())
        .ok_or_else(|| invalid_snapshot("sessions must be an array."))?;
    if array.len() > MAXIMUM_SESSIONS {
        return Err(invalid_snapshot("sessions contains too many entries."));
    }

    let mut ids = std::collections::HashSet::new();
    let mut sessions = Vec::with_capacity(array.len());
    for item in array {
        let item = item
            .as_object()
            .ok_or_else(|| invalid_snapshot("A session is invalid."))?;
        let id = item
            .get("id")
            .and_then(|v| v.as_str())
            .filter(|id| !id.is_empty() && id.len() <= 128 && !ids.contains(*id))
            .ok_or_else(|| invalid_snapshot("A session has an invalid or duplicate id."))?
            .to_string();
        let date = item
            .get("date")
            .and_then(|v| v.as_str())
            .filter(|d| looks_like_a_timestamp(d))
            .ok_or_else(|| invalid_snapshot("A session has an invalid date."))?
            .to_string();
        let source = SessionSource::parse(item.get("source").and_then(|v| v.as_str()))?;
        let reps = item
            .get("reps")
            .and_then(is_count)
            .ok_or_else(|| invalid_snapshot("A session has an invalid rep count."))?;
        let duration = optional_non_negative_integer(item.get("duration"), "duration")?;
        let average_rep_duration =
            optional_non_negative_integer(item.get("averageRepDuration"), "averageRepDuration")?;
        let manual_adjustments = match item.get("manualAdjustments") {
            None => 0,
            Some(value) => bounded_integer(value, -100_000, 100_000, "manualAdjustments")?,
        };
        let effort_score = match item.get("effortScore").filter(|value| !value.is_null()) {
            None => None,
            Some(value) => Some(bounded_integer(value, 1, 10, "effortScore")?),
        };

        ids.insert(id.clone());
        sessions.push(WorkoutSessionPayload {
            id,
            date,
            reps,
            source,
            duration,
            average_rep_duration,
            manual_adjustments,
            effort_score,
        });
    }
    Ok(sessions)
}

async fn parse_workout_request(request: &mut Request) -> ApiResult<WorkoutRequestPayload> {
    let body: serde_json::Value = json_body(request).await?;
    let snapshot_value = body
        .get("snapshot")
        .filter(|v| v.is_object())
        .ok_or_else(|| invalid_snapshot("The request body must contain a workout snapshot."))?;

    let day_totals = parse_day_totals(snapshot_value.get("dayTotals"))?;
    let sessions = parse_sessions(snapshot_value.get("sessions"))?;
    let preferences = snapshot_value
        .get("preferences")
        .filter(|v| v.is_object())
        .cloned()
        .unwrap_or_else(|| serde_json::json!({}));
    let updated_at = optional_iso_date(snapshot_value.get("updatedAt"), "updatedAt")?;
    let last_synced_at = optional_iso_date(snapshot_value.get("lastSyncedAt"), "lastSyncedAt")?;

    let client_context = body.get("clientContext").filter(|v| v.is_object());
    let today = today_key();
    let day_key = client_context
        .and_then(|c| c.get("dayKey"))
        .and_then(|v| v.as_str())
        .and_then(CalendarDayKey::parse)
        .unwrap_or(today);
    let week_key = client_context
        .and_then(|c| c.get("weekKey"))
        .and_then(|v| v.as_str())
        .and_then(CalendarDayKey::parse)
        .unwrap_or_else(|| week_start(&day_key));

    Ok(WorkoutRequestPayload {
        snapshot: WorkoutSnapshotPayload {
            day_totals,
            sessions,
            preferences,
            updated_at,
            last_synced_at,
        },
        day_key,
        week_key,
    })
}

struct WorkoutStats {
    today_count: i64,
    week_count: i64,
    best_day: i64,
    total_all_time: i64,
    streak: i64,
}

fn workout_stats(
    day_totals: &BTreeMap<String, i64>,
    day_key: &str,
    week_key: &str,
) -> WorkoutStats {
    let total_all_time: i64 = day_totals.values().sum();
    let week_count: i64 = day_totals
        .iter()
        .filter(|(key, _)| key.as_str() >= week_key && key.as_str() <= day_key)
        .map(|(_, count)| count)
        .sum();

    let mut streak = 0i64;
    let mut cursor = Some(day_key.to_string());
    if day_totals.get(day_key).copied().unwrap_or(0) == 0 {
        cursor = cursor.and_then(|c| shift_day_key(&c, -1));
    }
    while let Some(current) = cursor.clone() {
        if day_totals.get(&current).copied().unwrap_or(0) <= 0 {
            break;
        }
        streak += 1;
        cursor = shift_day_key(&current, -1);
    }

    WorkoutStats {
        today_count: day_totals.get(day_key).copied().unwrap_or(0),
        week_count,
        best_day: day_totals.values().copied().max().unwrap_or(0),
        total_all_time,
        streak,
    }
}

fn sha256_hex(data: &[u8]) -> String {
    Sha256::digest(data)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// Binds an integer that may exceed `i32` (validated up to
/// `MAX_SAFE_INTEGER`) as `D1Type::Real` — SQLite's `INTEGER`-affinity
/// columns store a whole-numbered `REAL` parameter as an integer anyway,
/// so this only changes the wire representation, never the stored value.
fn safe_integer_param(value: Option<i64>) -> D1Type<'static> {
    match value {
        None => D1Type::Null,
        Some(value) => match i32::try_from(value) {
            Ok(value) => D1Type::Integer(value),
            Err(_) => D1Type::Real(value as f64),
        },
    }
}

pub async fn put_workout_snapshot(
    request: &mut Request,
    env: &Env,
    user: &AuthenticatedUser,
    ctx: &Context,
) -> ApiResult<(serde_json::Value, u16)> {
    let db = AppConfig::db(env)?;
    let db = &db;
    let payload = parse_workout_request(request).await?;
    let snapshot = &payload.snapshot;
    let snapshot_json = serde_json::to_string(snapshot).map_err(|_| ApiError::internal())?;
    if snapshot_json.len() > MAXIMUM_SNAPSHOT_BYTES {
        return Err(ApiError::new(
            413,
            "snapshot_too_large",
            "The workout snapshot is too large to sync.",
        ));
    }

    let content_hash = sha256_hex(snapshot_json.as_bytes());
    let existing = db
        .prepare("SELECT sync_id, content_hash FROM workout_snapshots WHERE uid = ?")
        .bind_refs(&[D1Type::Text(user.uid())])?
        .first::<StoredSnapshotIdentity>(None)
        .await?;
    if let Some(existing) = existing.filter(|value| value.content_hash == content_hash) {
        return Ok((
            serde_json::json!({
                "status": "unchanged",
                "syncId": existing.sync_id,
                "contentHash": content_hash,
            }),
            200,
        ));
    }

    let now = now_iso();
    let sync_id = uuid::Uuid::new_v4().to_string();
    ensure_profile(db, user).await?;

    let previous_stats = db
        .prepare("SELECT today_count, today_key FROM friend_stats WHERE uid = ?")
        .bind_refs(&[D1Type::Text(user.uid())])?
        .first::<FriendStatsToday>(None)
        .await?;
    let previous_today_count = previous_stats
        .filter(|s| s.today_key.as_deref() == Some(payload.day_key.as_str()))
        .map(|s| s.today_count)
        .unwrap_or(0);
    let stats = workout_stats(
        &snapshot.day_totals,
        payload.day_key.as_str(),
        payload.week_key.as_str(),
    );

    let mut row_statements = Vec::new();
    for session in &snapshot.sessions {
        row_statements.push(
            db.prepare(
                "INSERT INTO workout_sessions (
                  uid, sync_id, session_id, occurred_at, reps, source,
                  duration_us, average_rep_duration_us, manual_adjustments
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind_refs(&[
                D1Type::Text(user.uid()),
                D1Type::Text(&sync_id),
                D1Type::Text(&session.id),
                D1Type::Text(&session.date),
                D1Type::Integer(session.reps as i32),
                D1Type::Text(session.source.as_str()),
                safe_integer_param(session.duration),
                safe_integer_param(session.average_rep_duration),
                D1Type::Integer(session.manual_adjustments as i32),
            ])?,
        );
    }
    for (day_key, reps) in &snapshot.day_totals {
        row_statements.push(
            db.prepare(
                "INSERT INTO daily_scores (uid, sync_id, day_key, reps) VALUES (?, ?, ?, ?)",
            )
            .bind_refs(&[
                D1Type::Text(user.uid()),
                D1Type::Text(&sync_id),
                D1Type::Text(day_key),
                D1Type::Integer(*reps as i32),
            ])?,
        );
    }
    for chunk in row_statements.chunks(STATEMENT_BATCH_SIZE) {
        db.batch(chunk.to_vec()).await?;
    }

    let source_json = serde_json::json!({
        "todayCount": stats.today_count, "weekCount": stats.week_count,
        "bestDay": stats.best_day, "totalAllTime": stats.total_all_time, "streak": stats.streak,
    })
    .to_string();
    db.batch(vec![
        db.prepare(
            "INSERT INTO workout_snapshots (
              uid, sync_id, snapshot_json, content_hash, source_updated_at,
              last_synced_at, schema_version, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
            ON CONFLICT(uid) DO UPDATE SET
              sync_id = excluded.sync_id,
              snapshot_json = excluded.snapshot_json,
              content_hash = excluded.content_hash,
              source_updated_at = excluded.source_updated_at,
              last_synced_at = excluded.last_synced_at,
              schema_version = excluded.schema_version,
              updated_at = excluded.updated_at",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(&sync_id),
            D1Type::Text(&snapshot_json),
            D1Type::Text(&content_hash),
            opt_text(snapshot.updated_at.as_deref()),
            opt_text(snapshot.last_synced_at.as_deref()),
            D1Type::Text(&now),
        ])?,
        db.prepare("DELETE FROM workout_sessions WHERE uid = ? AND sync_id <> ?")
            .bind_refs(&[D1Type::Text(user.uid()), D1Type::Text(&sync_id)])?,
        db.prepare("DELETE FROM daily_scores WHERE uid = ? AND sync_id <> ?")
            .bind_refs(&[D1Type::Text(user.uid()), D1Type::Text(&sync_id)])?,
        db.prepare(
            "INSERT INTO friend_stats (
              uid, today_count, today_key, week_count, week_key, best_day,
              total_all_time, streak, source_json, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(uid) DO UPDATE SET
              today_count = excluded.today_count,
              today_key = excluded.today_key,
              week_count = excluded.week_count,
              week_key = excluded.week_key,
              best_day = excluded.best_day,
              total_all_time = excluded.total_all_time,
              streak = excluded.streak,
              source_json = excluded.source_json,
              updated_at = excluded.updated_at",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            safe_integer_param(Some(stats.today_count)),
            D1Type::Text(payload.day_key.as_str()),
            safe_integer_param(Some(stats.week_count)),
            D1Type::Text(payload.week_key.as_str()),
            safe_integer_param(Some(stats.best_day)),
            safe_integer_param(Some(stats.total_all_time)),
            safe_integer_param(Some(stats.streak)),
            D1Type::Text(&source_json),
            D1Type::Text(&now),
        ])?,
        db.prepare("UPDATE users SET last_active_at = ? WHERE uid = ?")
            .bind_refs(&[D1Type::Text(&now), D1Type::Text(user.uid())])?,
    ])
    .await?;

    let uid = user.uid().to_string();
    let day_key = payload.day_key.as_str().to_string();
    let notification_triggered_at = now.clone();
    let env = env.clone();
    ctx.wait_until(async move {
        if let Err(error) = notify_friends_passed(
            &env,
            &uid,
            previous_today_count,
            stats.today_count,
            &day_key,
            &notification_triggered_at,
        )
        .await
        {
            log::error!("lead-change notification processing failed: {error}");
        }
    });

    Ok((
        serde_json::json!({"status": "stored", "syncId": sync_id, "contentHash": content_hash}),
        202,
    ))
}

pub async fn get_workout_snapshot(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<GetSnapshotOutcome> {
    let stored = db
        .prepare(
            "SELECT sync_id, snapshot_json, content_hash, updated_at
             FROM workout_snapshots WHERE uid = ?",
        )
        .bind_refs(&[D1Type::Text(user.uid())])?
        .first::<StoredSnapshot>(None)
        .await?
        .ok_or_else(|| {
            ApiError::new(
                404,
                "snapshot_not_found",
                "No workout snapshot exists for this user.",
            )
        })?;

    let etag = format!("\"{}\"", stored.content_hash);
    if request
        .headers()
        .get("if-none-match")
        .ok()
        .flatten()
        .as_deref()
        == Some(etag.as_str())
    {
        return Ok(GetSnapshotOutcome::NotModified { etag });
    }

    let snapshot: serde_json::Value =
        serde_json::from_str(&stored.snapshot_json).map_err(|_| ApiError::internal())?;
    Ok(GetSnapshotOutcome::Body {
        etag,
        value: serde_json::json!({
            "snapshot": snapshot,
            "meta": {
                "syncId": stored.sync_id,
                "contentHash": stored.content_hash,
                "storedAt": stored.updated_at,
                "source": "d1",
            }
        }),
    })
}

/// The GET route needs to add an `etag` header regardless of whether the
/// body is a fresh 200 or an empty 304 — a plain `ApiResult<Value>` return
/// can't carry that, so this is returned to `lib.rs` for response assembly
/// instead of building a `worker::Response` here directly.
pub enum GetSnapshotOutcome {
    NotModified {
        etag: String,
    },
    Body {
        etag: String,
        value: serde_json::Value,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    fn totals(pairs: &[(&str, i64)]) -> BTreeMap<String, i64> {
        pairs.iter().map(|(k, v)| (k.to_string(), *v)).collect()
    }

    #[test]
    fn parse_day_totals_accepts_shape_only_not_calendar_validity() {
        let value = serde_json::json!({"2026-13-40": 5});
        let parsed = parse_day_totals(Some(&value)).expect("shape-valid key is accepted");
        assert_eq!(parsed.get("2026-13-40"), Some(&5));
    }

    #[test]
    fn parse_day_totals_rejects_malformed_keys() {
        let value = serde_json::json!({"2026-8-6": 5});
        assert!(parse_day_totals(Some(&value)).is_err());
    }

    #[test]
    fn parse_day_totals_rejects_out_of_range_counts() {
        let value = serde_json::json!({"2026-08-06": 1_000_001});
        assert!(parse_day_totals(Some(&value)).is_err());
        let negative = serde_json::json!({"2026-08-06": -1});
        assert!(parse_day_totals(Some(&negative)).is_err());
    }

    #[test]
    fn looks_like_a_timestamp_accepts_utc_and_offset_less_forms() {
        assert!(looks_like_a_timestamp("2026-08-06T08:00:00.000Z"));
        assert!(looks_like_a_timestamp("2026-08-06T08:00:00.123456"));
        assert!(looks_like_a_timestamp("2026-08-06"));
        assert!(!looks_like_a_timestamp("not a date"));
    }

    #[test]
    fn workout_stats_computes_today_week_best_and_total() {
        let day_totals = totals(&[("2026-08-03", 10), ("2026-08-04", 0), ("2026-08-06", 20)]);
        let stats = workout_stats(&day_totals, "2026-08-06", "2026-08-03");
        assert_eq!(stats.today_count, 20);
        assert_eq!(stats.week_count, 30);
        assert_eq!(stats.best_day, 20);
        assert_eq!(stats.total_all_time, 30);
    }

    #[test]
    fn workout_stats_streak_counts_consecutive_days_ending_today() {
        let day_totals = totals(&[("2026-08-04", 5), ("2026-08-05", 5), ("2026-08-06", 5)]);
        let stats = workout_stats(&day_totals, "2026-08-06", "2026-08-03");
        assert_eq!(stats.streak, 3);
    }

    #[test]
    fn workout_stats_streak_looks_back_one_day_when_today_is_empty() {
        let day_totals = totals(&[("2026-08-04", 5), ("2026-08-05", 5)]);
        let stats = workout_stats(&day_totals, "2026-08-06", "2026-08-03");
        assert_eq!(stats.streak, 2);
    }

    #[test]
    fn workout_stats_streak_stops_at_a_zero_day() {
        let day_totals = totals(&[("2026-08-05", 5), ("2026-08-04", 0), ("2026-08-03", 5)]);
        let stats = workout_stats(&day_totals, "2026-08-05", "2026-08-03");
        assert_eq!(stats.streak, 1);
    }

    #[test]
    fn workout_stats_never_panics_on_a_calendar_invalid_day_key() {
        let day_totals = totals(&[("2026-13-40", 5)]);
        let stats = workout_stats(&day_totals, "2026-13-40", "2026-13-40");
        // The cursor can't step backward from an invalid date, so the walk
        // stops immediately rather than crashing the request.
        assert_eq!(stats.streak, 1);
    }

    #[test]
    fn safe_integer_param_uses_integer_within_i32_range() {
        assert!(matches!(safe_integer_param(Some(42)), D1Type::Integer(42)));
        assert!(matches!(safe_integer_param(None), D1Type::Null));
    }

    #[test]
    fn safe_integer_param_falls_back_to_real_beyond_i32_range() {
        let value = i64::from(i32::MAX) + 1;
        assert!(matches!(safe_integer_param(Some(value)), D1Type::Real(_)));
    }

    #[test]
    fn snapshot_json_round_trips_through_camel_case() {
        let payload = WorkoutSnapshotPayload {
            day_totals: totals(&[("2026-08-06", 12)]),
            sessions: vec![WorkoutSessionPayload {
                id: "s1".into(),
                date: "2026-08-06T08:00:00.000Z".into(),
                reps: 12,
                source: SessionSource::Manual,
                duration: None,
                average_rep_duration: None,
                manual_adjustments: 0,
                effort_score: Some(7),
            }],
            preferences: serde_json::json!({}),
            updated_at: Some("2026-08-06T08:01:00.000Z".into()),
            last_synced_at: None,
        };
        let json = serde_json::to_value(&payload).unwrap();
        assert_eq!(json["dayTotals"]["2026-08-06"], 12);
        assert_eq!(
            json["sessions"][0]["averageRepDuration"],
            serde_json::Value::Null
        );
        assert_eq!(json["sessions"][0]["effortScore"], 7);
        assert_eq!(json["updatedAt"], "2026-08-06T08:01:00.000Z");
        assert_eq!(json["lastSyncedAt"], serde_json::Value::Null);
    }
}
