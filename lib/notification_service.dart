import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_localizations.dart';
import 'app_settings_service.dart';
import 'plant_models.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _channelId = 'plant_reminder_channel';
  static const String _channelName = 'Plant Reminder';
  static const String _groupKey = 'plant_reminders';

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    _initialized = true;
  }

  static Future<bool> areNotificationsAllowed() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final permission = await ios.checkPermissions();
      return permission?.isEnabled ?? false;
    }

    return true;
  }

  static Future<bool> requestNotificationPermission() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? await areNotificationsAllowed();
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  static Future<void> rescheduleForPlants(
    List<PlantItem> plants, {
    required AppSettings settings,
  }) async {
    await init();
    await _plugin.cancelAll();

    if (!settings.notificationsEnabled) {
      return;
    }

    for (final plant in plants) {
      await schedulePlantTasks(plant, settings: settings);
    }
  }

  static Future<void> schedulePlantTasks(
    PlantItem plant, {
    required AppSettings settings,
  }) async {
    if (settings.notifySameDay) {
      await schedulePlantReminder(plant, settings: settings);
    }
    if (settings.notifyDayBefore) {
      await schedulePlantStatusCheck(plant, settings: settings);
    }
  }

  static Future<void> schedulePlantReminder(
    PlantItem plant, {
    required AppSettings settings,
  }) async {
    final l10n = AppLocalizations.forLocale(WidgetsBinding.instance.platformDispatcher.locale);
    final scheduled = _wateringReminderDateTime(plant, settings: settings);
    final id = _notificationIdFor(plant, offset: 1);
    final location = _locationLabel(l10n, plant);

    await _plugin.zonedSchedule(
      id,
      l10n.reminderTitle(plant.name),
      l10n.reminderBody(plant.type, plant.location, plant.wateringCycleDays),
      scheduled,
      _plantNotificationDetails(
        l10n: l10n,
        subtitle: location,
        body: l10n.reminderBody(plant.type, plant.location, plant.wateringCycleDays),
        threadIdentifier: 'watering_${plant.id}',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> schedulePlantStatusCheck(
    PlantItem plant, {
    required AppSettings settings,
  }) async {
    final l10n = AppLocalizations.forLocale(WidgetsBinding.instance.platformDispatcher.locale);
    final scheduled = _statusCheckReminderDateTime(plant, settings: settings);
    if (scheduled == null) return;

    final id = _notificationIdFor(plant, offset: 2);
    final location = _locationLabel(l10n, plant);
    await _plugin.zonedSchedule(
      id,
      l10n.statusCheckReminderTitle(plant.name),
      l10n.statusCheckReminderBody(plant.type, plant.location),
      scheduled,
      _plantNotificationDetails(
        l10n: l10n,
        subtitle: location,
        body: l10n.statusCheckReminderBody(plant.type, plant.location),
        threadIdentifier: 'check_${plant.id}',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> scheduleLockScreenTestNotifications(
    List<PlantItem> plants, {
    required AppSettings settings,
  }) async {
    await init();

    final l10n = AppLocalizations.forLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    final plant = plants.isNotEmpty
        ? plants.first
        : PlantItem(
            id: 'preview_plant',
            name: '몬스테라',
            type: '관엽식물',
            location: '거실',
            wateringCycleDays: 5,
            lastWateredAt: DateTime.now(),
            memo: '',
            sunlight: '',
          );

    await _plugin.show(
      990001,
      l10n.reminderTitle(plant.name),
      l10n.reminderBody(plant.type, plant.location, plant.wateringCycleDays),
      _plantNotificationDetails(
        l10n: l10n,
        subtitle: _locationLabel(l10n, plant),
        body: l10n.reminderBody(
          plant.type,
          plant.location,
          plant.wateringCycleDays,
        ),
        threadIdentifier: 'preview_watering',
      ),
    );
  }

  static NotificationDetails _plantNotificationDetails({
    required AppLocalizations l10n,
    required String subtitle,
    required String body,
    required String threadIdentifier,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: l10n.reminderChannelDescription(),
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        groupKey: _groupKey,
        subText: subtitle,
        ticker: body,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: DarwinNotificationDetails(
        subtitle: subtitle,
        threadIdentifier: threadIdentifier,
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  static tz.TZDateTime _wateringReminderDateTime(
    PlantItem plant, {
    required AppSettings settings,
  }) {
    final next = plant.nextWateringAt;
    final candidate = DateTime(
      next.year,
      next.month,
      next.day,
      settings.notificationHour,
      settings.notificationMinute,
    );
    final now = DateTime.now();
    if (candidate.isAfter(now)) {
      return _toUtcTzDateTime(candidate);
    }
    return _toUtcTzDateTime(now.add(const Duration(minutes: 1)));
  }

  static tz.TZDateTime? _statusCheckReminderDateTime(
    PlantItem plant, {
    required AppSettings settings,
  }) {
    final next = plant.nextWateringAt.subtract(const Duration(days: 1));
    final candidate = DateTime(
      next.year,
      next.month,
      next.day,
      settings.notificationHour,
      settings.notificationMinute,
    );
    if (!candidate.isAfter(DateTime.now())) {
      return null;
    }
    return _toUtcTzDateTime(candidate);
  }

  static tz.TZDateTime _toUtcTzDateTime(DateTime localDateTime) {
    return tz.TZDateTime.from(localDateTime.toUtc(), tz.UTC);
  }

  static int _notificationIdFor(PlantItem plant, {required int offset}) {
    final base = plant.id.hashCode & 0x0fffffff;
    return (base << 2) | (offset & 0x3);
  }

  static String _locationLabel(AppLocalizations l10n, PlantItem plant) {
    final location = plant.location.trim();
    if (location.isEmpty) {
      return l10n.locationUnset;
    }
    return location;
  }
}
