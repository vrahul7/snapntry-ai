import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'services/try_on_provider.dart';

/// Custom page route that uses a smooth fade + upward slide animation.
/// Makes all screen transitions feel polished and seamless.
class _FadeSlideRoute extends PageRouteBuilder {
  _FadeSlideRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeTween =
                Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut));
            final slideTween = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: SlideTransition(
                position: animation.drive(slideTween),
                child: child,
              ),
            );
          },
        );
}

class SnapnTryApp extends StatelessWidget {
  const SnapnTryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TryOnProvider()),
      ],
      child: MaterialApp(
        title: 'SnapnTry AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.login,
        // Use named route factory so each named push gets our smooth animation
        onGenerateRoute: (settings) {
          final builder = AppRoutes.routes[settings.name];
          if (builder == null) return null;
          return _FadeSlideRoute(builder: builder, settings: settings);
        },
        // Fallback for routes not found in onGenerateRoute
        onUnknownRoute: (settings) => _FadeSlideRoute(
          settings: settings,
          builder: (context) => const Scaffold(
            body: Center(child: Text('Page not found', style: TextStyle(color: Colors.white))),
          ),
        ),
      ),
    );
  }
}
