import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_auth_service.dart';
import '../../config/routes.dart';
import '../explore/explore_screen.dart';
import '../catalog/catalog_screen.dart';
import '../try_on/try_on_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/try_on_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Default to Home Feed (tab 0)

  final List<Widget> _screens = [
    const CatalogScreen(), // Tab 0: Home / Feed
    const ExploreScreen(), // Tab 1: TikTok-style Swipe
    const TryOnScreen(),   // Tab 2: AI Try-On Studio
    const ProfileScreen(), // Tab 3: Account Management
  ];

  @override
  void initState() {
    super.initState();
    TryOnState.currentTabNotifier.addListener(_onTabChange);
    _currentIndex = TryOnState.currentTabNotifier.value;
  }

  @override
  void dispose() {
    TryOnState.currentTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) {
      setState(() {
        _currentIndex = TryOnState.currentTabNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to flow behind the bottom navigation bar
      appBar: AppBar(
        title: _buildGradientTitle(_currentIndex),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          // Key forces AnimatedSwitcher to animate on tab change
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildGlassmorphicBottomBar(),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'SnapnTry';
      case 1: return 'Explore';
      case 2: return 'AI Try-On';
      case 3: return 'My Account';
      default: return 'SnapnTry';
    }
  }

  Widget _buildGradientTitle(int index) {
    final title = _getAppBarTitle(index);
    final isHome = index == 0;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFF6B35),  // Warm orange
          Color(0xFFFF2D78),  // Hot pink
          Color(0xFFC644FC),  // Purple
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white, // ShaderMask overrides this with gradient
          fontSize: isHome ? 26 : 22,
          fontWeight: FontWeight.w800,
          fontStyle: isHome ? FontStyle.italic : FontStyle.normal,
          letterSpacing: isHome ? -0.5 : 0.5,
        ),
      ),
    );
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
              color: AppTheme.darkCard.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
                _buildNavItem(index: 1, icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Swipe'),
                _buildNavItem(index: 2, icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'Try-On'),
                _buildNavItem(index: 3, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Account'),
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
        TryOnState.currentTabNotifier.value = index;
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: isActive ? 44 : 36,
            height: isActive ? 44 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.primaryNeon.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey<bool>(isActive),
                  color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary,
                  size: isActive ? 24 : 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary,
              fontSize: isActive ? 10.5 : 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
