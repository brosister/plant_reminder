import 'dart:convert';

enum PlantStatus { healthy, soon, today, overdue }

class PlantItem {
  PlantItem({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.wateringCycleDays,
    required this.lastWateredAt,
    required this.memo,
    required this.sunlight,
  });

  final String id;
  String name;
  String type;
  String location;
  int wateringCycleDays;
  DateTime lastWateredAt;
  String memo;
  String sunlight;

  DateTime get nextWateringAt => lastWateredAt.add(Duration(days: wateringCycleDays));

  int get daysUntilWatering {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextWateringAt.year, nextWateringAt.month, nextWateringAt.day);
    return target.difference(today).inDays;
  }

  PlantStatus get status {
    final days = daysUntilWatering;
    if (days < 0) return PlantStatus.overdue;
    if (days == 0) return PlantStatus.today;
    if (days <= 1) return PlantStatus.soon;
    return PlantStatus.healthy;
  }

  PlantItem copy() {
    return PlantItem(
      id: id,
      name: name,
      type: type,
      location: location,
      wateringCycleDays: wateringCycleDays,
      lastWateredAt: lastWateredAt,
      memo: memo,
      sunlight: sunlight,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'location': location,
        'wateringCycleDays': wateringCycleDays,
        'lastWateredAt': lastWateredAt.toIso8601String(),
        'memo': memo,
        'sunlight': sunlight,
      };

  factory PlantItem.fromJson(Map<String, dynamic> json) => PlantItem(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        location: json['location'] as String,
        wateringCycleDays: json['wateringCycleDays'] as int,
        lastWateredAt: DateTime.parse(json['lastWateredAt'] as String),
        memo: json['memo'] as String,
        sunlight: json['sunlight'] as String,
      );

  static String encodeList(List<PlantItem> items) => jsonEncode(items.map((e) => e.toJson()).toList());

  static List<PlantItem> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => PlantItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

class PlantPreset {
  const PlantPreset({
    required this.type,
    required this.defaultWateringCycleDays,
    required this.sunlight,
    required this.tip,
  });

  final String type;
  final int defaultWateringCycleDays;
  final String sunlight;
  final String tip;
}

const List<PlantPreset> kPlantPresets = [
  PlantPreset(type: '몬스테라', defaultWateringCycleDays: 5, sunlight: '밝은 간접광', tip: '흙 표면이 마르면 물주기'),
  PlantPreset(type: '스투키', defaultWateringCycleDays: 14, sunlight: '밝은 곳', tip: '과습 주의, 자주 주지 않기'),
  PlantPreset(type: '포토스', defaultWateringCycleDays: 6, sunlight: '간접광', tip: '잎이 축 처지기 전에 확인'),
  PlantPreset(type: '선인장', defaultWateringCycleDays: 21, sunlight: '직사광 가능', tip: '완전히 마른 뒤 물주기'),
  PlantPreset(type: '허브', defaultWateringCycleDays: 3, sunlight: '햇빛 필요', tip: '자주 확인하고 너무 마르지 않게'),
  PlantPreset(type: '고무나무', defaultWateringCycleDays: 7, sunlight: '밝은 간접광', tip: '통풍 좋은 곳에 두기'),
];
