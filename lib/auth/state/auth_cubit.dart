import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/auth_service.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/core/services/reminder_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthService authService,
    required ProfileService profileService,
    required ReminderService reminderService,
  }) : _authService = authService,
       _profileService = profileService,
       _reminderService = reminderService,
       super(const AuthLoading()) {
    unawaited(_initialize());
  }

  final AuthService _authService;
  final ProfileService _profileService;
  final ReminderService _reminderService;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  Future<void> _initialize() async {
    try {
      await _authService.initialize();
      _authSubscription = _authService.authStateChanges().listen(
        _handleAuthChanged,
        onError: (Object error, StackTrace _) {
          emit(
            AuthSignedOut(
              message: _messageForError(error),
            ),
          );
        },
      );
      await _handleAuthChanged(_authService.currentUser);
    } on Object catch (error) {
      emit(AuthSignedOut(message: _messageForError(error)));
    }
  }

  Future<void> signInWithGoogle() async {
    await _signIn(_authService.signInWithGoogle);
  }

  Future<void> signInWithApple() async {
    await _signIn(_authService.signInWithApple);
  }

  Future<void> signOut() async {
    emit(const AuthLoading());
    await _authService.signOut();
    await _reminderService.cancelAllManaged();
  }

  Future<void> deleteAccount() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account to delete.',
      );
    }

    await _profileService.deleteAccountData(uid: user.uid);
    await _authService.deleteCurrentUser();
    await _reminderService.cancelAllManaged();
  }

  Future<void> retryBootstrap() async {
    await _handleAuthChanged(_authService.currentUser);
  }

  Future<void> claimUsername(String username) async {
    final currentState = state;
    if (currentState is! AuthNeedsUsername) return;

    final user = _authService.currentUser;
    if (user == null) {
      emit(
        const AuthSignedOut(
          message: 'Session expired. Sign in again.',
        ),
      );
      return;
    }

    emit(currentState.copyWith(isSubmitting: true));
    final result = await _profileService.claimUsername(
      user: user,
      username: username,
    );
    if (!result.success) {
      emit(
        currentState.copyWith(
          isSubmitting: false,
          message: result.message,
        ),
      );
    }
  }

  Future<void> _signIn(
    Future<UserCredential?> Function() action,
  ) async {
    emit(const AuthLoading());
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      emit(
        AuthSignedOut(
          message: error.message ?? 'Unable to sign in right now.',
        ),
      );
    } on Object catch (error) {
      emit(AuthSignedOut(message: _messageForError(error)));
    }
  }

  Future<void> _handleAuthChanged(User? user) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (user == null) {
      await _reminderService.cancelAllManaged();
      emit(const AuthSignedOut());
      return;
    }

    emit(const AuthLoading());
    try {
      await _profileService.ensureProfileShell(user);
      _profileSubscription = _profileService
          .watchProfile(user.uid)
          .listen(
            (profile) {
              final currentUser = _authService.currentUser;
              if (currentUser == null) {
                emit(const AuthSignedOut());
                return;
              }

              if (profile == null || profile.needsUsername) {
                emit(
                  AuthNeedsUsername(
                    uid: currentUser.uid,
                    email: currentUser.email,
                    displayName:
                        profile?.displayName ?? currentUser.displayName,
                    photoUrl: profile?.photoUrl ?? currentUser.photoURL,
                  ),
                );
                return;
              }

              emit(AuthAuthenticated(profile));
            },
            onError: (Object error, StackTrace _) {
              emit(AuthBlocked(message: _messageForError(error)));
            },
          );
    } on Object catch (error) {
      emit(AuthBlocked(message: _messageForError(error)));
    }
  }

  String _messageForError(Object error) {
    if (error is FirebaseAuthException) {
      if (_isAppleOAuthError(error)) {
        return 'Apple sign-in is not configured correctly for this build.';
      }
      if (error.code == 'requires-recent-login') {
        return 'Sign in again before deleting this account.';
      }
      return error.message ?? 'Unable to sign in right now.';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Account setup is temporarily blocked. Try again shortly.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Could not reach the cloud. '
              'Check your connection and try again.';
        default:
          return error.message ?? 'Could not finish account setup right now.';
      }
    }

    final rawMessage = error.toString();
    if (rawMessage.contains('GIDCLIENTID')) {
      return 'Google sign-in is not configured for iOS yet.';
    }
    return rawMessage;
  }

  bool _isAppleOAuthError(FirebaseAuthException error) {
    final message = error.message?.toLowerCase() ?? '';
    return error.code == 'invalid-oauth-response' ||
        error.code == 'missing-or-invalid-nonce' ||
        (error.code == 'invalid-credential' && message.contains('apple'));
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
