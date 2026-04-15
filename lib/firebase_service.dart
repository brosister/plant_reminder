import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');
    } catch (error) {
      debugPrint('Firebase init skipped/failed: $error');
    }
    _initialized = true;
  }
}
