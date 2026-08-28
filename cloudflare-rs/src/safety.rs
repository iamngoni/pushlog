//! User safety for the small social surface in Pushlog. A report also blocks
//! both discovery and future contact immediately; moderation can happen later,
//! but the person reporting never has to wait to be separated from the account.

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Request};

use crate::db::now_iso;
use crate::env::AuthenticatedUser;
use crate::error::{json_body, ApiError, ApiResult};
use crate::profile::{ensure_profile, profile_row};
use crate::safety_validation::ReportReason;

#[derive(Debug, Deserialize)]
struct ReportBody {
    #[serde(rename = "reportedUid")]
    reported_uid: String,
    reason: String,
}

pub async fn report_and_block(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let body: ReportBody = json_body(request).await?;
    let reported_uid = body.reported_uid.trim();
    if reported_uid.is_empty() || reported_uid.len() > 128 || reported_uid == user.uid() {
        return Err(ApiError::new(
            422,
            "invalid_reported_user",
            "The reported account is invalid.",
        ));
    }
    let reason = ReportReason::parse(body.reason.trim()).ok_or_else(|| {
        ApiError::new(
            422,
            "invalid_report_reason",
            "The report reason is invalid.",
        )
    })?;

    ensure_profile(db, user).await?;
    if profile_row(db, reported_uid).await?.is_none() {
        return Err(ApiError::new(
            404,
            "profile_not_found",
            "That profile no longer exists.",
        ));
    }

    let report_id = uuid::Uuid::new_v4().to_string();
    let now = now_iso();
    db.batch(vec![
        db.prepare(
            "INSERT INTO user_reports (
               report_id, reporter_uid, reported_uid, reason, status, created_at
             ) VALUES (?, ?, ?, ?, 'open', ?)",
        )
        .bind_refs(&[
            D1Type::Text(&report_id),
            D1Type::Text(user.uid()),
            D1Type::Text(reported_uid),
            D1Type::Text(reason.as_str()),
            D1Type::Text(&now),
        ])?,
        db.prepare(
            "INSERT INTO user_blocks (blocker_uid, blocked_uid, created_at)
             VALUES (?, ?, ?)
             ON CONFLICT(blocker_uid, blocked_uid) DO NOTHING",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(reported_uid),
            D1Type::Text(&now),
        ])?,
        db.prepare(
            "DELETE FROM friend_links
             WHERE (owner_uid = ? AND friend_uid = ?)
                OR (owner_uid = ? AND friend_uid = ?)",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(reported_uid),
            D1Type::Text(reported_uid),
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
            D1Type::Text(reported_uid),
            D1Type::Text(reported_uid),
            D1Type::Text(user.uid()),
        ])?,
    ])
    .await?;

    Ok(serde_json::json!({"status": "reported_and_blocked"}))
}
