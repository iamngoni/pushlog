export interface LeadChangeCopy {
  title: string;
  body: string;
}

export interface LeadChangeInput {
  /** The friend who just went ahead, without a leading `@`. */
  actor: string;
  /** How far ahead they now are. Always >= 0. */
  deficit: number;
  /** Reps needed to retake the lead — `deficit + 1`. */
  repsToRetake: number;
}

/**
 * Competitive variants for the "a friend passed you" push.
 *
 * The tone is rivalry, not ridicule. Every line needles the *gap* or the
 * friend who closed it; none of them insult the reader, call them lazy, or
 * treat a rest day as a failure. That is a deliberate line: this push lands
 * unprompted on someone's lock screen, and copy that shames gets the app
 * muted or deleted rather than opened.
 *
 * Every body carries the exact rep count, so the notification stays
 * actionable rather than just being noise with an attitude.
 */
const VARIANTS: ReadonlyArray<(input: LeadChangeInput) => LeadChangeCopy> = [
  ({ actor, repsToRetake }) => ({
    title: `😬 @${actor} took your spot`,
    body: `${repsToRetake} reps. Go get it back.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} passed you. Ouch.`,
    body: `${repsToRetake} reps to remind them who runs this.`,
  }),

  ({ actor, deficit, repsToRetake }) => ({
    title: `🚨 You're losing to @${actor}`,
    body: `${deficit} behind. ${repsToRetake} reps to fix that.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} is ahead of you 👀`,
    body: `You're really going to let that happen? ${repsToRetake} reps.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} didn't wait for you`,
    body: `${repsToRetake} reps. Catch up or stay behind.`,
  }),

  ({ actor, deficit, repsToRetake }) => ({
    title: `You've been passed 😭`,
    body: `@${actor} is ${deficit} ahead. ${repsToRetake} reps to take it back.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `That's @${actor} in YOUR spot`,
    body: `${repsToRetake} reps to kick them back out.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} stole your lead`,
    body: `Are you letting them keep it? ${repsToRetake} reps.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} is cooking 🔥`,
    body: `You're getting cooked. ${repsToRetake} reps to catch up.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `Bad news: @${actor} passed you`,
    body: `Worse news: they might keep the lead. ${repsToRetake} reps.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} made their move`,
    body: `Your move. ${repsToRetake} reps.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `You're #2 now 🫣`,
    body: `@${actor} is enjoying first place. ${repsToRetake} reps to ruin their day.`,
  }),

  ({ actor, deficit, repsToRetake }) => ({
    title: `@${actor} is ${deficit} ahead of you`,
    body: `That's embarrassing. ${repsToRetake} reps fixes it.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} is having a better day than you`,
    body: `Do something about it. ${repsToRetake} reps.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `You really let @${actor} pass you?`,
    body: `${repsToRetake} reps. No excuses.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `Your lead is gone 💀`,
    body: `@${actor} took it. ${repsToRetake} reps to reclaim it.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} is laughing right now`,
    body: `${repsToRetake} reps could change that.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `They passed you while you were away`,
    body: `@${actor} is ahead. ${repsToRetake} reps. Get back to work.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `Someone wants your crown 👑`,
    body: `@${actor} took the lead. ${repsToRetake} reps to defend it.`,
  }),

  ({ actor, repsToRetake }) => ({
    title: `@${actor} thinks they're better than you`,
    body: `Prove them wrong. ${repsToRetake} reps.`,
  }),
];

export const leadChangeVariantCount = VARIANTS.length;

/**
 * Builds the copy for one lead-change push.
 *
 * @param variantIndex Which variant to use. Defaults to a random pick;
 *   pass an explicit index to make a test deterministic. Out-of-range and
 *   negative values wrap, so a caller can hand in any integer.
 */
export function buildLeadChangeCopy(
  input: LeadChangeInput,
  variantIndex: number = Math.floor(Math.random() * VARIANTS.length),
): LeadChangeCopy {
  const safeIndex =
    ((Math.trunc(variantIndex) % VARIANTS.length) + VARIANTS.length) %
    VARIANTS.length;
  // Strip a leading `@` so a stored username of "@ana" does not render as
  // "@@ana" in a title that adds its own.
  const actor = input.actor.replace(/^@+/, '') || 'A friend';
  return VARIANTS[safeIndex]({...input, actor});
}
