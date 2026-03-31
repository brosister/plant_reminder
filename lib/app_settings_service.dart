import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    this.pinnedHomePlantId,
  });

  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final String? pinnedHomePlantId;

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'pinnedHomePlantId': pinnedHomePlantId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    notificationsEnabled: json['notificationsEnabled'] == true,
    notificationHour: (json['notificationHour'] ?? 9) as int,
    notificationMinute: (json['notificationMinute'] ?? 0) as int,
    pinnedHomePlantId:
        (json['pinnedHomePlantId'] as String?)?.trim().isEmpty == true
        ? null
        : json['pinnedHomePlantId'] as String?,
  );

  AppSettings copyWith({
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    String? pinnedHomePlantId,
    bool clearPinnedHomePlantId = false,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      pinnedHomePlantId: clearPinnedHomePlantId
          ? null
          : (pinnedHomePlantId ?? this.pinnedHomePlantId),
    );
  }
}

class AppSettingsService {
  AppSettingsService._();

  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _notificationHourKey = 'notification_hour';
  static const _notificationMinuteKey = 'notification_minute';
  static const _pinnedHomePlantIdKey = 'pinned_home_plant_id';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      notificationHour: prefs.getInt(_notificationHourKey) ?? 9,
      notificationMinute: prefs.getInt(_notificationMinuteKey) ?? 0,
      pinnedHomePlantId: prefs.getString(_pinnedHomePlantIdKey),
    );
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _notificationsEnabledKey,
      settings.notificationsEnabled,
    );
    await prefs.setInt(_notificationHourKey, settings.notificationHour);
    await prefs.setInt(_notificationMinuteKey, settings.notificationMinute);
    if ((settings.pinnedHomePlantId ?? '').isEmpty) {
      await prefs.remove(_pinnedHomePlantIdKey);
    } else {
      await prefs.setString(_pinnedHomePlantIdKey, settings.pinnedHomePlantId!);
    }
  }
}
