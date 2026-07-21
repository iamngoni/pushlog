import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/services/auth_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

const _googleServerClientId =
    '944029873089-nv4hobvbq0g1l5toi3damisvq6pqqeo1.apps.googleusercontent.com';

void main() {
  setUpAll(() {
    registerFallbackValue(AppleAuthProvider());
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('signInWithApple delegates to Firebase Apple provider', () async {
    final firebaseAuth = _MockFirebaseAuth();
    final googleSignIn = _MockGoogleSignIn();
    final userCredential = _MockUserCredential();
    final authService = AuthService(firebaseAuth, googleSignIn);

    when(
      () => firebaseAuth.signInWithProvider(any()),
    ).thenAnswer((_) async => userCredential);

    final result = await authService.signInWithApple();

    expect(result, userCredential);
    final provider = verify(
      () => firebaseAuth.signInWithProvider(captureAny()),
    ).captured.single;
    expect(provider, isA<AppleAuthProvider>());
  });

  test('signInWithGoogle initializes Android with the web client id', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final firebaseAuth = _MockFirebaseAuth();
    final googleSignIn = _MockGoogleSignIn();
    final googleAccount = _MockGoogleSignInAccount();
    final userCredential = _MockUserCredential();
    final authService = AuthService(firebaseAuth, googleSignIn);

    when(
      () => googleSignIn.initialize(
        clientId: any(named: 'clientId'),
        serverClientId: any(named: 'serverClientId'),
      ),
    ).thenAnswer((_) async {});
    when(
      googleSignIn.attemptLightweightAuthentication,
    ).thenAnswer((_) => Future<GoogleSignInAccount?>.value());
    when(googleSignIn.authenticate).thenAnswer((_) async => googleAccount);
    when(
      () => googleAccount.authentication,
    ).thenReturn(const GoogleSignInAuthentication(idToken: 'id-token'));
    when(
      () => firebaseAuth.signInWithCredential(any()),
    ).thenAnswer((_) async => userCredential);

    final result = await authService.signInWithGoogle();

    expect(result, userCredential);
    verify(
      () => googleSignIn.initialize(
        serverClientId: _googleServerClientId,
      ),
    ).called(1);
  });
}
