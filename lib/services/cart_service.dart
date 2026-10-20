import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';

import '../models/cart_model.dart';
export '../models/cart_model.dart';

/// Singleton Cart Service — persists cart to Firestore per user, with local fallback.
class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // In-memory cart (local fallback / mirror)
  final List<CartItem> _localCart = [];
  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _firebaseEnabled {
    try {
      return _uid != null;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _cartCol {
    if (!_firebaseEnabled) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('cart');
  }

  // ── Add to cart ──────────────────────────────────────────────────────────────
  Future<void> addToCart({
    required String productId,
    required String title,
    required String imageUrl,
    required String price,
    required String sku,
    int quantity = 1,
  }) async {
    // Log addToCart event in analytics
    try {
      final parsedPrice = double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      AnalyticsService().logAddToCart(
        productId: productId,
        name: title,
        price: parsedPrice,
        quantity: quantity,
      );
    } catch (e) {
      debugPrint('Failed to log addToCart event: $e');
    }

    // Check if already in local cart
    final existing = _localCart.indexWhere((c) => c.productId == productId);
    if (existing != -1) {
      _localCart[existing].quantity += quantity;
      cartCountNotifier.value = totalCount;
      // Update in Firestore if available
      if (_firebaseEnabled) {
        try {
          await _cartCol!.doc(_localCart[existing].id).update({
            'quantity': _localCart[existing].quantity,
          });
        } catch (e) {
          debugPrint('CartService Firestore update error: $e');
        }
      }
      return;
    }

    final newItem = CartItem(
      id: productId, // use productId as doc id for easy lookup
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      price: price,
      sku: sku,
      quantity: quantity,
    );
    _localCart.add(newItem);
    cartCountNotifier.value = totalCount;

    if (_firebaseEnabled) {
      try {
        await _cartCol!.doc(productId).set(newItem.toMap());
      } catch (e) {
        debugPrint('CartService Firestore add error: $e');
      }
    }
  }

  // ── Remove from cart ─────────────────────────────────────────────────────────
  Future<void> removeFromCart(String productId) async {
    _localCart.removeWhere((c) => c.productId == productId);
    cartCountNotifier.value = totalCount;
    if (_firebaseEnabled) {
      try {
        await _cartCol!.doc(productId).delete();
      } catch (e) {
        debugPrint('CartService Firestore delete error: $e');
      }
    }
  }

  // ── Get all cart items ───────────────────────────────────────────────────────
  Future<List<CartItem>> getCart() async {
    if (_firebaseEnabled) {
      try {
        final snapshot = await _cartCol!.get();
        final items = snapshot.docs
            .map((doc) => CartItem.fromMap(doc.data(), doc.id))
            .toList();
        _localCart
          ..clear()
          ..addAll(items);
        cartCountNotifier.value = totalCount;
        return items;
      } catch (e) {
        debugPrint('CartService Firestore fetch error: $e');
      }
    }
    return List.from(_localCart);
  }

  // ── Update quantity ──────────────────────────────────────────────────────────
  Future<void> updateQuantity(String productId, int qty) async {
    final idx = _localCart.indexWhere((c) => c.productId == productId);
    if (idx == -1) return;
    if (qty <= 0) {
      await removeFromCart(productId);
      return;
    }
    _localCart[idx].quantity = qty;
    cartCountNotifier.value = totalCount;
    if (_firebaseEnabled) {
      try {
        await _cartCol!.doc(productId).update({'quantity': qty});
      } catch (e) {
        debugPrint('CartService Firestore qty update error: $e');
      }
    }
  }

  // ── Clear cart ───────────────────────────────────────────────────────────────
  Future<void> clearCart() async {
    _localCart.clear();
    cartCountNotifier.value = 0;
    if (_firebaseEnabled) {
      try {
        final snapshot = await _cartCol!.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        debugPrint('CartService Firestore clear error: $e');
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  int get totalCount => _localCart.fold(0, (acc, item) => acc + item.quantity);

  bool isInCart(String productId) => _localCart.any((c) => c.productId == productId);

  // Sync from Firestore on login
  Future<void> syncOnLogin() async {
    await getCart();
  }
}
