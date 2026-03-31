import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    debugPrint('Firebase 초기화는 google-services.json / GoogleService-Info.plist 연결 후 활성화됩니다.');
    _initialized = true;
  }
}
