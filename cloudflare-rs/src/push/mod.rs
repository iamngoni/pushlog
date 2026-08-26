//! Push delivery orchestration: looks up a user's registered devices and
//! dispatches to FCM, independent of how the caller assembled the copy.

mod fcm;

use serde::Deserialize;
use worker::d1::D1Type;
use worker::{D1Database, Env};

use crate::env::AppConfig;

pub struct PushNotification {
    pub title: String,
    pub body: String,
    pub data: Vec<(String, String)>,
    pub channel_id: &'static str,
    pub thread_id: &'static str,
    pub collapse_key: Option<String>,
}

/// The outcome recorded against a `notification_events` row. Variant names
/// match the TypeScript worker's stored `delivery_status` strings exactly,
/// so historical rows and this port agree on vocabulary.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeliveryOutcome {
    NoDevices,
    NotConfigured,
    Delivered,
    Failed,
}

impl DeliveryOutcome {
    pub fn as_code(self) -> &'static str {
        match self {
            Self::NoDevices => "no_devices",
            Self::NotConfigured => "not_configured",
            Self::Delivered => "delivered",
            Self::Failed => "failed",
        }
    }

    pub fn delivered(self) -> bool {
        self == Self::Delivered
    }
}

#[derive(Debug, Deserialize)]
struct DeviceToken {
    token: String,
}

async fn load_devices(db: &D1Database, uid: &str) -> worker::Result<Vec<DeviceToken>> {
    db.prepare("SELECT token FROM devices WHERE uid = ? ORDER BY updated_at DESC")
        .bind_refs(&[D1Type::Text(uid)])?
        .all()
        .await?
        .results::<DeviceToken>()
}

async fn delete_device(db: &D1Database, uid: &str, token: &str) -> worker::Result<()> {
    db.prepare("DELETE FROM devices WHERE uid = ? AND token = ?")
        .bind_refs(&[D1Type::Text(uid), D1Type::Text(token)])?
        .run()
        .await?;
    Ok(())
}

/// Delivers `notification` to every device `uid` has registered. Returns
/// `NoDevices`/`NotConfigured` without making a network call when there is
/// nothing to send or no service account is configured — matching the
/// TypeScript worker's degrade-gracefully behavior when `FCM_GATEWAY_*`
/// was unset.
pub async fn deliver_to_user(
    env: &Env,
    db: &D1Database,
    uid: &str,
    notification: &PushNotification,
) -> DeliveryOutcome {
    let devices = match load_devices(db, uid).await {
        Ok(devices) => devices,
        Err(error) => {
            log::error!("failed to load push devices: {error}");
            return DeliveryOutcome::Failed;
        }
    };
    if devices.is_empty() {
        return DeliveryOutcome::NoDevices;
    }

    let Some(service_account_json) = AppConfig::fcm_service_account_json(env) else {
        log::warn!("FCM service account is not configured; dropping push");
        return DeliveryOutcome::NotConfigured;
    };
    let account = match fcm::parse_service_account(&service_account_json) {
        Ok(account) => account,
        Err(error) => {
            log::error!("FCM service account is misconfigured: {error}");
            return DeliveryOutcome::NotConfigured;
        }
    };

    let mut delivered = false;
    for device in &devices {
        match fcm::send(&account, &device.token, notification).await {
            Ok(()) => delivered = true,
            Err(fcm::FcmError::Unregistered) => {
                if let Err(error) = delete_device(db, uid, &device.token).await {
                    log::warn!("failed to delete stale device token: {error}");
                }
            }
            Err(error) => {
                log::warn!("FCM send failed: {error}");
            }
        }
    }

    if delivered {
        DeliveryOutcome::Delivered
    } else {
        DeliveryOutcome::Failed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delivery_outcome_codes_match_the_typescript_worker_vocabulary() {
        assert_eq!(DeliveryOutcome::NoDevices.as_code(), "no_devices");
        assert_eq!(DeliveryOutcome::NotConfigured.as_code(), "not_configured");
        assert_eq!(DeliveryOutcome::Delivered.as_code(), "delivered");
        assert_eq!(DeliveryOutcome::Failed.as_code(), "failed");
    }

    #[test]
    fn only_delivered_counts_as_delivered() {
        assert!(DeliveryOutcome::Delivered.delivered());
        assert!(!DeliveryOutcome::Failed.delivered());
        assert!(!DeliveryOutcome::NoDevices.delivered());
        assert!(!DeliveryOutcome::NotConfigured.delivered());
    }
}
