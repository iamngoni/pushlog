//! Owns the `notification_events` inbox and lead-change detection: when a
//! stored workout snapshot pushes a user's today-count past a friend's,
//! this module records the event and hands it to `push` for delivery.
//!
//! Delivery failure never fails the triggering request — `notify_friends_passed`
//! runs from `workout::put_workout_snapshot`'s `ctx.wait_until`, after the
//! response has already been sent.

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Env, Request};

use crate::db::{now_iso, opt_text};
use crate::env::{AppConfig, AuthenticatedUser};
use crate::error::{ApiError, ApiResult};
use crate::lead_change_copy::{build_lead_change_copy, random_variant_index, LeadChangeInput};
use crate::push;

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

fn clamp_limit(raw: Option<&str>) -> i64 {
    raw.and_then(|v| v.parse::<i64>().ok())
        .map(|n| n.clamp(1, 100))
        .unwrap_or(25)
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
            serde_json::json!({
                "notificationId": row.notification_id,
                "type": row.kind,
                "title": row.title,
                "body": row.body,
                "actorUid": row.actor_uid,
                "competitorUid": row.competitor_uid,
                "dayKey": row.day_key,
                "payload": serde_json::from_str::<serde_json::Value>(&row.payload_json)
                    .unwrap_or_else(|_| serde_json::json!({})),
                "createdAt": row.created_at,
            })
        })
        .collect::<Vec<_>>();
    Ok(serde_json::json!({"notifications": notifications}))
}

pub async fn mark_notifications_read(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let body: serde_json::Value = request.json().await.map_err(|_| ApiError::invalid_json())?;
    let ids = body
        .get("notificationIds")
        .and_then(|v| v.as_array())
        .filter(|ids| {
            !ids.is_empty()
                && ids.len() <= 100
                && ids
                    .iter()
                    .all(|id| id.as_str().is_some_and(|s| !s.is_empty() && s.len() <= 128))
        })
        .ok_or_else(|| {
            ApiError::new(
                422,
                "invalid_notifications",
                "notificationIds must contain between 1 and 100 notification IDs.",
            )
        })?
        .iter()
        .map(|v| v.as_str().expect("validated above").to_string())
        .collect::<Vec<_>>();

    let placeholders = std::iter::repeat_n("?", ids.len())
        .collect::<Vec<_>>()
        .join(", ");
    let now = now_iso();
    let mut params = vec![D1Type::Text(&now), D1Type::Text(user.uid())];
    params.extend(ids.iter().map(|id| D1Type::Text(id)));
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
) -> ApiResult<()> {
    if current_count <= previous_count {
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
        let friend_count = if friend.today_key.as_deref() == Some(day_key) {
            friend.today_count
        } else {
            0
        };
        let notification_id = uuid::Uuid::new_v4().to_string();
        let deficit = current_count - friend_count;
        let copy = build_lead_change_copy(
            &LeadChangeInput {
                actor: actor_name.clone(),
                deficit,
                reps_to_retake: deficit + 1,
            },
            random_variant_index(),
        );
        let now = now_iso();
        let payload_json =
            serde_json::json!({"score": current_count, "previousLead": friend_count}).to_string();

        db.prepare(
            "INSERT INTO notification_events (
              uid, notification_id, type, title, body, actor_uid,
              competitor_uid, day_key, delivery_status, payload_json, created_at
            ) VALUES (?, ?, 'lead_change', ?, ?, ?, ?, ?, 'pending', ?, ?)",
        )
        .bind_refs(&[
            D1Type::Text(&friend.uid),
            D1Type::Text(&notification_id),
            D1Type::Text(&copy.title),
            D1Type::Text(&copy.body),
            D1Type::Text(actor_uid),
            D1Type::Text(actor_uid),
            D1Type::Text(day_key),
            D1Type::Text(&payload_json),
            D1Type::Text(&now),
        ])?
        .run()
        .await?;

        let data = [
            ("type", "lead_change".to_string()),
            ("notificationId", notification_id.clone()),
            ("actorUid", actor_uid.to_string()),
            ("competitorUid", actor_uid.to_string()),
            ("dayKey", day_key.to_string()),
            ("score", current_count.to_string()),
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
}
