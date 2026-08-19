//! Small D1 parameter-binding conveniences shared by every domain module,
//! plus the day-key (`YYYY-MM-DD`) helpers `friends` and `workout` both
//! need for leaderboard windows and streak arithmetic.

use chrono::{Datelike, Duration, NaiveDate, SecondsFormat, Utc};
use worker::d1::D1Type;

/// An `Option<String>` (or `Option<&str>`) as a bindable D1 parameter:
/// `Some` binds as text, `None` binds as SQL `NULL`.
pub fn opt_text(value: Option<&str>) -> D1Type<'_> {
    match value {
        Some(text) => D1Type::Text(text),
        None => D1Type::Null,
    }
}

/// The current instant in the same format the TypeScript worker wrote:
/// millisecond-precision ISO-8601 with a trailing `Z`.
pub fn now_iso() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true)
}

/// A `YYYY-MM-DD` string that also names a real calendar date. Used for
/// values a client fully controls (`clientContext.dayKey`/`weekKey`) where
/// a calendar-invalid value should be rejected outright, rather than for
/// `workout_snapshot.dayTotals` keys, which the TypeScript worker (and this
/// port) accept on shape alone — see `workout::parse_day_totals`.
pub fn valid_calendar_day_key(value: Option<&str>) -> Option<String> {
    let value = value?;
    if value.len() != 10 {
        return None;
    }
    NaiveDate::parse_from_str(value, "%Y-%m-%d").ok()?;
    Some(value.to_string())
}

pub fn today_key() -> String {
    Utc::now().format("%Y-%m-%d").to_string()
}

/// The Monday that starts the week containing `day_key` (ISO week, so
/// Sunday is the last day of its week rather than the first). `day_key`
/// must already be a valid calendar date.
pub fn week_start(day_key: &str) -> String {
    let date = NaiveDate::parse_from_str(day_key, "%Y-%m-%d").expect("day_key is pre-validated");
    let weekday_index = date.weekday().num_days_from_monday() as i64; // Mon=0 .. Sun=6
    (date - Duration::days(weekday_index))
        .format("%Y-%m-%d")
        .to_string()
}

/// `day_key` shifted by `delta` calendar days. `day_key` is not guaranteed
/// to be a real calendar date here (see `valid_calendar_day_key`'s doc) —
/// returns `None` rather than panicking when it isn't, so a malformed
/// `dayTotals` key stops streak arithmetic instead of crashing the request.
pub fn shift_day_key(day_key: &str, delta: i64) -> Option<String> {
    let date = NaiveDate::parse_from_str(day_key, "%Y-%m-%d").ok()?;
    Some(
        (date + Duration::days(delta))
            .format("%Y-%m-%d")
            .to_string(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn now_iso_ends_in_z_with_millisecond_precision() {
        let stamp = now_iso();
        assert!(stamp.ends_with('Z'));
        assert_eq!(stamp.len(), "2026-08-06T08:00:00.000Z".len());
    }

    #[test]
    fn valid_calendar_day_key_accepts_real_dates_only() {
        assert_eq!(
            valid_calendar_day_key(Some("2026-08-06")),
            Some("2026-08-06".to_string())
        );
        assert_eq!(valid_calendar_day_key(Some("2026-13-40")), None);
        assert_eq!(valid_calendar_day_key(Some("2026-8-6")), None);
        assert_eq!(valid_calendar_day_key(None), None);
    }

    #[test]
    fn week_start_is_the_preceding_or_same_monday() {
        assert_eq!(
            NaiveDate::parse_from_str("2026-08-06", "%Y-%m-%d")
                .unwrap()
                .weekday()
                .to_string(),
            "Thu"
        );
        assert_eq!(week_start("2026-08-06"), "2026-08-03");
        assert_eq!(week_start("2026-08-03"), "2026-08-03");
        assert_eq!(week_start("2026-08-09"), "2026-08-03");
    }

    #[test]
    fn shift_day_key_moves_by_whole_days() {
        assert_eq!(
            shift_day_key("2026-08-06", -1),
            Some("2026-08-05".to_string())
        );
        assert_eq!(
            shift_day_key("2026-08-01", -1),
            Some("2026-07-31".to_string())
        );
    }

    #[test]
    fn shift_day_key_rejects_calendar_invalid_input_instead_of_panicking() {
        assert_eq!(shift_day_key("2026-13-40", -1), None);
    }
}
