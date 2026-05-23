import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../config/theme.dart';
import '../../services/try_on_state.dart';

/// Visual Search Screen — lets users snap or upload a clothing photo to search
/// the catalog using Gemini Vision via the `searchCatalogByImage` Cloud Function.
class VisualSearchScreen extends StatefulWidget {
  const VisualSearchScreen({super.key});

  @override
  State<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends State<VisualSearchScreen>
    with SingleTickerProviderStateMixin {
  XFile? _selectedImage;
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _garmentInfo;
  List<String> _keywords = [];
  String? _errorText;
  bool _hasSearched = false;

  // Pulsing animation for drop zone
  late final AnimationController _pulseController;
  late final Animation<double> _pulseBorder;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseBorder = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _results = [];
          _garmentInfo = null;
          _keywords = [];
          _hasSearched = false;
          _errorText = null;
        });
        // Auto-search on pick
        await _runVisualSearch(image);
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _runVisualSearch(XFile image) async {
    setState(() {
      _isSearching = true;
      _errorText = null;
    });

    try {
      // Encode image to base64
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('searchCatalogByImage');
      final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'snapBase64': base64Str,
      });

      final data = result.data;
      final rawProducts = data['products'] as List<dynamic>? ?? [];
      final rawKeywords = data['keywords'] as List<dynamic>? ?? [];
      final rawGarmentInfo = data['garmentInfo'] as Map<dynamic, dynamic>?;

      if (mounted) {
        setState(() {
          _results = rawProducts
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          _keywords = rawKeywords.cast<String>();
          _garmentInfo = rawGarmentInfo != null
              ? Map<String, dynamic>.from(rawGarmentInfo)
              : null;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      debugPrint('Visual search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _errorText = 'Visual search unavailable. Please check connectivity.';
        });
      }
    }
  }

  void _tryOnProduct(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Product';
    final imageUrl = product['imageUrl'] as String? ?? '';
    final category = product['category'] as String? ?? 'upper_body';

    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product image not available for try-on.')),
      );
      return;
    }

    TryOnState.pendingTryOnNotifier.value = {
      'title': name,
      'image': imageUrl,
      'category': category,
    };

    Navigator.pop(context); // Close visual search screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Loading $name in AI Try-On Studio…'),
          ],
        ),
        backgroundColor: const Color(0xFF2A1A4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.instagramGradient.createShader(bounds),
          child: const Text(
            'Visual Search',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryNeon, size: 18),
            label: const Text(
              'Camera',
              style: TextStyle(color: AppTheme.primaryNeon, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload zone / preview
            _buildImageUploadZone(),
            const SizedBox(height: 8),

            // AI garment detection info
            if (_garmentInfo != null) _buildGarmentInfoChip(),

            // Keywords pill row
            if (_keywords.isNotEmpty) _buildKeywordPills(),

            // Results or state
            if (_isSearching)
              _buildSearchingState()
            else if (_hasSearched && _errorText != null)
              _buildErrorState()
            else if (_hasSearched && _results.isEmpty)
              _buildNoResultsState()
            else if (_results.isNotEmpty)
              _buildResultsGrid(),

            // Bottom padding for nav bar
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadZone() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      child: _selectedImage == null
          ? _buildDropZone()
          : _buildImagePreview(),
    );
  }

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: AnimatedBuilder(
        animation: _pulseBorder,
        builder: (context, child) => Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryNeon.withValues(alpha: _pulseBorder.value),
              width: 1.5,
            ),
          ),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.image_search_rounded,
                  color: AppTheme.primaryNeon,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Snap or upload a garment photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI will identify the item and find matches in the catalog',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPickButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 16),
                  _buildPickButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryNeon.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryNeon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: kIsWeb
              ? Image.network(
                  _selectedImage!.path,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(_selectedImage!.path),
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
        // Overlay with change option
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text('Change', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        // Scanning badge overlay when searching
        if (_isSearching)
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.55),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryNeon, strokeWidth: 2.5),
                  SizedBox(height: 14),
                  Text(
                    'Gemini is identifying the garment…',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Searching catalog for matches',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGarmentInfoChip() {
    final desc = _garmentInfo!['description'] as String? ?? '';
    final style = _garmentInfo!['style'] as String? ?? '';
    final color = _garmentInfo!['primaryColor'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryNeon.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryNeon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Detected', style: TextStyle(color: AppTheme.primaryNeon, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  if (desc.isNotEmpty)
                    Text(desc, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (color.isNotEmpty || style.isNotEmpty)
                    Text(
                      [if (color.isNotEmpty) color, if (style.isNotEmpty) style].join(' · '),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _keywords.take(8).map((kw) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Text(
            '#$kw',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSearchingState() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryNeon),
            SizedBox(height: 16),
            Text('Searching catalog…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No catalog matches found',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different photo or browse the catalog manually.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.instagramGradient,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Try Another Photo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CATALOG MATCHES',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_results.length} found',
                  style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final product = _results[index];
              return _buildResultCard(product);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Product';
    final imageUrl = product['imageUrl'] as String? ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final currency = product['currency'] as String? ?? 'INR';
    final priceStr = price > 0 ? '₹${price.toStringAsFixed(0)}' : currency;

    return GestureDetector(
      onTap: () => _tryOnProduct(product),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, e, s) => Container(
                          color: AppTheme.darkBg,
                          child: const Icon(Icons.image_not_supported_rounded,
                              color: AppTheme.textSecondary, size: 36),
                        ),
                      )
                    : Container(
                        color: AppTheme.darkBg,
                        child: const Icon(Icons.checkroom_rounded,
                            color: AppTheme.textSecondary, size: 36),
                      ),
              ),
            ),
            // Info + button
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(priceStr, style: const TextStyle(color: AppTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.instagramGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Try On',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
