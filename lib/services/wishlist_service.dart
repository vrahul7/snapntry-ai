import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';

import '../models/wishlist_model.dart';
export '../models/wishlist_model.dart';

/// Singleton Wishlist Service — persists to Firestore per user, with local fallback.
class WishlistService {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final List<WishlistItem> _local = [];
  final ValueNotifier<List<WishlistItem>> wishlistNotifier =
      ValueNotifier<List<WishlistItem>>([]);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _firebaseEnabled {
    try {
      return _uid != null;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _col {
    if (!_firebaseEnabled) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('wishlist');
  }

  bool isWishlisted(String productId) =>
      _local.any((w) => w.productId == productId);

  // ── Toggle (add / remove) ────────────────────────────────────────────────────
  Future<bool> toggle({
    required String productId,
    required String title,
    required String imageUrl,
    required String price,
    required String sku,
  }) async {
    if (isWishlisted(productId)) {
      await remove(productId);
      return false; // removed
    } else {
      await add(
        productId: productId,
        title: title,
        imageUrl: imageUrl,
        price: price,
        sku: sku,
      );
      return true; // added
    }
  }

  // ── Add to wishlist ──────────────────────────────────────────────────────────
  Future<void> add({
    required String productId,
    required String title,
    required String imageUrl,
    required String price,
    required String sku,
  }) async {
    // Log addToWishlist event in analytics
    try {
      final parsedPrice = double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      AnalyticsService().logAddToWishlist(
        productId: productId,
        name: title,
        price: parsedPrice,
      );
    } catch (e) {
      debugPrint('Failed to log addToWishlist event: $e');
    }

    if (isWishlisted(productId)) return;
    final item = WishlistItem(
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      price: price,
      sku: sku,
    );
    _local.add(item);
    wishlistNotifier.value = List.from(_local);

    if (_firebaseEnabled) {
      try {
        await _col!.doc(productId).set(item.toMap());
      } catch (e) {
        debugPrint('WishlistService add error: $e');
      }
    }
  }

  // ── Remove from wishlist ─────────────────────────────────────────────────────
  Future<void> remove(String productId) async {
    _local.removeWhere((w) => w.productId == productId);
    wishlistNotifier.value = List.from(_local);

    if (_firebaseEnabled) {
      try {
        await _col!.doc(productId).delete();
      } catch (e) {
        debugPrint('WishlistService remove error: $e');
      }
    }
  }

  // ── Get all wishlist items ───────────────────────────────────────────────────
  Future<List<WishlistItem>> getWishlist() async {
    if (_firebaseEnabled) {
      try {
        final snapshot = await _col!.orderBy('savedAt', descending: true).get();
        final items = snapshot.docs
            .map((doc) => WishlistItem.fromMap(doc.data(), doc.id))
            .toList();
        _local
          ..clear()
          ..addAll(items);
        wishlistNotifier.value = List.from(_local);
        return items;
      } catch (e) {
        debugPrint('WishlistService fetch error: $e');
      }
    }
    return List.from(_local);
  }

  // Sync from Firestore on login
  Future<void> syncOnLogin() async {
    await getWishlist();
  }
}
