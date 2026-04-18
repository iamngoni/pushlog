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
  })  : _authService = authService,
        _profileService = profileService,
        _reminderService = reminderService,
        super(const AuthLoading()) {
    _initialize();
  }

  final AuthService _authService;
  final ProfileService _profileService;
  final ReminderService _reminderService;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  Future<void> _initialize() async {
    await _authService.initialize();
    _authSubscription = _authService.authStateChanges().listen(
      _handleAuthChanged,
      onError: (Object error, StackTrace _) {
        emit(
          AuthSignedOut(
            message: error.toString(),
          ),
        );
      },
    );
    await _handleAuthChanged(_authService.currentUser);
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
          message:
              error.message ?? 'Unable to sign in right now.',
        ),
      );
    } catch (error) {
      final rawMessage = error.toString();
      final message =
          rawMessage.contains('GIDCLIENTID')
              ? 'Google sign-in is not configured for iOS yet.'
              : rawMessage;
      emit(
        AuthSignedOut(
          message: message,
        ),
      );
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
    await _profileService.ensureProfileShell(user);
    _profileSubscription = _profileService
        .watchProfile(user.uid)
        .listen((profile) {
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
            displayName: profile?.displayName ??
                currentUser.displayName,
            photoUrl:
                profile?.photoUrl ?? currentUser.photoURL,
          ),
        );
        return;
      }

      emit(AuthAuthenticated(profile));
    });
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
