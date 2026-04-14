import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppAuthUser {
  const AppAuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    this.profileImageUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String provider;
  final String? profileImageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'provider': provider,
        'profileImageUrl': profileImageUrl,
      };

  factory AppAuthUser.fromJson(Map<String, dynamic> json) => AppAuthUser(
        id: (json['id'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        provider: (json['provider'] ?? '').toString(),
        profileImageUrl: (json['profileImageUrl'] ?? '').toString().trim().isEmpty
            ? null
            : json['profileImageUrl'].toString(),
      );
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
        id: googleUser.id,
        displayName: googleUser.displayName?.trim().isNotEmpty == true
            ? googleUser.displayName!
            : 'Google User',
        email: googleUser.email,
        provider: 'google',
        profileImageUrl: googleUser.photoUrl,
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
        id: credential.userIdentifier ?? credential.identityToken ?? credential.email ?? 'apple-user',
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

  Future<void> unlink({required String provider}) async {
    if (provider == 'google') {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // disconnect는 이미 연결이 끊긴 경우 예외가 날 수 있어 무시합니다.
      }
      await _googleSignIn.signOut();
      return;
    }

    // Apple은 앱에서 세션을 유지하지 않으므로 로컬 세션 정리만 수행합니다.
  }
}
