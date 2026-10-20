import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../services/try_on_provider.dart';

/// Selector component for choosing the virtual scene environment (Vertex AI Imagen background).
class TryOnBackgroundSelector extends StatelessWidget {
  const TryOnBackgroundSelector({super.key});

  static const List<Map<String, dynamic>> backgroundStyles = [
    {'id': 'studio', 'name': 'Modern Studio', 'icon': Icons.camera_rounded},
    {'id': 'boutique', 'name': 'Luxury Boutique', 'icon': Icons.storefront_rounded},
    {'id': 'palace', 'name': 'Royal Palace Hall', 'icon': Icons.location_city_rounded},
    {'id': 'courtyard', 'name': 'Heritage Courtyard', 'icon': Icons.nature_people_rounded},
    {'id': 'showroom', 'name': 'Boutique Interior', 'icon': Icons.lightbulb_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TryOnProvider>();
    final selectedStyle = provider.selectedBackgroundStyle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT TRY-ON BACKGROUND',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: backgroundStyles.length,
              itemBuilder: (context, index) {
                final item = backgroundStyles[index];
                final isSelected = selectedStyle == item['id'];
                return GestureDetector(
                  onTap: () => provider.setBackgroundStyle(item['id'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryNeon.withValues(alpha: 0.15)
                          : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected ? AppTheme.primaryNeon : Colors.white60,
                          size: 18,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
