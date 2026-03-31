import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
  });

  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        notificationsEnabled: json['notificationsEnabled'] == true,
        notificationHour: (json['notificationHour'] ?? 9) as int,
        notificationMinute: (json['notificationMinute'] ?? 0) as int,
      );

  AppSettings copyWith({
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
    );
  }
}

class AppSettingsService {
  AppSettingsService._();

  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _notificationHourKey = 'notification_hour';
  static const _notificationMinuteKey = 'notification_minute';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      notificationHour: prefs.getInt(_notificationHourKey) ?? 9,
      notificationMinute: prefs.getInt(_notificationMinuteKey) ?? 0,
    );
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, settings.notificationsEnabled);
    await prefs.setInt(_notificationHourKey, settings.notificationHour);
    await prefs.setInt(_notificationMinuteKey, settings.notificationMinute);
  }
}
