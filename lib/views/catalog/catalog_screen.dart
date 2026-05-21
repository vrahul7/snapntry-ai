import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _firestoreService = FirestoreService();
  late Future<List<ProductItem>> _productsFuture;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'New In', 'icon': Icons.fiber_new_rounded},
    {'name': 'Tops', 'icon': Icons.checkroom_rounded},
    {'name': 'Dresses', 'icon': Icons.dry_cleaning_rounded},
    {'name': 'Summer', 'icon': Icons.wb_sunny_rounded},
  ];

  final List<Map<String, String>> _vibes = [
    {
      'name': 'The Minimalist',
      'image': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400',
    },
    {
      'name': 'The Trendsetter',
      'image': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
    },
    {
      'name': 'Party Night',
      'image': 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400',
    },
    {
      'name': 'Summer Vibe',
      'image': 'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=400',
    },
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = _firestoreService.getCatalogProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Search & Actions Row
            _buildHeaderRow(),

            // Hero Banner Info Card
            _buildHeroBanner(),

            // Horizontal Categories Scroll Bar
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'BROWSE BY CATEGORY',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildCategoryScroller(),

            // Mood Card "Find Your Vibe" Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'FIND YOUR VIBE',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildVibeGrid(),

            // Bestsellers / Sample Orders Feed
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'EXECUTIVE SPOTLIGHT',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildProductFeed(),
            
            const SizedBox(height: 100), // Spacing to avoid layout overlapping bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Elegant search bar mock
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Search corporate collections...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification circle
          _buildIconButton(Icons.notifications_none_rounded, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No new wholesale notifications.'),
                backgroundColor: AppTheme.darkCard,
              ),
            );
          }),
          const SizedBox(width: 8),
          // Cart circle
          _buildIconButton(Icons.shopping_bag_outlined, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sample cart is currently empty.'),
                backgroundColor: AppTheme.darkCard,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.15), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkCard,
            AppTheme.primaryNeon.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryNeon, size: 16),
              const SizedBox(width: 8),
              Text(
                'FIT CHECK STARTS HERE',
                style: TextStyle(
                  color: AppTheme.primaryNeon,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Online try-on : save the drama for group chat.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScroller() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.categoryDetails,
                  arguments: cat['name'],
                );
              },
              child: Column(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                    ),
                    child: Icon(cat['icon'] as IconData, color: AppTheme.primaryNeon, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat['name'] as String,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVibeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: _vibes.length,
      itemBuilder: (context, index) {
        final vibe = _vibes[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.categoryDetails,
              arguments: vibe['name']!,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Mood background image
                  Image.network(
                    vibe['image']!,
                    fit: BoxFit.cover,
                  ),
                  // Dark shadow gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  // Mood title
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      vibe['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductFeed() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon)),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Failed: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('Spotlight is empty.'),
          );
        }

        final products = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: AppTheme.darkBg,
                          child: const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.price,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryNeon,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sample order placed for ${product.title}!'),
                            backgroundColor: AppTheme.primaryNeon,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Order'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
