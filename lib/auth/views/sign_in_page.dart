import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final message = switch (context.watch<AuthCubit>().state) {
      AuthSignedOut(:final message) => _readableMessage(message),
      _ => null,
    };

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
                    'Sign in',
                    style: AppTypography.headingXLarge(color: theme.ink),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // A short accent rule instead of a decorative flourish.
                  // It puts Signal Lime on the screen without colouring a
                  // provider button, which would imply one sign-in method
                  // is the recommended one when both are equivalent.
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
                    'Sync your sessions across devices, claim a username, '
                    'and race your friends.',
                    style: AppTypography.bodyLarge(color: theme.secondaryInk),
                  ),
                  const SizedBox(height: AppSpacing.sectionLarge),
                  PushlogButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple_rounded,
                    variant: PushlogButtonVariant.secondary,
                    onPressed: () =>
                        context.read<AuthCubit>().signInWithApple(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PushlogButton(
                    label: 'Continue with Google',
                    variant: PushlogButtonVariant.ghost,
                    onPressed: () =>
                        context.read<AuthCubit>().signInWithGoogle(),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    InlineNotice(message: message),
                  ],
                  const Spacer(),
                  const _PrivacyNote(),
                  const SizedBox(height: AppSpacing.block),
                ],
              ),
            ),
          ),
        ),
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
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
            'Your email stays private. Friends find you by username.',
            style: AppTypography.bodySmall(color: theme.tertiaryInk),
          ),
        ),
      ],
    );
  }
}
