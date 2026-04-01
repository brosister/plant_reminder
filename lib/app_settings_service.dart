import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    required this.notifyDayBefore,
    required this.notifySameDay,
    required this.allowSnooze,
    this.pinnedHomePlantId,
  });

  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final bool notifyDayBefore;
  final bool notifySameDay;
  final bool allowSnooze;
  final String? pinnedHomePlantId;

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'notifyDayBefore': notifyDayBefore,
    'notifySameDay': notifySameDay,
    'allowSnooze': allowSnooze,
    'pinnedHomePlantId': pinnedHomePlantId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    notificationsEnabled: json['notificationsEnabled'] == true,
    notificationHour: (json['notificationHour'] ?? 9) as int,
    notificationMinute: (json['notificationMinute'] ?? 0) as int,
    notifyDayBefore: json['notifyDayBefore'] != false,
    notifySameDay: json['notifySameDay'] != false,
    allowSnooze: json['allowSnooze'] != false,
    pinnedHomePlantId:
        (json['pinnedHomePlantId'] as String?)?.trim().isEmpty == true
        ? null
        : json['pinnedHomePlantId'] as String?,
  );

  AppSettings copyWith({
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    bool? notifyDayBefore,
    bool? notifySameDay,
    bool? allowSnooze,
    String? pinnedHomePlantId,
    bool clearPinnedHomePlantId = false,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      notifyDayBefore: notifyDayBefore ?? this.notifyDayBefore,
      notifySameDay: notifySameDay ?? this.notifySameDay,
      allowSnooze: allowSnooze ?? this.allowSnooze,
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
  static const _notifyDayBeforeKey = 'notify_day_before';
  static const _notifySameDayKey = 'notify_same_day';
  static const _allowSnoozeKey = 'allow_snooze';
  static const _pinnedHomePlantIdKey = 'pinned_home_plant_id';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      notificationHour: prefs.getInt(_notificationHourKey) ?? 9,
      notificationMinute: prefs.getInt(_notificationMinuteKey) ?? 0,
      notifyDayBefore: prefs.getBool(_notifyDayBeforeKey) ?? true,
      notifySameDay: prefs.getBool(_notifySameDayKey) ?? true,
      allowSnooze: prefs.getBool(_allowSnoozeKey) ?? true,
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
    await prefs.setBool(_notifyDayBeforeKey, settings.notifyDayBefore);
    await prefs.setBool(_notifySameDayKey, settings.notifySameDay);
    await prefs.setBool(_allowSnoozeKey, settings.allowSnooze);
    if ((settings.pinnedHomePlantId ?? '').isEmpty) {
      await prefs.remove(_pinnedHomePlantIdKey);
    } else {
      await prefs.setString(_pinnedHomePlantIdKey, settings.pinnedHomePlantId!);
    }
  }
}
