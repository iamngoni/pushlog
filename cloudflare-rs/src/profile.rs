//! Owns the `users` / `username_claims` tables: profile upsert, username
//! claiming, and the leaderboard-joined profile projection that `friends`
//! reuses for every friend/request listing.

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Request};

use crate::db::{now_iso, opt_text};
use crate::env::AuthenticatedUser;
use crate::error::{json_body, ApiError, ApiResult};

#[derive(Debug, Clone, Deserialize)]
pub struct ProfileRow {
    pub uid: String,
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub photo_url: Option<String>,
    pub username: Option<String>,
    pub username_lower: Option<String>,
    pub created_at: Option<String>,
    pub updated_at: String,
    pub today_count: Option<i64>,
    pub week_count: Option<i64>,
    pub total_all_time: Option<i64>,
    pub best_day: Option<i64>,
    pub streak: Option<i64>,
}

fn clean_optional(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    (!trimmed.is_empty()).then(|| trimmed.to_string())
}

const PROFILE_SELECT: &str = "SELECT
    u.uid, u.email, u.display_name, u.photo_url, u.username,
    u.username_lower, u.created_at, u.updated_at,
    fs.today_count, fs.week_count, fs.total_all_time, fs.best_day, fs.streak
  FROM users u
  LEFT JOIN friend_stats fs ON fs.uid = u.uid";

pub(crate) async fn profile_row(db: &D1Database, uid: &str) -> ApiResult<Option<ProfileRow>> {
    let row = db
        .prepare(format!("{PROFILE_SELECT} WHERE u.uid = ?"))
        .bind_refs(&[D1Type::Text(uid)])?
        .first::<ProfileRow>(None)
        .await?;
    Ok(row)
}

/// Renders a stored row into the wire shape every profile-bearing endpoint
/// returns. `include_email` is false for anything visible to someone other
/// than the profile's owner (friends, search, friend requests).
pub(crate) fn profile_json(row: &ProfileRow, include_email: bool) -> serde_json::Value {
    let mut value = serde_json::json!({
        "uid": row.uid,
        "displayName": row.display_name,
        "photoUrl": row.photo_url,
        "username": row.username,
        "usernameLower": row.username_lower,
        "todayCount": row.today_count.unwrap_or(0),
        "weekCount": row.week_count.unwrap_or(0),
        "totalAllTime": row.total_all_time.unwrap_or(0),
        "bestDay": row.best_day.unwrap_or(0),
        "streak": row.streak.unwrap_or(0),
        "createdAt": row.created_at,
        "updatedAt": row.updated_at,
    });
    if include_email {
        value["email"] = serde_json::json!(row.email);
    }
    value
}

/// Creates the caller's profile row if it does not exist yet, and refreshes
/// display name / photo / email from the verified token on every call
/// (username is untouched here — only `claim_username` changes it).
pub(crate) async fn ensure_profile(
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<ProfileRow> {
    let existing = profile_row(db, user.uid()).await?;
    let now = now_iso();

    let display_name = clean_optional(user.name())
        .or_else(|| {
            existing
                .as_ref()
                .and_then(|r| clean_optional(r.display_name.as_deref()))
        })
        .or_else(|| {
            existing
                .as_ref()
                .and_then(|r| clean_optional(r.username.as_deref()))
        })
        .unwrap_or_else(|| "Pusher".to_string());
    let photo_url = clean_optional(user.picture())
        .or_else(|| existing.as_ref().and_then(|r| r.photo_url.clone()));
    let email =
        clean_optional(user.email()).or_else(|| existing.as_ref().and_then(|r| r.email.clone()));
    let created_at = existing
        .as_ref()
        .and_then(|r| r.created_at.clone())
        .unwrap_or_else(|| now.clone());
    let username = existing.as_ref().and_then(|r| r.username.clone());
    let username_lower = existing.as_ref().and_then(|r| r.username_lower.clone());

    let private_json = serde_json::json!({
        "uid": user.uid(), "email": email, "displayName": display_name,
        "photoUrl": photo_url, "username": username, "usernameLower": username_lower,
        "createdAt": created_at, "updatedAt": now,
    })
    .to_string();
    let public_json = serde_json::json!({
        "uid": user.uid(), "displayName": display_name, "photoUrl": photo_url,
        "username": username, "usernameLower": username_lower,
        "createdAt": created_at, "updatedAt": now,
    })
    .to_string();

    db.prepare(
        "INSERT INTO users (
          uid, email, display_name, photo_url, username, username_lower,
          private_json, public_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(uid) DO UPDATE SET
          email = excluded.email,
          display_name = excluded.display_name,
          photo_url = excluded.photo_url,
          private_json = excluded.private_json,
          public_json = excluded.public_json,
          updated_at = excluded.updated_at",
    )
    .bind_refs(&[
        D1Type::Text(user.uid()),
        opt_text(email.as_deref()),
        D1Type::Text(&display_name),
        opt_text(photo_url.as_deref()),
        opt_text(username.as_deref()),
        opt_text(username_lower.as_deref()),
        D1Type::Text(&private_json),
        D1Type::Text(&public_json),
        D1Type::Text(&created_at),
        D1Type::Text(&now),
    ])?
    .run()
    .await?;

    profile_row(db, user.uid())
        .await?
        .ok_or_else(ApiError::internal)
}

pub async fn get_own_profile(
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let row = ensure_profile(db, user).await?;
    Ok(serde_json::json!({"profile": profile_json(&row, true)}))
}

struct Username {
    display: String,
    normalized: String,
}

impl Username {
    fn parse(raw: &str) -> Option<Self> {
        let display = raw.trim().to_string();
        let normalized = display.to_lowercase();
        let len = normalized.len();
        ((3..=20).contains(&len)
            && normalized
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'_'))
        .then_some(Self {
            display,
            normalized,
        })
    }
}

