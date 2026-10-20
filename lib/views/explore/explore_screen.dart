import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../services/try_on_state.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/app_network_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _firestoreService = FirestoreService();
  final _wishlistService = WishlistService();

  late Future<List<ProductItem>> _productsFuture;
  final PageController _pageController = PageController();

  // Track wishlist state per product id for icon animation
  final Map<String, bool> _wishlisted = {};

  @override
  void initState() {
    super.initState();
    _productsFuture = _firestoreService.getCatalogProducts();
    // Sync wishlist state
    _wishlistService.getWishlist().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _handleBuy(ProductItem product) async {
    final Uri url = Uri.parse(product.productUrl);
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      if (!launched) throw 'In-app webview failed';
    } catch (e) {
      debugPrint('Error launching URL in-app: $e');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load store: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleSave(ProductItem product) async {
    final added = await _wishlistService.toggle(
      productId: product.id,
      title: product.title,
      imageUrl: product.imageUrl,
      price: product.price,
      sku: product.sku,
    );

    if (mounted) {
      setState(() {
        _wishlisted[product.id] = added;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                added ? Icons.bookmark_rounded : Icons.bookmark_remove_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  added
                      ? '${product.title} saved to wishlist!'
                      : '${product.title} removed from wishlist',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: added ? AppTheme.darkCard : Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
          action: added
              ? SnackBarAction(
                  label: 'View',
                  textColor: AppTheme.primaryNeon,
                  onPressed: () => Navigator.pushNamed(context, '/wishlist'),
                )
              : null,
        ),
      );
    }
  }

  void _handleShare(ProductItem product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share Fashion Discovery',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share ${product.title} with retail partners or friends.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(Icons.link_rounded, 'Copy Link', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Link copied to clipboard: ${product.productUrl}'),
                          backgroundColor: AppTheme.primaryNeon,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }),
                    _buildShareOption(Icons.chat_bubble_rounded, 'Chat App', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening Chat sharing...'), backgroundColor: AppTheme.darkCard),
                      );
                    }),
                    _buildShareOption(Icons.mail_outline_rounded, 'Email', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening Email client...'), backgroundColor: AppTheme.darkCard),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Icon(icon, color: AppTheme.primaryNeon, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
              final isSaved = _wishlisted[product.id] ??
                  _wishlistService.isWishlisted(product.id);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Fullscreen Background Photo
                  AppNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                  ),

                  // Bottom Shadow Overlay
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
                        Row(
                          children: [
                            Text(
                              product.price.split(' /').first,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7EB8FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.brand.toUpperCase(),
                                style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
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
                            TryOnState.selectProductForTryOn(
                                product.title, product.imageUrl);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Buy Action
                        _buildFloatingActionButton(
                          icon: Icons.shopping_bag_rounded,
                          color: const Color(0xFF0066CC),
                          label: 'Buy',
                          onTap: () => _handleBuy(product),
                        ),
                        const SizedBox(height: 16),

                        // Save / Wishlist Action
                        _buildFloatingActionButton(
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved
                              ? AppTheme.primaryNeon.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.15),
                          label: isSaved ? 'Saved ✓' : 'Save',
                          onTap: () => _handleSave(product),
                        ),
                        const SizedBox(height: 16),

                        // Share Action
                        _buildFloatingActionButton(
                          icon: Icons.share_rounded,
                          color: Colors.white.withValues(alpha: 0.15),
                          label: 'Share',
                          onTap: () => _handleShare(product),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
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
            child: Icon(icon, size: 26, color: Colors.white),
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
