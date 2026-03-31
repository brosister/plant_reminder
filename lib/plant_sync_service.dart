import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_settings_service.dart';
import 'auth_service.dart';
import 'plant_models.dart';

class PlantSyncProfile {
  const PlantSyncProfile({
    required this.exists,
    required this.plants,
    required this.settings,
    this.updatedAt,
  });

  final bool exists;
  final List<PlantItem> plants;
  final AppSettings settings;
  final DateTime? updatedAt;
}

class PlantSyncResult {
  const PlantSyncResult({
    required this.plants,
    required this.settings,
    this.updatedAt,
  });

  final List<PlantItem> plants;
  final AppSettings settings;
  final DateTime? updatedAt;
}

class PlantSyncService {
  PlantSyncService._();

  static const String _baseUrl = 'https://app-master.officialsite.kr';
  static const String _appName = 'plant_reminder';

  static Future<PlantSyncProfile> fetchProfile(AppAuthUser user) async {
    final uri = Uri.parse('$_baseUrl/api/plant-reminder/sync/profile').replace(
      queryParameters: {
        'provider': user.provider,
        'social_id': user.id,
        'email': user.email,
        'app_name': _appName,
      },
    );
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception((body['message'] ?? 'sync fetch failed').toString());
    }
    final data = (body['data'] ?? {}) as Map<String, dynamic>;
    return PlantSyncProfile(
      exists: data['exists'] == true,
      plants: _decodePlants(data['plants']),
      settings: _decodeSettings(data['settings']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  static Future<PlantSyncResult> replaceWithLocal({
    required AppAuthUser user,
    required List<PlantItem> plants,
    required AppSettings settings,
  }) async {
    return _postSync(
      '/api/plant-reminder/sync/replace',
      user: user,
      plants: plants,
      settings: settings,
    );
  }

  static Future<PlantSyncResult> mergeWithServer({
    required AppAuthUser user,
    required List<PlantItem> localPlants,
    required AppSettings localSettings,
  }) async {
    return _postSync(
      '/api/plant-reminder/sync/merge',
      user: user,
      plants: localPlants,
      settings: localSettings,
    );
  }

  static Future<PlantSyncResult> _postSync(
    String path, {
    required AppAuthUser user,
    required List<PlantItem> plants,
    required AppSettings settings,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': user.provider,
        'social_id': user.id,
        'email': user.email,
        'display_name': user.displayName,
        'profile_image_url': user.profileImageUrl,
        'app_name': _appName,
        'plants': plants.map((item) => item.toJson()).toList(),
        'settings': settings.toJson(),
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception((body['message'] ?? 'sync failed').toString());
    }
    final data = (body['data'] ?? {}) as Map<String, dynamic>;
    return PlantSyncResult(
      plants: _decodePlants(data['plants']),
      settings: _decodeSettings(data['settings']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  static List<PlantItem> _decodePlants(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => PlantItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static AppSettings _decodeSettings(dynamic value) {
    if (value is! Map) {
      return const AppSettings(
        notificationsEnabled: true,
        notificationHour: 9,
        notificationMinute: 0,
      );
    }
    return AppSettings.fromJson(Map<String, dynamic>.from(value));
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
