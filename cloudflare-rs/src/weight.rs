//! Body-weight log, private settings, and the opt-in friends board.
//!
//! Absolute grams never leave the owner's account unless `share_latest_weight`
//! is on. Progress sharing is off by default. Workout snapshots are untouched.

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Request};

use crate::db::{now_iso, shift_day_key, today_key, CalendarDayKey};
use crate::env::AuthenticatedUser;
use crate::error::{json_body, ApiError, ApiResult};
use crate::profile::ensure_profile;

const MIN_WEIGH_INS: usize = 2;
const WINDOW_DAYS: i64 = 27;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WeightGoal {
    Lose,
    Maintain,
    Gain,
}

impl WeightGoal {
    fn parse(value: &str) -> Option<Self> {
        match value {
            "lose" => Some(Self::Lose),
            "maintain" => Some(Self::Maintain),
            "gain" => Some(Self::Gain),
            _ => None,
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Lose => "lose",
            Self::Maintain => "maintain",
            Self::Gain => "gain",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WeighIn {
    pub recorded_on: String,
    pub weight_grams: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FriendWeighInCandidate {
    pub uid: String,
    pub display_name: Option<String>,
    pub username: Option<String>,
    pub goal: WeightGoal,
    pub share_latest_weight: bool,
    pub entries: Vec<WeighIn>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FriendWeighInSummary {
    pub uid: String,
    pub display_name: Option<String>,
    pub username: Option<String>,
    pub goal: WeightGoal,
    pub signed_change_grams: i64,
    pub weigh_in_count: usize,
    pub latest_weight_grams: Option<i64>,
    progress: i64,
}

pub fn validate_weight_grams(grams: i64) -> ApiResult<i64> {
    if (1..500_000).contains(&grams) {
        Ok(grams)
    } else {
        Err(ApiError::new(
            400,
            "invalid_weight",
            "Weight must be between 1 and 499999 grams.",
        ))
    }
}

pub fn parse_unit(value: &str) -> ApiResult<&'static str> {
    match value {
        "kg" => Ok("kg"),
        "lb" => Ok("lb"),
        _ => Err(ApiError::new(400, "invalid_unit", "Unit must be kg or lb.")),
    }
}

/// Summarize one opted-in person over the inclusive window.
///
/// Fewer than two weigh-ins returns `None` so the board omits them instead of
/// ranking a zero.
pub fn summarize_friend(
    candidate: FriendWeighInCandidate,
    window_start: &str,
    window_end: &str,
) -> Option<FriendWeighInSummary> {
    let mut entries: Vec<WeighIn> = candidate
        .entries
        .into_iter()
        .filter(|entry| {
            entry.recorded_on.as_str() >= window_start && entry.recorded_on.as_str() <= window_end
        })
        .collect();
    entries.sort_by(|left, right| left.recorded_on.cmp(&right.recorded_on));
    entries.dedup_by(|right, left| right.recorded_on == left.recorded_on);
    if entries.len() < MIN_WEIGH_INS {
        return None;
    }
    let baseline = entries.first()?.weight_grams;
    let current = entries.last()?.weight_grams;
    let signed_change_grams = current - baseline;
    let progress = match candidate.goal {
        WeightGoal::Lose => -signed_change_grams,
        WeightGoal::Gain => signed_change_grams,
        WeightGoal::Maintain => -signed_change_grams.abs(),
    };
    let latest_weight_grams = candidate.share_latest_weight.then_some(current);
    Some(FriendWeighInSummary {
        uid: candidate.uid,
        display_name: candidate.display_name,
        username: candidate.username,
        goal: candidate.goal,
        signed_change_grams,
        weigh_in_count: entries.len(),
        latest_weight_grams,
        progress,
    })
}

pub fn rank_friends(mut rows: Vec<FriendWeighInSummary>) -> Vec<FriendWeighInSummary> {
    rows.sort_by(|left, right| {
        right
            .progress
            .cmp(&left.progress)
            .then_with(|| right.weigh_in_count.cmp(&left.weigh_in_count))
            .then_with(|| left.uid.cmp(&right.uid))
    });
    rows
}

fn summary_json(row: &FriendWeighInSummary) -> serde_json::Value {
    let mut value = serde_json::json!({
        "uid": row.uid,
        "displayName": row.display_name,
        "username": row.username,
        "goal": row.goal.as_str(),
        "signedChangeGrams": row.signed_change_grams,
        "weighInCount": row.weigh_in_count,
    });
    if let Some(grams) = row.latest_weight_grams {
        value["latestWeightGrams"] = serde_json::json!(grams);
    }
    value
}

#[derive(Debug, Deserialize)]
struct EntryPut {
    #[serde(rename = "recordedOn")]
    recorded_on: String,
    #[serde(rename = "weightGrams")]
    weight_grams: i64,
}

#[derive(Debug, Deserialize)]
struct SettingsPut {
    unit: String,
    goal: String,
    #[serde(rename = "shareProgress")]
    share_progress: bool,
    #[serde(rename = "shareLatestWeight")]
    share_latest_weight: bool,
}

#[derive(Debug, Deserialize)]
struct EntryRow {
    recorded_on: String,
    weight_grams: i64,
    updated_at: String,
}

#[derive(Debug, Deserialize)]
struct SettingsRow {
    unit: String,
    goal: String,
    share_progress: i64,
    share_latest_weight: i64,
}

#[derive(Debug, Deserialize)]
struct BoardRow {
    uid: String,
    display_name: Option<String>,
    username: Option<String>,
    goal: String,
    share_latest_weight: i64,
    recorded_on: Option<String>,
    weight_grams: Option<i64>,
}

fn settings_json(row: &SettingsRow) -> serde_json::Value {
    serde_json::json!({
        "unit": row.unit,
        "goal": row.goal,
        "shareProgress": row.share_progress != 0,
        "shareLatestWeight": row.share_progress != 0 && row.share_latest_weight != 0,
    })
}

fn default_settings() -> serde_json::Value {
    serde_json::json!({
        "unit": "kg",
        "goal": "maintain",
        "shareProgress": false,
        "shareLatestWeight": false,
    })
}

pub async fn get_entries(
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let rows = db
        .prepare(
            "SELECT recorded_on, weight_grams, updated_at
             FROM weight_entries
             WHERE uid = ?
             ORDER BY recorded_on ASC",
        )
        .bind_refs(&[D1Type::Text(user.uid())])?
        .all()
        .await?
        .results::<EntryRow>()?;
    Ok(serde_json::json!({
        "entries": rows.iter().map(|row| serde_json::json!({
            "recordedOn": row.recorded_on,
            "weightGrams": row.weight_grams,
            "updatedAt": row.updated_at,
        })).collect::<Vec<_>>(),
    }))
}

pub async fn put_entry(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let payload: EntryPut = json_body(request).await?;
    let day = CalendarDayKey::parse(&payload.recorded_on)
        .ok_or_else(|| ApiError::new(400, "invalid_date", "recordedOn must be YYYY-MM-DD."))?;
    let grams = validate_weight_grams(payload.weight_grams)?;
    ensure_profile(db, user).await?;
    let now = now_iso();
    db.prepare(
        "INSERT INTO weight_entries (uid, recorded_on, weight_grams, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(uid, recorded_on) DO UPDATE SET
           weight_grams = excluded.weight_grams,
           updated_at = excluded.updated_at",
    )
    .bind_refs(&[
        D1Type::Text(user.uid()),
        D1Type::Text(day.as_str()),
        D1Type::Integer(i32::try_from(grams).map_err(|_| ApiError::internal())?),
        D1Type::Text(&now),
    ])?
    .run()
    .await?;
    Ok(serde_json::json!({
        "recordedOn": day.as_str(),
        "weightGrams": grams,
        "updatedAt": now,
    }))
}

pub async fn get_settings(
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let row = db
        .prepare(
            "SELECT unit, goal, share_progress, share_latest_weight
             FROM weight_settings WHERE uid = ?",
        )
        .bind_refs(&[D1Type::Text(user.uid())])?
        .first::<SettingsRow>(None)
        .await?;
    Ok(row
        .map(|row| settings_json(&row))
        .unwrap_or_else(default_settings))
}

pub async fn put_settings(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let payload: SettingsPut = json_body(request).await?;
    let unit = parse_unit(&payload.unit)?;
    let goal = WeightGoal::parse(&payload.goal).ok_or_else(|| {
        ApiError::new(400, "invalid_goal", "Goal must be lose, maintain, or gain.")
    })?;
    let share_progress = payload.share_progress;
    let share_latest = share_progress && payload.share_latest_weight;
    ensure_profile(db, user).await?;
    let now = now_iso();
    db.prepare(
        "INSERT INTO weight_settings (
           uid, unit, goal, share_progress, share_latest_weight, updated_at
         ) VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(uid) DO UPDATE SET
           unit = excluded.unit,
           goal = excluded.goal,
           share_progress = excluded.share_progress,
           share_latest_weight = excluded.share_latest_weight,
           updated_at = excluded.updated_at",
    )
    .bind_refs(&[
        D1Type::Text(user.uid()),
        D1Type::Text(unit),
        D1Type::Text(goal.as_str()),
        D1Type::Integer(i32::from(share_progress)),
        D1Type::Integer(i32::from(share_latest)),
        D1Type::Text(&now),
    ])?
    .run()
    .await?;
    Ok(serde_json::json!({
        "unit": unit,
        "goal": goal.as_str(),
        "shareProgress": share_progress,
        "shareLatestWeight": share_latest,
    }))
}

/// Removes every weigh-in and the settings row, so a reset also stops sharing.
pub async fn delete_all(db: &D1Database, user: &AuthenticatedUser) -> ApiResult<()> {
    db.batch(vec![
        db.prepare("DELETE FROM weight_entries WHERE uid = ?")
            .bind_refs(&[D1Type::Text(user.uid())])?,
        db.prepare("DELETE FROM weight_settings WHERE uid = ?")
            .bind_refs(&[D1Type::Text(user.uid())])?,
    ])
    .await?;
    Ok(())
}

pub async fn get_friends_board(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let url = request.url().map_err(|_| ApiError::internal())?;
    let as_of = url
        .query_pairs()
        .find(|(key, _)| key == "asOf")
        .and_then(|(_, value)| CalendarDayKey::parse(&value))
        .unwrap_or_else(today_key);
    let window_start =
        shift_day_key(as_of.as_str(), -WINDOW_DAYS).ok_or_else(ApiError::internal)?;
    let rows = db
        .prepare(
            "SELECT u.uid, u.display_name, u.username, s.goal, s.share_latest_weight,
                    e.recorded_on, e.weight_grams
             FROM weight_settings s
             JOIN users u ON u.uid = s.uid
             LEFT JOIN weight_entries e
               ON e.uid = s.uid AND e.recorded_on >= ? AND e.recorded_on <= ?
             WHERE s.share_progress = 1
               AND (
                 s.uid = ?
                 OR EXISTS (
                   SELECT 1 FROM friend_links links
                   WHERE links.owner_uid = ? AND links.friend_uid = s.uid
                 )
               )
               AND NOT EXISTS (
                 SELECT 1 FROM user_blocks blocks
                 WHERE (blocks.blocker_uid = ? AND blocks.blocked_uid = s.uid)
                    OR (blocks.blocker_uid = s.uid AND blocks.blocked_uid = ?)
               )
             ORDER BY u.uid ASC, e.recorded_on ASC",
        )
        .bind_refs(&[
            D1Type::Text(&window_start),
            D1Type::Text(as_of.as_str()),
            D1Type::Text(user.uid()),
            D1Type::Text(user.uid()),
            D1Type::Text(user.uid()),
            D1Type::Text(user.uid()),
        ])?
        .all()
        .await?
        .results::<BoardRow>()?;

    let mut grouped: Vec<FriendWeighInCandidate> = Vec::new();
    for row in rows {
        let goal = WeightGoal::parse(&row.goal).unwrap_or(WeightGoal::Maintain);
        if grouped.last().map(|item| item.uid.as_str()) != Some(row.uid.as_str()) {
            grouped.push(FriendWeighInCandidate {
                uid: row.uid.clone(),
                display_name: row.display_name.clone(),
                username: row.username.clone(),
                goal,
                share_latest_weight: row.share_latest_weight != 0,
                entries: Vec::new(),
            });
        }
        if let (Some(recorded_on), Some(weight_grams)) = (row.recorded_on, row.weight_grams) {
            grouped
                .last_mut()
                .expect("group was just pushed")
                .entries
                .push(WeighIn {
                    recorded_on,
                    weight_grams,
                });
        }
    }

    let ranked = rank_friends(
        grouped
            .into_iter()
            .filter_map(|candidate| summarize_friend(candidate, &window_start, as_of.as_str()))
            .collect(),
    );
    Ok(serde_json::json!({
        "asOf": as_of.as_str(),
        "windowStart": window_start,
        "entries": ranked.iter().map(summary_json).collect::<Vec<_>>(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn candidate(
        uid: &str,
        goal: WeightGoal,
        share_latest: bool,
        entries: &[(&str, i64)],
    ) -> FriendWeighInCandidate {
        FriendWeighInCandidate {
            uid: uid.into(),
            display_name: Some(uid.into()),
            username: Some(uid.into()),
            goal,
            share_latest_weight: share_latest,
            entries: entries
                .iter()
                .map(|(day, grams)| WeighIn {
                    recorded_on: (*day).into(),
                    weight_grams: *grams,
                })
                .collect(),
        }
    }

    #[test]
    fn replace_same_day_is_a_storage_constraint_and_grams_bounds_reject_zero() {
        assert!(validate_weight_grams(0).is_err());
        assert!(validate_weight_grams(500_000).is_err());
        assert_eq!(validate_weight_grams(72_500).unwrap(), 72_500);
    }

    #[test]
    fn maintain_ranks_smaller_absolute_change_first() {
        let start = "2026-09-01";
        let end = "2026-09-27";
        let larger = summarize_friend(
            candidate(
                "a",
                WeightGoal::Maintain,
                false,
                &[("2026-09-01", 70_000), ("2026-09-20", 69_600)],
            ),
            start,
            end,
        )
        .unwrap();
        let smaller = summarize_friend(
            candidate(
                "b",
                WeightGoal::Maintain,
                false,
                &[("2026-09-02", 80_000), ("2026-09-21", 80_100)],
            ),
            start,
            end,
        )
        .unwrap();
        let ranked = rank_friends(vec![larger, smaller]);
        assert_eq!(ranked[0].uid, "b");
        assert!(ranked[0].latest_weight_grams.is_none());
    }

    #[test]
    fn one_weigh_in_is_omitted() {
        let summary = summarize_friend(
            candidate("solo", WeightGoal::Lose, true, &[("2026-09-10", 70_000)]),
            "2026-09-01",
            "2026-09-27",
        );
        assert!(summary.is_none());
    }

    #[test]
    fn latest_weight_is_included_only_when_shared() {
        let shared = summarize_friend(
            candidate(
                "ana",
                WeightGoal::Lose,
                true,
                &[("2026-09-01", 70_000), ("2026-09-20", 69_200)],
            ),
            "2026-09-01",
            "2026-09-27",
        )
        .unwrap();
        assert_eq!(shared.signed_change_grams, -800);
        assert_eq!(shared.latest_weight_grams, Some(69_200));
        let hidden = summary_json(&FriendWeighInSummary {
            latest_weight_grams: None,
            ..shared
        });
        assert!(hidden.get("latestWeightGrams").is_none());
    }

    #[test]
    fn lose_goal_ranks_larger_loss_first() {
        let start = "2026-09-01";
        let end = "2026-09-27";
        let small = summarize_friend(
            candidate(
                "small",
                WeightGoal::Lose,
                false,
                &[("2026-09-01", 70_000), ("2026-09-20", 69_800)],
            ),
            start,
            end,
        )
        .unwrap();
        let large = summarize_friend(
            candidate(
                "large",
                WeightGoal::Lose,
                false,
                &[("2026-09-01", 70_000), ("2026-09-20", 68_000)],
            ),
            start,
            end,
        )
        .unwrap();
        let ranked = rank_friends(vec![small, large]);
        assert_eq!(ranked[0].uid, "large");
    }

    #[test]
    fn entries_outside_the_window_do_not_count() {
        let summary = summarize_friend(
            candidate(
                "old",
                WeightGoal::Gain,
                false,
                &[("2026-08-01", 60_000), ("2026-09-20", 61_000)],
            ),
            "2026-09-01",
            "2026-09-27",
        );
        assert!(summary.is_none());
    }
}
