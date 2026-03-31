import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class SyncState {
  const SyncState({
    required this.lastSyncedAt,
    required this.isDirty,
    required this.userKey,
  });

  final DateTime? lastSyncedAt;
  final bool isDirty;
  final String? userKey;
}

class SyncStateService {
  SyncStateService._();

  static const _lastSyncedAtKey = 'sync_last_synced_at';
  static const _isDirtyKey = 'sync_is_dirty';
  static const _userKey = 'sync_user_key';

  static String userKeyFor(AppAuthUser user) => '${user.provider}:${user.id}';

  static Future<SyncState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDate = prefs.getString(_lastSyncedAtKey);
    return SyncState(
      lastSyncedAt: rawDate == null || rawDate.isEmpty ? null : DateTime.tryParse(rawDate),
      isDirty: prefs.getBool(_isDirtyKey) ?? false,
      userKey: prefs.getString(_userKey),
    );
  }

  static Future<void> markDirty(AppAuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDirtyKey, true);
    await prefs.setString(_userKey, userKeyFor(user));
  }

  static Future<void> markSynced(AppAuthUser user, DateTime? syncedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDirtyKey, false);
    await prefs.setString(_userKey, userKeyFor(user));
    if (syncedAt != null) {
      await prefs.setString(_lastSyncedAtKey, syncedAt.toIso8601String());
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncedAtKey);
    await prefs.remove(_isDirtyKey);
    await prefs.remove(_userKey);
  }
}
