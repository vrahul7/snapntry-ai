import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';

class SnapnTryApp extends StatelessWidget {
  const SnapnTryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapnTry AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
