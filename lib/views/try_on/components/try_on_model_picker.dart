import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme.dart';
import '../../../services/try_on_provider.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/app_network_image.dart';

/// Component for selecting the model photo or uploading a custom user photo.
class TryOnModelPicker extends StatelessWidget {
  const TryOnModelPicker({super.key});

  Future<void> _pickModelImage(BuildContext context, ImageSource source) async {
    final provider = context.read<TryOnProvider>();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      provider.setProcessing(true);

      String modelImageUrl;
      if (StorageService().isFirebaseEnabled) {
        modelImageUrl = await StorageService().uploadUserPhoto(image);
      } else {
        modelImageUrl = image.path;
      }

      provider.setCustomModel(
        title: source == ImageSource.camera ? 'Camera Photo' : 'Gallery Photo',
        image: modelImageUrl,
      );
      provider.setProcessing(false);
    } catch (e) {
      provider.setProcessing(false);
      if (context.mounted) {
        AppTheme.showErrorSnackbar(context, 'Error selecting image: $e');
      }
    }
  }

  void _showModelSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Upload Target Photo',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a full body or waist-up portrait in good lighting.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton(
                      context: ctx,
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Selfie',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickModelImage(context, ImageSource.camera);
                      },
                    ),
                    _buildOptionButton(
                      context: ctx,
                      icon: Icons.photo_library_rounded,
                      label: 'From Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickModelImage(context, ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryNeon, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TryOnProvider>();
    final modelList = provider.modelList;
    final selectedImage = provider.selectedModelImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TARGET MODEL / PHOTO',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => _showModelSourceBottomSheet(context),
                child: const Row(
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryNeon, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Upload Custom',
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
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: modelList.length,
              itemBuilder: (context, index) {
                final model = modelList[index];
                final isSelected = selectedImage == model['image'];

                return GestureDetector(
                  onTap: () => provider.selectModel(
                    title: model['title']!,
                    image: model['image']!,
                  ),
                  child: Container(
                    width: 74,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(
                          imageUrl: model['image'],
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium - 1),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryNeon,
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
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(AppTheme.radiusMedium - 1),
                              ),
                            ),
                            child: Text(
                              model['title']!,
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
}
