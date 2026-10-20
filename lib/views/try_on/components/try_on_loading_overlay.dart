import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme.dart';

/// Loading overlay widget displaying an animated pulsating glow ring and contextual messages.
class TryOnLoadingOverlay extends StatelessWidget {
  final String category;
  final String tier;
  final Animation<double> pulseAnimation;
  final bool is3DProcessing;
  final String? active3DJobId;

  const TryOnLoadingOverlay({
    super.key,
    required this.category,
    required this.tier,
    required this.pulseAnimation,
    this.is3DProcessing = false,
    this.active3DJobId,
  });

  @override
  Widget build(BuildContext context) {
    if (is3DProcessing && active3DJobId != null) {
      return _build3DStreamOverlay();
    }

    final isSaree = category == 'saree';
    final is3D = tier == '3d';

    final Color glowColor = isSaree
        ? const Color(0xFFE040FB)
        : is3D
            ? const Color(0xFF9C27B0)
            : AppTheme.primaryNeon;

    final String emoji = isSaree ? '🥻' : is3D ? '👑' : '✨';

    final List<String> messages = isSaree
        ? [
            'Detecting saree regions via AI…',
            'Segmenting blouse, pallu, drape…',
            'Mapping regions to body keypoints…',
            'Compositing Nivi draping style…',
            'Applying post-processing…',
          ]
        : is3D
            ? [
                'Initializing 3D mesh model…',
                'Mapping UV texture coordinates…',
                'Blender cycles rendering…',
                'Capturing multi-angle frames…',
                'Applying Vertex AI Imagen…',
              ]
            : [
                'Analyzing garment structure…',
                'Running VTON warping pipeline…',
                'Fitting to body proportions…',
                'Applying Imagen post-processing…',
                'Almost done…',
              ];

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                glowColor.withValues(alpha: 0.10 * pulseAnimation.value),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80 * pulseAnimation.value,
                        height: 80 * pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: glowColor.withValues(alpha: 0.3 * pulseAnimation.value),
                            width: 2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: glowColor,
                          backgroundColor: glowColor.withValues(alpha: 0.12),
                        ),
                      ),
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  messages[DateTime.now().second % messages.length],
                  style: TextStyle(
                    color: glowColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isSaree
                      ? 'This may take 15–20 seconds'
                      : is3D
                          ? 'Elite 3D rendering in progress…'
                          : 'Powered by Vertex AI',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _build3DStreamOverlay() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('3d_renders').doc(active3DJobId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE040FB)),
                  SizedBox(height: 16),
                  Text(
                    'Initiating async 3D server container...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final double progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        final String currentStep = data['currentStep'] ?? 'Initializing...';
        final List<dynamic> steps = data['steps'] ?? [];

        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
              border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('👑 ', style: TextStyle(fontSize: 18)),
                        Text(
                          '3D Mesh Pipeline',
                          style: TextStyle(
                            color: Color(0xFFE040FB),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${progress.toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFE040FB),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  currentStep,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ...steps.map((s) {
                  final m = s as Map<String, dynamic>;
                  final bool isDone = (m['progress'] as num? ?? 0) <= progress;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isDone ? const Color(0xFFE040FB) : Colors.white30,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m['label'] ?? '',
                            style: TextStyle(
                              color: isDone ? Colors.white : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
