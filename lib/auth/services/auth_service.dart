import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool _initialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() =>
      _firebaseAuth.authStateChanges();

  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize();
    _initialized = true;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await initialize();
      final lightweightAttempt =
          _googleSignIn.attemptLightweightAuthentication();
      final account = await lightweightAttempt ??
          await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google_sign_in_failed',
          message:
              'Google sign-in did not return an ID token.',
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
          message:
              'Google sign-in is not configured for iOS yet.',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithApple() async {
    final rawNonce = _nonce();
    final nonce = _sha256(rawNonce);
    final credential =
        await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential =
        OAuthProvider('apple.com').credential(
      idToken: credential.identityToken,
      rawNonce: rawNonce,
    );

    return _firebaseAuth.signInWithCredential(
      oauthCredential,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  static String _nonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256(String input) {
    return sha256
        .convert(utf8.encode(input))
        .toString();
  }
}
