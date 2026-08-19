//
//  pushlog
//  about_sheet.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

/// Opens the About sheet.
///
/// Matches the day-detail and friend sheets: rounded top, drag handle, safe
/// area. Sheets in one app should not disagree about what a sheet looks like.
Future<void> showAboutSheet(BuildContext context, AppTheme theme) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.background,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.top(AppRadius.xxl),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AboutSheet(theme: theme),
  );
}

/// What Pushlog is, for someone deciding whether to sign in.
///
/// This sheet is reachable before a user has an account, so it answers
/// "what am I signing into?" rather than listing build metadata.
class AboutSheet extends StatelessWidget {
  const AboutSheet({required this.theme, super.key});

  final AppTheme theme;

  static const List<({IconData icon, String title, String body})> _points = [
    (
      icon: Icons.trending_up_rounded,
      title: 'A plan, not a target',
      body:
          'An adjustable 8, 12, or 16-week progression built around your '
          'current ability, with planned rest days and periodic reassessment.',
    ),
    (
      icon: Icons.bolt_rounded,
      title: 'Logging that stays out of the way',
      body:
          'Record a set in a tap, or run a counted session and let the app '
          'track the reps for you.',
    ),
    (
      icon: Icons.insights_rounded,
      title: 'Progress you can trust',
      body:
          'Daily, weekly, and monthly totals, streaks, best days, and '
          'all-time counts — adapted from what you actually did.',
    ),
    (
      icon: Icons.groups_rounded,
      title: 'Friends, optionally',
      body:
          'Claim a username, add friends, and compare on daily, weekly, '
          'and all-time boards. Competition is opt-in, never the point.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // `showModalBottomSheet` gives its child loose horizontal constraints,
    // so without an explicit width this content shrink-wraps into a narrow
    // pill instead of using the sheet's available width.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.block,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ABOUT',
                style: AppTypography.overline(color: theme.tertiaryInk),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Pushlog',
                style: AppTypography.headingLarge(color: theme.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              // The same accent rule the sign-in screen uses, so the sheet
              // reads as part of that screen rather than a separate place.
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: AppRadius.all(AppRadius.indicator),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Pushlog turns a longer-term push-up goal into a realistic '
                'plan and a simple daily practice — without mascots, streak '
                'guilt, or a wall of badges competing with the workout.',
                style: AppTypography.bodyLarge(color: theme.secondaryInk),
              ),
              const SizedBox(height: AppSpacing.sectionLarge),
              for (final point in _points) ...[
                _AboutPoint(point: point, theme: theme),
                const SizedBox(height: AppSpacing.xxl),
              ],
              const _AboutFootnote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutPoint extends StatelessWidget {
  const _AboutPoint({required this.point, required this.theme});

  final ({IconData icon, String title, String body}) point;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(point.icon, size: 20, color: theme.tertiaryInk),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.title,
                style: AppTypography.title(color: theme.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                point.body,
                style: AppTypography.bodySmall(color: theme.secondaryInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutFootnote extends StatelessWidget {
  const _AboutFootnote();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: theme.tertiaryInk,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              'Your sessions sync to your account so you can pick up on '
              'another device. Your email stays private — friends find you '
              'by username.',
              style: AppTypography.bodySmall(color: theme.tertiaryInk),
            ),
          ),
        ],
      ),
    );
  }
}
