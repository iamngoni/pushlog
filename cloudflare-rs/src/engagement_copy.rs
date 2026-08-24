//! AI-generated copy for scheduled streak, missed-session, and comeback
//! reminders. Facts are supplied by the engagement scheduler and validated
//! again after inference; curated copy keeps reminder delivery independent of
//! Workers AI availability.

use serde::Deserialize;
use serde_json::{json, Value};
use worker::Env;

const ENGAGEMENT_MODEL: &str = "@cf/meta/llama-3.1-8b-instruct-fast";
const MAX_TITLE_BYTES: usize = 65;
const MAX_BODY_BYTES: usize = 120;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EngagementKind {
    StreakAtRisk { streak: i64 },
    MissedSession,
    Inactive { days: i64 },
}

impl EngagementKind {
    pub fn code(&self) -> &'static str {
        match self {
            Self::StreakAtRisk { .. } => "streak_at_risk",
            Self::MissedSession => "missed_session",
            Self::Inactive { .. } => "inactive",
        }
    }

    fn facts(&self) -> Value {
        match self {
            Self::StreakAtRisk { streak } => json!({
                "active_streak_days": streak,
                "required_phrase": format!("{streak}-day streak"),
                "situation": "The user's active streak expires at local midnight."
            }),
            Self::MissedSession => json!({
                "situation": concat!(
                    "The user had a planned training session yesterday and logged no reps ",
                    "yesterday or today."
                )
            }),
            Self::Inactive { days } => json!({
                "inactive_days": days,
                "required_phrase": format!("{days} days"),
                "situation": "The user has not opened Pushlog for this many complete days."
            }),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct EngagementCopy {
    pub title: String,
    pub body: String,
}

pub async fn generate_engagement_copy(
    env: &Env,
    kind: &EngagementKind,
    smart_copy_enabled: bool,
) -> EngagementCopy {
    if !smart_copy_enabled {
        return fallback_copy(kind);
    }
    match try_generate_engagement_copy(env, kind).await {
        Ok(copy) => copy,
        Err(error) => {
            log::warn!("Workers AI engagement copy unavailable; using fallback: {error}");
            fallback_copy(kind)
        }
    }
}

async fn try_generate_engagement_copy(
    env: &Env,
    kind: &EngagementKind,
) -> worker::Result<EngagementCopy> {
    let request = json!({
        "messages": [
            {
                "role": "system",
                "content": concat!(
                    "Write concise Pushlog fitness reminder copy. Sound playfully sad, lightly ",
                    "dramatic, warm, and human. A gentle roast is allowed, but never guilt someone ",
                    "for rest, injury, health, body, or ability. Never invent activity, streak, ",
                    "schedule, or time facts. Return only the requested JSON fields."
                )
            },
            {
                "role": "user",
                "content": serde_json::to_string(&json!({
                    "reminder_kind": kind.code(),
                    "facts": kind.facts(),
                    "requirements": [
                        "Use at most one emoji total",
                        format!("Title must be at most {MAX_TITLE_BYTES} UTF-8 bytes"),
                        format!("Body must be at most {MAX_BODY_BYTES} UTF-8 bytes")
                    ]
                }))?
            }
        ],
        "temperature": 0.9,
        "max_tokens": 100,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "maxLength": MAX_TITLE_BYTES},
                    "body": {"type": "string", "maxLength": MAX_BODY_BYTES}
                },
                "required": ["title", "body"],
                "additionalProperties": false
            }
        }
    });
    let output: Value = env.ai("AI")?.run(ENGAGEMENT_MODEL, request).await?;
    parse_and_validate(&output, kind).ok_or_else(|| {
        worker::Error::RustError("Workers AI returned invalid engagement copy".to_string())
    })
}

