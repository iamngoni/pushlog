import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/auth_service.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/core/services/reminder_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileService extends Mock implements ProfileService {}

class _MockReminderService extends Mock implements ReminderService {}

class _MockUser extends Mock implements User {}

void main() {
  late AuthService authService;
  late ProfileService profileService;
  late ReminderService reminderService;
  late User user;

  setUpAll(() {
    registerFallbackValue(_MockUser());
  });

  setUp(() {
    authService = _MockAuthService();
    profileService = _MockProfileService();
    reminderService = _MockReminderService();
    user = _MockUser();

    when(() => authService.initialize()).thenAnswer((_) async {});
    when(
      () => authService.authStateChanges(),
    ).thenAnswer((_) => const Stream<User?>.empty());
    when(() => authService.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('uid-123');
    when(() => user.email).thenReturn('push@test.com');
    when(() => user.displayName).thenReturn('Push Tester');
    when(() => user.photoURL).thenReturn(null);
    when(() => reminderService.cancelAllManaged()).thenAnswer((_) async {});
  });

  blocTest<AuthCubit, AuthState>(
    'deletes account data before deleting the auth user',
    build: () {
      when(() => profileService.ensureProfileShell(any())).thenAnswer(
        (_) async {},
      );
      when(() => profileService.watchProfile('uid-123')).thenAnswer(
        (_) => const Stream<UserProfile>.empty(),
      );
      when(
        () => profileService.deleteAccountData(uid: 'uid-123'),
      ).thenAnswer((_) async {});
      when(() => authService.deleteCurrentUser()).thenAnswer((_) async {});
      return AuthCubit(
        authService: authService,
        profileService: profileService,
        reminderService: reminderService,
      );
    },
    wait: const Duration(milliseconds: 10),
    act: (cubit) => cubit.deleteAccount(),
    verify: (_) {
      verifyInOrder([
        () => profileService.deleteAccountData(uid: 'uid-123'),
        () => authService.deleteCurrentUser(),
        () => reminderService.cancelAllManaged(),
      ]);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'emits blocked state when the Worker rejects profile setup',
    build: () {
      when(() => profileService.ensureProfileShell(any())).thenThrow(
        const PushlogApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'Profile access was denied.',
        ),
      );
      return AuthCubit(
        authService: authService,
        profileService: profileService,
        reminderService: reminderService,
      );
    },
    wait: const Duration(milliseconds: 10),
    expect: () => const [
      AuthLoading(),
      AuthBlocked(
        message: 'Profile access was denied.',
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'emits blocked state when the Worker is unavailable',
    build: () {
      when(() => profileService.ensureProfileShell(any())).thenAnswer(
        (_) async {},
      );
      when(() => profileService.watchProfile(any())).thenAnswer(
        (_) => Stream<UserProfile?>.error(
          const PushlogApiException(
            statusCode: 503,
            code: 'unavailable',
            message: 'Service unavailable.',
          ),
        ),
      );
      return AuthCubit(
        authService: authService,
        profileService: profileService,
        reminderService: reminderService,
      );
    },
    wait: const Duration(milliseconds: 10),
    expect: () => const [
      AuthLoading(),
      AuthBlocked(
        message:
            'Could not reach Pushlog. Check your connection and try again.',
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'does not expose raw Google sign-in exceptions',
    build: () {
      when(() => authService.currentUser).thenReturn(null);
      when(authService.signInWithGoogle).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: '[16] Account reauth failed.',
        ),
      );
      return AuthCubit(
        authService: authService,
        profileService: profileService,
        reminderService: reminderService,
      );
    },
    wait: const Duration(milliseconds: 10),
    act: (cubit) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await cubit.signInWithGoogle();
    },
    expect: () => const [
      AuthSignedOut(),
      AuthLoading(),
      AuthSignedOut(
        message: 'Google sign-in could not finish. Try again.',
      ),
    ],
  );
}
