//! Owns friendships and friend requests: the `friend_links` and
//! `friend_requests` tables. Reuses `profile::ProfileRow`/`profile_json`
//! for every friend-shaped row this module returns.

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Request};

use crate::db::{now_iso, today_key, valid_calendar_day_key, week_start};
use crate::env::AuthenticatedUser;
use crate::error::{ApiError, ApiResult};
use crate::profile::{ensure_profile, profile_json, profile_row, ProfileRow};

pub async fn get_friends(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    ensure_profile(db, user).await?;
    let url = request.url()?;
    let params: std::collections::HashMap<_, _> = url.query_pairs().into_owned().collect();
    let day_key =
        valid_calendar_day_key(params.get("dayKey").map(String::as_str)).unwrap_or_else(today_key);
    let week_key = valid_calendar_day_key(params.get("weekKey").map(String::as_str))
        .unwrap_or_else(|| week_start(&day_key));

    let rows = db
        .prepare(
            "SELECT
              friend.uid, NULL AS email, friend.display_name, friend.photo_url,
              friend.username, friend.username_lower, friend.created_at,
              friend.updated_at,
              CASE WHEN stats.today_key = ? THEN stats.today_count ELSE 0 END AS today_count,
              CASE WHEN stats.week_key = ? THEN stats.week_count ELSE 0 END AS week_count,
              stats.total_all_time, stats.best_day, stats.streak
            FROM friend_links links
            JOIN users friend ON friend.uid = links.friend_uid
            LEFT JOIN friend_stats stats ON stats.uid = friend.uid
            WHERE links.owner_uid = ?
            ORDER BY stats.today_count DESC, friend.username_lower ASC",
        )
        .bind_refs(&[
            D1Type::Text(&day_key),
            D1Type::Text(&week_key),
            D1Type::Text(user.uid()),
        ])?
        .all()
        .await?
        .results::<ProfileRow>()?;

    Ok(serde_json::json!({
        "friends": rows.iter().map(|row| profile_json(row, false)).collect::<Vec<_>>(),
    }))
}

#[derive(Debug, Deserialize)]
struct FriendRequestRow {
    uid: String,
    display_name: Option<String>,
    photo_url: Option<String>,
    username: Option<String>,
    username_lower: Option<String>,
    created_at: Option<String>,
    updated_at: String,
    today_count: Option<i64>,
    week_count: Option<i64>,
    total_all_time: Option<i64>,
    best_day: Option<i64>,
    streak: Option<i64>,
    request_created_at: Option<String>,
}

pub async fn get_friend_requests(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    ensure_profile(db, user).await?;
    let url = request.url()?;
    let direction = url
        .query_pairs()
        .find(|(key, _)| key == "direction")
        .map(|(_, value)| value.into_owned());
    let (owner_column, other_column) = match direction.as_deref() {
        Some("incoming") => ("receiver_uid", "sender_uid"),
        Some("outgoing") => ("sender_uid", "receiver_uid"),
        _ => {
            return Err(ApiError::new(
                422,
                "invalid_direction",
                "Direction must be incoming or outgoing.",
            ))
        }
    };

    let rows = db
        .prepare(format!(
            "SELECT
              other.uid, NULL AS email, other.display_name, other.photo_url,
              other.username, other.username_lower, other.created_at,
              other.updated_at, stats.today_count, stats.week_count,
              stats.total_all_time, stats.best_day, stats.streak,
              requests.created_at AS request_created_at
            FROM friend_requests requests
            JOIN users other ON other.uid = requests.{other_column}
            LEFT JOIN friend_stats stats ON stats.uid = other.uid
            WHERE requests.{owner_column} = ? AND requests.status = 'pending'
            ORDER BY requests.created_at DESC"
        ))
        .bind_refs(&[D1Type::Text(user.uid())])?
        .all()
        .await?
        .results::<FriendRequestRow>()?;

    let requests = rows
        .into_iter()
        .map(|row| {
            let request_created_at = row.request_created_at.clone();
            let profile = ProfileRow {
                uid: row.uid,
                email: None,
                display_name: row.display_name,
                photo_url: row.photo_url,
                username: row.username,
                username_lower: row.username_lower,
                created_at: row.created_at,
                updated_at: row.updated_at,
                today_count: row.today_count,
                week_count: row.week_count,
                total_all_time: row.total_all_time,
                best_day: row.best_day,
                streak: row.streak,
            };
            let mut json = profile_json(&profile, false);
            json["createdAt"] = serde_json::json!(request_created_at);
            json
        })
        .collect::<Vec<_>>();
    Ok(serde_json::json!({"requests": requests}))
}

async fn uid_from_body(request: &mut Request, key: &str) -> ApiResult<String> {
    let body: serde_json::Value = request.json().await.map_err(|_| ApiError::invalid_json())?;
    if !body.is_object() {
        return Err(ApiError::invalid_json());
    }
    body.get(key)
        .and_then(|v| v.as_str())
        .filter(|uid| !uid.is_empty() && uid.len() <= 128)
        .map(str::to_string)
        .ok_or_else(|| ApiError::new(422, "invalid_uid", format!("{key} is invalid.")))
}

