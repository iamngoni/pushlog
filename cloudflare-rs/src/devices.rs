//! Owns the `devices` table: push-token registration. A token is always
//! reassigned to whichever account most recently registered it — the same
//! physical device can only ever forward pushes to one signed-in user.

use worker::d1::D1Type;
use worker::{D1Database, Request};

use crate::db::{now_iso, opt_text};
use crate::env::AuthenticatedUser;
use crate::error::{json_body, ApiError, ApiResult};
use crate::profile::ensure_profile;

const ALLOWED_PLATFORMS: &[&str] = &["android", "ios", "macos"];

struct DevicePayload {
    token: String,
    platform: Option<String>,
}

async fn device_payload(request: &mut Request, require_platform: bool) -> ApiResult<DevicePayload> {
    let body: serde_json::Value = json_body(request).await?;
    if !body.is_object() {
        return Err(ApiError::invalid_json());
    }
    let token = body
        .get("token")
        .and_then(|v| v.as_str())
        .filter(|t| (16..=4_096).contains(&t.len()))
        .ok_or_else(|| ApiError::new(422, "invalid_token", "The device token is invalid."))?
        .to_string();
    let platform = body
        .get("platform")
        .and_then(|v| v.as_str())
        .filter(|p| ALLOWED_PLATFORMS.contains(p))
        .map(str::to_string);
    if require_platform && platform.is_none() {
        return Err(ApiError::new(
            422,
            "invalid_platform",
            "The device platform is invalid.",
        ));
    }
    Ok(DevicePayload { token, platform })
}

pub async fn register_device(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let payload = device_payload(request, true).await?;
    ensure_profile(db, user).await?;
    let now = now_iso();
    db.batch(vec![
        db.prepare("DELETE FROM devices WHERE token = ? AND uid <> ?")
            .bind_refs(&[D1Type::Text(&payload.token), D1Type::Text(user.uid())])?,
        db.prepare(
            "INSERT INTO devices (uid, token, platform, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(uid, token) DO UPDATE SET
               platform = excluded.platform, updated_at = excluded.updated_at",
        )
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(&payload.token),
            opt_text(payload.platform.as_deref()),
            D1Type::Text(&now),
        ])?,
    ])
    .await?;
    Ok(serde_json::json!({"status": "registered"}))
}

pub async fn unregister_device(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<()> {
    let payload = device_payload(request, false).await?;
    db.prepare("DELETE FROM devices WHERE uid = ? AND token = ?")
        .bind_refs(&[D1Type::Text(user.uid()), D1Type::Text(&payload.token)])?
        .run()
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allowed_platforms_matches_the_documented_set() {
        assert_eq!(ALLOWED_PLATFORMS, ["android", "ios", "macos"]);
    }
}
