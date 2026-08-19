//! Typed configuration access and the proof-bearing authenticated-user type.
//!
//! `AuthenticatedUser` can only be constructed from inside this crate (by a
//! real `AuthVerifier` or, in tests, by the fake verifier in `testing`), so
//! a handler that receives one has a compile-time guarantee its request
//! carried a verified Firebase ID token — it never re-checks a boolean.

use worker::{D1Database, Env, Request, Result};

use crate::error::ApiResult;

/// A principal proven by a verified Firebase ID token.
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    uid: String,
    email: Option<String>,
    name: Option<String>,
    picture: Option<String>,
}

impl AuthenticatedUser {
    pub(crate) fn new(
        uid: String,
        email: Option<String>,
        name: Option<String>,
        picture: Option<String>,
    ) -> Self {
        Self {
            uid,
            email,
            name,
            picture,
        }
    }

    pub fn uid(&self) -> &str {
        &self.uid
    }

    pub fn email(&self) -> Option<&str> {
        self.email.as_deref()
    }

    pub fn name(&self) -> Option<&str> {
        self.name.as_deref()
    }

    pub fn picture(&self) -> Option<&str> {
        self.picture.as_deref()
    }
}

/// Verifies a request's credential and returns the principal it proves.
/// Implemented once for production (`auth::FirebaseAuthVerifier`) and once
/// for tests (`testing::FakeAuthVerifier`) — the same seam the TypeScript
/// worker used to inject a fake verifier into `handleRequest`.
pub trait AuthVerifier {
    async fn verify(&self, request: &Request, env: &Env) -> ApiResult<AuthenticatedUser>;
}

/// Typed accessors over the raw `worker::Env`, so a missing binding fails
/// once, here, with a clear message instead of surfacing as a confusing
/// downstream JS-interop error.
pub struct AppConfig;

impl AppConfig {
    pub fn db(env: &Env) -> Result<D1Database> {
        env.d1("DB")
    }

    pub fn firebase_project_id(env: &Env) -> Result<String> {
        Ok(env.var("FIREBASE_PROJECT_ID")?.to_string())
    }

    pub fn environment(env: &Env) -> Result<String> {
        Ok(env.var("ENVIRONMENT")?.to_string())
    }

    /// The Google service-account key (JSON, as downloaded from the
    /// Firebase console) used to sign FCM v1 OAuth2 assertions. Optional:
    /// push delivery degrades to `not_configured` without it, exactly like
    /// the TypeScript worker degraded without `FCM_GATEWAY_SECRET`.
    pub fn fcm_service_account_json(env: &Env) -> Option<String> {
        env.secret("FCM_SERVICE_ACCOUNT_JSON")
            .ok()
            .map(|s| s.to_string())
    }
}
