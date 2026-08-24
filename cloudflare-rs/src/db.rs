//! Small D1 parameter-binding conveniences shared by every domain module,
//! plus the day-key (`YYYY-MM-DD`) helpers `friends` and `workout` both
//! need for leaderboard windows and streak arithmetic.

use chrono::{Datelike, Duration, NaiveDate, SecondsFormat, Utc};
use worker::d1::D1Type;

/// A canonical `YYYY-MM-DD` value proven to name a real calendar date.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct CalendarDayKey {
    value: String,
    date: NaiveDate,
}

impl CalendarDayKey {
    /// Parses a client-supplied day key, preserving the calendar-validity proof.
    pub(crate) fn parse(value: &str) -> Option<Self> {
        if value.len() != 10 {
            return None;
        }
        let date = NaiveDate::parse_from_str(value, "%Y-%m-%d").ok()?;
        Some(Self {
            value: value.to_string(),
            date,
        })
    }

    pub(crate) fn as_str(&self) -> &str {
        &self.value
    }
}

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

/// Returns today's UTC date as a calendar-valid key.
pub fn today_key() -> CalendarDayKey {
    let date = Utc::now().date_naive();
    CalendarDayKey {
        value: date.format("%Y-%m-%d").to_string(),
        date,
    }
}

/// The Monday that starts the week containing `day_key` (ISO week, so
/// Sunday is the last day of its week rather than the first). Accepting a
/// `CalendarDayKey` makes the calculation total without reparsing or panicking.
pub fn week_start(day_key: &CalendarDayKey) -> CalendarDayKey {
    let weekday_index = day_key.date.weekday().num_days_from_monday() as i64; // Mon=0 .. Sun=6
    let date = day_key.date - Duration::days(weekday_index);
    CalendarDayKey {
        value: date.format("%Y-%m-%d").to_string(),
        date,
    }
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
    fn optional_text_maps_absence_to_sql_null() {
        assert!(matches!(opt_text(None), D1Type::Null));
        assert!(matches!(opt_text(Some("value")), D1Type::Text("value")));
    }

    #[test]
    fn now_iso_ends_in_z_with_millisecond_precision() {
        let stamp = now_iso();
        assert!(stamp.ends_with('Z'));
        assert_eq!(stamp.len(), "2026-08-06T08:00:00.000Z".len());
    }

    #[test]
    fn today_key_is_a_canonical_calendar_day() {
        let today = today_key();
        assert_eq!(today.as_str().len(), 10);
        assert_eq!(CalendarDayKey::parse(today.as_str()), Some(today));
    }

    #[test]
    fn calendar_day_key_accepts_real_dates_only() {
        assert_eq!(
            CalendarDayKey::parse("2026-08-06").map(|day| day.value),
            Some("2026-08-06".to_string())
        );
        assert_eq!(CalendarDayKey::parse("2026-13-40"), None);
        assert_eq!(CalendarDayKey::parse("2026-8-6"), None);
    }

    #[test]
    fn week_start_is_the_preceding_or_same_monday() {
        let thursday = CalendarDayKey::parse("2026-08-06").expect("fixture is a valid date");
        assert_eq!(thursday.date.weekday().to_string(), "Thu");
        assert_eq!(week_start(&thursday).as_str(), "2026-08-03");
        assert_eq!(
            week_start(&CalendarDayKey::parse("2026-08-03").expect("fixture is a valid date"))
                .as_str(),
            "2026-08-03"
        );
        assert_eq!(
            week_start(&CalendarDayKey::parse("2026-08-09").expect("fixture is a valid date"))
                .as_str(),
            "2026-08-03"
        );
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
