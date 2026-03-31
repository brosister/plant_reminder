import 'package:shared_preferences/shared_preferences.dart';

import 'plant_models.dart';

class PlantStorageService {
  PlantStorageService._();

  static const _plantsKey = 'plants';

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
}
