import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pushlog/firebase_options.dart';

class AuthService {
  AuthService(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool _initialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Future<void> initialize() async {
    if (_initialized) return;

    final clientId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => DefaultFirebaseOptions.ios.iosClientId,
      TargetPlatform.macOS => DefaultFirebaseOptions.ios.iosClientId,
      _ => null,
    };

    await _googleSignIn.initialize(
      clientId: clientId,
    );
    _initialized = true;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await initialize();
      final lightweightAttempt = _googleSignIn
          .attemptLightweightAuthentication();
      final account =
          await lightweightAttempt ?? await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google_sign_in_failed',
          message: 'Google sign-in did not return an ID token.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      return _firebaseAuth.signInWithCredential(credential);
    } on PlatformException catch (error) {
      if (error.message?.contains('GIDCLIENTID') ?? false) {
        throw FirebaseAuthException(
          code: 'google_sign_in_not_configured',
          message: 'Google sign-in is not configured for iOS yet.',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithApple() async {
    return _firebaseAuth.signInWithProvider(AppleAuthProvider());
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account to delete.',
      );
    }

    await user.delete();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }
}
