import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_auth_service.dart';
import '../../config/routes.dart';
import '../explore/explore_screen.dart';
import '../catalog/catalog_screen.dart';
import '../try_on/try_on_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default to Catalog view (tab 1)

  final List<Widget> _screens = [
    const ExploreScreen(), // Tab 0: Discover / Swipe
    const CatalogScreen(), // Tab 1: Catalog List
    const TryOnScreen(),   // Tab 2: AI Try-On Studio
    const ProfileScreen(), // Tab 3: Partner Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to flow behind the bottom navigation bar
      appBar: AppBar(
        title: Text(_getAppBarTitle(_currentIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _buildGlassmorphicBottomBar(),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'DISCOVER';
      case 1:
        return 'WHOLESALE CATALOG';
      case 2:
        return 'AI TRY-ON STUDIO';
      case 3:
        return 'PARTNER ACCOUNT';
      default:
        return 'GENA2Z';
    }
  }

  Widget _buildGlassmorphicBottomBar() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // frosted glass blur
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withOpacity(0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(index: 0, icon: Icons.compass_calibration_outlined, activeIcon: Icons.explore, label: 'Swipe'),
                _buildNavItem(index: 1, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Feed'),
                _buildNavItem(index: 2, icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'AI Try-On'),
                _buildNavItem(index: 3, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
