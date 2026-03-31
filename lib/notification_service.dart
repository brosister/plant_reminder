import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'plant_models.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static Future<void> rescheduleForPlants(List<PlantItem> plants) async {
    await init();
    await _plugin.cancelAll();

    for (final plant in plants) {
      await schedulePlantReminder(plant);
    }
  }

  static Future<void> schedulePlantReminder(PlantItem plant) async {
    final scheduled = _nextReminderDateTime(plant);
    final id = plant.id.hashCode & 0x7fffffff;

    await _plugin.zonedSchedule(
      id,
      '${plant.name} 물줄 시간',
      '${plant.type} 물주기 확인이 필요해요.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_reminder_channel',
          'Plant Reminder',
          channelDescription: '식물 물주기 알림 채널',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static tz.TZDateTime _nextReminderDateTime(PlantItem plant) {
    final next = plant.nextWateringAt;
    final local = tz.local;
    final candidate = tz.TZDateTime(local, next.year, next.month, next.day, 9);
    final now = tz.TZDateTime.now(local);
    if (candidate.isAfter(now)) return candidate;
    return now.add(const Duration(minutes: 1));
  }
}
