import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../services/try_on_provider.dart';

/// Selector component for switching between standard 2D TPS Warping and Asynchronous 3D Mesh Photography.
class TryOnTierSelector extends StatelessWidget {
  const TryOnTierSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TryOnProvider>();
    final selectedTier = provider.selectedRenderTier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RENDERING TIER',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (selectedTier == '3d')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D1259),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE040FB), width: 0.8),
                  ),
                  child: const Text(
                    'ELITE 3D ACTIVE',
                    style: TextStyle(
                      color: Color(0xFFE040FB),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => provider.setRenderTier('2d'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedTier == '2d' ? AppTheme.darkBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '2D TPS Warp',
                        style: TextStyle(
                          color: selectedTier == '2d' ? AppTheme.primaryNeon : AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => provider.setRenderTier('3d'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedTier == '3d' ? const Color(0xFF3D1259) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: selectedTier == '3d'
                            ? Border.all(color: const Color(0xFFE040FB), width: 1)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('👑 ', style: TextStyle(fontSize: 11)),
                          Text(
                            '3D Mesh Render',
                            style: TextStyle(
                              color: selectedTier == '3d' ? const Color(0xFFE040FB) : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
