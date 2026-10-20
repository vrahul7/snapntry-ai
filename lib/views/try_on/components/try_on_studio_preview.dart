import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../services/try_on_provider.dart';
import '../../../widgets/app_network_image.dart';
import 'try_on_loading_overlay.dart';

/// Main studio preview card displaying input garment/model or the generated AI result.
class TryOnStudioPreview extends StatefulWidget {
  final AnimationController revealController;
  final AnimationController pulseController;
  final VoidCallback onTriggerTryOn;

  const TryOnStudioPreview({
    super.key,
    required this.revealController,
    required this.pulseController,
    required this.onTriggerTryOn,
  });

  @override
  State<TryOnStudioPreview> createState() => _TryOnStudioPreviewState();
}

class _TryOnStudioPreviewState extends State<TryOnStudioPreview> {
  bool _showComparison = false;

  void _openFullscreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: AppNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
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
    final isProcessing = provider.isProcessing || provider.is3DProcessing;
    final resultUrl = provider.generatedImageUrl;
    final is3D = provider.selectedRenderTier == '3d';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
        border: Border.all(
          color: is3D ? const Color(0xFFE040FB).withValues(alpha: 0.4) : AppTheme.glassBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Visual Canvas Box
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSheet - 1),
            child: SizedBox(
              height: 380,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (resultUrl != null && !isProcessing)
                    _buildResultView(context, provider, resultUrl)
                  else if (isProcessing)
                    TryOnLoadingOverlay(
                      category: provider.selectedApparelCategory,
                      tier: provider.selectedRenderTier,
                      pulseAnimation: widget.pulseController,
                      is3DProcessing: provider.is3DProcessing,
                      active3DJobId: provider.active3DJobId,
                    )
                  else
                    _buildIdleInputView(provider),
                ],
              ),
            ),
          ),

          // Primary Trigger CTA Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isProcessing ? null : widget.onTriggerTryOn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: is3D
                        ? const LinearGradient(
                            colors: [Color(0xFF8E24AA), Color(0xFFD81B60), Color(0xFFFF8F00)],
                          )
                        : AppTheme.instagramGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          is3D ? Icons.view_in_ar_rounded : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          resultUrl != null
                              ? 'Regenerate Try-On'
                              : (is3D ? 'Render 3D Elite Model' : 'Generate AI Try-On'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, TryOnProvider provider, String resultUrl) {
    final fadeAnimation = CurvedAnimation(
      parent: widget.revealController,
      curve: Curves.easeOut,
    );
    final scaleAnimation = Tween<double>(begin: 1.04, end: 1.0).animate(
      CurvedAnimation(parent: widget.revealController, curve: Curves.easeOutBack),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_showComparison)
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(imageUrl: provider.selectedModelImage),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('BEFORE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 2, color: AppTheme.primaryNeon),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(imageUrl: resultUrl),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('AFTER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              AppNetworkImage(
                imageUrl: resultUrl,
                fit: BoxFit.cover,
              ),

            // Top Control Bar
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showComparison = !_showComparison),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showComparison ? Icons.view_carousel_rounded : Icons.compare_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showComparison ? 'Single' : 'Compare',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openFullscreen(context, resultUrl),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Style Badge
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  '${provider.selectedApparelTitle} • ${provider.selectedBackgroundStyle.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleInputView(TryOnProvider provider) {
    return Container(
      color: AppTheme.darkBg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(imageUrl: provider.selectedModelImage),
                    Container(color: Colors.black.withValues(alpha: 0.3)),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider.selectedModelTitle.isNotEmpty
                              ? provider.selectedModelTitle
                              : 'Select Model',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 2, color: AppTheme.glassBorder),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(imageUrl: provider.selectedApparelImage),
                    Container(color: Colors.black.withValues(alpha: 0.3)),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider.selectedApparelTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Central Plus Glow Ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.instagramGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