pub async fn send_friend_request(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<(serde_json::Value, u16)> {
    let receiver_uid = uid_from_body(request, "receiverUid").await?;
    if receiver_uid == user.uid() {
        return Err(ApiError::new(
            422,
            "invalid_friend",
            "You cannot add yourself.",
        ));
    }
    ensure_profile(db, user).await?;
    if profile_row(db, &receiver_uid).await?.is_none() {
        return Err(ApiError::new(
            404,
            "profile_not_found",
            "That profile no longer exists.",
        ));
    }

    let already_friends = db
        .prepare("SELECT 1 AS found FROM friend_links WHERE owner_uid = ? AND friend_uid = ?")
        .bind_refs(&[D1Type::Text(user.uid()), D1Type::Text(&receiver_uid)])?
        .first::<serde_json::Value>(None)
        .await?
        .is_some();
    if already_friends {
        return Ok((serde_json::json!({"status": "already_friends"}), 200));
    }

    let reciprocal = db
        .prepare(
            "SELECT 1 AS found FROM friend_requests
             WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'",
        )
        .bind_refs(&[D1Type::Text(&receiver_uid), D1Type::Text(user.uid())])?
        .first::<serde_json::Value>(None)
        .await?
        .is_some();
    if reciprocal {
        accept(db, user.uid(), &receiver_uid).await?;
        return Ok((serde_json::json!({"status": "accepted"}), 200));
    }

    let now = now_iso();
    db.prepare(
        "INSERT INTO friend_requests (
          sender_uid, receiver_uid, status, created_at, updated_at
        ) VALUES (?, ?, 'pending', ?, ?)
        ON CONFLICT(sender_uid, receiver_uid) DO UPDATE SET
          status = 'pending', created_at = excluded.created_at,
          updated_at = excluded.updated_at",
    )
    .bind_refs(&[
        D1Type::Text(user.uid()),
        D1Type::Text(&receiver_uid),
        D1Type::Text(&now),
        D1Type::Text(&now),
    ])?
    .run()
    .await?;
    Ok((serde_json::json!({"status": "pending"}), 201))
}

pub async fn accept_friend_request(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let requester_uid = uid_from_body(request, "requesterUid").await?;
    let pending = db
        .prepare(
            "SELECT 1 AS found FROM friend_requests
             WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'",
        )
        .bind_refs(&[D1Type::Text(&requester_uid), D1Type::Text(user.uid())])?
        .first::<serde_json::Value>(None)
        .await?;
    if pending.is_none() {
        return Err(ApiError::new(
            404,
            "request_not_found",
            "That friend request is no longer open.",
        ));
    }
    accept(db, user.uid(), &requester_uid).await?;
    Ok(serde_json::json!({"status": "accepted"}))
}

pub async fn decline_friend_request(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<()> {
    let requester_uid = uid_from_body(request, "requesterUid").await?;
    let now = now_iso();
    db.prepare(
        "UPDATE friend_requests SET status = 'declined', updated_at = ?
         WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'",
    )
    .bind_refs(&[
        D1Type::Text(&now),
        D1Type::Text(&requester_uid),
        D1Type::Text(user.uid()),
    ])?
    .run()
    .await?;
    Ok(())
}

pub async fn cancel_friend_request(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<()> {
    let receiver_uid = uid_from_body(request, "receiverUid").await?;
    let now = now_iso();
    db.prepare(
        "UPDATE friend_requests SET status = 'cancelled', updated_at = ?
         WHERE sender_uid = ? AND receiver_uid = ? AND status = 'pending'",
    )
    .bind_refs(&[
        D1Type::Text(&now),
        D1Type::Text(user.uid()),
        D1Type::Text(&receiver_uid),
    ])?
    .run()
    .await?;
    Ok(())
}

pub async fn remove_friend(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<()> {
    let friend_uid = uid_from_body(request, "friendUid").await?;
    let now = now_iso();
    db.batch(vec![
        db.prepare(
            "DELETE FROM friend_links
             WHERE (owner_uid = ? AND friend_uid = ?)
                OR (owner_uid = ? AND friend_uid = ?)",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(&friend_uid),
            D1Type::Text(&friend_uid),
            D1Type::Text(user.uid()),
        ])?,
        db.prepare(
            "UPDATE friend_requests SET status = 'cancelled', updated_at = ?
             WHERE ((sender_uid = ? AND receiver_uid = ?)
                OR (sender_uid = ? AND receiver_uid = ?))
               AND status = 'pending'",
        )
        .bind_refs(&[
            D1Type::Text(&now),
            D1Type::Text(user.uid()),
            D1Type::Text(&friend_uid),
            D1Type::Text(&friend_uid),
            D1Type::Text(user.uid()),
        ])?,
    ])
    .await?;
    Ok(())
}

async fn accept(db: &D1Database, receiver_uid: &str, requester_uid: &str) -> ApiResult<()> {
    let now = now_iso();
    db.batch(vec![
        db.prepare(
            "INSERT INTO friend_links (owner_uid, friend_uid, added_at, source_json)
             VALUES (?, ?, ?, '{}')
             ON CONFLICT(owner_uid, friend_uid) DO UPDATE SET added_at = excluded.added_at",
        )
        .bind_refs(&[
            D1Type::Text(receiver_uid),
            D1Type::Text(requester_uid),
            D1Type::Text(&now),
        ])?,
        db.prepare(
            "INSERT INTO friend_links (owner_uid, friend_uid, added_at, source_json)
             VALUES (?, ?, ?, '{}')
             ON CONFLICT(owner_uid, friend_uid) DO UPDATE SET added_at = excluded.added_at",
        )
        .bind_refs(&[
            D1Type::Text(requester_uid),
            D1Type::Text(receiver_uid),
            D1Type::Text(&now),
        ])?,
        db.prepare(
            "UPDATE friend_requests SET status = 'accepted', updated_at = ?
             WHERE ((sender_uid = ? AND receiver_uid = ?)
                OR (sender_uid = ? AND receiver_uid = ?))
               AND status = 'pending'",
        )
        .bind_refs(&[
            D1Type::Text(&now),
            D1Type::Text(requester_uid),
            D1Type::Text(receiver_uid),
            D1Type::Text(receiver_uid),
            D1Type::Text(requester_uid),
        ])?,
    ])
    .await?;
    Ok(())
}
