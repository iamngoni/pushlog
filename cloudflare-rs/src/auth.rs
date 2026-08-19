//! Production `AuthVerifier`: verifies the `authorization` header against
//! Firebase Auth ID tokens. All cryptographic and claim logic lives in
//! `jwks`; this module only wires it to the transport and maps failures to
//! the stable API error shape.

use worker::{Env, Request};

use crate::env::{AppConfig, AuthVerifier, AuthenticatedUser};
use crate::error::ApiError;
use crate::jwks::{bearer_token, verify_firebase_id_token, VerifyError};

pub struct FirebaseAuthVerifier;

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
