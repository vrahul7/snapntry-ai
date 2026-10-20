/// Domain model representing a product in the SnapnTry AI catalog.
class ProductItem {
  final String id;
  final String title;
  final String description;
  final String price;
  final String imageUrl;
  final String sku;
  final String productUrl;
  final String gender;
  final String brand;
  final String category; // 'upper_body' | 'lower_body' | 'one_piece' | 'saree' | 'bridal_lehenga' | 'kanjeevaram_heavy' | 'fusion_ethnic'
  final bool isSaree;
  final String renderTier; // '2d' | '3d'

  const ProductItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sku,
    required this.productUrl,
    required this.gender,
    required this.brand,
    this.category = 'upper_body',
    this.isSaree = false,
    this.renderTier = '2d',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'sku': sku,
      'productUrl': productUrl,
      'gender': gender,
      'brand': brand,
      'category': category,
      'isSaree': isSaree,
      'renderTier': renderTier,
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
      productUrl: map['productUrl'] ?? 'https://www.zara.com/in/',
      gender: map['gender'] ?? 'Men',
      brand: map['brand'] ?? 'Zara',
      category: map['category'] ?? 'upper_body',
      isSaree: map['isSaree'] == true,
      renderTier: map['renderTier'] ?? '2d',
    );
  }

  ProductItem copyWith({
    String? id,
    String? title,
    String? description,
    String? price,
    String? imageUrl,
    String? sku,
    String? productUrl,
    String? gender,
    String? brand,
    String? category,
    bool? isSaree,
    String? renderTier,
  }) {
    return ProductItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      productUrl: productUrl ?? this.productUrl,
      gender: gender ?? this.gender,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      isSaree: isSaree ?? this.isSaree,
      renderTier: renderTier ?? this.renderTier,
    );
  }
}
