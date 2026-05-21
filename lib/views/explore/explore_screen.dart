import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _firestoreService = FirestoreService();
  late Future<List<ProductItem>> _productsFuture;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _productsFuture = _firestoreService.getCatalogProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<ProductItem>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryNeon),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading explore feed: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Explore feed is empty.'),
            );
          }

          final products = snapshot.data!;
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Fullscreen Background Photo
                  Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppTheme.darkBg,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 64, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),

                  // Bottom Shadow Overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Product Details (Bottom Left)
                  Positioned(
                    bottom: 120,
                    left: 20,
                    right: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AI TRY-ON AVAILABLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.sku,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryNeon,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Actions Panel (Right Overlay)
                  Positioned(
                    bottom: 120,
                    right: 20,
                    child: Column(
                      children: [
                        // Try-On Sparkle Action
                        _buildFloatingActionButton(
                          icon: Icons.auto_awesome_rounded,
                          color: AppTheme.primaryNeon,
                          label: 'Try On',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Scheduling AI Try-On for ${product.title}...'),
                                backgroundColor: AppTheme.primaryNeon,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Buy/Cart Action
                        _buildFloatingActionButton(
                          icon: Icons.shopping_bag_outlined,
                          color: Colors.white.withValues(alpha: 0.1),
                          label: 'Buy',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.title} added to purchase cart!'),
                                backgroundColor: AppTheme.darkCard,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Save Action
                        _buildFloatingActionButton(
                          icon: Icons.bookmark_border_rounded,
                          color: Colors.white.withValues(alpha: 0.1),
                          label: 'Save',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.title} saved to corporate wardrobe.'),
                                backgroundColor: AppTheme.darkCard,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 26,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