pub async fn claim_username(
    request: &mut Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let body: serde_json::Value = json_body(request).await?;
    let raw_username = body
        .get("username")
        .and_then(|v| v.as_str())
        .ok_or_else(|| ApiError::new(422, "invalid_username", "A username is required."))?;
    let username = Username::parse(raw_username).ok_or_else(|| {
        ApiError::new(
            422,
            "invalid_username",
            "Use 3-20 letters, numbers, or underscores.",
        )
    })?;
    let normalized = &username.normalized;
    let username = &username.display;

    let current = ensure_profile(db, user).await?;
    let owner = db
        .prepare("SELECT uid FROM username_claims WHERE username_lower = ?")
        .bind_refs(&[D1Type::Text(normalized)])?
        .first::<OwnerRow>(None)
        .await?;
    if let Some(owner) = &owner {
        if owner.uid != user.uid() {
            return Err(username_taken());
        }
    }

    let now = now_iso();
    let display_name = clean_optional(user.name())
        .or_else(|| current.display_name.clone())
        .unwrap_or_else(|| username.to_string());
    let private_json = serde_json::json!({
        "uid": user.uid(), "email": current.email, "displayName": display_name,
        "photoUrl": current.photo_url, "username": username, "usernameLower": normalized,
        "createdAt": current.created_at, "updatedAt": now,
    })
    .to_string();
    let public_json = serde_json::json!({
        "uid": user.uid(), "displayName": display_name, "photoUrl": current.photo_url,
        "username": username, "usernameLower": normalized,
        "createdAt": current.created_at, "updatedAt": now,
    })
    .to_string();
    let claim_json = serde_json::json!({
        "uid": user.uid(), "username": username, "usernameLower": normalized,
    })
    .to_string();

    let mut statements = Vec::new();
    if let Some(previous) = current.username_lower.as_deref() {
        if previous != normalized {
            statements.push(
                db.prepare("DELETE FROM username_claims WHERE username_lower = ? AND uid = ?")
                    .bind_refs(&[D1Type::Text(previous), D1Type::Text(user.uid())])?,
            );
        }
    }
    statements.push(if owner.is_none() {
        db.prepare(
            "INSERT INTO username_claims (
              username_lower, uid, username, source_json, updated_at
            ) VALUES (?, ?, ?, ?, ?)",
        )
        .bind_refs(&[
            D1Type::Text(normalized),
            D1Type::Text(user.uid()),
            D1Type::Text(username),
            D1Type::Text(&claim_json),
            D1Type::Text(&now),
        ])?
    } else {
        db.prepare(
            "UPDATE username_claims
             SET username = ?, source_json = ?, updated_at = ?
             WHERE username_lower = ? AND uid = ?",
        )
        .bind_refs(&[
            D1Type::Text(username),
            D1Type::Text(&claim_json),
            D1Type::Text(&now),
            D1Type::Text(normalized),
            D1Type::Text(user.uid()),
        ])?
    });
    statements.push(
        db.prepare(
            "UPDATE users SET
              display_name = ?, username = ?, username_lower = ?,
              private_json = ?, public_json = ?, updated_at = ?
            WHERE uid = ?",
        )
        .bind_refs(&[
            D1Type::Text(&display_name),
            D1Type::Text(username),
            D1Type::Text(normalized),
            D1Type::Text(&private_json),
            D1Type::Text(&public_json),
            D1Type::Text(&now),
            D1Type::Text(user.uid()),
        ])?,
    );

    let results = db.batch(statements).await?;
    for result in &results {
        if !result.success() {
            let message = result.error().unwrap_or_default();
            if message.contains("UNIQUE constraint failed") {
                return Err(username_taken());
            }
            return Err(ApiError::internal());
        }
    }

    let updated = profile_row(db, user.uid())
        .await?
        .ok_or_else(ApiError::internal)?;
    Ok(serde_json::json!({"profile": profile_json(&updated, true)}))
}

