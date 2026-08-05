---
name: Pushlog
description: A disciplined training ledger for sustainable push-up progress.
colors:
  signal-lime: "#D7FF1F"
  warm-black: "#0A0908"
  deep-carbon: "#141210"
  chalk: "#F8F5F0"
  paper: "#FAFAF8"
  warm-gray: "#B7B1A9"
  graphite: "#625D58"
  dark-divider: "#282522"
  light-divider: "#D5D2CE"
  dark-accent-stroke: "#F8F5F029"
  light-accent-stroke: "#0A090824"
  accessible-lime-ink: "#718500"
typography:
  display:
    fontFamily: "system-ui, sans-serif"
    fontSize: "64px"
    fontWeight: 900
    lineHeight: 1
  headline:
    fontFamily: "system-ui, sans-serif"
    fontSize: "48px"
    fontWeight: 900
    lineHeight: 1
  title:
    fontFamily: "system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 900
    lineHeight: 1
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "SF Mono, Menlo, Monaco, monospace"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "1.5px"
rounded:
  indicator: "2px"
  square: "0px"
spacing:
  xs: "4px"
  sm: "8px"
  compact: "12px"
  md: "16px"
  lg: "24px"
  screen: "28px"
  xl: "32px"
  section: "48px"
components:
  button-primary:
    backgroundColor: "{colors.signal-lime}"
    textColor: "{colors.warm-black}"
    typography: "{typography.title}"
    rounded: "{rounded.square}"
    padding: "16px 24px"
    height: "56px"
  button-secondary:
    backgroundColor: "{colors.warm-black}"
    textColor: "{colors.chalk}"
    typography: "{typography.label}"
    rounded: "{rounded.square}"
    padding: "16px 24px"
    height: "56px"
  action-cell:
    backgroundColor: "{colors.signal-lime}"
    textColor: "{colors.warm-black}"
    typography: "{typography.title}"
    rounded: "{rounded.square}"
    height: "88px"
  progress-indicator:
    backgroundColor: "{colors.signal-lime}"
    textColor: "{colors.warm-black}"
    rounded: "{rounded.indicator}"
    height: "8px"
---

# Design System: Pushlog

## Overview

**Creative North Star: "The Training Ledger"**

Pushlog should feel like a precise record that quietly turns effort into momentum. Large numbers make today's work instantly legible. Monospaced labels provide the rhythm of a training log. Signal Lime marks the next action, current state, or earned completion, never decoration.

The product is flat, fast, and mature. Structure comes from spacing, alignment, dividers, and tonal changes rather than floating cards or ornamental effects. Motivation appears in the sequence and feedback, not in mascots, currencies, or visual noise.

**Key Characteristics:**

- One dominant action per screen.
- Strong numeric hierarchy with compact supporting labels.
- Restrained Signal Lime on active, selected, and completed states.
- Warm neutral light and dark themes rather than pure white or black.
- Square, divided controls that feel tactile and deliberate.
- Brief state motion that respects reduced-motion settings.

## Colors

The palette is a warm neutral ledger punctuated by one high-visibility training signal.

### Primary

- **Signal Lime:** Reserved for primary actions, active progress, selection, and earned completion. It must never become a general background treatment.

### Neutral

- **Warm Black:** Dark canvas and fixed ink on Signal Lime.
- **Deep Carbon:** Secondary dark surface for grouped content.
- **Chalk:** Primary text on dark surfaces.
- **Paper:** Light canvas with a warm tint.
- **Warm Gray and Graphite:** Secondary text for dark and light themes.
- **Dark Divider and Light Divider:** Structural separators, not decorative borders.

### Named Rules

**The One Signal Rule.** Signal Lime has one job on each screen: identify the next action or the most important current state.

**The Warm Neutral Rule.** Pure black and pure white are prohibited. Every neutral remains slightly warm so both themes feel related.

**The Color Independence Rule.** Every state communicated with color must also have text, shape, progress, or icon support.

## Typography

**Display Font:** Platform system sans

**Body Font:** Platform system sans

**Label/Mono Font:** SF Mono with Menlo, Monaco, and monospace fallbacks

**Character:** Heavy system numerals feel physical and immediate. Small monospaced labels feel measured and exact. Ordinary explanatory copy stays readable and quiet.

