//! Sends push notifications through FCM's HTTP v1 API, authenticated with
//! a Google service-account JWT-bearer OAuth2 exchange — no Firebase
//! Functions or Admin SDK involved.
//!
//! FCM v1 is also the delivery path for iOS: Google's backend forwards a
//! message carrying an `apns` block to APNs on our behalf using the same
//! Firebase project's APNs credentials, so one send call reaches both
//! platforms. Only Android needs FCM as a platform requirement (there is
//! no non-Google push transport for a Play Store app); routing iOS through
//! it too, rather than signing our own APNs JWTs, means the client's
//! existing `firebase_messaging` token registration needs no change and
//! this worker owns exactly one delivery path instead of two.

use std::sync::Mutex;

use rsa::pkcs1v15::SigningKey;
use rsa::pkcs8::DecodePrivateKey;
use rsa::signature::Signer;
use rsa::RsaPrivateKey;
use serde::Deserialize;
use sha2::Sha256;
use worker::{Fetch, Method, Request, RequestInit};

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;

const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const MESSAGING_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
/// Refresh this many seconds before Google's stated expiry, so a request
/// arriving right at the edge never races an already-expired token.
const EXPIRY_SAFETY_MARGIN_SECONDS: i64 = 60;

#[derive(Debug, thiserror::Error)]
pub enum FcmError {
    #[error("the FCM service account JSON could not be parsed")]
    InvalidServiceAccount,
    #[error("exchanging the service-account JWT for an access token failed")]
    TokenExchangeFailed,
    #[error("the FCM send request failed")]
    SendFailed,
    /// FCM reported this token as unregistered — the caller should delete
    /// it so it is never dialed again.
    #[error("the device token is no longer registered")]
    Unregistered,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServiceAccount {
    pub client_email: String,
    pub private_key: String,
    pub project_id: String,
}

pub fn parse_service_account(json: &str) -> Result<ServiceAccount, FcmError> {
    serde_json::from_str(json).map_err(|_| FcmError::InvalidServiceAccount)
}

struct CachedToken {
    client_email: String,
    access_token: String,
    expires_at: i64,
}

static TOKEN_CACHE: Mutex<Option<CachedToken>> = Mutex::new(None);

fn cached_token(client_email: &str, now: i64) -> Option<String> {
    let guard = TOKEN_CACHE
        .lock()
        .expect("fcm token cache mutex is never poisoned: no panics occur while holding it");
    guard.as_ref().and_then(|cached| {
        (cached.client_email == client_email && cached.expires_at > now)
            .then(|| cached.access_token.clone())
    })
}

fn store_token(client_email: String, access_token: String, expires_at: i64) {
    *TOKEN_CACHE
        .lock()
        .expect("fcm token cache mutex is never poisoned: no panics occur while holding it") =
        Some(CachedToken {
            client_email,
            access_token,
            expires_at,
        });
}

/// Builds and signs the RS256 JWT assertion Google's token endpoint
/// exchanges for an OAuth2 access token. Pure and independently testable.
fn build_assertion(account: &ServiceAccount, issued_at: i64) -> Result<String, FcmError> {
    let private_key = RsaPrivateKey::from_pkcs8_pem(&account.private_key)
        .map_err(|_| FcmError::InvalidServiceAccount)?;
    let header = URL_SAFE_NO_PAD.encode(r#"{"alg":"RS256","typ":"JWT"}"#);
    let claims = serde_json::json!({
        "iss": account.client_email,
        "scope": MESSAGING_SCOPE,
        "aud": TOKEN_URL,
        "iat": issued_at,
        "exp": issued_at + 3600,
    });
    let payload = URL_SAFE_NO_PAD.encode(claims.to_string());
    let signing_input = format!("{header}.{payload}");
    let signing_key = SigningKey::<Sha256>::new(private_key);
    let signature: rsa::pkcs1v15::Signature = signing_key.sign(signing_input.as_bytes());
    let signature_b64 =
        URL_SAFE_NO_PAD.encode(rsa::signature::SignatureEncoding::to_bytes(&signature).as_ref());
    Ok(format!("{signing_input}.{signature_b64}"))
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
}

async fn fetch_access_token(account: &ServiceAccount, now: i64) -> Result<String, FcmError> {
    if let Some(token) = cached_token(&account.client_email, now) {
        return Ok(token);
    }

    let assertion = build_assertion(account, now)?;
    let body = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
        .append_pair("assertion", &assertion)
        .finish();

    let mut init = RequestInit::new();
    init.with_method(Method::Post).with_body(Some(body.into()));
    let request =
        Request::new_with_init(TOKEN_URL, &init).map_err(|_| FcmError::TokenExchangeFailed)?;
    request
        .headers()
        .set("content-type", "application/x-www-form-urlencoded")
        .map_err(|_| FcmError::TokenExchangeFailed)?;

    let mut response = Fetch::Request(request)
        .send()
        .await
        .map_err(|_| FcmError::TokenExchangeFailed)?;
    if response.status_code() != 200 {
        return Err(FcmError::TokenExchangeFailed);
    }
    let parsed: TokenResponse = response
        .json()
        .await
        .map_err(|_| FcmError::TokenExchangeFailed)?;

    store_token(
        account.client_email.clone(),
        parsed.access_token.clone(),
        now + parsed.expires_in - EXPIRY_SAFETY_MARGIN_SECONDS,
    );
    Ok(parsed.access_token)
}

#[derive(Debug, Deserialize)]
struct FcmErrorBody {
    error: FcmErrorDetail,
}

#[derive(Debug, Deserialize)]
struct FcmErrorDetail {
    status: Option<String>,
}

/// Sends one push to one device token. The `android`/`apns` override
/// blocks are attached unconditionally — FCM applies only the block that
/// matches the token's actual platform and ignores the other, so this
/// module never needs to know which platform a token belongs to.
pub async fn send(
    account: &ServiceAccount,
    device_token: &str,
    title: &str,
    body: &str,
    data: &[(String, String)],
) -> Result<(), FcmError> {
    let now = chrono::Utc::now().timestamp();
    let access_token = fetch_access_token(account, now).await?;

    let message = serde_json::json!({
        "message": {
            "token": device_token,
            "notification": {"title": title, "body": body},
            "data": data.iter().cloned().collect::<std::collections::HashMap<_, _>>(),
            "android": {
                "priority": "high",
                "notification": {"channel_id": "pushlog_competition", "sound": "default"},
            },
            "apns": {
                "payload": {"aps": {"sound": "default", "thread-id": "pushlog_competition"}},
            },
        }
    });

    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_body(Some(message.to_string().into()));
    let url = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        account.project_id
    );
    let request = Request::new_with_init(&url, &init).map_err(|_| FcmError::SendFailed)?;
    request
        .headers()
        .set("authorization", &format!("Bearer {access_token}"))
        .map_err(|_| FcmError::SendFailed)?;
    request
        .headers()
        .set("content-type", "application/json")
        .map_err(|_| FcmError::SendFailed)?;

    let mut response = Fetch::Request(request)
        .send()
        .await
        .map_err(|_| FcmError::SendFailed)?;
    if response.status_code() == 200 {
        return Ok(());
    }

    if let Ok(error_body) = response.json::<FcmErrorBody>().await {
        if error_body.error.status.as_deref() == Some("UNREGISTERED") {
            return Err(FcmError::Unregistered);
        }
    }
    Err(FcmError::SendFailed)
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_KEY_PEM: &str = include_str!("../../testdata/test_rsa_key.pem");

    fn account() -> ServiceAccount {
        ServiceAccount {
            client_email: "worker@pushlog-app.iam.gserviceaccount.com".to_string(),
            private_key: TEST_KEY_PEM.to_string(),
            project_id: "pushlog-app".to_string(),
        }
    }

    #[test]
    fn parse_service_account_reads_the_three_fields_it_needs() {
        let json = serde_json::json!({
            "client_email": "worker@pushlog-app.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\n...",
            "project_id": "pushlog-app",
            "type": "service_account",
        })
        .to_string();
        let account = parse_service_account(&json).expect("parses despite extra fields");
        assert_eq!(account.project_id, "pushlog-app");
    }

    #[test]
    fn parse_service_account_rejects_malformed_json() {
        assert!(parse_service_account("not json").is_err());
    }

    #[test]
    fn build_assertion_produces_a_three_segment_jwt_with_the_right_claims() {
        let assertion = build_assertion(&account(), 1_700_000_000).expect("signs successfully");
        let segments: Vec<&str> = assertion.split('.').collect();
        assert_eq!(segments.len(), 3);
        let payload = URL_SAFE_NO_PAD.decode(segments[1]).unwrap();
        let claims: serde_json::Value = serde_json::from_slice(&payload).unwrap();
        assert_eq!(claims["iss"], "worker@pushlog-app.iam.gserviceaccount.com");
        assert_eq!(claims["scope"], MESSAGING_SCOPE);
        assert_eq!(claims["aud"], TOKEN_URL);
        assert_eq!(claims["exp"], 1_700_003_600i64);
    }

    #[test]
    fn cached_token_is_scoped_to_client_email_and_expiry() {
        store_token("a@example.test".to_string(), "token-a".to_string(), 1_000);
        assert_eq!(
            cached_token("a@example.test", 500),
            Some("token-a".to_string())
        );
        assert_eq!(
            cached_token("a@example.test", 1_500),
            None,
            "expired token is not returned"
        );
        assert_eq!(
            cached_token("b@example.test", 500),
            None,
            "different account is not returned"
        );
    }
}
