import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/wishlist_service.dart';
import '../../services/cart_service.dart';
import '../../services/try_on_state.dart';

/// Wishlist screen — shows all saved items with Try-On and Add to Cart actions.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _wishlistService = WishlistService();
  final _cartService = CartService();
  List<WishlistItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _wishlistService.wishlistNotifier.addListener(_onWishlistChange);
  }

  @override
  void dispose() {
    _wishlistService.wishlistNotifier.removeListener(_onWishlistChange);
    super.dispose();
  }

  void _onWishlistChange() {
    if (mounted) {
      setState(() => _items = List.from(_wishlistService.wishlistNotifier.value));
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await _wishlistService.getWishlist();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _removeItem(WishlistItem item) async {
    await _wishlistService.remove(item.productId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bookmark_remove_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('${item.title} removed from wishlist'),
            ],
          ),
          backgroundColor: AppTheme.darkCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppTheme.primaryNeon,
            onPressed: () => _wishlistService.add(
              productId: item.productId,
              title: item.title,
              imageUrl: item.imageUrl,
              price: item.price,
              sku: item.sku,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _addToCart(WishlistItem item) async {
    await _cartService.addToCart(
      productId: item.productId,
      title: item.title,
      imageUrl: item.imageUrl,
      price: item.price,
      sku: item.sku,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('${item.title} added to cart!'),
            ],
          ),
          backgroundColor: const Color(0xFF0066CC),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _tryOn(WishlistItem item) {
    TryOnState.selectProductForTryOn(item.title, item.imageUrl);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.instagramGradient.createShader(bounds),
          child: const Text(
            'Saved Items',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_items.length} saved',
              style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon))
          : _items.isEmpty
              ? _buildEmpty()
              : _buildGrid(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.instagramGradient.createShader(bounds),
            child: const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 72),
          ),
          const SizedBox(height: 20),
          const Text(
            'No saved items yet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the Save button while swiping to build your wishlist',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.instagramGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Swipe Feed',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildCard(item);
      },
    );
  }

  Widget _buildCard(WishlistItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image + remove button
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => Container(
                          height: 140,
                          color: AppTheme.darkBg,
                          child: const Icon(Icons.checkroom_rounded, color: AppTheme.textSecondary, size: 40),
                        ),
                      )
                    : Container(
                        height: 140,
                        color: AppTheme.darkBg,
                        child: const Icon(Icons.checkroom_rounded, color: AppTheme.textSecondary, size: 40),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeItem(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_remove_rounded, color: AppTheme.primaryNeon, size: 16),
                  ),
                ),
              ),
            ],
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.price,
                  style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _tryOn(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.instagramGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Try On',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _addToCart(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.shopping_bag_rounded, color: AppTheme.secondaryNeon, size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
