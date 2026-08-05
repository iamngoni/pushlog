# Pushlog Onboarding and Progression

## Product Decision

Pushlog serves beginners and experienced users through one adaptive onboarding flow. Guidance changes with experience level, but the underlying training record, plan model, and daily loop stay shared.

The default plan horizon is 12 weeks. Users can choose a shorter or longer horizon, edit the generated plan, and change coaching or consistency preferences later.

## Reference Patterns

The following Mobbin flows were reviewed as structural references. Pushlog borrows interaction patterns, not visual identity.

- [Tonal: Setting up a fitness profile](https://mobbin.com/flows/9f597ed6-aea4-4ec7-b573-48ea7484b164): single-topic steps, goal grouping, a final confirmation summary, and editable preferences after onboarding.
- [Equinox+: Personalizing a program](https://mobbin.com/flows/754cee5d-c1f4-44a7-9ae9-5e09474db3a3): goal selection followed by a simple physical assessment and a clear generated-program explanation.
- [Pliability: Tailoring content](https://mobbin.com/flows/ba530414-fbc6-4e1f-a353-bbed6c52305a): a short, skippable experience and frequency flow.
- [Duolingo: Onboarding](https://mobbin.com/flows/7d7aacbe-213b-471e-8b1f-b5b7087bcb65): one decision per screen, a persistent progress rail, self-reported level, daily commitment, and a recommended path.
- [Pliability: Marking a challenge as complete](https://mobbin.com/flows/0991bfd8-c3da-4dad-b151-f25189371484): weekly consistency, compact streak context, and a post-session difficulty check.
- [Atoms: Habit reminder](https://mobbin.com/flows/0d561da1-ec6b-4741-a57c-a63e0749a119): reminders tied to an individual routine and weekly frequency rather than a generic daily alarm.

### Patterns to Use

1. One meaningful decision per screen.
2. A visible step rail with back navigation and saved answers.
3. Choice rows with concise explanations, not unlabeled icons.
4. A baseline assessment that can be completed now or entered manually.
5. A generated plan summary that explains the first week and remains editable.
6. A fixed primary action that is disabled until the current answer is valid.
7. Account creation after the user understands the value of the plan, when the data migration path is ready.
8. One post-session question that can improve future targets.

### Patterns to Reject

1. Mascots as the primary source of instruction.
2. Artificial currencies, XP, loot, badge walls, and reward claims.
3. Daily streak pressure that ignores planned rest days.
4. Long inspirational quotes in completion summaries.
5. Height, weight, age, or demographic questions that are not required by the push-up plan.
6. Dense dashboards that present every metric before the user asks for it.

## Evidence Boundary

Pushlog is a training planner and log, not a medical device or a guarantee of a future performance result.

The 2026 American College of Sports Medicine position stand found that progressive resistance training improves strength and physical performance, that consistency is more important than unnecessary complexity for most healthy adults, and that bodyweight and home-based training can be effective. It also found benefits from at least two resistance-training sessions per week and two to three sets for strength-focused work.

The Physical Activity Guidelines for Americans recognize push-ups as muscle-strengthening activity, recommend muscle-strengthening activity on at least two days per week, and advise inactive adults to start with small amounts and build over time.

Sources:

- [ACSM 2026 resistance-training update](https://acsm.org/resistance-training-guidelines-update-2026/)
- [ACSM 2026 position stand on PubMed](https://pubmed.ncbi.nlm.nih.gov/41843416/)
- [Physical Activity Guidelines for Americans](https://health.gov/paguidelines/second-edition/pdf/Physical_Activity_Guidelines_2nd_edition.pdf)

The sources do not provide a universal push-up progression formula or guarantee that a chosen repetition target will be reached in 12 weeks. Pushlog must present the user's target as an aspiration, expose how each training target is calculated, and adapt from actual performance.

## Onboarding Flow

### 1. Intent

Question: What do you want Pushlog to help with?

Choices:

- Build a consistent habit.
- Increase my unbroken push-up maximum.
- Improve push-up endurance.
- Maintain my current ability.
- Set my own target.

### 2. Experience

Question: Which description fits you today?

Choices:

- New: I am starting or returning after a long break.
- Regular: I currently train one to three times per week.
- Experienced: I train consistently and want direct plan control.

This changes guidance density and defaults. It never locks advanced controls.

### 3. Baseline

Question: How many clean push-ups can you complete before form breaks?

Options:

- Enter a recent number.
- Run a guided baseline test.
- Start conservatively without a test.

The baseline test must include a stop-on-pain warning, a manual count option, and camera tracking only when supported.

### 4. Outcome

Question: Where would you like to be at the end of the plan?

Capture a target unbroken repetition count and plan duration. Default to 12 weeks. Make it clear that this is a target, not a prediction.

### 5. Schedule

Question: When can you train consistently?

Capture two to five sessions per week and preferred weekdays. Recommend at least two sessions, include planned rest days, and allow changes at any time.

### 6. Consistency

Question: What should count as staying on track?

Choices:

- Weekly plan: complete the planned sessions during the week.
- Daily practice: maintain a daily check-in with recovery days counted honestly.
- No streak: show progress without a streak counter.

### 7. Coaching

Question: How should Pushlog coach you?

Choices:

- Calm: concise, low-pressure prompts.
- Energetic: stronger encouragement and more visible celebration.
- Minimal: numbers and status only.

### 8. Reminder

Offer reminders only after schedule selection. Pre-fill the selected training days and let the user choose a time or skip.

### 9. Plan Preview

Show:

- The 12-week target as an aspiration.
- This week's scheduled days.
- Today's planned sets and repetitions.
- The next reassessment date.
- A plain-language explanation of the starting workload.
- Edit and confirm actions.

## Initial Progression Model

The first internal-testing version should use a deliberately simple and transparent model:

1. Convert the baseline maximum into a conservative working-set target below the maximum.
2. Use two sets for new users and two or three sets for regular and experienced users.
3. Schedule at least two sessions per week, with user-selected rest days.
4. Move the working target gradually toward the target-derived workload across the selected plan duration.
5. Round changes to whole repetitions and avoid increasing every session solely to preserve a visual streak.
6. Reassess every four weeks or when the user requests it.
7. Ask whether a completed session felt easy, right, hard, or painful.
8. Repeat or reduce the next target after hard sessions. Stop progression and show a safety message after pain.

All calculations must be covered by deterministic unit tests. The generated plan must store its inputs and version so future algorithm changes do not silently rewrite an active plan.

## Daily Loop

The Today screen should answer four questions in order:

1. Is today a training day or a planned recovery day?
2. What is the target?
3. How much is complete?
4. What is the next action?

The primary action opens the planned session. Manual `+1`, `+10`, and `+25` logging remains available as a compact secondary control.

## Completion Loop

After a planned session:

1. Confirm completed repetitions and duration.
2. Show today's target completion and this week's completed sessions.
3. Ask how the workload felt: easy, right, hard, or painful.
4. Explain any resulting adjustment in one sentence.
5. Return to Today with a brief state transition.

Sharing and friend encouragement are optional secondary actions. Completion must never be blocked by social actions.

## Internal Testing Gate

- Onboarding can be completed, resumed, edited, and reset.
- Existing users receive a safe migration path and are not forced to lose workout data.
- Plan calculations and serialization have unit tests.
- Today, live session, manual logging, history, reminders, export, reset, and authentication remain functional.
- Android internal app bundle and iOS archive build successfully from clean source.
- Store listings explain camera, HealthKit, watch, account, and data-deletion behavior accurately.
- Real-device checks cover Android manual sessions and iOS camera, HealthKit, Apple sign-in, Google sign-in, and watch fallback.
