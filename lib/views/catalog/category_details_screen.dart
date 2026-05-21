import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryDetailsScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  final _firestoreService = FirestoreService();
  late Future<List<ProductItem>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _firestoreService.getCatalogProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching AppTheme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0E),
                  Color(0xFF14142B),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorder, width: 1),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.categoryName.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2x2 Grid Layout of products
                Expanded(
                  child: FutureBuilder<List<ProductItem>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryNeon),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No items in this category.'),
                        );
                      }

                      final products = snapshot.data!;
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildGridCard(product);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(ProductItem product) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.title} selected for virtual fit mapping.'),
            backgroundColor: AppTheme.primaryNeon,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Product Image Background
              Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.darkCard,
                  child: const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary),
                ),
              ),

              // Gradient Overlay at the bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),

              // Item details overlayed at bottom-left corner
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.price.split(' /').first, // just show price value e.g. $129.00
                      style: const TextStyle(
                        color: AppTheme.secondaryNeon,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
