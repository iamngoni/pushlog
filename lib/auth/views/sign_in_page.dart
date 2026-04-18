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
              const SizedBox(height: 28),
              Text(
                'PUSH',
                style: AppTypography.displayLarge(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 240,
                child: Text(
                  'SIGN IN TO SYNC SESSIONS, CLAIM A USERNAME, AND BUILD YOUR FRIENDS BOARD.',
                  style: AppTypography.labelMono(
                    size: 11,
                    color: theme.secondaryInk,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Divider(height: 1, color: theme.divider),
              const SizedBox(height: 24),
              _AuthButton(
                title: 'CONTINUE WITH APPLE',
                subtitle: 'APPLE ID',
                theme: theme,
                emphasized: true,
                onTap: () =>
                    context.read<AuthCubit>().signInWithApple(),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                title: 'CONTINUE WITH GOOGLE',
                subtitle: 'GOOGLE',
                theme: theme,
                onTap: () => context
                    .read<AuthCubit>()
                    .signInWithGoogle(),
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  message.toUpperCase(),
                  style: AppTypography.labelMono(
                    size: 10,
                    color: theme.accentInk,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'ONLY APPLE + GOOGLE. USERNAMES ARE HOW FRIENDS FIND YOU.',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.1,
                ),
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
  State<UsernameClaimPage> createState() =>
      _UsernameClaimPageState();
}

class _UsernameClaimPageState
    extends State<UsernameClaimPage> {
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
              const SizedBox(height: 28),
              Text(
                'CLAIM',
                style: AppTypography.displayLarge(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'PICK THE HANDLE FRIENDS WILL SEARCH FOR.',
                style: AppTypography.labelMono(
                  size: 11,
                  color: theme.secondaryInk,
                  letterSpacing: 1.3,
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
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: AppTypography.displayCompact(
                    color: theme.secondaryInk,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: theme.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: theme.accent),
                  ),
                ),
                onSubmitted: (_) => _submit(context),
              ),
              const SizedBox(height: 12),
              Text(
                '3-20 CHARS · LETTERS, NUMBERS, UNDERSCORES',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.1,
                ),
              ),
              if (state.message != null &&
                  state.message!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  state.message!.toUpperCase(),
                  style: AppTypography.labelMono(
                    size: 10,
                    color: theme.accentInk,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: _AuthButton(
                  title: state.isSubmitting
                      ? 'CLAIMING...'
                      : 'CLAIM USERNAME',
                  subtitle: 'CONTINUE',
                  theme: theme,
                  emphasized: true,
                  onTap: state.isSubmitting
                      ? null
                      : () => _submit(context),
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
    context
        .read<AuthCubit>()
        .claimUsername(_controller.text);
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
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMono(
                      size: 12,
                      color: emphasized
                          ? AppColors.fixedDark
                          : theme.ink,
                      weight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelMono(
                    size: 10,
                    color: emphasized
                        ? AppColors.fixedDark
                        : theme.secondaryInk,
                    letterSpacing: 1.5,
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
