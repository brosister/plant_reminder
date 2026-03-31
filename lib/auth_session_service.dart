import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AuthSessionService {
  AuthSessionService._();

  static const _authUserKey = 'auth_user';

  static Future<AppAuthUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authUserKey);
    if (raw == null || raw.isEmpty) return null;
    return AppAuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveUser(AppAuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authUserKey, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authUserKey);
  }
}
