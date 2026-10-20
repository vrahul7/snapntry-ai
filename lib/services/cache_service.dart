import 'package:hive_flutter/hive_flutter.dart';
import 'firestore_service.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Box? _feedBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _feedBox = await Hive.openBox('product_feed');
  }

  Future<void> cacheProducts(List<ProductItem> products) async {
    if (_feedBox == null) return;
    
    // Clear previous cache and store serialized lists
    await _feedBox!.clear();
    final serialized = products.map((p) => {
      'id': p.id,
      'title': p.title,
      'description': p.description,
      'price': p.price,
      'imageUrl': p.imageUrl,
      'sku': p.sku,
      'productUrl': p.productUrl,
      'gender': p.gender,
      'brand': p.brand,
    }).toList();
    
    await _feedBox!.put('cached_catalog', serialized);
  }

  List<ProductItem> getCachedProducts() {
    if (_feedBox == null) return [];
    
    final List<dynamic>? rawList = _feedBox!.get('cached_catalog');
    if (rawList == null) return [];
    
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item);
      return ProductItem(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        price: map['price'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        sku: map['sku'] ?? '',
        productUrl: map['productUrl'] ?? '',
        gender: map['gender'] ?? '',
        brand: map['brand'] ?? '',
      );
    }).toList();
  }
}