### Hierarchy

- **Display** (900, 64px, 1.0): Today's count, target, and live-session metrics. The existing 104px size is reserved for a single hero count when the viewport safely supports it.
- **Headline** (900, 48px, 1.0): Completion totals and major onboarding outcomes.
- **Title** (900, 32px, 1.0): Section values and compact numeric emphasis.
- **Body** (400, 16px, 1.45): Explanations, plan rationale, errors, and onboarding guidance. Prose is capped at 70 characters per line.
- **Label** (400, 12px, 1.45, 1.5px tracking): Navigation, metadata, short control labels, and dates. Uppercase is limited to short labels.

### Named Rules

**The Number Leads Rule.** Training values lead through size and weight. Labels explain them without competing.

**The Mono Restraint Rule.** Monospaced text is for metadata and controls. Paragraphs and instructional copy must use the system sans.

## Elevation

Pushlog is flat by default and uses no decorative shadows. Depth comes from background tone, divider lines, and state changes. Temporary overlays may use a restrained platform-standard shadow only when they must separate from moving content.

### Named Rules

**The Ledger Plane Rule.** Core content lives on one plane. If a screen resembles a pile of cards, the hierarchy is wrong.

## Components

### Buttons

- **Shape:** Square and architectural, with no corner rounding on primary action cells.
- **Primary:** Signal Lime with Warm Black text, at least 56px high and 44px wide.
- **Hover / Focus:** Native pressed feedback plus a visible focus outline. State transitions run for 150 to 200ms and disappear when reduced motion is enabled.
- **Secondary / Ghost:** Neutral surface or transparent background, visible divider or focus treatment, and no inactive Signal Lime.

### Chips

- **Style:** Compact square or gently rounded indicators using neutral fills and concise labels.
- **State:** Selected chips use Signal Lime plus an explicit selected label or check. Unselected chips stay neutral.

### Cards / Containers

- **Corner Style:** Square by default. The 2px indicator radius is for progress marks, not generic cards.
- **Background:** Canvas or one adjacent tonal surface.
- **Shadow Strategy:** None at rest.
- **Border:** One-pixel structural divider only when spacing cannot establish the relationship.
- **Internal Padding:** 16px for compact groups, 24px for primary sections, and 28px at screen edges.

### Inputs / Fields

- **Style:** Full-width, neutral surface, one-pixel divider or outline, 56px minimum height, and system body type.
- **Focus:** Signal Lime outline plus a persistent label. Focus cannot depend on color alone.
- **Error / Disabled:** Plain-language status beneath the field. Disabled states retain readable contrast and explain how to continue when useful.

### Navigation

Use three stable destinations: Today, History, and Settings. The active destination has stronger text and a structural state indicator. Keep labels short, preserve platform safe areas, and provide semantic selection state to assistive technology.

### Daily Target

The daily target is Pushlog's signature component. It combines completed reps, today's planned reps, weekly context, and one primary start or log action. It reveals plan rationale progressively rather than placing every metric on the home screen.

## Do's and Don'ts

### Do:

- **Do** make today's target and next action understandable within one glance.
- **Do** reserve Signal Lime for active, selected, completed, and primary-action states.
- **Do** use 16px, 24px, and 28px spacing to create clear rhythm rather than wrapping every section in a card.
- **Do** keep celebrations brief, earned, and optional through the selected coaching style.
- **Do** support dynamic text, reduced motion, VoiceOver, TalkBack, and 44-by-44-point touch targets.
- **Do** provide manual alternatives when camera, HealthKit, or watch features are unavailable.

### Don't:

- **Don't** use childish mascots, cartoon-heavy fitness experiences, or imitation-Duolingo visuals.
- **Don't** build noisy badge walls, multiple currencies, constant confetti, or gamification that competes with the workout.
- **Don't** use punitive streak mechanics, guilt-driven notifications, or language that frames rest as failure.
- **Don't** create decorative, poster-like layouts that make core controls harder to find.
- **Don't** foreground every available metric like a generic fitness dashboard.
- **Don't** make medical or performance claims without transparent calculations and evidence.
- **Don't** use glassmorphism, gradient text, decorative side stripes, nested cards, or saturated inactive states.
