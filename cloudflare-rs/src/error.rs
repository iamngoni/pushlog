//! The stable API error shape returned to clients, and the JSON response
//! helpers every route builds its output through.
//!
//! `ApiError` is the only way a route signals failure to the caller. It
//! carries a machine-readable `code` (stable across releases; existing app
//! builds pattern-match on these strings) and an HTTP `status`.

use serde::de::DeserializeOwned;
use serde::Serialize;
use worker::{Request, Response, Result};

const MAXIMUM_JSON_BODY_BYTES: usize = 1_000_000;

#[derive(Debug, thiserror::Error)]
#[error("{message}")]
pub struct ApiError {
    pub status: u16,
    pub code: &'static str,
    pub message: String,
}

impl ApiError {
    pub fn new(status: u16, code: &'static str, message: impl Into<String>) -> Self {
        Self {
            status,
            code,
            message: message.into(),
        }
    }

    pub fn invalid_json() -> Self {
        Self::new(400, "invalid_json", "The request body must be JSON.")
    }

    pub fn internal() -> Self {
        Self::new(500, "internal_error", "An unexpected error occurred.")
    }
}

/// A route handler's result: either a JSON-serializable success value or a
/// stable `ApiError`. `lib.rs` maps both branches to a `worker::Response`.
pub type ApiResult<T> = std::result::Result<T, ApiError>;

/// Reads and parses a bounded JSON body before any domain side effect.
///
/// Cloudflare's platform limit is intentionally not our application limit:
/// one megabyte is sufficient for the largest accepted workout snapshot.
pub async fn json_body<T: DeserializeOwned>(request: &mut Request) -> ApiResult<T> {
    let bytes = request
        .bytes()
        .await
        .map_err(|_| ApiError::invalid_json())?;
    if bytes.len() > MAXIMUM_JSON_BODY_BYTES {
        return Err(ApiError::new(
            413,
            "request_too_large",
            "The request body is too large.",
        ));
    }
    serde_json::from_slice(&bytes).map_err(|_| ApiError::invalid_json())
}

/// Bridges a D1 (or other worker-runtime) failure into the stable API error
/// shape without leaking internal detail to the client. The original
/// message is logged here, at the point of conversion, since it is the
/// last place the detail is still available.
impl From<worker::Error> for ApiError {
    fn from(error: worker::Error) -> Self {
        log::error!("worker runtime error: {error}");
        Self::internal()
    }
}

/// Serializes `value` with the same headers every Pushlog API response
/// uses: JSON content type, no caching, and no MIME sniffing. Mirrors the
/// TypeScript worker's `jsonResponse` exactly so existing clients see an
/// unchanged wire format.
pub fn json_response<T: Serialize>(value: &T, status: u16) -> Result<Response> {
    let mut response = Response::from_json(value)?.with_status(status);
    let headers = response.headers_mut();
    headers.set("cache-control", "no-store")?;
    headers.set("x-content-type-options", "nosniff")?;
    Ok(response)
}

pub fn ok_json<T: Serialize>(value: &T) -> Result<Response> {
    json_response(value, 200)
}

pub fn no_content() -> Result<Response> {
    let mut response = Response::empty()?.with_status(204);
    response.headers_mut().set("cache-control", "no-store")?;
    response
        .headers_mut()
        .set("x-content-type-options", "nosniff")?;
    Ok(response)
}

pub fn error_response(error: &ApiError, request_id: &str) -> Result<Response> {
    json_response(
        &serde_json::json!({
            "error": {
                "code": error.code,
                "message": error.message,
                "requestId": request_id,
            }
        }),
        error.status,
    )
}

/// A 405 with the `Allow` header listing the methods this route accepts.
pub fn method_not_allowed(methods: &[&str]) -> Result<Response> {
    let mut response = json_response(
        &serde_json::json!({
            "error": {
                "code": "method_not_allowed",
                "message": "Method not allowed.",
            }
        }),
        405,
    )?;
    response.headers_mut().set("allow", &methods.join(", "))?;
    Ok(response)
}
