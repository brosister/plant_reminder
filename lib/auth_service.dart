import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppAuthUser {
  const AppAuthUser({
    required this.displayName,
    required this.email,
    required this.provider,
  });

  final String displayName;
  final String email;
  final String provider;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<AppAuthUser?> signInForCurrentPlatform() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return signInWithGoogle();
    }
    if (Platform.isIOS) {
      return signInWithApple();
    }
    return null;
  }

  Future<AppAuthUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      return AppAuthUser(
        displayName: googleUser.displayName?.trim().isNotEmpty == true
            ? googleUser.displayName!
            : 'Google User',
        email: googleUser.email,
        provider: 'google',
      );
    } catch (error) {
      debugPrint('구글 로그인 실패: $error');
      rethrow;
    }
  }

  Future<AppAuthUser?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

      return AppAuthUser(
        displayName: fullName.isNotEmpty ? fullName : 'Apple User',
        email: credential.email ?? 'apple-user@private.local',
        provider: 'apple',
      );
    } catch (error) {
      debugPrint('애플 로그인 실패: $error');
      rethrow;
    }
  }

  Future<void> signOut({String? provider}) async {
    if (provider == 'google') {
      await _googleSignIn.signOut();
    }
  }
}
