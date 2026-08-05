import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final rawMessage = switch (context.watch<AuthCubit>().state) {
      AuthSignedOut(:final message) => message,
      _ => null,
    };
    final message = _normalizeMessage(rawMessage);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _Header(theme: theme, trailing: 'ACCOUNT'),
              const SizedBox(height: 64),
              Text(
                'Sign in',
                style: AppTypography.displayMedium(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 320,
                child: Text(
                  'Sync your sessions, choose a username, '
                  'and compete with friends.',
                  style: AppTypography.bodyLarge(
                    color: theme.secondaryInk,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _AuthButton(
                title: 'Continue with Apple',
                subtitle: 'Apple ID',
                theme: theme,
                emphasized: true,
                onTap: () => context.read<AuthCubit>().signInWithApple(),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                title: 'Continue with Google',
                subtitle: 'Google',
                theme: theme,
                onTap: () => context.read<AuthCubit>().signInWithGoogle(),
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  message,
                  style: AppTypography.body(
                    color: theme.accentInk,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: theme.secondaryInk,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your email stays private. Friends find you by username.',
                      style: AppTypography.body(color: theme.secondaryInk),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _normalizeMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    if (message.contains('GIDCLIENTID')) {
      return 'GOOGLE SIGN-IN IS NOT CONFIGURED FOR IOS YET.';
    }
    return message.toUpperCase();
  }
}

class UsernameClaimPage extends StatefulWidget {
  const UsernameClaimPage({
    required this.state,
    super.key,
  });

  final AuthNeedsUsername state;

  @override
  State<UsernameClaimPage> createState() => _UsernameClaimPageState();
}

class _UsernameClaimPageState extends State<UsernameClaimPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final state = widget.state;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _Header(theme: theme, trailing: 'USERNAME'),
              const SizedBox(height: 48),
              Text(
                'Choose your name',
                style: AppTypography.displayMedium(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This is how friends find you and how you appear on the board.',
                style: AppTypography.bodyLarge(
                  color: theme.secondaryInk,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                style: AppTypography.displayCompact(
                  color: theme.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: AppTypography.displayCompact(
                    color: theme.secondaryInk,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.accent),
                  ),
                ),
                onSubmitted: (_) => _submit(context),
              ),
              const SizedBox(height: 12),
              Text(
                '3-20 CHARS · LETTERS, NUMBERS, UNDERSCORES',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 1.1,
                ),
              ),
              if (state.message != null && state.message!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  state.message!.toUpperCase(),
                  style: AppTypography.labelMono(
                    color: theme.accentInk,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: _AuthButton(
                  title: state.isSubmitting ? 'Saving...' : 'Use this username',
                  subtitle: 'Continue',
                  theme: theme,
                  emphasized: true,
                  onTap: state.isSubmitting ? null : () => _submit(context),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    unawaited(
      context.read<AuthCubit>().claimUsername(_controller.text),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _Header(theme: theme, trailing: 'ACCOUNT'),
              const SizedBox(height: 28),
              Text(
                'SYNC',
                style: AppTypography.displayMedium(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'YOUR ACCOUNT IS AUTHENTICATED, '
                'BUT PUSHLOG COULD NOT FINISH ACCOUNT SETUP.',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Divider(height: 1, color: theme.divider),
              const SizedBox(height: 24),
              Text(
                message.toUpperCase(),
                style: AppTypography.labelMono(
                  color: theme.accentInk,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              _BottomPair(
                theme: theme,
                leading: 'SIGN OUT',
                onLeadingTap: () {
                  unawaited(context.read<AuthCubit>().signOut());
                },
                trailing: 'RETRY',
                onTrailingTap: () {
                  unawaited(
                    context.read<AuthCubit>().retryBootstrap(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.trailing,
  });

  final AppTheme theme;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 3,
          ),
        ),
        Text(
          trailing,
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BottomPair extends StatelessWidget {
  const _BottomPair({
    required this.theme,
    required this.leading,
    required this.onLeadingTap,
    required this.trailing,
    required this.onTrailingTap,
  });

  final AppTheme theme;
  final String leading;
  final VoidCallback onLeadingTap;
  final String trailing;
  final VoidCallback onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onLeadingTap,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.divider),
                ),
                alignment: Alignment.center,
                child: Text(
                  leading,
                  style: AppTypography.displayUndo(
                    color: theme.ink,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTrailingTap,
              child: ColoredBox(
                color: theme.accent,
                child: Center(
                  child: Text(
                    trailing,
                    style: AppTypography.displayUndo(
                      color: AppColors.fixedDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final AppTheme theme;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: emphasized ? theme.accent : theme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.title(
                      color: emphasized ? AppColors.fixedDark : theme.ink,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.body(
                    color: emphasized
                        ? AppColors.fixedDark
                        : theme.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
