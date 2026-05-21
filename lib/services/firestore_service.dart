import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProductItem {
  final String id;
  final String title;
  final String description;
  final String price;
  final String imageUrl;
  final String sku;

  ProductItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sku,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'sku': sku,
    };
  }

  factory ProductItem.fromMap(Map<String, dynamic> map, String docId) {
    return ProductItem(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      sku: map['sku'] ?? '',
    );
  }
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  bool get isFirebaseEnabled => Firebase.apps.isNotEmpty;

  final List<ProductItem> _mockProducts = [
    ProductItem(
      id: 'p1',
      title: 'Tech Jacket Pro',
      description: 'Vapor-permeable waterproof shell jacket for corporate outdoor wear.',
      price: '\$129.00 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500',
      sku: 'SKU-TJP-01',
    ),
    ProductItem(
      id: 'p2',
      title: 'Obsidian Smart Duffel',
      description: 'Water-resistant carbon fiber canvas travel duffel with modular slots.',
      price: '\$89.50 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500',
      sku: 'SKU-OSD-02',
    ),
    ProductItem(
      id: 'p3',
      title: 'Minimalist Titanium Pen',
      description: 'CNC machined grade-5 titanium executive writing tool with pressurized refill.',
      price: '\$45.00 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1583485088034-697b5bc54ccd?w=500',
      sku: 'SKU-MTP-03',
    ),
    ProductItem(
      id: 'p4',
      title: 'HyperCharge 100W Hub',
      description: 'Anodized aluminum multi-port power adapter with GaN tech.',
      price: '\$65.00 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1606229365731-98ac445351ae?w=500',
      sku: 'SKU-HCH-04',
    ),
  ];

  // Return elegant catalog items for our B2B catalog UI
  Future<List<ProductItem>> getCatalogProducts() async {
    if (isFirebaseEnabled) {
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('products').get();
        if (querySnapshot.docs.isEmpty) {
          debugPrint('Firestore products collection is empty. Seeding default products...');
          await _seedProducts();
          final seededSnapshot = await FirebaseFirestore.instance.collection('products').get();
          return seededSnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
        }
        return querySnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
      } catch (e) {
        debugPrint('Firestore fetch catalog products error: $e. Falling back to mock data.');
        return _mockProducts;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800)); // Network simulation
      return _mockProducts;
    }
  }

  Future<void> _seedProducts() async {
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('products');
    for (final prod in _mockProducts) {
      final docRef = collection.doc(prod.id);
      batch.set(docRef, prod.toMap());
    }
    await batch.commit();
  }

  // Log Try-On transaction to Firestore for production logging/auditing
  Future<void> logTryOnTransaction({
    required String userId,
    required String apparelId,
    required String apparelTitle,
    required String apparelImageUrl,
    required String userPhotoUrl,
    required String resultImageUrl,
    required String status,
  }) async {
    if (isFirebaseEnabled) {
      try {
        await FirebaseFirestore.instance.collection('try_ons').add({
          'userId': userId,
          'apparelId': apparelId,
          'apparelTitle': apparelTitle,
          'apparelImageUrl': apparelImageUrl,
          'userPhotoUrl': userPhotoUrl,
          'resultImageUrl': resultImageUrl,
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to log try-on transaction: $e');
      }
    }
  }
}

