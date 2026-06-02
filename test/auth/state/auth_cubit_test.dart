import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/auth_service.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
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
    'emits blocked state when profile shell write is denied',
    build: () {
      when(() => profileService.ensureProfileShell(any())).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
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
        message: 'Account setup is temporarily blocked. Try again shortly.',
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'emits blocked state when profile stream errors',
    build: () {
      when(() => profileService.ensureProfileShell(any())).thenAnswer(
        (_) async {},
      );
      when(() => profileService.watchProfile(any())).thenAnswer(
        (_) => Stream<UserProfile?>.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
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
            'Could not reach the cloud. Check your connection and try again.',
      ),
    ],
  );
}