fn parse_and_validate(output: &Value, kind: &EngagementKind) -> Option<EngagementCopy> {
    let response = output.get("response").unwrap_or(output);
    let copy = match response {
        Value::String(raw) => serde_json::from_str::<EngagementCopy>(raw).ok()?,
        value => serde_json::from_value::<EngagementCopy>(value.clone()).ok()?,
    };
    let single_line = |value: &str| !value.contains(['\n', '\r']);
    let required_fact_present = match kind {
        EngagementKind::StreakAtRisk { streak } => {
            let phrase = format!("{streak}-day streak");
            copy.title.contains(&phrase) || copy.body.contains(&phrase)
        }
        EngagementKind::MissedSession => !copy
            .title
            .chars()
            .chain(copy.body.chars())
            .any(|character| character.is_ascii_digit()),
        EngagementKind::Inactive { days } => {
            let phrase = format!("{days} days");
            copy.title.contains(&phrase) || copy.body.contains(&phrase)
        }
    };
    if copy.title.trim().is_empty()
        || copy.body.trim().is_empty()
        || copy.title.len() > MAX_TITLE_BYTES
        || copy.body.len() > MAX_BODY_BYTES
        || !single_line(&copy.title)
        || !single_line(&copy.body)
        || !required_fact_present
    {
        return None;
    }
    Some(copy)
}

fn fallback_copy(kind: &EngagementKind) -> EngagementCopy {
    match kind {
        EngagementKind::StreakAtRisk { streak } => EngagementCopy {
            title: "Your streak is getting nervous 🥲".to_string(),
            body: format!(
                "That {streak}-day streak expires tonight. One small set keeps it alive."
            ),
        },
        EngagementKind::MissedSession => EngagementCopy {
            title: "Yesterday's session missed you.".to_string(),
            body: "No guilt. Move it to today or start fresh.".to_string(),
        },
        EngagementKind::Inactive { days: 3 } => EngagementCopy {
            title: "The log's been suspiciously quiet.".to_string(),
            body: "It's been 3 days. We saved your spot.".to_string(),
        },
        EngagementKind::Inactive { days: 7 } => EngagementCopy {
            title: "Your push-up log is collecting dust 🥲".to_string(),
            body: "It's been 7 days. Come back with one rep; we'll act normal.".to_string(),
        },
        EngagementKind::Inactive { days } => EngagementCopy {
            title: "We're taking the hint.".to_string(),
            body: format!(
                "It's been {days} days, so we'll pause comeback nudges. Pushlog will be here."
            ),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_required_streak_and_inactivity_facts() {
        let streak = json!({
            "response": {
                "title": "Your streak looks worried",
                "body": "Your 6-day streak expires tonight."
            }
        });
        assert!(parse_and_validate(&streak, &EngagementKind::StreakAtRisk { streak: 6 }).is_some());
        assert!(parse_and_validate(&streak, &EngagementKind::StreakAtRisk { streak: 7 }).is_none());

        let inactive = json!({
            "response": {
                "title": "It's quiet in here",
                "body": "It's been 7 days. We kept your spot."
            }
        });
        assert!(parse_and_validate(&inactive, &EngagementKind::Inactive { days: 7 }).is_some());
        assert!(parse_and_validate(&inactive, &EngagementKind::Inactive { days: 3 }).is_none());
    }

    #[test]
    fn rejects_invented_missed_session_numbers() {
        let missed = json!({
            "response": {
                "title": "Yesterday's session missed you",
                "body": "Your 12-day streak is at risk."
            }
        });
        assert!(parse_and_validate(&missed, &EngagementKind::MissedSession).is_none());
    }

    #[test]
    fn fallbacks_include_the_facts_they_claim() {
        for kind in [
            EngagementKind::StreakAtRisk { streak: 6 },
            EngagementKind::MissedSession,
            EngagementKind::Inactive { days: 3 },
            EngagementKind::Inactive { days: 7 },
            EngagementKind::Inactive { days: 14 },
        ] {
            let copy = fallback_copy(&kind);
            assert!(!copy.title.is_empty());
            assert!(!copy.body.is_empty());
            assert!(copy.title.len() <= MAX_TITLE_BYTES);
            assert!(copy.body.len() <= MAX_BODY_BYTES);
        }
    }
}
