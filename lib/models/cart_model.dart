import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model representing an item in the user's B2B shopping cart.
class CartItem {
  final String id;
  final String productId;
  final String title;
  final String imageUrl;
  final String price;
  final String sku;
  int quantity;

  CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.sku,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'title': title,
    'imageUrl': imageUrl,
    'price': price,
    'sku': sku,
    'quantity': quantity,
    'addedAt': FieldValue.serverTimestamp(),
  };

  factory CartItem.fromMap(Map<String, dynamic> map, String docId) => CartItem(
    id: docId,
    productId: map['productId'] ?? '',
    title: map['title'] ?? '',
    imageUrl: map['imageUrl'] ?? '',
    price: map['price'] ?? '',
    sku: map['sku'] ?? '',
    quantity: (map['quantity'] as int?) ?? 1,
  );

  CartItem copyWith({
    String? id,
    String? productId,
    String? title,
    String? imageUrl,
    String? price,
    String? sku,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
    );
  }
}
