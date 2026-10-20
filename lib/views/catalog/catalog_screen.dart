import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';
import '../../services/try_on_state.dart';
import '../../services/wishlist_service.dart';
import 'visual_search_delegate.dart';
import '../../widgets/app_network_image.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _firestoreService = FirestoreService();
  final _wishlistService = WishlistService();
  final List<ProductItem> _products = [];
  
  // State for filtering
  String _selectedGender = 'Men'; // Default to Men
  String _selectedBrand = 'All'; // Brand filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  // Predefined brand lists
  final List<String> _menBrands = ['All', 'Zara', 'H&M', 'Tommy Hilfiger', 'Calvin Klein', 'Nike'];
  final List<String> _womenBrands = ['All', 'Zara', 'H&M', 'Vero Moda', 'Mango', 'Chanel'];

  // Suggestions list
  final List<Map<String, String>> _menSuggestions = [
    {'name': 'Blazers', 'query': 'Blazer', 'img': 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=150'},
    {'name': 'Hoodies', 'query': 'Hoodie', 'img': 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=150'},
    {'name': 'Shirts', 'query': 'Shirt', 'img': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=150'},
    {'name': 'Trousers', 'query': 'Trousers', 'img': 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=150'},
  ];

  final List<Map<String, String>> _womenSuggestions = [
    {'name': 'Dresses', 'query': 'Dress', 'img': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=150'},
    {'name': 'Gowns', 'query': 'Gown', 'img': 'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=150'},
    {'name': 'Cardigans', 'query': 'Cardigan', 'img': 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=150'},
    {'name': 'Cargo Pants', 'query': 'Cargo', 'img': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=150'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _resetAndLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _products.clear();
      _currentPage = 1;
      _hasMore = true;
      _isLoading = false;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final newProducts = await _firestoreService.getCatalogProductsPaged(
        page: _currentPage,
        limit: 4,
        gender: _selectedGender,
        brand: _selectedBrand,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _currentPage++;
          if (newProducts.length < 4) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchProductInApp(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      if (!launched) {
        throw 'Webview failed';
      }
    } catch (e) {
      debugPrint('In-app browser failed, falling back: $e');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open page: $urlString'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBrands = _selectedGender == 'Men' ? _menBrands : _womenBrands;
    final activeSuggestions = _selectedGender == 'Men' ? _menSuggestions : _womenSuggestions;

    return Scaffold(
      body: Column(
        children: [
          // 1. Search Bar Button Header (Myntra-style)
          _buildSearchHeader(),

          // 2. Gender Category Switcher (Men / Women)
          _buildGenderSelector(),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Horizontal Brands Scroller
                  _buildBrandScroller(activeBrands),

                  // 4. Suggestions / Category Bubbles
                  _buildSuggestionsHeader(),
                  _buildSuggestionsScroller(activeSuggestions),

                  // 5. Explore More / Product Feed
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text(
                      'EXPLORE MORE FOR YOU',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  _buildProductGrid(),

                  if (_isLoading && _products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon)),
                    ),

                  if (!_hasMore && _products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'You\'ve viewed all available recommendations.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 120), // Spacing to avoid bottom bar overlap
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: AppTheme.primaryNeon,
                decoration: InputDecoration(
                  hintText: 'Search brand, fit, style or outfit...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                            _resetAndLoad();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                  _resetAndLoad();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisualSearchScreen(),
                ),
              );
            },
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.primaryNeon,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildGenderTab('Men'),
            ),
            Expanded(
              child: _buildGenderTab('Women'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderTab(String gender) {
    final isActive = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        if (_selectedGender != gender) {
          setState(() {
            _selectedGender = gender;
            _selectedBrand = 'All';
          });
          _resetAndLoad();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.darkBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$gender Apparel',
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandScroller(List<String> brands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'FEATURED BRANDS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brandName = brands[index];
              final isSelected = _selectedBrand == brandName;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(brandName),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryNeon.withValues(alpha: 0.15),
                  backgroundColor: AppTheme.darkCard,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryNeon : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
                      width: 1,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedBrand = brandName;
                      });
                      _resetAndLoad();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        'TRENDING CATEGORIES',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSuggestionsScroller(List<Map<String, String>> suggestions) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final item = suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _searchController.text = item['query']!;
                  _searchQuery = item['query']!;
                });
                _resetAndLoad();
              },
              child: Column(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                    ),
                    child: ClipOval(
                      child: AppNetworkImage(
                        imageUrl: item['img'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['name']!,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No matching products found.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.52, // Elongated card layout
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final isSaved = _wishlistService.isWishlisted(product.id);

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    // Wishlist Heart Button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          final added = await _wishlistService.toggle(
                            productId: product.id,
                            title: product.title,
                            imageUrl: product.imageUrl,
                            price: product.price,
                            sku: product.sku,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? '${product.title} saved!'
                                      : '${product.title} removed from wishlist.',
                                ),
                                backgroundColor: AppTheme.darkCard,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            setState(() {}); // Rebuild
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSaved ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            color: isSaved ? Colors.redAccent : Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Brand Tag
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.brand.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.secondaryNeon,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title and details
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  product.price.split(' /').first, // short price
                  style: const TextStyle(
                    color: Color(0xFF7EB8FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                child: Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),

              // Try-On & Redirect buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          TryOnState.selectProductForTryOn(product.title, product.imageUrl);
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 12),
                        label: const Text('Try-On Fit', style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primaryNeon.withValues(alpha: 0.5)),
                          foregroundColor: AppTheme.primaryNeon,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchProductInApp(product.productUrl),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.black),
                        label: const Text('Sample Order', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryNeon,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
