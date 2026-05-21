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
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Return elegant catalog items for our B2B catalog UI
  Future<List<ProductItem>> getCatalogProducts() async {
    await Future.delayed(const Duration(milliseconds: 800)); // Network simulation
    return [
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
  }
}
