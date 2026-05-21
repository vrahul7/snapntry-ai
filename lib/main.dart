import 'package:flutter/material.dart';
import 'app.dart';
import 'services/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService().init();
  runApp(const GenA2ZApp());
}
