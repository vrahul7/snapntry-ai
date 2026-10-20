import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme.dart';
import '../../../services/try_on_provider.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/app_network_image.dart';

/// Component for picking an apparel item from presets or uploading a custom garment.
class TryOnApparelPicker extends StatefulWidget {
  const TryOnApparelPicker({super.key});

  @override
  State<TryOnApparelPicker> createState() => _TryOnApparelPickerState();
}

class _TryOnApparelPickerState extends State<TryOnApparelPicker> {
  String _selectedFilter = 'All'; // 'All' | 'upper_body' | 'lower_body' | 'one_piece' | 'saree' | '3d'

  Future<void> _pickApparelImage(BuildContext context, ImageSource source) async {
    final provider = context.read<TryOnProvider>();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;
      if (!context.mounted) return;
      final String? selectedCategory = await _showCategorySelectionDialog(context);
      if (selectedCategory == null) return;

      provider.setProcessing(true);

      String apparelImageUrl;
      if (StorageService().isFirebaseEnabled) {
        apparelImageUrl = await StorageService().uploadUserPhoto(image);
      } else {
        apparelImageUrl = image.path;
      }

      provider.setCustomApparel(
        title: source == ImageSource.camera ? 'Camera Apparel' : 'Gallery Apparel',
        image: apparelImageUrl,
        category: selectedCategory,
      );
      provider.setProcessing(false);
    } catch (e) {
      provider.setProcessing(false);
      if (context.mounted) {
        AppTheme.showErrorSnackbar(context, 'Error selecting apparel: $e');
      }
    }
  }

  Future<String?> _showCategorySelectionDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          title: const Text(
            'Select Apparel Type',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help the AI understand where to fit this garment.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildCategoryOption(ctx, 'Tops / Shirts / Jackets', 'upper_body'),
              const SizedBox(height: 8),
              _buildCategoryOption(ctx, 'Pants / Shorts / Skirts', 'lower_body'),
              const SizedBox(height: 8),
              _buildCategoryOption(ctx, 'Dresses / One-Pieces', 'one_piece'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D1259),
                    side: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, 'saree'),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🥻 ', style: TextStyle(fontSize: 16)),
                      Text(
                        'Indian Saree',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryOption(BuildContext context, String title, String categoryValue) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkBg,
          side: const BorderSide(color: AppTheme.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
        onPressed: () => Navigator.pop(context, categoryValue),
        child: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TryOnProvider>();
    final apparelList = provider.apparelList;
    final selectedImage = provider.selectedApparelImage;

    final filteredList = apparelList.where((item) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == '3d') return item['renderTier'] == '3d';
      return item['category'] == _selectedFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GARMENT / APPAREL CATALOG',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => _pickApparelImage(context, ImageSource.gallery),
                child: const Row(
                  children: [
                    Icon(Icons.upload_file_rounded, color: AppTheme.primaryNeon, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Upload Garment',
                      style: TextStyle(
                        color: AppTheme.primaryNeon,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All'),
                _buildFilterChip('Tops', 'upper_body'),
                _buildFilterChip('Bottoms', 'lower_body'),
                _buildFilterChip('Dresses', 'one_piece'),
                _buildFilterChip('Sarees 🥻', 'saree'),
                _buildFilterChip('3D Elite 👑', '3d'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Garment horizontal scroll list
          SizedBox(
            height: 115,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final item = filteredList[index];
                final isSelected = selectedImage == item['image'];
                final is3D = item['renderTier'] == '3d';
                final isSaree = item['category'] == 'saree';

                return GestureDetector(
                  onTap: () => provider.selectApparel(
                    title: item['title']!,
                    image: item['image']!,
                    category: item['category']!,
                    renderTier: item['renderTier'] ?? '2d',
                  ),
                  child: Container(
                    width: 82,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: isSelected
                            ? (is3D ? const Color(0xFFE040FB) : AppTheme.primaryNeon)
                            : AppTheme.glassBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(
                          imageUrl: item['image'],
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium - 1),
                        ),
                        if (is3D)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3D1259),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('3D', style: TextStyle(color: Color(0xFFE040FB), fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          )
                        else if (isSaree)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('SAREE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: is3D ? const Color(0xFFE040FB) : AppTheme.primaryNeon,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 10, color: Colors.white),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(AppTheme.radiusMedium - 1),
                              ),
                            ),
                            child: Text(
                              item['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNeon.withValues(alpha: 0.2) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
