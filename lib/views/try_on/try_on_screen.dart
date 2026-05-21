import 'package:flutter/material.dart';
import '../../config/theme.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  bool _isProcessing = false;
  String? _generatedImageUrl;

  void _triggerTryOn() async {
    setState(() {
      _isProcessing = true;
      _generatedImageUrl = null;
    });

    // Simulate Cloud Function / Vertex AI inference processing latency
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isProcessing = false;
        // Mock output of high-fidelity try-on image
        _generatedImageUrl = 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=500';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Try-On Studio',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Mix apparel collections with partner target models instantly.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),

            // Apparel Mapping Tool container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder, width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Product Selected Card
                      Expanded(
                        child: _buildInputPreviewCard(
                          label: 'Apparel Product',
                          imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200',
                          title: 'Tech Jacket Pro',
                        ),
                      ),
                      
                      // Mapping connector icon
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primaryNeon,
                          size: 28,
                        ),
                      ),

                      // User/Model Selected Card
                      Expanded(
                        child: _buildInputPreviewCard(
                          label: 'Target Model',
                          imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                          title: 'Model Alpha',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _triggerTryOn,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isProcessing ? 'Generating AI Fit...' : 'Generate Virtual Try-On'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Try-On Output Status Viewer
            Text(
              'Generated Result',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isProcessing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primaryNeon),
                            SizedBox(height: 16),
                            Text(
                              'Running Vertex AI try-on pipeline...',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : (_generatedImageUrl != null
                        ? Image.network(
                            _generatedImageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.textSecondary),
                                SizedBox(height: 12),
                                Text(
                                  'Tap generate above to check fit.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPreviewCard({
    required String label,
    required String imageUrl,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
