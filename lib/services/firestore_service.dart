import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
export '../models/product_model.dart';

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
      productUrl: 'https://www.zara.com/in/en/linen-blend-blazer-p02753043.html',
      gender: 'Men',
      brand: 'Zara',
    ),
    ProductItem(
      id: 'p2',
      title: 'H&M Oversized Fit Hoodie',
      description: 'Cozy hoodie in soft heavyweight organic cotton sweatshirt fabric with kangaroo pocket.',
      price: '₹2,299 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=500',
      sku: 'SKU-HM-HOOD-02',
      productUrl: 'https://www2.hm.com/en_in/productpage.0970818001.html',
      gender: 'Men',
      brand: 'H&M',
    ),
    ProductItem(
      id: 'p3',
      title: 'H&M Linen Resort Shirt',
      description: 'Flowy shirt in airy woven pure linen fabric with a relaxed collar and chest pocket.',
      price: '₹1,999 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=500',
      sku: 'SKU-HM-SHRT-03',
      productUrl: 'https://www2.hm.com/en_in/productpage.0967550001.html',
      gender: 'Men',
      brand: 'H&M',
    ),
    ProductItem(
      id: 'p4',
      title: 'Zara Wide-Leg Cargo Pants',
      description: 'High-waisted utility trousers with multi-pocket detailing and drawstrings at the hem.',
      price: '₹3,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=500',
      sku: 'SKU-ZR-CARG-04',
      productUrl: 'https://www.zara.com/in/en/wide-leg-cargo-pants-p08197232.html',
      gender: 'Women',
      brand: 'Zara',
    ),
    ProductItem(
      id: 'p5',
      title: 'Zara Ribbed Midi Knit Dress',
      description: 'Sleeveless dress featuring a round neckline, premium ribbed texture, and side split.',
      price: '₹2,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=500',
      sku: 'SKU-ZR-DRES-05',
      productUrl: 'https://www.zara.com/in/en/ribbed-midi-knit-dress-p05039387.html',
      gender: 'Women',
      brand: 'Zara',
    ),
    ProductItem(
      id: 'p6',
      title: 'H&M Corduroy Utility Jacket',
      description: 'Regular-fit utility jacket in thick cotton corduroy with chest flap pockets.',
      price: '₹3,499 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=500',
      sku: 'SKU-HM-JKT-06',
      productUrl: 'https://www2.hm.com/en_in/productpage.1017137001.html',
      gender: 'Men',
      brand: 'H&M',
    ),
    ProductItem(
      id: 'p7',
      title: 'Zara Pleated Smart Trousers',
      description: 'Pleated trousers with a relaxed tapered leg and formal pressed creases.',
      price: '₹3,490 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=500',
      sku: 'SKU-ZR-TRSR-07',
      productUrl: 'https://www.zara.com/in/en/pleated-smart-trousers-p03057310.html',
      gender: 'Men',
      brand: 'Zara',
    ),
    ProductItem(
      id: 'p8',
      title: 'H&M Knit Crewneck Cardigan',
      description: 'Soft knit cardigan in premium cotton-viscose blend with button front closure.',
      price: '₹2,499 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=500',
      sku: 'SKU-HM-CARD-08',
      productUrl: 'https://www2.hm.com/en_in/productpage.1009140001.html',
      gender: 'Women',
      brand: 'H&M',
      category: 'upper_body',
    ),
    // ──────────────────────────────────────────────────────────────────────
    // Indian Saree Collection (uses specialized Saree Draping Pipeline)
    // ──────────────────────────────────────────────────────────────────────
    ProductItem(
      id: 'saree_01',
      title: 'Banarasi Silk Saree',
      description: 'Opulent Banarasi silk saree with zari weave border and rich pallu embellishment. A timeless heritage weave from Varanasi.',
      price: '₹12,500 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=500',
      sku: 'SKU-SAR-BAN-01',
      productUrl: 'https://www.nykaa.com/clothing/sarees/banarasi-silk-saree',
      gender: 'Women',
      brand: 'Heritage Weaves',
      category: 'saree',
      isSaree: true,
      renderTier: '2d',
    ),
    ProductItem(
      id: 'saree_02',
      title: 'Kanjeevaram Silk Saree',
      description: 'Pure Kanjivaram silk saree with temple border motifs and heavy zari pallu. A South Indian bridal classic.',
      price: '₹18,990 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=500',
      sku: 'SKU-SAR-KAN-02',
      productUrl: 'https://www.myntra.com/sarees?rawQuery=kanjeevaram+silk+saree',
      gender: 'Women',
      brand: 'Kanjivaram House',
      category: 'saree',
      isSaree: true,
      renderTier: '2d',
    ),
    ProductItem(
      id: 'saree_03',
      title: 'Bandhani Tie-Dye Saree',
      description: 'Vibrant Rajasthani Bandhani saree with traditional tie-dye dots in rich sunset colors. Pure georgette fabric.',
      price: '₹4,299 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1617897903246-719242758050?w=500',
      sku: 'SKU-SAR-BDH-03',
      productUrl: 'https://www.myntra.com/sarees?rawQuery=bandhani+saree',
      gender: 'Women',
      brand: 'Rajputana Craft',
      category: 'saree',
      isSaree: true,
      renderTier: '2d',
    ),
    ProductItem(
      id: 'saree_04',
      title: 'Chiffon Georgette Saree',
      description: 'Lightweight chiffon georgette saree with delicate printed border, perfect for casual and semi-formal occasions.',
      price: '₹2,799 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=500',
      sku: 'SKU-SAR-CHF-04',
      productUrl: 'https://www.myntra.com/sarees?rawQuery=chiffon+georgette+saree',
      gender: 'Women',
      brand: 'Elegant Drapes',
      category: 'saree',
      isSaree: true,
      renderTier: '2d',
    ),
    // ──────────────────────────────────────────────────────────────────────
    // Elite 3D Mesh Rendering Collection (Bridal, Heavy Silks, Fusion)
    // ──────────────────────────────────────────────────────────────────────
    ProductItem(
      id: 'elite_lehenga_01',
      title: 'Sabyasachi Bridal Lehenga',
      description: 'Elite hand-embroidered velvet bridal lehenga with complex zardozi borders and dynamic silk draping. Built for 3D render mapping.',
      price: '₹2,50,000 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=500',
      sku: 'SKU-SAR-LEH-01',
      productUrl: 'https://www.sabyasachi.com/',
      gender: 'Women',
      brand: 'Sabyasachi Heritage',
      category: 'bridal_lehenga',
      isSaree: false,
      renderTier: '3d',
    ),
    ProductItem(
      id: 'elite_kanjeevaram_01',
      title: 'Varnam Heavy Kanjivaram',
      description: 'Pure Kanjeevaram silk saree with intricate gold tissue zari border and heavy pallu. Rendered dynamically via 3D mesh mapping.',
      price: '₹85,000 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=500',
      sku: 'SKU-SAR-KAN-03',
      productUrl: 'https://www.myntra.com/sarees?rawQuery=kanjeevaram+heavy+zari',
      gender: 'Women',
      brand: 'Varnam Silk House',
      category: 'kanjeevaram_heavy',
      isSaree: true,
      renderTier: '3d',
    ),
    ProductItem(
      id: 'elite_fusion_01',
      title: 'Anamika Khanna Fusion Set',
      description: 'Contemporary drape saree with a structured jacket and embroidered trousers. A high-complexity fusion silhouette.',
      price: '₹95,000 / unit',
      imageUrl: 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=500',
      sku: 'SKU-SAR-FUS-01',
      productUrl: 'https://www.anamikakhanna.in/',
      gender: 'Women',
      brand: 'Anamika Couture',
      category: 'fusion_ethnic',
      isSaree: true,
      renderTier: '3d',
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
          p.title.contains('Hub') ||
          !p.toMap().containsKey('gender') ||
          !p.toMap().containsKey('renderTier')
        ) || !list.any((p) => p.id == 'elite_lehenga_01');
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
  Future<List<ProductItem>> getCatalogProductsPaged({
    required int page,
    required int limit,
    String? gender,
    String? brand,
    String? search,
  }) async {
    List<ProductItem> allProducts = [];
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
        allProducts = querySnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList();
        
        // Re-seed self-healing if needed
        final hasOldMockData = allProducts.any((p) => 
          p.title.contains('Pen') || 
          p.title.contains('Duffel') || 
          p.title.contains('Hub') ||
          !p.toMap().containsKey('gender') ||
          !p.toMap().containsKey('renderTier')
        ) || !allProducts.any((p) => p.id == 'elite_lehenga_01');
        if (hasOldMockData) {
          await forceReSeedProducts();
          final seededSnapshot = await collection.get();
          allProducts.clear();
          allProducts.addAll(seededSnapshot.docs.map((doc) => ProductItem.fromMap(doc.data(), doc.id)).toList());
        }
      } catch (e) {
        debugPrint('Firestore fetch paged error: $e. Falling back to mock pagination.');
        allProducts = List.from(_mockProducts);
      }
    } else {
      allProducts = List.from(_mockProducts);
    }

    // Apply filtering
    if (gender != null && gender.isNotEmpty) {
      allProducts = allProducts.where((p) => p.gender.toLowerCase() == gender.toLowerCase()).toList();
    }
    if (brand != null && brand.isNotEmpty && brand != 'All') {
      allProducts = allProducts.where((p) => p.brand.toLowerCase() == brand.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      allProducts = allProducts.where((p) => 
        p.title.toLowerCase().contains(search.toLowerCase()) || 
        p.description.toLowerCase().contains(search.toLowerCase()) ||
        p.brand.toLowerCase().contains(search.toLowerCase())
      ).toList();
    }

    final startIndex = (page - 1) * limit;
    if (startIndex >= allProducts.length) {
      return _generateInfiniteProducts(page, limit, gender: gender, brand: brand);
    }
    
    final endIndex = startIndex + limit;
    final pageProducts = allProducts.sublist(
      startIndex, 
      endIndex > allProducts.length ? allProducts.length : endIndex
    );
    
    // Dynamic infinite padding
    if (pageProducts.length < limit) {
      final needed = limit - pageProducts.length;
      final extra = _generateInfiniteProducts(page, needed, gender: gender, brand: brand);
      pageProducts.addAll(extra);
    }
    
    return pageProducts;
  }

  // Generates infinite clothing items from Zara/H&M with different styles/Unsplash images
  List<ProductItem> _generateInfiniteProducts(int page, int count, {String? gender, String? brand}) {
    final List<ProductItem> list = [];
    final items = [
      {
        'title': 'Cotton Cable-Knit Cardigan',
        'desc': 'Relaxed-fit cardigan in soft organic cotton knit with ribbing.',
        'price': '₹2,799',
        'img': 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=500',
        'gender': 'Women',
        'brand': 'H&M',
        'url': 'https://www2.hm.com/en_in/productpage.1009140001.html',
      },
      {
        'title': 'Pleated Summer Gown',
        'desc': 'Floaty pleated dress with spaghetti straps and floral lace back.',
        'price': '₹3,499',
        'img': 'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=500',
        'gender': 'Women',
        'brand': 'Zara',
        'url': 'https://www.zara.com/in/en/ribbed-midi-knit-dress-p05039387.html',
      },
      {
        'title': 'Casual Linen Drawstring Trouser',
        'desc': 'Relaxed-fit linen-cotton blend trousers with adjustable elastic waist.',
        'price': '₹2,999',
        'img': 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=500',
        'gender': 'Men',
        'brand': 'Zara',
        'url': 'https://www.zara.com/in/en/pleated-smart-trousers-p03057310.html',
      },
      {
        'title': 'Tailored Blazer',
        'desc': 'Single-breasted blazer in structured weave with flap pockets.',
        'price': '₹6,990',
        'img': 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=500',
        'gender': 'Men',
        'brand': 'Zara',
        'url': 'https://www.zara.com/in/en/linen-blend-blazer-p02753043.html',
      },
      {
        'title': 'Denim Sherpa Jacket',
        'desc': 'Washed denim jacket lined with soft faux sherpa wool collar.',
        'price': '₹4,990',
        'img': 'https://images.unsplash.com/photo-1611312449412-6cefac5dc3e4?w=500',
        'gender': 'Men',
        'brand': 'H&M',
        'url': 'https://www2.hm.com/en_in/productpage.1017137001.html',
      },
      {
        'title': 'Viscose Blend Mock-neck Sweater',
        'desc': 'Soft mock-neck knit sweater in premium sustainable viscose yarn.',
        'price': '₹1,599',
        'img': 'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=500',
        'gender': 'Women',
        'brand': 'H&M',
        'url': 'https://www2.hm.com/en_in/productpage.0970818001.html',
      },
    ];

    int itemsAdded = 0;
    int index = 0;
    while (itemsAdded < count) {
      final idx = (page * count + index) % items.length;
      final item = items[idx];
      final itemGender = item['gender'] as String;
      final itemBrand = item['brand'] as String;

      // Filter matches
      bool genderMatch = (gender == null || gender.isEmpty || gender.toLowerCase() == itemGender.toLowerCase());
      bool brandMatch = (brand == null || brand.isEmpty || brand == 'All' || brand.toLowerCase() == itemBrand.toLowerCase());

      if (genderMatch && brandMatch) {
        list.add(ProductItem(
          id: 'gen_p_${page}_${index}_$itemsAdded',
          title: '$itemBrand ${item['title']}',
          description: '${item['desc']} Premium selection.',
          price: '${item['price']} / unit',
          imageUrl: item['img'] as String,
          sku: 'SKU-GEN-$page-$index-$itemsAdded',
          productUrl: item['url'] as String,
          gender: itemGender,
          brand: itemBrand,
        ));
        itemsAdded++;
      }
      index++;
      // Safety breakout
      if (index > 100) {
        list.add(ProductItem(
          id: 'gen_p_fallback_${page}_$itemsAdded',
          title: '${brand ?? "Zara"} Fallback Item',
          description: 'High-quality cotton garment.',
          price: '₹2,499 / unit',
          imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=500',
          sku: 'SKU-GEN-FALLBACK-$page-$itemsAdded',
          productUrl: 'https://www.zara.com/in/',
          gender: gender ?? 'Men',
          brand: brand ?? 'Zara',
        ));
        itemsAdded++;
      }
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
