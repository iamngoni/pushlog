//! Pushlog API worker: profiles, friends, workout sync, and lead-change
//! push delivery, backed by D1. The HTTP contract (paths, methods, JSON
//! shapes, status codes) is an intentional, verified match for the
//! TypeScript worker it replaces — existing app builds must keep working
//! unmodified. See `docs/release` for the migration note.

mod auth;
mod db;
mod devices;
mod engagement;
mod engagement_copy;
mod env;
mod error;
mod friends;
mod jwks;
mod lead_change_copy;
mod notifications;
mod profile;
mod push;
mod safety;
mod safety_validation;
mod workout;

use worker::*;

use env::{AppConfig, AuthVerifier};
use error::{
    error_response, json_response, method_not_allowed, no_content, ok_json, ApiError, ApiResult,
};

#[event(fetch)]
pub async fn main(req: Request, env: Env, ctx: Context) -> Result<Response> {
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();
    let _ = console_log::init_with_level(log::Level::Info);

    let request_id = uuid::Uuid::new_v4().to_string();
    #[cfg(not(feature = "integration-test-auth"))]
    let routed = route(req, &env, &ctx, &auth::FirebaseAuthVerifier).await;
    #[cfg(feature = "integration-test-auth")]
    let routed = if AppConfig::environment(&env).ok().as_deref() == Some("integration") {
        route(req, &env, &ctx, &auth::IntegrationTestAuthVerifier).await
    } else {
        route(req, &env, &ctx, &auth::FirebaseAuthVerifier).await
    };
    match routed {
        Ok(response) => Ok(response),
        Err(error) => {
            if error.status == 500 {
                log::error!(
                    "unhandled request error request_id={request_id} code={}",
                    error.code
                );
            }
            error_response(&error, &request_id)
        }
    }
}

#[event(scheduled)]
pub async fn scheduled(_event: ScheduledEvent, env: Env, _ctx: ScheduleContext) {
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();
    let _ = console_log::init_with_level(log::Level::Info);
    if let Err(error) = engagement::deliver_due_reminders(&env).await {
        log::error!("scheduled engagement reminder run failed: {error}");
    }
}

