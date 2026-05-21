import 'package:flutter/material.dart';
import '../views/auth/login_screen.dart';
import '../views/home/home_screen.dart';
import '../views/catalog/catalog_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/catalog/category_details_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String catalog = '/catalog';
  static const String profile = '/profile';
  static const String categoryDetails = '/category_details';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      home: (context) => const HomeScreen(),
      catalog: (context) => const CatalogScreen(),
      profile: (context) => const ProfileScreen(),
      categoryDetails: (context) {
        final categoryName = ModalRoute.of(context)!.settings.arguments as String? ?? 'Collection';
        return CategoryDetailsScreen(categoryName: categoryName);
      },
    };
  }
}
