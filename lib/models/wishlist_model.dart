import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model representing an item in the user's wishlist.
class WishlistItem {
  final String productId;
  final String title;
  final String imageUrl;
  final String price;
  final String sku;

  WishlistItem({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.sku,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'imageUrl': imageUrl,
    'price': price,
    'sku': sku,
    'savedAt': FieldValue.serverTimestamp(),
  };

  factory WishlistItem.fromMap(Map<String, dynamic> map, String docId) => WishlistItem(
    productId: docId,
    title: map['title'] ?? '',
    imageUrl: map['imageUrl'] ?? '',
    price: map['price'] ?? '',
    sku: map['sku'] ?? '',
  );

  WishlistItem copyWith({
    String? productId,
    String? title,
    String? imageUrl,
    String? price,
    String? sku,
  }) {
    return WishlistItem(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      sku: sku ?? this.sku,
    );
  }
}
