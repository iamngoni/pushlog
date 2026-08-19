//! Competitive push copy for "a friend passed you", ported verbatim from
//! the TypeScript worker's `lead_change_copy.ts`.
//!
//! The tone is rivalry, not ridicule. Every line needles the *gap* or the
//! friend who closed it; none of them insult the reader, call them lazy, or
//! treat a rest day as a failure. That is a deliberate line: this push
//! lands unprompted on someone's lock screen, and copy that shames gets
//! the app muted or deleted rather than opened.
//!
//! Every body carries the exact rep count, so the notification stays
//! actionable rather than just being noise with an attitude.

pub struct LeadChangeCopy {
    pub title: String,
    pub body: String,
}

/// `actor` is the friend who just went ahead, without a leading `@`.
/// `deficit` is how far ahead they now are (always >= 0). `reps_to_retake`
/// is the reps needed to retake the lead (`deficit + 1`).
pub struct LeadChangeInput {
    pub actor: String,
    pub deficit: i64,
    pub reps_to_retake: i64,
}

type Variant = fn(&str, i64, i64) -> LeadChangeCopy;

fn copy(title: impl Into<String>, body: impl Into<String>) -> LeadChangeCopy {
    LeadChangeCopy {
        title: title.into(),
        body: body.into(),
    }
}

