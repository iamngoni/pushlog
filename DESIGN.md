---
name: Pushlog
description: A disciplined training ledger for sustainable push-up progress.
colors:
  signal-lime: "#C8F135"
  accent-ink-light: "#506900"
  on-accent: "#171811"
  on-accent-muted: "#485A16"
  warm-black: "#151611"
  deep-carbon: "#1F211A"
  raised-carbon: "#2A2C23"
  chalk: "#F3F5EA"
  paper: "#F7F7F2"
  warm-gray: "#A9AD9D"
  graphite: "#686B60"
  dark-divider: "#33362C"
  light-divider: "#DFE1D7"
  danger-dark: "#E46B58"
  danger-light: "#BC3824"
  warning-dark: "#F5B13D"
  warning-light: "#915108"
typography:
  scale: "11 · 12 · 13 · 15 · 17 · 20 · 24 · 28 · 32 · 40 · 48 · 56 · 72"
  metric-hero:
    fontFamily: "system-ui, sans-serif"
    fontSize: "72px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-3.2px"
    fontFeatures: "tabular-nums"
  heading-xlarge:
    fontFamily: "system-ui, sans-serif"
    fontSize: "48px"
    fontWeight: 800
    lineHeight: 1.02
    letterSpacing: "-2px"
  heading-large:
    fontFamily: "system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: "-1px"
  title:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  overline:
    fontFamily: "system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.32px"
rounded:
  indicator: "4px"
  chip: "8px"
  button: "12px"
  cell: "14px"
  card: "18px"
  primary: "24px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  xxl: "20px"
  block: "24px"
  section: "32px"
  sectionLarge: "40px"
  hero: "48px"
  heroLarge: "64px"
components:
  button-primary:
    backgroundColor: "{colors.signal-lime}"
    textColor: "{colors.on-accent}"
    typography: "{typography.title}"
    rounded: "{rounded.card}"
    height: "56px"
  button-secondary:
    backgroundColor: "{colors.chalk}"
    textColor: "{colors.warm-black}"
    typography: "{typography.title}"
    rounded: "{rounded.card}"
    height: "56px"
  button-ghost:
    backgroundColor: "transparent"
    border: "1px {colors.dark-divider}"
    textColor: "{colors.chalk}"
    rounded: "{rounded.card}"
    height: "56px"
  action-cell:
    backgroundColor: "{colors.deep-carbon}"
    textColor: "{colors.chalk}"
    rounded: "{rounded.cell}"
    height: "56px"
  progress-indicator:
    backgroundColor: "{colors.signal-lime}"
    rounded: "{rounded.indicator}"
    height: "8px"
  toast:
    backgroundColor: "{colors.raised-carbon}"
    rounded: "{rounded.card}"
    stripe: "4px tone colour"
    position: "top"
---

# Design System: Pushlog

## Overview

**Creative North Star: "The Training Ledger"**

Pushlog should feel like a precise record that quietly turns effort into
momentum. Large numbers make today's work instantly legible. Compact labels
provide the rhythm of a training log. Signal Lime marks the next action,
the current state, or earned completion — never decoration.

The product is flat, fast, and mature. Structure comes from spacing,
alignment, dividers, and tonal changes rather than floating cards or
ornamental effects. Motivation appears in the sequence and the feedback,
not in mascots, currencies, or visual noise.

**Key Characteristics:**

- One dominant action per screen.
- Strong numeric hierarchy with compact supporting labels.
- Restrained Signal Lime on active, selected, and completed states.
- Warm neutral light and dark themes rather than pure white or black.
- Divided, tactile controls with deliberate, modest corner radii.
- Brief state motion that respects reduced-motion settings.

## Implementation

The system lives in code, and the code is the source of truth:

| Concern | File |
|---|---|
| Palette, themes, `AppTheme.of(context)` | `lib/core/configs/colors.dart` |
| Type scale and families | `lib/core/configs/typography.dart` |
| Spacing and radius scales | `lib/core/configs/spacing.dart` |
| Durations, curves, haptics | `lib/core/configs/motion.dart` |
| Overlay shadows and inset edges | `lib/core/configs/elevation.dart` |
| Buttons and press feedback | `lib/core/views/widgets/pushlog_button.dart` |
| Cards, section headers, stat blocks | `lib/core/views/widgets/pushlog_surface.dart` |
| In-app messages | `lib/core/views/widgets/pushlog_toast.dart` |
| Empty states | `lib/core/views/widgets/empty_state.dart` |
| Initials avatars | `lib/core/views/widgets/avatar_badge.dart` |

