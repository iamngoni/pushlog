//! Pure validation for the report contract. Keeping this separate from the D1
//! adapter makes the accepted vocabulary exhaustively testable on the host.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ReportReason {
    SafetyConcern,
    Harassment,
    Spam,
    InappropriateProfile,
    Other,
}

impl ReportReason {
    pub(crate) fn parse(value: &str) -> Option<Self> {
        match value {
            "safety_concern" => Some(Self::SafetyConcern),
            "harassment" => Some(Self::Harassment),
            "spam" => Some(Self::Spam),
            "inappropriate_profile" => Some(Self::InappropriateProfile),
            "other" => Some(Self::Other),
            _ => None,
        }
    }

    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::SafetyConcern => "safety_concern",
            Self::Harassment => "harassment",
            Self::Spam => "spam",
            Self::InappropriateProfile => "inappropriate_profile",
            Self::Other => "other",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_every_stable_report_reason() {
        let cases = [
            ("safety_concern", ReportReason::SafetyConcern),
            ("harassment", ReportReason::Harassment),
            ("spam", ReportReason::Spam),
            ("inappropriate_profile", ReportReason::InappropriateProfile),
            ("other", ReportReason::Other),
        ];
        for (raw, expected) in cases {
            assert_eq!(ReportReason::parse(raw), Some(expected));
            assert_eq!(expected.as_str(), raw);
        }
    }

    #[test]
    fn rejects_unrecognized_or_malformed_reasons() {
        assert_eq!(ReportReason::parse("anything"), None);
        assert_eq!(ReportReason::parse(" Safety_concern "), None);
        assert_eq!(ReportReason::parse(""), None);
    }
}