const VARIANTS: &[Variant] = &[
    |actor, _deficit, reps| {
        copy(
            format!("😬 @{actor} took your spot"),
            format!("{reps} reps. Go get it back."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} passed you. Ouch."),
            format!("{reps} reps to remind them who runs this."),
        )
    },
    |actor, deficit, reps| {
        copy(
            format!("🚨 You're losing to @{actor}"),
            format!("{deficit} behind. {reps} reps to fix that."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} is ahead of you 👀"),
            format!("You're really going to let that happen? {reps} reps."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} didn't wait for you"),
            format!("{reps} reps. Catch up or stay behind."),
        )
    },
    |actor, deficit, reps| {
        copy(
            "You've been passed 😭".to_string(),
            format!("@{actor} is {deficit} ahead. {reps} reps to take it back."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("That's @{actor} in YOUR spot"),
            format!("{reps} reps to kick them back out."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} stole your lead"),
            format!("Are you letting them keep it? {reps} reps."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} is cooking 🔥"),
            format!("You're getting cooked. {reps} reps to catch up."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("Bad news: @{actor} passed you"),
            format!("Worse news: they might keep the lead. {reps} reps."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} made their move"),
            format!("Your move. {reps} reps."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            "You're #2 now 🫣".to_string(),
            format!("@{actor} is enjoying first place. {reps} reps to ruin their day."),
        )
    },
    |actor, deficit, reps| {
        copy(
            format!("@{actor} is {deficit} ahead of you"),
            format!("That's embarrassing. {reps} reps fixes it."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} is having a better day than you"),
            format!("Do something about it. {reps} reps."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("You really let @{actor} pass you?"),
            format!("{reps} reps. No excuses."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            "Your lead is gone 💀".to_string(),
            format!("@{actor} took it. {reps} reps to reclaim it."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} is laughing right now"),
            format!("{reps} reps could change that."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            "They passed you while you were away".to_string(),
            format!("@{actor} is ahead. {reps} reps. Get back to work."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            "Someone wants your crown 👑".to_string(),
            format!("@{actor} took the lead. {reps} reps to defend it."),
        )
    },
    |actor, _deficit, reps| {
        copy(
            format!("@{actor} thinks they're better than you"),
            format!("Prove them wrong. {reps} reps."),
        )
    },
];

pub const LEAD_CHANGE_VARIANT_COUNT: usize = VARIANTS.len();
const _: () = assert!(
    LEAD_CHANGE_VARIANT_COUNT >= 10,
    "fewer than 10 variants defeats the point of varying the copy"
);

/// Builds the copy for one lead-change push using `variant_index`. Negative
/// and out-of-range values wrap, matching the TypeScript port's behavior so
/// a random `i64` (e.g. from a UUID's low bits) never needs bounds-checking
/// at the call site.
pub fn build_lead_change_copy(input: &LeadChangeInput, variant_index: i64) -> LeadChangeCopy {
    let len = LEAD_CHANGE_VARIANT_COUNT as i64;
    let safe_index = ((variant_index % len) + len) % len;
    // Strip a leading `@` so a stored username of "@ana" does not render as
    // "@@ana" in a title that adds its own.
    let actor = input.actor.trim_start_matches('@');
    let actor = if actor.is_empty() { "A friend" } else { actor };
    VARIANTS[safe_index as usize](actor, input.deficit, input.reps_to_retake)
}

/// Picks a variant index using OS-provided randomness. The result may be
/// negative; `build_lead_change_copy`'s modulo wrap handles any `i64`,
/// including `i64::MIN`, without overflow. Falls back to variant 0 only if
/// entropy is genuinely unavailable — copy variety is a cosmetic concern,
/// never worth failing a notification over.
pub fn random_variant_index() -> i64 {
    let mut buf = [0u8; 8];
    if getrandom::getrandom(&mut buf).is_err() {
        return 0;
    }
    i64::from_le_bytes(buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input() -> LeadChangeInput {
        LeadChangeInput {
            actor: "ana".to_string(),
            deficit: 4,
            reps_to_retake: 5,
        }
    }

    #[test]
    fn produces_distinct_copy_for_each_variant() {
        let mut rendered = (0..LEAD_CHANGE_VARIANT_COUNT as i64)
            .map(|i| {
                let copy = build_lead_change_copy(&input(), i);
                (copy.title, copy.body)
            })
            .collect::<Vec<_>>();
        rendered.sort();
        rendered.dedup();
        assert_eq!(rendered.len(), LEAD_CHANGE_VARIANT_COUNT);
    }

    #[test]
    fn every_variant_stays_actionable_and_well_formed() {
        for i in 0..LEAD_CHANGE_VARIANT_COUNT as i64 {
            let copy = build_lead_change_copy(&input(), i);
            assert!(
                copy.body.contains('5'),
                "variant {i} body must carry the rep count"
            );
            assert!(
                !copy.title.is_empty(),
                "variant {i} title must not be empty"
            );
            assert!(
                copy.title.len() <= 65,
                "variant {i} title too long for a push"
            );
            assert!(
                copy.body.len() <= 120,
                "variant {i} body too long for a push"
            );
            assert!(
                !copy.title.contains("@@"),
                "variant {i} doubled the @ sigil in the title"
            );
            assert!(
                !copy.body.contains("@@"),
                "variant {i} doubled the @ sigil in the body"
            );
        }
    }

    #[test]
    fn negative_and_out_of_range_indices_wrap() {
        let len = LEAD_CHANGE_VARIANT_COUNT as i64;
        assert_eq!(
            build_lead_change_copy(&input(), -1).title,
            build_lead_change_copy(&input(), len - 1).title
        );
        assert_eq!(
            build_lead_change_copy(&input(), len).title,
            build_lead_change_copy(&input(), 0).title
        );
    }

    #[test]
    fn strips_a_leading_sigil_from_the_actor_name() {
        let input = LeadChangeInput {
            actor: "@ana".to_string(),
            deficit: 1,
            reps_to_retake: 2,
        };
        let copy = build_lead_change_copy(&input, 0);
        assert!(!copy.title.contains("@@"));
    }

    #[test]
    fn falls_back_to_a_friend_when_actor_is_only_sigils() {
        let input = LeadChangeInput {
            actor: "@@@".to_string(),
            deficit: 1,
            reps_to_retake: 2,
        };
        let copy = build_lead_change_copy(&input, 0);
        assert!(copy.title.contains("A friend"));
    }

    #[test]
    fn random_variant_index_always_maps_to_a_valid_variant() {
        for _ in 0..64 {
            let len = LEAD_CHANGE_VARIANT_COUNT as i64;
            let safe_index = ((random_variant_index() % len) + len) % len;
            assert!((0..len).contains(&safe_index));
        }
    }

    #[test]
    fn i64_min_does_not_panic_when_wrapped() {
        let copy = build_lead_change_copy(&input(), i64::MIN);
        assert!(!copy.title.is_empty());
    }
}