Screens must not hard-code a colour, size, gap, or duration. If a value is
missing, add it to the scale so it exists exactly once.

## Colors

Every neutral sits on a warm olive axis — hue ≈ 74°, saturation 9–14% — so
the light and dark themes read as the same product rather than two
inversions of it. Signal Lime shares that hue, which is why the accent
feels native to the neutrals instead of pasted on top of them.

Colours are defined as fixed ramps. Never lighten or darken at the call
site: the accent ramp rotates hue from 66° at its palest tint to 80° at its
deepest shade, because lightening a saturated colour without rotating it
toward yellow drains the life out of it.

### Primary

- **Signal Lime (`accent500`):** primary actions, active progress,
  selection, and earned completion. Never a general background treatment.
- **Accent Ink:** lime as *text*. The raw accent cannot carry text on
  paper, so the light theme uses a deep lime ink instead.

### Neutral

- **Warm Black / Deep Carbon / Raised Carbon:** dark canvas, grouped
  surface, and the one step above it used for overlays.
- **Chalk / Paper:** primary text on dark, and the light canvas.
- **Warm Gray / Graphite:** secondary text for dark and light themes.
- **Dividers:** structural separators, not decorative borders.

### Semantic

Danger and warning have separate inks per theme, each verified against the
surface it sits on. Success reuses Signal Lime: in a training ledger,
"done" and "next" are the same signal, and a second green would dilute it.

### Named Rules

**The One Signal Rule.** Signal Lime has one job on each screen: identify
the next action or the most important current state. Today's count is not
lime while the target is outstanding — the block *becomes* lime when the
target is met, so the accent is the reward.

**The Warm Neutral Rule.** Pure black and pure white are prohibited. Every
neutral stays slightly warm so both themes feel related.

**The Color Independence Rule.** Every state communicated with colour must
also have text, shape, progress, or an icon behind it.

**The No Alpha Ink Rule.** Text on a coloured background gets a hand-picked
colour in that background's own hue. Dropping the opacity of black over
Signal Lime leaks the lime through and reads as disabled.

### Contrast

All pairings meet WCAG AA. Verified ratios:

| Pairing | Ratio |
|---|---|
| On-accent ink on Signal Lime | 13.7:1 |
| On-accent muted on Signal Lime | 5.9:1 |
| Signal Lime on Warm Black | 13.9:1 |
| Warm Gray on Warm Black | 7.9:1 |
| Graphite on Paper | 5.1:1 |
| Tertiary ink (dark / light) | 6.0:1 / 6.4:1 |
| Danger ink (dark / light) | 5.1:1 / 5.2:1 |
| Warning ink (dark / light) | 8.7:1 / 5.8:1 |

## Typography

**All faces:** the platform system sans. There is no monospace face; the
`labelMono` name that once implied one has been retired.

Sizes are hand-picked rather than generated from a ratio, because a modular
scale produces fractional sizes that round inconsistently and leaves gaps
exactly where the UI needs one.

### Families

- **Metric** — training numbers. Heavy, tightly tracked, and always set
  with **tabular figures** so a counter animating from 9 to 10 does not
  shift the glyphs beside it.
- **Heading** and **body** — proportional figures, normal tracking. Prose
  is capped at roughly 65 characters per line.
- **Label** — small, semi-bold, for metadata and controls. `overline` is
  the all-caps variant, opened up by ~0.12em.

### Named Rules

**The Number Leads Rule.** Training values lead through size and weight.
Labels explain them without competing — a caption is set smaller *and*
lighter than the figure above it.

**The Sentence Case Rule.** Uppercase is for short labels only. Sentences,
instructions, and error messages are sentence case; all-caps prose is
slower to read and reads as shouting.

**The Floor Rule.** Nothing renders below 10pt. Requests for smaller sizes
are clamped in the token, not honoured.

**The Baseline Rule.** Mixed type sizes on one row align on the baseline,
never on centre.

## Elevation

