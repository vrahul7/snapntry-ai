import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/cache_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService().init();

  try {
    // Safely attempt Firebase initialization (supporting automatic fallback if config is absent)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase successfully initialized.');
  } catch (e) {
    debugPrint('Firebase initialization failed/skipped: $e');
    debugPrint('Running app in Offline Mock Hybrid mode.');
  }

  runApp(const SnapnTryApp());
}
