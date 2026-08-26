//! Production `AuthVerifier`: verifies the `authorization` header against
//! Firebase Auth ID tokens. All cryptographic and claim logic lives in
//! `jwks`; this module only wires it to the transport and maps failures to
//! the stable API error shape.

use std::collections::HashMap;
use std::sync::Mutex;

use rsa::RsaPublicKey;
use worker::{Env, Request};

use crate::env::{AppConfig, AuthVerifier, AuthenticatedUser};
use crate::error::ApiError;
use crate::jwks::{
    bearer_token, decode_jwt, parse_jwks, validate_claims, verify_signature, FirebaseClaims,
    VerifyError,
};

const JWKS_URL: &str =
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

/// Isolate-lifetime key cache. Durable authentication truth remains Google's
/// JWKS; a miss is safe to satisfy with another idempotent fetch.
static JWKS_CACHE: Mutex<Option<HashMap<String, RsaPublicKey>>> = Mutex::new(None);

pub struct FirebaseAuthVerifier;

/// Local-runtime verifier compiled only for the integration-test Worker build.
///
/// Production builds cannot construct this verifier because its feature is
/// disabled by default. Test credentials use `Bearer test:<uid>`.
#[cfg(feature = "integration-test-auth")]
pub struct IntegrationTestAuthVerifier;

fn cached_key(kid: &str) -> Option<RsaPublicKey> {
    JWKS_CACHE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .as_ref()
        .and_then(|keys| keys.get(kid).cloned())
}

fn store_keys(keys: HashMap<String, RsaPublicKey>) {
    *JWKS_CACHE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = Some(keys);
}

async fn fetch_jwks() -> Result<HashMap<String, RsaPublicKey>, VerifyError> {
    let url = JWKS_URL
        .parse()
        .map_err(|_| VerifyError::KeySourceUnavailable)?;
    let mut response = worker::Fetch::Url(url)
        .send()
        .await
        .map_err(|_| VerifyError::KeySourceUnavailable)?;
    let body = response
        .text()
        .await
        .map_err(|_| VerifyError::KeySourceUnavailable)?;
    parse_jwks(&body)
}

async fn public_key_for_kid(kid: &str) -> Result<RsaPublicKey, VerifyError> {
    if let Some(key) = cached_key(kid) {
        return Ok(key);
    }
    let keys = fetch_jwks().await?;
    let key = keys.get(kid).cloned();
    store_keys(keys);
    key.ok_or(VerifyError::UnknownKey)
}

/// Verifies a Firebase token using the isolate cache and Google's current keys.
async fn verify_firebase_id_token(
    token: &str,
    project_id: &str,
) -> Result<FirebaseClaims, VerifyError> {
    let decoded = decode_jwt(token)?;
    let kid = decoded.kid.as_deref().ok_or(VerifyError::UnknownKey)?;
    let public_key = public_key_for_kid(kid).await?;
    verify_signature(&public_key, &decoded.signing_input, &decoded.signature)?;
    validate_claims(&decoded.claims, project_id, chrono::Utc::now().timestamp())
}

impl AuthVerifier for FirebaseAuthVerifier {
    async fn verify(&self, request: &Request, env: &Env) -> Result<AuthenticatedUser, ApiError> {
        let header = request.headers().get("authorization").ok().flatten();
        let token = bearer_token(header.as_deref()).map_err(map_verify_error)?;

        let project_id = AppConfig::firebase_project_id(env).map_err(|_| ApiError::internal())?;
        let claims = verify_firebase_id_token(token, &project_id)
            .await
            .map_err(map_verify_error)?;

        Ok(AuthenticatedUser::new(
            claims.sub,
            claims.email,
            claims.name,
            claims.picture,
        ))
    }
}

#[cfg(feature = "integration-test-auth")]
impl AuthVerifier for IntegrationTestAuthVerifier {
    async fn verify(&self, request: &Request, _env: &Env) -> Result<AuthenticatedUser, ApiError> {
        let header = request.headers().get("authorization").ok().flatten();
        let uid = bearer_token(header.as_deref())
            .map_err(map_verify_error)?
            .strip_prefix("test:")
            .filter(|uid| !uid.is_empty() && uid.len() <= 128)
            .ok_or_else(|| map_verify_error(VerifyError::Malformed))?;
        Ok(AuthenticatedUser::new(
            uid.to_string(),
            Some(format!("{uid}@example.test")),
            Some(uid.to_string()),
            None,
        ))
    }
}

fn map_verify_error(error: VerifyError) -> ApiError {
    match error {
        VerifyError::MissingToken => ApiError::new(
            401,
            "authentication_required",
            "A Firebase ID token is required.",
        ),
        VerifyError::KeySourceUnavailable => ApiError::internal(),
        _ => ApiError::new(
            401,
            "invalid_token",
            "The Firebase ID token is invalid or expired.",
        ),
    }
}
