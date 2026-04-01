import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AppUserIdentity {
  const AppUserIdentity({
    required this.id,
    required this.deviceSerial,
    required this.loginType,
    this.socialId,
    this.name,
    this.email,
    this.profileImage,
  });

  final String id;
  final String deviceSerial;
  final String loginType;
  final String? socialId;
  final String? name;
  final String? email;
  final String? profileImage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceSerial': deviceSerial,
        'loginType': loginType,
        'socialId': socialId,
        'name': name,
        'email': email,
        'profileImage': profileImage,
      };

  factory AppUserIdentity.fromJson(Map<String, dynamic> json) => AppUserIdentity(
        id: (json['id'] ?? '').toString(),
        deviceSerial: (json['deviceSerial'] ?? '').toString(),
        loginType: (json['loginType'] ?? 'device').toString(),
        socialId: (json['socialId'] as String?)?.trim().isEmpty == true
            ? null
            : json['socialId'] as String?,
        name: (json['name'] as String?)?.trim().isEmpty == true
            ? null
            : json['name'] as String?,
        email: (json['email'] as String?)?.trim().isEmpty == true
            ? null
            : json['email'] as String?,
        profileImage: (json['profileImage'] as String?)?.trim().isEmpty == true
            ? null
            : json['profileImage'] as String?,
      );

  AppUserIdentity copyWith({
    String? id,
    String? deviceSerial,
    String? loginType,
    String? socialId,
    String? name,
    String? email,
    String? profileImage,
  }) {
    return AppUserIdentity(
      id: id ?? this.id,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      loginType: loginType ?? this.loginType,
      socialId: socialId ?? this.socialId,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}

class AppUserIdentityService {
  AppUserIdentityService._();

  static const _identityKey = 'app_user_identity';

  static Future<AppUserIdentity> ensureIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_identityKey);
    if (raw != null && raw.isNotEmpty) {
      return AppUserIdentity.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }

    final uuid = _generateUuid();
    final identity = AppUserIdentity(
      id: uuid,
      deviceSerial: _buildDeviceSerial(uuid),
      loginType: 'device',
      socialId: _buildDeviceSerial(uuid),
    );
    await save(identity);
    return identity;
  }

  static Future<void> save(AppUserIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  static String _buildDeviceSerial(String uuid) {
    if (Platform.isIOS) {
      return 'I_iPhone_$uuid';
    }
    if (Platform.isAndroid) {
      return 'A_Android_$uuid';
    }
    return 'D_Device_$uuid';
  }

  static String _generateUuid() {
    final random = Random.secure();
    String segment(int length) =>
        List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${segment(8)}-${segment(4)}-4${segment(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${segment(3)}-${segment(12)}';
  }
}

class AppUserService {
  AppUserService._();

  static const _baseUrl = 'https://app-master.officialsite.kr';
  static const _appName = 'plant_reminder';

  static Future<AppUserIdentity> registerDeviceUser(
    AppUserIdentity identity,
  ) async {
    return _postIdentity(
      '/api/plant-reminder/users/bootstrap',
      identity: identity.copyWith(
        loginType: identity.loginType,
        socialId: identity.socialId ?? identity.deviceSerial,
      ),
    );
  }

  static Future<AppUserIdentity> linkSocialAccount({
    required AppUserIdentity identity,
    required AppAuthUser authUser,
  }) async {
    return _postIdentity(
      '/api/plant-reminder/users/link-social',
      identity: identity.copyWith(
        loginType: authUser.provider,
        socialId: authUser.id,
        name: authUser.displayName,
        email: authUser.email,
        profileImage: authUser.profileImageUrl,
      ),
    );
  }

  static Future<AppUserIdentity> _postIdentity(
    String path, {
    required AppUserIdentity identity,
  }) async {
    final now = DateTime.now().toIso8601String();
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': identity.id,
        'social_id': identity.socialId,
        'login_type': identity.loginType,
        'app_name': _appName,
        'name': identity.name,
        'email': identity.email,
        'password': null,
        'is_admin': 0,
        'admin_apps': null,
        'profile_image': identity.profileImage,
        'device_serial': identity.deviceSerial,
        'mobile': null,
        'gender': null,
        'age_range': null,
        'terms_agreed': 0,
        'privacy_agreed': 0,
        'terms_agreed_at': null,
        'privacy_agreed_at': null,
        'apple_refresh_token': null,
        'last_login_at': now,
        'created_at': now,
        'updated_at': now,
        'tutorial_completed': 0,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('app user sync failed');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == false) {
      throw Exception((body['message'] ?? 'app user sync failed').toString());
    }

    final data = body['data'];
    if (data is! Map) {
      return identity;
    }

    return identity.copyWith(
      id: (data['id'] ?? identity.id).toString(),
      deviceSerial: (data['device_serial'] ?? identity.deviceSerial).toString(),
      loginType: (data['login_type'] ?? identity.loginType).toString(),
      socialId: (data['social_id'] ?? identity.socialId)?.toString(),
      name: (data['name'] ?? identity.name)?.toString(),
      email: (data['email'] ?? identity.email)?.toString(),
      profileImage: (data['profile_image'] ?? identity.profileImage)?.toString(),
    );
  }
}
