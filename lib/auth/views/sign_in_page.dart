import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/about_sheet.dart';
import 'package:pushlog/core/views/widgets/google_glyph.dart';
import 'package:pushlog/core/views/widgets/gym_backdrop.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_logo.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  /// Whether to offer Sign in with Apple.
  ///
  /// On Apple platforms this is a system sheet the user already trusts. On
  /// Android it would fall back to a web redirect, which is a worse journey
  /// than the Google button sitting right beside it — and it would strand
  /// anyone who picked it, because the resulting account cannot be reached
  /// again from an Android device without that same detour. Offering it
  /// there advertises parity the platform does not have.
  static bool get _appleSignInIsOffered => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final message = switch (context.watch<AuthCubit>().state) {
      AuthSignedOut(:final message) => _readableMessage(message),
      _ => null,
    };

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          // Behind everything, and outside the SafeArea so the texture runs
          // under the status bar rather than stopping at a visible seam.
          const Positioned.fill(child: GymBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.proseMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.block),
                      // About is the only header affordance now. The wordmark
                      // that used to sit opposite it would repeat the name the
                      // brand block below already states at full size.
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _AboutButton(),
                      ),
                      const Spacer(flex: 2),
                      const Center(child: PushlogLogo()),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Pushlog',
                        textAlign: TextAlign.center,
                        style: AppTypography.headingXLarge(color: theme.ink),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // This screen is a hard gate — there is no guest path
                      // — so the line has two jobs: say what Pushlog is, and
                      // say why an account is being asked for at all.
                      //
                      // It deliberately leaves out friends and leaderboards.
                      // Competition is opt-in and, per the product's own
                      // anti-references, never the pitch; promising a race
                      // before the user has done a single push-up sells the
                      // wrong thing. The About sheet covers it instead.
                      Text(
                        'Turn a push-up goal into a plan you can keep. '
                        'Your progress stays with you on any device.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge(
                          color: theme.secondaryInk,
                        ),
                      ),
                      // The mark now carries Signal Lime, so the accent rule
                      // that used to sit under the heading is gone — two lime
                      // elements stacked would just compete with each other.
                      //
                      // The gap under the brand block is deliberately the
                      // smallest of the three, so the actions stay tied to the
                      // pitch above them and the slack collects at the bottom
                      // rather than splitting the screen in half.
                      const Spacer(),
                      if (_appleSignInIsOffered) ...[
                        PushlogButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple_rounded,
                          variant: PushlogButtonVariant.secondary,
                          onPressed: () =>
                              context.read<AuthCubit>().signInWithApple(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      PushlogButton(
                        label: 'Continue with Google',
                        leading: const GoogleGlyph(),
                        // Ghost only while Apple sits above it holding the
                        // weight. Alone on the screen it is the one thing to
                        // do, so it should not also be the quietest control.
                        variant: _appleSignInIsOffered
                            ? PushlogButtonVariant.ghost
                            : PushlogButtonVariant.secondary,
                        onPressed: () =>
                            context.read<AuthCubit>().signInWithGoogle(),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        InlineNotice(message: message),
                      ],
                      const Spacer(flex: 2),
                      const _PrivacyNote(),
                      const SizedBox(height: AppSpacing.block),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _readableMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    if (message.contains('GIDCLIENTID')) {
      return 'Google sign-in is not configured for iOS yet. '
          'Continue with Apple instead.';
    }
    return message;
  }
}

