import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/services/auth_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppleAuthProvider());
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
}
