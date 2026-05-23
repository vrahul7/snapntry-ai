import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/try_on_state.dart';
import 'visual_search_delegate.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _firestoreService = FirestoreService();
  final List<ProductItem> _products = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Pre-Fall \'26', 'icon': Icons.fiber_new_rounded},
    {'name': 'Athleisure', 'icon': Icons.fitness_center_rounded},
    {'name': 'Paris Denim', 'icon': Icons.dry_cleaning_rounded},
    {'name': 'Core Basics', 'icon': Icons.checkroom_rounded},
  ];

  final List<Map<String, String>> _vibes = [
    {
      'name': 'East Coast Retailers',
      'image': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400',
    },
    {
      'name': 'Sustainable Collective',
      'image': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
    },
    {
      'name': 'High-Street Hub',
      'image': 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400',
    },
    {
      'name': 'Independent Boutiques',
      'image': 'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=400',
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final newProducts = await _firestoreService.getCatalogProductsPaged(
        page: _currentPage,
        limit: 4,
      );
      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _currentPage++;
          if (newProducts.length < 4) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load page $_currentPage: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
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
                'NEW RELEASES',
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
                'COMMUNITY LISTINGS',
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
                'BRAND POSTINGS & FEED',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildProductFeed(),
            if (_isLoading && _products.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon)),
              ),
            if (!_hasMore && _products.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No more products to show.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            
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
            child: GestureDetector(
              onTap: () {
                // Future: open keyboard search
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.glassBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Search collections...',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // AI Visual Search camera button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VisualSearchScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.primaryNeon,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
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
    if (_products.isEmpty && _isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon)),
      );
    } else if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: Text('Spotlight is empty.')),
      );
    }

    final brands = ['Apex Design Studio', 'Savana Wholesale', 'Zara Corporate', 'H&M B2B'];
    final times = ['2h ago', '5h ago', '1d ago', '3d ago'];
    final logos = [
      Icons.brightness_auto_rounded,
      Icons.style_rounded,
      Icons.wallet_giftcard_rounded,
      Icons.storefront_rounded
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final brandName = brands[index % brands.length];
        final timeAgo = times[index % times.length];
        final brandIcon = logos[index % logos.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryNeon.withValues(alpha: 0.1),
                        child: Icon(brandIcon, color: AppTheme.primaryNeon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  brandName,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppTheme.secondaryNeon,
                                  size: 14,
                                ),
                              ],
                            ),
                            Text(
                              timeAgo,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textSecondary),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Main Post Image
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    product.imageUrl,
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 280,
                      color: AppTheme.darkBg,
                      child: const Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.textSecondary),
                    ),
                  ),
                ),

                // Instagram-style action icons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded, color: AppTheme.textPrimary, size: 24),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textPrimary, size: 22),
                      const SizedBox(width: 16),
                      const Icon(Icons.send_outlined, color: AppTheme.textPrimary, size: 22),
                      const Spacer(),
                      const Icon(Icons.bookmark_border_rounded, color: AppTheme.textPrimary, size: 24),
                    ],
                  ),
                ),

                // Description / Caption
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
                      children: [
                        TextSpan(
                          text: '$brandName ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '${product.description} Wholesale unit price is ${product.price}.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Try-On and Order buttons row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            TryOnState.selectProductForTryOn(product.title, product.imageUrl);
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Try-On Fit', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.primaryNeon.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            foregroundColor: AppTheme.primaryNeon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sample order request sent for ${product.title}!'),
                                backgroundColor: AppTheme.secondaryNeon,
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                          label: const Text('Sample Order', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryNeon,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