Pushlog is flat at rest and uses no decorative shadows. Depth comes from
background tone, divider lines, and state changes. Shadows are reserved for
surfaces that genuinely float above moving content — toasts, sheets, and
dialogs — and each is built from two layers: a soft cast shadow plus a
tighter ambient shadow where the surface blocks light from reaching
underneath it.

### Named Rules

**The Ledger Plane Rule.** Core content lives on one plane. If a screen
resembles a pile of cards, the hierarchy is wrong.

**The One Boundary Rule.** A tone change and a border say the same thing
twice. A surface that already sits a step off its background carries no
border.

**The Inset Edge Rule.** Avatars and any user-supplied imagery get an inset
hairline rather than a border, so the edge is defined without a hard stroke
that clashes with the content underneath.

## Motion

Every duration routes through `AppMotion.duration(context, …)`, which
returns zero when the platform asks for reduced motion. Reading the media
query at the call site is the most common accessibility regression in the
app; the helper exists so it cannot happen.

Deceleration curves (`easeOutQuart`, `easeOutCubic`) for anything entering
the screen. No bounce, no elastic.

## Components

### Buttons

Three variants map to the page's action pyramid — **primary** (Signal
Lime), **secondary** (solid neutral), **ghost** (outline). A screen gets
one primary. Destructive actions stay quiet on the page that offers them
and become primary only inside their own confirmation dialog.

Minimum height 44pt, 56pt for the standard control. Press feedback is a
slight settle rather than an ink ripple, which washes out on large flat
cells.

### In-app messages

`PushlogToast` replaces `SnackBar`. Messages appear at the **top** of the
screen — the bottom belongs to the action strip and the tab bar, the exact
region a thumb occupies mid-set.

Four tones — success, info, warning, danger — each with an icon and a 4px
stripe so the meaning never rests on colour alone. A draining hairline
shows the time remaining, the card can be swiped up or dismissed outright,
and it can carry a single action such as Undo.

### Cards / Containers

Square-ish and architectural: 18px for cards, 24px for the primary daily
block. No shadow at rest, no border when a tone change already separates
the surface. Internal padding 20px for compact groups, 24px at screen
edges.

### Inputs / Fields

Full-width, recessed one tonal step below the page (darker reads as
further away), 56px minimum height. Validation is answered as the user
types, not on submit. Errors use the danger ink with an icon.

### Navigation

Four stable destinations: Today, History, Friends, You. Every glyph comes
from the rounded family — mixing rounded and outlined icons is invisible in
isolation and obvious in a row of four. Selection is carried by ink level,
text weight, and an accent rule, so it survives a greyscale screenshot.

### Empty states

Treated as onboarding, not as errors. Icon, what the feature is for, and
the one action that fills it. Chrome that operates on nothing — filters,
summary rows of zeroes — is hidden while the state is showing.

### Daily Target

Pushlog's signature component. Today's count sits at 72pt on a neutral
surface with a lime progress track while the target is outstanding; the
whole block turns lime on completion. It reveals plan rationale
progressively rather than placing every metric on the home screen.

## Do's and Don'ts

### Do:

- **Do** make today's target and next action understandable within one glance.
- **Do** reserve Signal Lime for active, selected, completed, and primary-action states.
- **Do** take every colour, size, gap, radius, and duration from the token files.
- **Do** use spacing to create rhythm rather than wrapping every section in a card.
- **Do** keep celebrations brief, earned, and optional through the selected coaching style.
- **Do** support dynamic text, reduced motion, VoiceOver, TalkBack, and 44-by-44-point touch targets.
- **Do** provide manual alternatives when camera, HealthKit, or watch features are unavailable.

### Don't:

- **Don't** use childish mascots, cartoon-heavy fitness experiences, or imitation-Duolingo visuals.
- **Don't** build noisy badge walls, multiple currencies, constant confetti, or gamification that competes with the workout.
- **Don't** use punitive streak mechanics, guilt-driven notifications, or language that frames rest as failure.
- **Don't** set prose, errors, or instructions in all caps.
- **Don't** put grey or translucent text on a coloured background.
- **Don't** pair a tone change with a border, or scale an icon up to fill a space.
- **Don't** foreground every available metric like a generic fitness dashboard.
- **Don't** make medical or performance claims without transparent calculations and evidence.
- **Don't** use glassmorphism, gradient text, decorative side stripes, nested cards, or saturated inactive states.
