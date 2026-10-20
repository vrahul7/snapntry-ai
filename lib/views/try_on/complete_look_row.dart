import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/try_on_state.dart';
import '../../widgets/app_network_image.dart';

/// "Complete the Look" horizontal product row displayed under the generated try-on result.
/// Shows complementary products that pair well with the currently selected garment.
class CompleteLookRow extends StatelessWidget {
  final String currentApparelTitle;
  final String currentApparelCategory;

  const CompleteLookRow({
    super.key,
    required this.currentApparelTitle,
    required this.currentApparelCategory,
  });

  // Curated cross-sell pairings: for each apparel title, show suggested complementary items.
  // In production, this would come from Firestore `matchingApparelIds` field.
  static const Map<String, List<Map<String, String>>> _crossSellMap = {
    'Tech Jacket Pro': [
      {
        'title': 'Urban Cargo Pants',
        'image': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=200',
        'category': 'lower_body',
        'price': '₹1,499',
      },
      {
        'title': 'Slim Fit Joggers',
        'image': 'https://images.unsplash.com/photo-1594938298603-c8148c4b3dd2?w=200',
        'category': 'lower_body',
        'price': '₹999',
      },
      {
        'title': 'Graphic Tee',
        'image': 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=200',
        'category': 'upper_body',
        'price': '₹699',
      },
    ],
    'Silk Evening Dress': [
      {
        'title': 'Strappy Heels',
        'image': 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=200',
        'category': 'accessory',
        'price': '₹2,199',
      },
      {
        'title': 'Evening Clutch',
        'image': 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=200',
        'category': 'accessory',
        'price': '₹1,299',
      },
      {
        'title': 'Gold Cuff Bracelet',
        'image': 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=200',
        'category': 'accessory',
        'price': '₹799',
      },
    ],
    'Urban Cargo Pants': [
      {
        'title': 'Tech Jacket Pro',
        'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200',
        'category': 'upper_body',
        'price': '₹2,499',
      },
      {
        'title': 'Premium Linen Shirt',
        'image': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=200',
        'category': 'upper_body',
        'price': '₹1,299',
      },
      {
        'title': 'Oversized Hoodie',
        'image': 'https://images.unsplash.com/photo-1556821840-3a63f15732ce?w=200',
        'category': 'upper_body',
        'price': '₹1,099',
      },
    ],
    'Premium Linen Shirt': [
      {
        'title': 'Slim Chinos',
        'image': 'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=200',
        'category': 'lower_body',
        'price': '₹1,699',
      },
      {
        'title': 'Urban Cargo Pants',
        'image': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=200',
        'category': 'lower_body',
        'price': '₹1,499',
      },
      {
        'title': 'Leather Belt',
        'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200',
        'category': 'accessory',
        'price': '₹599',
      },
    ],
  };

  List<Map<String, String>> get _suggestions {
    final direct = _crossSellMap[currentApparelTitle];
    if (direct != null) return direct;

    // Fallback: suggest opposite category items
    if (currentApparelCategory == 'upper_body') {
      return [
        {
          'title': 'Urban Cargo Pants',
          'image': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=200',
          'category': 'lower_body',
          'price': '₹1,499',
        },
        {
          'title': 'Slim Fit Joggers',
          'image': 'https://images.unsplash.com/photo-1594938298603-c8148c4b3dd2?w=200',
          'category': 'lower_body',
          'price': '₹999',
        },
      ];
    } else if (currentApparelCategory == 'lower_body') {
      return [
        {
          'title': 'Premium Linen Shirt',
          'image': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=200',
          'category': 'upper_body',
          'price': '₹1,299',
        },
        {
          'title': 'Tech Jacket Pro',
          'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200',
          'category': 'upper_body',
          'price': '₹2,499',
        },
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.instagramGradient.createShader(bounds),
                  child: const Icon(Icons.style_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Complete the Look',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Text(
              'AI Styled',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pairs perfectly with your $currentApparelTitle',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        // Horizontal scrolling product cards
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final item = suggestions[index];
              return _CompleteLookCard(
                title: item['title']!,
                imageUrl: item['image']!,
                category: item['category']!,
                price: item['price']!,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompleteLookCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String category;
  final String price;

  const _CompleteLookCard({
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.price,
  });

  @override
  State<_CompleteLookCard> createState() => _CompleteLookCardState();
}

class _CompleteLookCardState extends State<_CompleteLookCard> {
  bool _isHovered = false;

  void _tryOnThis(BuildContext context) {
    // Push this item to TryOnState so it's loaded in the studio
    TryOnState.pendingTryOnNotifier.value = {
      'title': widget.title,
      'image': widget.imageUrl,
      'category': widget.category,
    };
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Loading ${widget.title} in AI Studio…'),
          ],
        ),
        backgroundColor: const Color(0xFF2A1A4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        _tryOnThis(context);
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        transform: Matrix4.diagonal3Values(
            _isHovered ? 0.96 : 1.0, _isHovered ? 0.96 : 1.0, 1.0),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppTheme.primaryNeon.withValues(alpha: 0.6)
                : AppTheme.glassBorder,
            width: 1.2,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            AppNetworkImage(
              imageUrl: widget.imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.price,
                    style: const TextStyle(
                      color: AppTheme.primaryNeon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // "Try On" mini button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppTheme.instagramGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text(
                          'Try On',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