/// An inline problem message.
///
/// Errors used to be set in Signal Lime, which is the same colour the app
/// uses for a completed target — the two states read identically at a
/// glance. They now use the danger ink and carry an icon, so the meaning
/// does not rest on colour alone.
class InlineNotice extends StatelessWidget {
  const InlineNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.dangerSoft,
          borderRadius: AppRadius.all(AppRadius.sm),
          border: Border(left: BorderSide(color: theme.danger, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.priority_high_rounded,
              size: 18,
              color: theme.danger,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(color: theme.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsernameClaimPage extends StatefulWidget {
  const UsernameClaimPage({required this.state, super.key});

  final AuthNeedsUsername state;

  @override
  State<UsernameClaimPage> createState() => _UsernameClaimPageState();
}

class _UsernameClaimPageState extends State<UsernameClaimPage> {
  static final RegExp _allowed = RegExp(r'^[a-zA-Z0-9_]+$');

  late final TextEditingController _controller;
  String _value = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()
      ..addListener(() => setState(() => _value = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Null when the current text is acceptable.
  ///
  /// Checked as the user types rather than on submit, so the rule is
  /// answered before they commit to a name and get bounced.
  String? get _problem {
    if (_value.isEmpty) return null;
    if (_value.length < 3) return 'At least 3 characters';
    if (_value.length > 20) return 'No more than 20 characters';
    if (!_allowed.hasMatch(_value)) {
      return 'Letters, numbers, and underscores only';
    }
    return null;
  }

  bool get _canSubmit =>
      _value.length >= 3 && _problem == null && !widget.state.isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final state = widget.state;
    final problem = _problem;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.proseMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.block),
                  const _Wordmark(trailing: 'USERNAME'),
                  const SizedBox(height: AppSpacing.hero),
                  Text(
                    'Choose your name',
                    style: AppTypography.headingLarge(color: theme.ink),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'This is how friends find you and how you appear on '
                    'the board.',
                    style: AppTypography.bodyLarge(color: theme.secondaryInk),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  _UsernameField(
                    controller: _controller,
                    theme: theme,
                    hasProblem: problem != null,
                    onSubmitted: _canSubmit ? () => _submit(context) : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // The hint and the error occupy the same slot so the
                  // layout does not jump as the user types.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          problem ?? '3–20 characters · letters, numbers, _',
                          style: AppTypography.bodySmall(
                            color: problem != null
                                ? theme.danger
                                : theme.secondaryInk,
                          ),
                        ),
                      ),
                      Text(
                        '${_value.length}/20',
                        style: AppTypography.metricInline(
                          color: theme.tertiaryInk,
                        ),
                      ),
                    ],
                  ),
                  if (state.message != null && state.message!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    InlineNotice(message: state.message!),
                  ],
                  const Spacer(),
                  PushlogButton(
                    label: 'Use this username',
                    isLoading: state.isSubmitting,
                    onPressed: _canSubmit ? () => _submit(context) : null,
                  ),
                  const SizedBox(height: AppSpacing.block),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    unawaited(context.read<AuthCubit>().claimUsername(_controller.text));
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.theme,
    required this.hasProblem,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final AppTheme theme;
  final bool hasProblem;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasProblem ? theme.danger : theme.divider;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        // A recessed well: darker than the page reads as further away,
        // which is what an input should feel like.
        color: theme.surfaceSunken,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '@',
            style: AppTypography.headingLarge(color: theme.tertiaryInk),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
              ],
              style: AppTypography.headingLarge(color: theme.ink),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                ),
                hintText: 'username',
                hintStyle: AppTypography.headingLarge(
                  color: theme.tertiaryInk,
                ),
              ),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBlockedPage extends StatelessWidget {
  const AuthBlockedPage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.proseMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.block),
                  const _Wordmark(trailing: 'ACCOUNT'),
                  const Spacer(),
                  Text(
                    'Almost there',
                    style: AppTypography.headingLarge(color: theme.ink),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'You are signed in, but Pushlog could not finish '
                    'setting up your account.',
                    style: AppTypography.bodyLarge(color: theme.secondaryInk),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  InlineNotice(message: message),
                  const Spacer(),
                  PushlogButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onPressed: () => unawaited(
                      context.read<AuthCubit>().retryBootstrap(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Signing out is the escape hatch, not the recommended
                  // move, so it is the quietest control on the screen.
                  PushlogButton(
                    label: 'Sign out',
                    variant: PushlogButtonVariant.ghost,
                    onPressed: () =>
                        unawaited(context.read<AuthCubit>().signOut()),
                  ),
                  const SizedBox(height: AppSpacing.block),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.trailing});

  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        Text(
          trailing,
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
      ],
    );
  }
}

/// Opens the About sheet from the sign-in header.
///
/// The header used to read "ACCOUNT", which only restated the screen the
/// user was already looking at. Someone who has not signed in yet is more
/// likely to be asking what Pushlog is, so the slot does that instead.
class _AboutButton extends StatelessWidget {
  const _AboutButton();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return PressFeedback(
      semanticLabel: 'About Pushlog',
      onTap: () => unawaited(showAboutSheet(context, theme)),
      // The glyph is small, so the touch target is padded out to the
      // platform minimum rather than left at the icon's own size.
      child: SizedBox(
        width: AppSpacing.minTapTarget,
        height: AppSpacing.minTapTarget,
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: theme.tertiaryInk,
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // Centred to sit under a centred composition. The row hugs its content
    // rather than filling the width, so the lock stays beside the sentence
    // instead of drifting to the far edge.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: theme.tertiaryInk,
        ),
        const SizedBox(width: AppSpacing.lg),
        Flexible(
          child: Text(
            'Your email stays private. Friends find you by username.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(color: theme.tertiaryInk),
          ),
        ),
      ],
    );
  }
}
