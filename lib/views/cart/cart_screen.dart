import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/cart_service.dart';
import '../../services/analytics_service.dart';

/// Full cart screen — shows all added items, quantity controls, and place order CTA.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  List<CartItem> _items = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    final items = await _cartService.getCart();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  double get _subtotal {
    double total = 0;
    for (final item in _items) {
      // Extract numeric value from price string like "₹2,999 / unit"
      final clean = item.price.replaceAll(RegExp(r'[^\d.]'), '');
      total += (double.tryParse(clean) ?? 0) * item.quantity;
    }
    return total;
  }

  Future<void> _removeItem(String productId) async {
    await _cartService.removeFromCart(productId);
    await _loadCart();
  }

  Future<void> _updateQty(String productId, int qty) async {
    await _cartService.updateQuantity(productId, qty);
    await _loadCart();
  }

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);
    
    // Log purchase event in analytics before clearing the cart
    try {
      final total = _subtotal;
      final cartItemsMap = _items.map((item) => {
        'id': item.productId,
        'name': item.title,
        'price': double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
        'quantity': item.quantity,
      }).toList();
      
      AnalyticsService().logPurchase(
        transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        cartItems: cartItemsMap,
        total: total,
      );
    } catch (e) {
      debugPrint('Failed to log purchase event: $e');
    }

    await Future.delayed(const Duration(seconds: 2)); // Simulate order placement
    await _cartService.clearCart();
    if (mounted) {
      setState(() { _isPlacingOrder = false; _items = []; });
      _showOrderSuccessSheet();
    }
  }

  void _showOrderSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppTheme.instagramGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order Placed! 🎉',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your sample order is confirmed. Our team will contact you for delivery details.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.instagramGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Continue Shopping',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
            'My Cart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _cartService.clearCart();
                await _loadCart();
              },
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon))
          : _items.isEmpty
              ? _buildEmptyCart()
              : _buildCartList(),
      bottomNavigationBar: _items.isEmpty
          ? null
          : _buildCheckoutBar(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items from the catalog or swipe feed',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                'Browse Catalog',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: 90,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => Container(
                          width: 90,
                          height: 100,
                          color: AppTheme.darkBg,
                          child: const Icon(Icons.checkroom_rounded, color: AppTheme.textSecondary),
                        ),
                      )
                    : Container(
                        width: 90,
                        height: 100,
                        color: AppTheme.darkBg,
                        child: const Icon(Icons.checkroom_rounded, color: AppTheme.textSecondary),
                      ),
              ),
              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.price,
                        style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Quantity controls
                          _buildQtyButton(
                            icon: Icons.remove,
                            onTap: () => _updateQty(item.productId, item.quantity - 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          _buildQtyButton(
                            icon: Icons.add,
                            onTap: () => _updateQty(item.productId, item.quantity + 1),
                          ),
                          const Spacer(),
                          // Delete
                          GestureDetector(
                            onTap: () => _removeItem(item.productId),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.glassBorder,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text(
                '₹${_subtotal.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isPlacingOrder ? null : _placeOrder,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _isPlacingOrder ? null : AppTheme.instagramGradient,
                color: _isPlacingOrder ? AppTheme.glassBorder : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isPlacingOrder
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : Text(
                      'Place Sample Order  •  ${_items.length} item${_items.length > 1 ? 's' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
