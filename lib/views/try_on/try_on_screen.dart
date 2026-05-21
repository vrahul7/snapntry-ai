import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  bool _isProcessing = false;
  String? _generatedImageUrl;

  // Selected State
  String _selectedApparelTitle = 'Tech Jacket Pro';
  String _selectedApparelImage = 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200';
  String _selectedModelTitle = 'Model Alpha';
  String _selectedModelImage = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';

  // Mock datasets for selectors
  final List<Map<String, String>> _apparelList = [
    {
      'title': 'Tech Jacket Pro',
      'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200',
    },
    {
      'title': 'Silk Evening Dress',
      'image': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=200',
    },
    {
      'title': 'Urban Cargo Pants',
      'image': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=200',
    },
    {
      'title': 'Premium Linen Shirt',
      'image': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=200',
    },
  ];

  final List<Map<String, String>> _modelList = [
    {
      'title': 'Model Alpha',
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
    },
    {
      'title': 'Model Beta',
      'image': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=200',
    },
    {
      'title': 'Model Gamma',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    },
  ];

  // Recent history of Try-Ons
  final List<Map<String, String>> _recentTryOns = [
    {
      'apparelTitle': 'Silk Evening Dress',
      'apparelImage': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=200',
      'modelTitle': 'Model Beta',
      'modelImage': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=200',
      'resultImage': 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=500',
    },
    {
      'apparelTitle': 'Urban Cargo Pants',
      'apparelImage': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=200',
      'modelTitle': 'Model Gamma',
      'modelImage': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      'resultImage': 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=500',
    },
  ];

  void _triggerTryOn() async {
    setState(() {
      _isProcessing = true;
      _generatedImageUrl = null;
    });

    // Simulate Cloud Function / Vertex AI inference processing latency
    await Future.delayed(const Duration(seconds: 3));

    // Map selected to specific results to make demo look realistic
    String mockResult = 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=500';
    if (_selectedApparelTitle == 'Tech Jacket Pro') {
      mockResult = 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=500';
    } else if (_selectedApparelTitle == 'Silk Evening Dress') {
      mockResult = 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=500';
    } else if (_selectedApparelTitle == 'Urban Cargo Pants') {
      mockResult = 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=500';
    } else if (_selectedApparelTitle == 'Premium Linen Shirt') {
      mockResult = 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500';
    }

    final currentUser = FirebaseAuthService().currentUser;
    final userId = currentUser?.uid ?? 'mock_uid_12345';
    // Async log transaction to firestore
    FirestoreService().logTryOnTransaction(
      userId: userId,
      apparelId: _selectedApparelTitle.toLowerCase().replaceAll(' ', '_'),
      apparelTitle: _selectedApparelTitle,
      apparelImageUrl: _selectedApparelImage,
      userPhotoUrl: _selectedModelImage,
      resultImageUrl: mockResult,
      status: 'success',
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _generatedImageUrl = mockResult;
        
        // Add to recent try-ons history
        _recentTryOns.insert(0, {
          'apparelTitle': _selectedApparelTitle,
          'apparelImage': _selectedApparelImage,
          'modelTitle': _selectedModelTitle,
          'modelImage': _selectedModelImage,
          'resultImage': mockResult,
        });
      });
    }
  }

  void _selectApparel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Apparel Product',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _apparelList.length,
                    itemBuilder: (context, index) {
                      final item = _apparelList[index];
                      final isSelected = item['title'] == _selectedApparelTitle;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedApparelTitle = item['title']!;
                            _selectedApparelImage = item['image']!;
                            _generatedImageUrl = null;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['image']!,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['title']!,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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
          ),
        );
      },
    );
  }

  void _selectModel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Target Model',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _modelList.length,
                    itemBuilder: (context, index) {
                      final item = _modelList[index];
                      final isSelected = item['title'] == _selectedModelTitle;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedModelTitle = item['title']!;
                            _selectedModelImage = item['image']!;
                            _generatedImageUrl = null;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryNeon : AppTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['image']!,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['title']!,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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
          ),
        );
      },
    );
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
            const SizedBox(height: 20),

            // Recent Try-Ons Title & List
            if (_recentTryOns.isNotEmpty) ...[
              const Text(
                'RECENT TRY-ONS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentTryOns.length,
                  itemBuilder: (context, index) {
                    final item = _recentTryOns[index];
                    final isCurrentResult = _generatedImageUrl == item['resultImage'] &&
                        _selectedApparelTitle == item['apparelTitle'] &&
                        _selectedModelTitle == item['modelTitle'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedApparelTitle = item['apparelTitle']!;
                          _selectedApparelImage = item['apparelImage']!;
                          _selectedModelTitle = item['modelTitle']!;
                          _selectedModelImage = item['modelImage']!;
                          _generatedImageUrl = item['resultImage']!;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrentResult ? AppTheme.primaryNeon : AppTheme.glassBorder,
                            width: 2.0,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            item['resultImage']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                        child: GestureDetector(
                          onTap: _selectApparel,
                          child: _buildInputPreviewCard(
                            label: 'Apparel Product',
                            imageUrl: _selectedApparelImage,
                            title: _selectedApparelTitle,
                          ),
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
                        child: GestureDetector(
                          onTap: _selectModel,
                          child: _buildInputPreviewCard(
                            label: 'Target Model',
                            imageUrl: _selectedModelImage,
                            title: _selectedModelTitle,
                          ),
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
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 48, color: AppTheme.textSecondary),
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
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 40, color: AppTheme.textSecondary),
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
