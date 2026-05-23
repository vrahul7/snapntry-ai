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

  // New catalog: clothing items only, from H&M and Zara
  final List<ProductItem> _mockProducts = [
    ProductItem(
      id: 'p1',
      title: 'Zara Linen-Blend Blazer',
      description: 'Slim-fit structured blazer in linen-blend fabric with notch lapels and pocket details.',
      price: '₹5,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=500',
      sku: 'SKU-ZR-BLZR-01',
    ),
    ProductItem(
      id: 'p2',
      title: 'H&M Oversized Fit Hoodie',
      description: 'Cozy hoodie in soft heavyweight organic cotton sweatshirt fabric with kangaroo pocket.',
      price: '₹2,299 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=500',
      sku: 'SKU-HM-HOOD-02',
    ),
    ProductItem(
      id: 'p3',
      title: 'H&M Linen Resort Shirt',
      description: 'Flowy shirt in airy woven pure linen fabric with a relaxed collar and chest pocket.',
      price: '₹1,999 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=500',
      sku: 'SKU-HM-SHRT-03',
    ),
    ProductItem(
      id: 'p4',
      title: 'Zara Wide-Leg Cargo Pants',
      description: 'High-waisted utility trousers with multi-pocket detailing and drawstrings at the hem.',
      price: '₹3,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=500',
      sku: 'SKU-ZR-CARG-04',
    ),
    ProductItem(
      id: 'p5',
      title: 'Zara Ribbed Midi Knit Dress',
      description: 'Sleeveless dress featuring a round neckline, premium ribbed texture, and side split.',
      price: '₹2,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=500',
      sku: 'SKU-ZR-DRES-05',
    ),
    ProductItem(
      id: 'p6',
      title: 'H&M Corduroy Utility Jacket',
      description: 'Regular-fit utility jacket in thick cotton corduroy with chest flap pockets.',
      price: '₹3,499 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=500',
      sku: 'SKU-HM-JKT-06',
    ),
    ProductItem(
      id: 'p7',
      title: 'Zara Pleated Smart Trousers',
      description: 'Pleated trousers with a relaxed tapered leg and formal pressed creases.',
      price: '₹3,490 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=500',
      sku: 'SKU-ZR-TRSR-07',
    ),
    ProductItem(
      id: 'p8',
      title: 'H&M Knit Crewneck Cardigan',
      description: 'Soft knit cardigan in premium cotton-viscose blend with button front closure.',
      price: '₹2,499 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=500',
      sku: 'SKU-HM-CARD-08',
    ),
  ];

  // Force re-seeding default clothing-only items into Firestore
  Future<void> forceReSeedProducts() async {
    if (isFirebaseEnabled) {
      try {
        final collection = FirebaseFirestore.instance.collection('products');
        final querySnapshot = await collection.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        await _seedProducts();
        debugPrint('Firestore products collection re-seeded with clothing items successfully.');
      } catch (e) {
        debugPrint('Failed to re-seed Firestore products: $e');
      }
    }
  }

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
        
        final list = querySnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
        
        // Self-healing check: if old non-clothing mock data (Pen, Duffel) exists, force-clean and re-seed
        final hasOldMockData = list.any((p) => 
          p.title.contains('Pen') || 
          p.title.contains('Duffel') || 
          p.title.contains('Hub')
        );
        if (hasOldMockData) {
          debugPrint('Old non-clothing mock products detected. Executing forced re-seed...');
          await forceReSeedProducts();
          final seededSnapshot = await FirebaseFirestore.instance.collection('products').get();
          return seededSnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
        }
        
        return list;
      } catch (e) {
        debugPrint('Firestore fetch catalog products error: $e. Falling back to mock data.');
        return _mockProducts;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400)); // Network simulation
      return _mockProducts;
    }
  }

  // Paged catalog products for infinite scrolling
  Future<List<ProductItem>> getCatalogProductsPaged({required int page, required int limit}) async {
    if (isFirebaseEnabled) {
      try {
        final collection = FirebaseFirestore.instance.collection('products');
        
        // Ensure database has seeded clothing products
        final checkSnapshot = await collection.limit(1).get();
        if (checkSnapshot.docs.isEmpty) {
          debugPrint('Firestore products collection is empty. Seeding default clothing products...');
          await _seedProducts();
        }
        
        final querySnapshot = await collection.get();
        final allProducts = querySnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
        
        // Re-seed self-healing if needed
        final hasOldMockData = allProducts.any((p) => 
          p.title.contains('Pen') || 
          p.title.contains('Duffel') || 
          p.title.contains('Hub')
        );
        if (hasOldMockData) {
          await forceReSeedProducts();
          final seededSnapshot = await collection.get();
          allProducts.clear();
          allProducts.addAll(seededSnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList());
        }
        
        final startIndex = (page - 1) * limit;
        if (startIndex >= allProducts.length) {
          return _generateInfiniteProducts(page, limit);
        }
        
        final endIndex = startIndex + limit;
        final pageProducts = allProducts.sublist(
          startIndex, 
          endIndex > allProducts.length ? allProducts.length : endIndex
        );
        
        // Dynamic infinite padding
        if (pageProducts.length < limit) {
          final needed = limit - pageProducts.length;
          final extra = _generateInfiniteProducts(page, needed);
          pageProducts.addAll(extra);
        }
        
        return pageProducts;
      } catch (e) {
        debugPrint('Firestore fetch paged error: $e. Falling back to mock pagination.');
        return _getMockPaged(page, limit);
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      return _getMockPaged(page, limit);
    }
  }

  List<ProductItem> _getMockPaged(int page, int limit) {
    final startIndex = (page - 1) * limit;
    if (startIndex >= _mockProducts.length) {
      return _generateInfiniteProducts(page, limit);
    }
    final endIndex = startIndex + limit;
    final pageProducts = List<ProductItem>.from(
      _mockProducts.sublist(
        startIndex,
        endIndex > _mockProducts.length ? _mockProducts.length : endIndex
      )
    );
    if (pageProducts.length < limit) {
      final needed = limit - pageProducts.length;
      final extra = _generateInfiniteProducts(page, needed);
      pageProducts.addAll(extra);
    }
    return pageProducts;
  }

  // Generates infinite clothing items from Zara/H&M with different styles/Unsplash images
  List<ProductItem> _generateInfiniteProducts(int page, int count) {
    final List<ProductItem> list = [];
    final brands = ['Zara India', 'H&M India', 'Zara B2B', 'H&M Online'];
    final items = [
      {
        'title': 'Cotton Cable-Knit Cardigan',
        'desc': 'Relaxed-fit cardigan in soft organic cotton knit with ribbing.',
        'price': '₹2,799',
        'img': 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=500'
      },
      {
        'title': 'Pleated Summer Gown',
        'desc': 'Floaty pleated dress with spaghetti straps and floral lace back.',
        'price': '₹3,499',
        'img': 'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=500'
      },
      {
        'title': 'Casual Linen Drawstring Trouser',
        'desc': 'Relaxed-fit linen-cotton blend trousers with adjustable elastic waist.',
        'price': '₹2,999',
        'img': 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=500'
      },
      {
        'title': 'Tailored Check Blazer',
        'desc': 'Single-breasted check blazer in structured weave with flap pockets.',
        'price': '₹6,990',
        'img': 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=500'
      },
      {
        'title': 'Denim Sherpa Jacket',
        'desc': 'Washed denim jacket lined with soft faux sherpa wool collar.',
        'price': '₹4,990',
        'img': 'https://images.unsplash.com/photo-1611312449412-6cefac5dc3e4?w=500'
      },
      {
        'title': 'Viscose Blend Mock-neck Sweater',
        'desc': 'Soft mock-neck knit sweater in premium sustainable viscose yarn.',
        'price': '₹1,599',
        'img': 'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=500'
      },
    ];

    for (int i = 0; i < count; i++) {
      final idx = (page * count + i) % items.length;
      final brand = brands[(page * count + i) % brands.length];
      final item = items[idx];
      list.add(ProductItem(
        id: 'gen_p_${page}_$i',
        title: '$brand ${item['title']}',
        description: '${item['desc']} Made with high quality materials. Exclusively for $brand.',
        price: '${item['price']} / unit',
        imageUrl: item['img']!,
        sku: 'SKU-GEN-$page$i-$idx',
      ));
    }
    return list;
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
