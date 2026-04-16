# UX Principles

This document outlines the user experience standards and principles for SETA. Every feature should be built with these principles in mind to deliver a polished, professional experience that shows we care about our users.

## Core Philosophy

**Thoughtful Polish Over Speed**: Users notice when an app is carefully crafted. Small details compound into an experience that feels premium and intentional.

## Loading States

### Rule: Never Show Blank Screens

Users should always know what's happening. Every loading state needs proper feedback.

**Do:**
- Show skeleton loaders while content loads
- Display progress indicators during operations
- Use smooth transitions with minimum durations
- Provide context (e.g., "Syncing workout data...")

**Don't:**
- Flash empty screens
- Show content that immediately disappears
- Leave users wondering if the app is working
- Use jarring instant transitions for quick operations

**Examples:**
```dart
// Good: Minimum splash duration for smooth experience
static const _minSplashDuration = Duration(milliseconds: 1500);

// Good: Loading indicator with context
CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
)

// Good: Skeleton loader
Container(
  height: 80,
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
  ),
)
```

### Minimum Duration Guidelines

For operations that complete quickly, enforce minimum durations to avoid jarring flashes:

| Operation | Minimum Duration | Reason |
|-----------|-----------------|--------|
| Splash screen | 1500ms | Brand impression, smooth entry |
| Pull-to-refresh | 800ms | User expects visual feedback |
| Button press feedback | 200ms | Confirms action registered |
| Page transitions | 300ms | Smooth navigation feel |

## Animations and Transitions

### Rule: Motion Should Be Purposeful

Every animation should have a reason - guide attention, provide feedback, or smooth transitions.

**Timing Standards:**
- **Fast**: 150-200ms - Micro-interactions (button press, toggle)
- **Medium**: 250-350ms - Content transitions (page navigation)
- **Slow**: 400-600ms - Complex animations (card expansion)

**Do:**
- Use consistent easing curves (e.g., `Curves.easeInOut`)
- Animate related properties together
- Respect user's motion preferences (reduce motion if enabled)
- Keep animations subtle and professional

**Don't:**
- Use different timings for similar interactions
- Animate just because you can
- Use bouncy or overly playful animations (this is a fitness app, not a game)
- Make users wait for animations to complete critical actions

## User Feedback

### Rule: Always Acknowledge User Actions

Users need to know their actions were registered and what happened as a result.

**Success Feedback:**
```dart
// Good: Clear, helpful confirmation
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Health data imported successfully'),
    backgroundColor: AppColors.surface,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ),
);
```

**Error Feedback:**
```dart
// Good: Helpful error with action
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Failed to sync workout data'),
    backgroundColor: Colors.red.shade800,
    action: SnackBarAction(
      label: 'Retry',
      onPressed: () => _retrySync(),
    ),
  ),
);
```

**Status Messaging:**
- Be positive and clear
- Use active voice ("Tracking with iPhone" not "iPhone tracking")
- Show what's working, not what's missing
- Provide context, not technical errors

**Examples:**
```dart
// Bad: Negative, error-like
'Watch app not installed'
'No watch connection'

// Good: Positive, informative
'Tracking with iPhone'
'Connected to Watch'
```

## Visual Consistency

### Rule: Design System is Sacred

Never introduce one-off styles or colors. Everything should use the design system.

**Do:**
- Use `AppColors` constants for all colors
- Use `AppTypography` for all text styles
- Follow spacing conventions (8px grid: 8, 16, 24, 32, etc.)
- Reuse components from `/core/widgets/`

**Don't:**
- Hardcode colors (`Color(0xFF123456)` outside theme)
- Create custom text styles inline
- Use arbitrary spacing values (e.g., 13px, 27px)
- Duplicate components instead of extracting shared widgets

### Spacing Standards

Use consistent spacing throughout:

```dart
// Standard spacing scale (8px grid)
const SizedBox(height: 8)   // Tight
const SizedBox(height: 16)  // Normal
const SizedBox(height: 24)  // Comfortable
const SizedBox(height: 32)  // Section break
const SizedBox(height: 48)  // Major division
```

## Thoughtful Details

### Rule: Sweat the Small Stuff

It's the small details that separate a good app from a great one.

**Examples from SETA:**

1. **Calculated Age from Birthdate**
   - Store birthdate (immutable fact)
   - Calculate age dynamically (always current)
   - Show both in picker: "January 15, 1990 (Age: 35)"

2. **Positive Status Messaging**
   - "Tracking with iPhone" (green) instead of "Watch not connected" (gray)
   - Shows what's working, not what's broken

3. **Real Device Counts**
   - "2 Active Connections" not hardcoded
   - Updates in real-time via streams
   - Refreshes after returning from device page

4. **Smart Import**
   - One tap to import from Health
   - Pre-fills form fields
   - User can still manually edit after import

5. **Contextual Actions**
   - Refresh icon only appears when watch app is installed
   - Connect button appears when device is disconnected
   - Actions change based on state

### Common Patterns

