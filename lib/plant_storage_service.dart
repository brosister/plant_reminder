import 'package:shared_preferences/shared_preferences.dart';

import 'plant_models.dart';

class PlantStorageService {
  PlantStorageService._();

  static const _plantsKey = 'plants';
  static const _activityLogKey = 'plant_activity_log';

  static Future<List<PlantItem>> loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plantsKey);
    if (raw == null || raw.isEmpty) return [];
    return PlantItem.decodeList(raw);
  }

  static Future<void> savePlants(List<PlantItem> plants) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plantsKey, PlantItem.encodeList(plants));
  }

  static Future<List<PlantActivityEntry>> loadActivityLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activityLogKey);
    if (raw == null || raw.isEmpty) return [];
    return PlantActivityEntry.decodeList(raw);
  }

  static Future<void> saveActivityLog(List<PlantActivityEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activityLogKey, PlantActivityEntry.encodeList(items));
  }
}