async fn route<A: AuthVerifier>(
    mut request: Request,
    env: &Env,
    ctx: &Context,
    verify_auth: &A,
) -> ApiResult<Response> {
    let url = request.url()?;
    let path = url.path().to_string();
    let method = request.method();

    if path == "/health" {
        return match method {
            Method::Get | Method::Head => {
                let db = AppConfig::db(env)?;
                db.prepare("SELECT 1")
                    .first::<serde_json::Value>(None)
                    .await?;
                let body = serde_json::json!({
                    "status": "ok",
                    "service": "pushlog-api",
                    "environment": AppConfig::environment(env)?,
                    "database": "d1",
                });
                if method == Method::Head {
                    let response = ok_json(&body)?;
                    Ok(Response::empty()?.with_status(response.status_code()))
                } else {
                    Ok(ok_json(&body)?)
                }
            }
            _ => Ok(method_not_allowed(&["GET", "HEAD"])?),
        };
    }

    if path == "/v1/workout-snapshot" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Get => {
                let db = AppConfig::db(env)?;
                match workout::get_workout_snapshot(&request, &db, &user).await? {
                    workout::GetSnapshotOutcome::NotModified { etag } => {
                        let mut response = Response::empty()?.with_status(304);
                        response.headers_mut().set("etag", &etag)?;
                        response
                            .headers_mut()
                            .set("cache-control", "private, no-cache")?;
                        Ok(response)
                    }
                    workout::GetSnapshotOutcome::Body { etag, value } => {
                        let mut response = ok_json(&value)?;
                        response.headers_mut().set("etag", &etag)?;
                        Ok(response)
                    }
                }
            }
            Method::Put => {
                let (value, status) =
                    workout::put_workout_snapshot(&mut request, env, &user, ctx).await?;
                Ok(json_response(&value, status)?)
            }
            _ => Ok(method_not_allowed(&["GET", "PUT"])?),
        };
    }

    if path == "/v1/profile" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Get | Method::Put => {
                let db = AppConfig::db(env)?;
                Ok(ok_json(&profile::get_own_profile(&db, &user).await?)?)
            }
            _ => Ok(method_not_allowed(&["GET", "PUT"])?),
        };
    }

    if path == "/v1/profile/username" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Put => {
                let db = AppConfig::db(env)?;
                Ok(ok_json(
                    &profile::claim_username(&mut request, &db, &user).await?,
                )?)
            }
            _ => Ok(method_not_allowed(&["PUT"])?),
        };
    }

    if path == "/v1/users/search" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Get => {
                let db = AppConfig::db(env)?;
                Ok(ok_json(
                    &profile::search_profiles(&request, &db, &user).await?,
                )?)
            }
            _ => Ok(method_not_allowed(&["GET"])?),
        };
    }

    if path == "/v1/friends" {
        let user = verify_auth.verify(&request, env).await?;
        let db = AppConfig::db(env)?;
        return match method {
            Method::Get => Ok(ok_json(&friends::get_friends(&request, &db, &user).await?)?),
            Method::Delete => {
                friends::remove_friend(&mut request, &db, &user).await?;
                Ok(no_content()?)
            }
            _ => Ok(method_not_allowed(&["GET", "DELETE"])?),
        };
    }

    if path == "/v1/friend-requests" {
        let user = verify_auth.verify(&request, env).await?;
        let db = AppConfig::db(env)?;
        return match method {
            Method::Get => Ok(ok_json(
                &friends::get_friend_requests(&request, &db, &user).await?,
            )?),
            Method::Post => {
                let (value, status) =
                    friends::send_friend_request(&mut request, &db, &user).await?;
                Ok(json_response(&value, status)?)
            }
            _ => Ok(method_not_allowed(&["GET", "POST"])?),
        };
    }

    if path == "/v1/friend-requests/accept" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Post => {
                let db = AppConfig::db(env)?;
                Ok(ok_json(
                    &friends::accept_friend_request(&mut request, &db, &user).await?,
                )?)
            }
            _ => Ok(method_not_allowed(&["POST"])?),
        };
    }

    if path == "/v1/friend-requests/decline" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Post => {
                let db = AppConfig::db(env)?;
                friends::decline_friend_request(&mut request, &db, &user).await?;
                Ok(no_content()?)
            }
            _ => Ok(method_not_allowed(&["POST"])?),
        };
    }

    if path == "/v1/friend-requests/cancel" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Post => {
                let db = AppConfig::db(env)?;
                friends::cancel_friend_request(&mut request, &db, &user).await?;
                Ok(no_content()?)
            }
            _ => Ok(method_not_allowed(&["POST"])?),
        };
    }

    if path == "/v1/devices" {
        let user = verify_auth.verify(&request, env).await?;
        let db = AppConfig::db(env)?;
        return match method {
            Method::Put => Ok(ok_json(
                &devices::register_device(&mut request, &db, &user).await?,
            )?),
            Method::Delete => {
                devices::unregister_device(&mut request, &db, &user).await?;
                Ok(no_content()?)
            }
            _ => Ok(method_not_allowed(&["PUT", "DELETE"])?),
        };
    }

    if path == "/v1/notifications" {
        let user = verify_auth.verify(&request, env).await?;
        let db = AppConfig::db(env)?;
        return match method {
            Method::Get => Ok(ok_json(
                &notifications::get_notifications(&request, &db, &user).await?,
            )?),
            Method::Post => Ok(ok_json(
                &notifications::mark_notifications_read(&mut request, &db, &user).await?,
            )?),
            _ => Ok(method_not_allowed(&["GET", "POST"])?),
        };
    }

    if path == "/v1/reports" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Post => {
                let db = AppConfig::db(env)?;
                let value = safety::report_and_block(&mut request, &db, &user).await?;
                Ok(json_response(&value, 201)?)
            }
            _ => Ok(method_not_allowed(&["POST"])?),
        };
    }

    if path == "/v1/account" {
        let user = verify_auth.verify(&request, env).await?;
        return match method {
            Method::Delete => {
                let db = AppConfig::db(env)?;
                profile::delete_account_data(&db, &user).await?;
                Ok(no_content()?)
            }
            _ => Ok(method_not_allowed(&["DELETE"])?),
        };
    }

    Err(ApiError::new(404, "not_found", "Route not found."))
}