**Pull-to-Refresh:**
```dart
RefreshIndicator(
  onRefresh: _checkDevices,
  backgroundColor: AppColors.surface,
  color: AppColors.accent,
  child: ListView(...),
)
```

**Loading Button:**
```dart
ElevatedButton(
  onPressed: _isLoading ? null : _handleSubmit,
  child: _isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Submit'),
)
```

**Empty States:**
```dart
// Good: Helpful, actionable
Center(
  child: Column(
    children: [
      Icon(Icons.fitness_center, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      Text('No workouts yet', style: AppTypography.titleMedium),
      const SizedBox(height: 8),
      Text(
        'Start your first workout to see it here',
        style: AppTypography.bodyMedium,
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () => _startWorkout(),
        child: const Text('Start Workout'),
      ),
    ],
  ),
)
```

## Accessibility

### Rule: Build for Everyone

Accessibility isn't an afterthought - it's part of polish.

**Do:**
- Provide semantic labels for interactive elements
- Ensure sufficient color contrast (WCAG AA minimum)
- Support dynamic type sizes
- Test with VoiceOver/TalkBack
- Make tap targets at least 44x44 points

**Don't:**
- Rely on color alone to convey information
- Use tiny touch targets
- Assume all users can see animations
- Forget about keyboard navigation (iPad support)

## Performance as UX

### Rule: Fast Feels Polished

Performance issues break the illusion of quality.

**Standards:**
- Page transitions: < 16ms (60 FPS)
- First meaningful paint: < 1 second
- Time to interactive: < 3 seconds
- No frame drops during animations

**Do:**
- Use `const` constructors everywhere possible
- Lazy load heavy content
- Optimize images and assets
- Profile before optimizing (measure, don't guess)

**Don't:**
- Rebuild entire widget trees unnecessarily
- Load all data upfront
- Ignore performance warnings
- Sacrifice UX for premature optimization

## Error Handling

### Rule: Errors Are Part of the Experience

How we handle errors defines the user's trust in the app.

**Principles:**
1. **Prevent when possible** - Validation before submission
2. **Recover gracefully** - Auto-retry transient failures
3. **Explain clearly** - What went wrong in plain language
4. **Provide action** - What can the user do about it

**Error Message Guidelines:**
```dart
// Bad: Technical, scary
'NullPointerException in WorkoutBloc'
'Network error: 500 Internal Server Error'

// Good: Clear, actionable
'Unable to save workout'
'Connection lost. Check your internet and try again.'
```

**Retry Pattern:**
```dart
// Good: Automatic retry with feedback
Future<void> _saveWorkout() async {
  const maxRetries = 3;
  var attempt = 0;

  while (attempt < maxRetries) {
    try {
      await repository.saveWorkout(workout);
      _showSuccess('Workout saved');
      return;
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) {
        _showError('Unable to save workout', canRetry: true);
      } else {
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }
}
```

## Testing for Polish

### Rule: Test Like a User, Not a Developer

**Manual Testing Checklist:**
- [ ] Does the splash screen feel smooth?
- [ ] Are all loading states covered?
- [ ] Do animations feel natural at 60 FPS?
- [ ] Are error messages helpful?
- [ ] Does every action provide feedback?
- [ ] Is the spacing consistent?
- [ ] Do colors follow the design system?
- [ ] Can you complete tasks quickly?
- [ ] Does it feel premium?

**Device Testing:**
- [ ] iPhone SE (small screen)
- [ ] iPhone Pro Max (large screen)
- [ ] iPad (different layout considerations)
- [ ] Different iOS versions

**Edge Cases:**
- [ ] No internet connection
- [ ] Slow internet connection
- [ ] Empty states (no data)
- [ ] Maximum data (performance)
- [ ] Interrupted flows (phone call during workout)

## When to Break the Rules

Rules exist to maintain consistency, but sometimes breaking them creates a better experience.

**Valid reasons to deviate:**
1. **User safety** - Immediate error feedback without delay
2. **User expectation** - Platform conventions (iOS patterns)
3. **Technical constraints** - Third-party SDK limitations
4. **Better UX** - Measurably improves user satisfaction

**Invalid reasons:**
1. ~~"It's faster to hardcode"~~ - Technical debt compounds
2. ~~"Users won't notice"~~ - They will, subconsciously
3. ~~"It's just one screen"~~ - Inconsistency spreads
4. ~~"We'll fix it later"~~ - Later rarely comes

## Continuous Improvement

Polish is never "done" - it's a continuous commitment.

**Regular Audits:**
- Monthly UX review of new features
- Quarterly consistency check across the app
- User feedback analysis for pain points
- Performance monitoring and optimization

**User Feedback:**
- Watch for patterns in support requests
- Monitor app store reviews for UX mentions
- Run periodic user testing sessions
- Track task completion times

## References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Material Design](https://m3.material.io/)
- [WCAG Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Google's HEART Framework](https://www.dtelepathy.com/ux-metrics/#happiness) (UX metrics)

---

Remember: **Every interaction is an opportunity to show we care about our users' experience.**
