import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';

class GenA2ZApp extends StatelessWidget {
  const GenA2ZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B2B GenA2Z',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
