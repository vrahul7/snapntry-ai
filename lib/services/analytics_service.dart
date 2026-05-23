import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  bool _initialized = false;

  void init() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      _initialized = true;
      debugPrint('Firebase Analytics successfully initialized.');
      logAppOpen();
    } catch (e) {
      debugPrint('Firebase Analytics initialization failed: $e');
    }
  }

  FirebaseAnalyticsObserver? get observer => _observer;

  Future<void> logAppOpen() async {
    if (!_initialized) return;
    try {
      await _analytics!.logAppOpen();
      debugPrint('Analytics: App open event logged.');
    } catch (e) {
      debugPrint('Failed to log app open event: $e');
    }
  }

  Future<void> logTryOnEvent({
    required String apparelId,
    required String category,
    required bool success,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics!.logEvent(
        name: 'virtual_try_on',
        parameters: {
          'apparel_id': apparelId,
          'category': category,
          'success': success ? 1 : 0,
        },
      );
      debugPrint('Analytics: Virtual try-on event logged ($apparelId).');
    } catch (e) {
      debugPrint('Failed to log try-on event: $e');
    }
  }

  Future<void> logAddToCart({
    required String productId,
    required String name,
    required double price,
    int quantity = 1,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics!.logAddToCart(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: name,
            price: price,
            quantity: quantity,
          ),
        ],
        value: price * quantity,
        currency: 'INR',
      );
      debugPrint('Analytics: Add to cart event logged ($productId).');
    } catch (e) {
      debugPrint('Failed to log add to cart event: $e');
    }
  }

  Future<void> logAddToWishlist({
    required String productId,
    required String name,
    required double price,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics!.logAddToWishlist(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: name,
            price: price,
          ),
        ],
        value: price,
        currency: 'INR',
      );
      debugPrint('Analytics: Add to wishlist event logged ($productId).');
    } catch (e) {
      debugPrint('Failed to log add to wishlist event: $e');
    }
  }

  Future<void> logCheckout({
    required List<Map<String, dynamic>> cartItems,
    required double total,
  }) async {
    if (!_initialized) return;
    try {
      final items = cartItems.map((item) {
        return AnalyticsEventItem(
          itemId: item['id'] as String? ?? '',
          itemName: item['name'] as String? ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          quantity: item['quantity'] as int? ?? 1,
        );
      }).toList();

      await _analytics!.logBeginCheckout(
        items: items,
        value: total,
        currency: 'INR',
      );
      debugPrint('Analytics: Begin checkout logged (Total: $total).');
    } catch (e) {
      debugPrint('Failed to log checkout event: $e');
    }
  }

  Future<void> logPurchase({
    required String transactionId,
    required List<Map<String, dynamic>> cartItems,
    required double total,
  }) async {
    if (!_initialized) return;
    try {
      final items = cartItems.map((item) {
        return AnalyticsEventItem(
          itemId: item['id'] as String? ?? '',
          itemName: item['name'] as String? ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          quantity: item['quantity'] as int? ?? 1,
        );
      }).toList();

      await _analytics!.logPurchase(
        transactionId: transactionId,
        items: items,
        value: total,
        currency: 'INR',
      );
      debugPrint('Analytics: Purchase event logged ($transactionId).');
    } catch (e) {
      debugPrint('Failed to log purchase event: $e');
    }
  }

  Future<void> logVisualSearch({required bool success}) async {
    if (!_initialized) return;
    try {
      await _analytics!.logEvent(
        name: 'visual_search',
        parameters: {
          'success': success ? 1 : 0,
        },
      );
      debugPrint('Analytics: Visual search event logged (Success: $success).');
    } catch (e) {
      debugPrint('Failed to log visual search event: $e');
    }
  }
}
