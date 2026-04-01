import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'plant_models.dart';

class PlantPresetService {
  static const String _endpoint = 'https://app-master.officialsite.kr/api/plant-reminder/presets';

  static Future<List<PlantPreset>> loadPresets({String? localeCode}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final resolvedLocaleCode = _normalizeLocaleCode(
      localeCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    try {
      final request = await client.getUrl(
        Uri.parse(_endpoint).replace(
          queryParameters: {
            'lang': resolvedLocaleCode,
            'locale': resolvedLocaleCode,
          },
        ),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptLanguageHeader, resolvedLocaleCode);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return List<PlantPreset>.from(kPlantPresets);
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = (decoded['data'] as List<dynamic>? ?? const []);
      final presets = data
          .map(
            (item) => PlantPreset.fromJson(
              Map<String, dynamic>.from(item as Map),
              localeCode: resolvedLocaleCode,
            ),
          )
          .where((preset) => preset.type.trim().isNotEmpty)
          .toList();

      if (presets.isEmpty) {
        return List<PlantPreset>.from(kPlantPresets);
      }
      return presets;
    } catch (_) {
      return List<PlantPreset>.from(kPlantPresets);
    } finally {
      client.close(force: true);
    }
  }

  static String _normalizeLocaleCode(String raw) {
    switch (raw.toLowerCase()) {
      case 'ko':
      case 'en':
      case 'ja':
      case 'zh':
        return raw.toLowerCase();
      default:
        return 'en';
    }
  }
}