fn username_taken() -> ApiError {
    ApiError::new(409, "username_taken", "That username is already taken.")
}

#[derive(Debug, Deserialize)]
struct OwnerRow {
    uid: String,
}

struct SearchQuery(String);

impl SearchQuery {
    fn parse(raw: &str) -> Option<Self> {
        let query = raw.trim().to_lowercase();
        let len = query.len();
        ((2..=20).contains(&len)
            && query
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'_'))
        .then_some(Self(query))
    }

    fn as_str(&self) -> &str {
        &self.0
    }
}

pub async fn search_profiles(
    request: &Request,
    db: &D1Database,
    user: &AuthenticatedUser,
) -> ApiResult<serde_json::Value> {
    let url = request.url()?;
    let query = url
        .query_pairs()
        .find(|(key, _)| key == "q")
        .and_then(|(_, value)| SearchQuery::parse(&value));
    let Some(query) = query else {
        return Ok(serde_json::json!({"profiles": []}));
    };

    let upper_bound = format!("{}\u{f8ff}", query.as_str());
    let rows = db
        .prepare(format!(
            "{PROFILE_SELECT}
             WHERE u.uid <> ?
               AND u.username_lower >= ? AND u.username_lower < ?
               AND NOT EXISTS (
                 SELECT 1 FROM user_blocks blocks
                 WHERE (blocks.blocker_uid = ? AND blocks.blocked_uid = u.uid)
                    OR (blocks.blocker_uid = u.uid AND blocks.blocked_uid = ?)
               )
             ORDER BY u.username_lower ASC
             LIMIT 8"
        ))
        .bind_refs(&[
            D1Type::Text(user.uid()),
            D1Type::Text(query.as_str()),
            D1Type::Text(&upper_bound),
            D1Type::Text(user.uid()),
            D1Type::Text(user.uid()),
        ])?
        .all()
        .await?
        .results::<ProfileRow>()?;

    Ok(serde_json::json!({
        "profiles": rows.iter().map(|row| profile_json(row, false)).collect::<Vec<_>>(),
    }))
}

pub async fn delete_account_data(db: &D1Database, user: &AuthenticatedUser) -> ApiResult<()> {
    db.prepare("DELETE FROM users WHERE uid = ?")
        .bind_refs(&[D1Type::Text(user.uid())])?
        .run()
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn username_validity() {
        let username = Username::parse(" Ana_123 ").expect("valid username");
        assert_eq!(username.display, "Ana_123");
        assert_eq!(username.normalized, "ana_123");
        assert!(Username::parse("an").is_none()); // too short
        assert!(Username::parse(&"a".repeat(21)).is_none()); // too long
        assert!(Username::parse("ana!").is_none());
    }

    #[test]
    fn search_query_validity() {
        assert_eq!(
            SearchQuery::parse(" AN ").map(|query| query.0),
            Some("an".to_string())
        );
        assert!(SearchQuery::parse("a").is_none());
        assert!(SearchQuery::parse(&"a".repeat(21)).is_none());
        assert!(SearchQuery::parse("an a").is_none());
    }

    #[test]
    fn profile_json_hides_email_unless_requested() {
        let row = ProfileRow {
            uid: "u1".into(),
            email: Some("u1@example.test".into()),
            display_name: Some("Ana".into()),
            photo_url: None,
            username: Some("ana".into()),
            username_lower: Some("ana".into()),
            created_at: Some("2026-01-01T00:00:00.000Z".into()),
            updated_at: "2026-01-01T00:00:00.000Z".into(),
            today_count: None,
            week_count: None,
            total_all_time: None,
            best_day: None,
            streak: None,
        };
        let without_email = profile_json(&row, false);
        assert!(without_email.get("email").is_none());
        let with_email = profile_json(&row, true);
        assert_eq!(with_email["email"], "u1@example.test");
        assert_eq!(with_email["todayCount"], 0);
    }
}
