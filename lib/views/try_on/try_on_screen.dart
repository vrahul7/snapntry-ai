import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/try_on_state.dart';
import 'size_advisor_panel.dart';
import 'complete_look_row.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isCheckingVisibility = false;
  String? _generatedImageUrl;
  bool _isLoadingHistory = false;

  // Reveal animation for generated result
  late final AnimationController _revealController;
  late final Animation<double> _revealFade;
  late final Animation<double> _revealScale;
  bool _hasPlayedReveal = false;

  // Selected State
  String _selectedApparelTitle = 'Tech Jacket Pro';
  String _selectedApparelImage = 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200';
  String _selectedApparelCategory = 'upper_body';
  String _selectedApparelOriginalCategory = 'upper_body';
  String _selectedModelTitle = 'Model Alpha';
  String _selectedModelImage = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _revealFade = CurvedAnimation(parent: _revealController, curve: Curves.easeOut);
    _revealScale = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutBack),
    );
    TryOnState.pendingTryOnNotifier.addListener(_onPendingTryOnChanged);
    _onPendingTryOnChanged();
    _loadRecentTryOns();
  }

  @override
  void dispose() {
    _revealController.dispose();
    TryOnState.pendingTryOnNotifier.removeListener(_onPendingTryOnChanged);
    super.dispose();
  }

  // Load try-on history from Firestore — filtered strictly by the current user's UID
  Future<void> _loadRecentTryOns() async {
    final user = FirebaseAuthService().currentUser;
    if (user == null || !StorageService().isFirebaseEnabled) return;
    setState(() => _isLoadingHistory = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('try_ons')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      final loaded = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'apparelTitle': (d['apparelTitle'] as String?) ?? '',
          'apparelImage': (d['apparelImageUrl'] as String?) ?? '',
          'modelTitle': 'Custom Photo',
          'modelImage': (d['userPhotoUrl'] as String?) ?? '',
          'resultImage': (d['resultImageUrl'] as String?) ?? '',
        };
      }).where((item) => item['resultImage']!.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _recentTryOns
            ..clear()
            ..addAll(loaded);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading try-on history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _onPendingTryOnChanged() {
    final pending = TryOnState.pendingTryOnNotifier.value;
    if (pending != null) {
      if (mounted) {
        setState(() {
          _selectedApparelTitle = pending['title'] ?? '';
          _selectedApparelImage = pending['image'] ?? '';
          _selectedApparelCategory = pending['category'] ?? 'upper_body';
          _selectedApparelOriginalCategory = pending['category'] ?? 'upper_body';
          _selectedModelImage = ''; // Clear right panel to show prompt
          _selectedModelTitle = '';
          _generatedImageUrl = null;
        });
      }
      TryOnState.pendingTryOnNotifier.value = null;
    }
  }

  // Opens fullscreen interactive zoom viewer for the generated try-on result
  void _openImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full-screen interactive viewer with pinch-to-zoom and pan
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 80, color: Colors.white54),
                  ),
                ),
              ),
            ),
            // Close button top-right
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Zoom hint label at the bottom
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pinch_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Pinch to zoom · Tap ✕ to close',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows animated retry popup when required body region isn't visible
  Future<bool> _showBodyRetryDialog({required String reason}) async {
    String title;
    String message;
    String tip;
    IconData icon;

    switch (reason) {
      case 'upper_body_missing':
        title = 'Upper Body Not Visible';
        message = 'This garment is a top/shirt/jacket. Your photo must clearly show the upper body — chest, shoulders and torso.';
        tip = '💡 Stand facing the camera, frame from waist up with good lighting.';
        icon = Icons.airline_seat_recline_extra_rounded;
        break;
      case 'lower_body_missing':
        title = 'Lower Body Not Visible';
        message = 'This garment is pants/skirt/shorts. Your photo must clearly show the lower body — hips, thighs and legs.';
        tip = '💡 Step back to show waist-to-feet. A full-length mirror works great!';
        icon = Icons.airline_seat_legroom_normal_rounded;
        break;
      case 'both_body_missing':
        title = 'Body Not Detected';
        message = 'This is a full-body outfit. Neither your upper nor lower body was clearly visible in the photo.';
        tip = '💡 Use a full-body mirror shot or stand far enough back to show head-to-toe.';
        icon = Icons.person_off_rounded;
        break;
      default:
        title = 'Photo Issue Detected';
        message = 'The AI could not detect the required body region for this garment type.';
        tip = '💡 Try a clear, well-lit photo showing the full garment area.';
        icon = Icons.warning_amber_rounded;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child!),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orangeAccent.withValues(alpha: 0.18),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.orangeAccent.withValues(alpha: 0.25),
                        Colors.transparent,
                      ]),
                    ),
                    child: Icon(icon, color: Colors.orangeAccent, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(message,
                    style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
                    ),
                    child: Text(tip,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.5),
                      textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 26),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF3A3A5C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF8080A0))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFF0058)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          label: const Text('Upload New Photo',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  void _pickModelImage(ImageSource source) async {

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isProcessing = true;
      });

      String modelImageUrl;
      if (StorageService().isFirebaseEnabled) {
        modelImageUrl = await StorageService().uploadUserPhoto(image);
      } else {
        modelImageUrl = image.path;
      }

      setState(() {
        _selectedModelTitle = source == ImageSource.camera ? 'Camera Photo' : 'Gallery Photo';
        _selectedModelImage = modelImageUrl;
        _isProcessing = false;
        _generatedImageUrl = null;
      });
    } catch (e) {
      debugPrint('Error picking model image: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Widget _buildModelPromptCard() {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: AppTheme.primaryNeon,
            size: 24,
          ),
          const SizedBox(height: 4),
          const Text(
            'Your Photo',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Camera Button
              GestureDetector(
                onTap: () => _pickModelImage(ImageSource.camera),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryNeon, size: 16),
                ),
              ),
              // Gallery Button
              GestureDetector(
                onTap: () => _pickModelImage(ImageSource.gallery),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryNeon, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildImageWidget(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('http') || path.startsWith('blob:') || kIsWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: AppTheme.textSecondary),
      );
    } else {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: AppTheme.textSecondary),
      );
    }
  }

  Future<String?> _showCategorySelectionDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          title: const Text(
            'Select Apparel Type',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help the AI understand where to fit this garment on the model.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildCategoryDialogOption(context, 'Tops / Shirts / Jackets', 'upper_body'),
              const SizedBox(height: 10),
              _buildCategoryDialogOption(context, 'Pants / Shorts / Skirts', 'lower_body'),
              const SizedBox(height: 10),
              _buildCategoryDialogOption(context, 'Dresses / One-Pieces', 'one_piece'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryDialogOption(BuildContext context, String title, String categoryValue) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: TextButton(
        onPressed: () => Navigator.pop(context, categoryValue),
        child: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _pickCustomApparel() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Ask for apparel category immediately
      final String? selectedCategory = await _showCategorySelectionDialog();
      if (selectedCategory == null) return; // User cancelled

      setState(() {
        _isProcessing = true;
      });

      String apparelImageUrl;
      if (StorageService().isFirebaseEnabled) {
        apparelImageUrl = await StorageService().uploadUserPhoto(image);
      } else {
        apparelImageUrl = image.path;
      }

      setState(() {
        _selectedApparelTitle = 'Custom Apparel';
        _selectedApparelImage = apparelImageUrl;
        _selectedApparelCategory = selectedCategory;
        _selectedApparelOriginalCategory = selectedCategory;
        _isProcessing = false;
        _generatedImageUrl = null;
      });
    } catch (e) {
      debugPrint('Error picking custom apparel: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting apparel: $e')),
        );
      }
    }
  }

  void _pickCustomPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isProcessing = true;
      });

      String modelImageUrl;
      if (StorageService().isFirebaseEnabled) {
        modelImageUrl = await StorageService().uploadUserPhoto(image);
      } else {
        modelImageUrl = image.path;
      }

      setState(() {
        _selectedModelTitle = 'Custom Photo';
        _selectedModelImage = modelImageUrl;
        _isProcessing = false;
        _generatedImageUrl = null;
      });
    } catch (e) {
      debugPrint('Error picking custom photo: $e');
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photo: $e')),
        );
      }
    }
  }

  void _triggerTryOn() async {
    if (_selectedModelImage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a target photo first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isFirebaseEnabled = StorageService().isFirebaseEnabled;

    // ── Step 1: Gemini Vision body-visibility pre-check ──────────────────────
    if (isFirebaseEnabled && _selectedModelImage.startsWith('http')) {
      setState(() { _isCheckingVisibility = true; });
      try {
        final HttpsCallable checker =
            FirebaseFunctions.instance.httpsCallable('analyzeBodyVisibility');
        final checkResult = await checker.call<Map<String, dynamic>>(<String, dynamic>{
          'personImageUrl': _selectedModelImage,
          'category': _selectedApparelCategory,
        });
        final checkData = checkResult.data;
        final bool allowed = (checkData['allowed'] as bool?) ?? true;
        final String reason = (checkData['reason'] as String?) ?? '';
        final String effectiveCategory =
            (checkData['effectiveCategory'] as String?) ?? _selectedApparelCategory;

        if (mounted) setState(() { _isCheckingVisibility = false; });

        if (!allowed) {
          final retry = await _showBodyRetryDialog(reason: reason);
          if (retry && mounted) _pickModelImage(ImageSource.gallery);
          return;
        }

        // Auto-adjust category for partial one_piece visibility
        if (effectiveCategory != _selectedApparelCategory && mounted) {
          setState(() { _selectedApparelCategory = effectiveCategory; });
          final regionLabel = effectiveCategory == 'upper_body' ? 'upper body' : 'lower body';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Only $regionLabel detected — AI will fit garment to that region.'),
              backgroundColor: const Color(0xFF2A2A4A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
        }
      } catch (e) {
        debugPrint('Body visibility check failed (proceeding): $e');
        if (mounted) setState(() { _isCheckingVisibility = false; });
      }
    }

    // ── Step 2: Run the actual try-on generation ──────────────────────────────
    setState(() {
      _isProcessing = true;
      _generatedImageUrl = null;
      _hasPlayedReveal = false;
    });

    if (isFirebaseEnabled) {
      try {
        final category = _selectedApparelCategory;
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('generateTryOn');
        final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'personImage': _selectedModelImage,
          'apparelImage': _selectedApparelImage,
          'apparelTitle': _selectedApparelTitle,
          'category': category,
          'originalCategory': _selectedApparelOriginalCategory,
        });
        final data = result.data;
        final outputUrl = data['outputUrl'] as String;
        final currentUser = FirebaseAuthService().currentUser;
        final userId = currentUser?.uid ?? 'mock_uid_12345';
        await FirestoreService().logTryOnTransaction(
          userId: userId,
          apparelId: _selectedApparelTitle.toLowerCase().replaceAll(' ', '_'),
          apparelTitle: _selectedApparelTitle,
          apparelImageUrl: _selectedApparelImage,
          userPhotoUrl: _selectedModelImage,
          resultImageUrl: outputUrl,
          status: 'success',
        );
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _generatedImageUrl = outputUrl;
            _recentTryOns.insert(0, {
              'apparelTitle': _selectedApparelTitle,
              'apparelImage': _selectedApparelImage,
              'modelTitle': _selectedModelTitle,
              'modelImage': _selectedModelImage,
              'resultImage': outputUrl,
            });
          });
          _revealController.forward(from: 0);
          setState(() { _hasPlayedReveal = true; });
        }
      } catch (e) {
        debugPrint('Vertex AI try-on function execution error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating try-on: $e')));
          setState(() { _isProcessing = false; });
        }
      }
    } else {
      await Future.delayed(const Duration(seconds: 3));
      String mockResult =
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500';
      if (_selectedApparelTitle == 'Tech Jacket Pro') {
        mockResult = 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=500';
      } else if (_selectedApparelTitle == 'Silk Evening Dress') {
        mockResult = 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=500';
      } else if (_selectedApparelTitle == 'Urban Cargo Pants') {
        mockResult = 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=500';
      } else if (_selectedApparelTitle == 'Premium Linen Shirt') {
        mockResult = 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500';
      } else if (_selectedApparelTitle == 'Custom Apparel') {
        mockResult = 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=500';
      }
      final currentUser = FirebaseAuthService().currentUser;
      final userId = currentUser?.uid ?? 'mock_uid_12345';
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
          _recentTryOns.insert(0, {
            'apparelTitle': _selectedApparelTitle,
            'apparelImage': _selectedApparelImage,
            'modelTitle': _selectedModelTitle,
            'modelImage': _selectedModelImage,
            'resultImage': mockResult,
          });
        });
        _revealController.forward(from: 0);
        setState(() { _hasPlayedReveal = true; });
      }
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Apparel Product',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickCustomApparel();
                      },
                      icon: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryNeon, size: 18),
                      label: const Text(
                        'Upload Custom',
                        style: TextStyle(color: AppTheme.primaryNeon, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                            if (_selectedApparelTitle == 'Silk Evening Dress') {
                              _selectedApparelCategory = 'one_piece';
                            } else if (_selectedApparelTitle == 'Urban Cargo Pants') {
                              _selectedApparelCategory = 'lower_body';
                            } else {
                              _selectedApparelCategory = 'upper_body';
                            }
                            _selectedApparelOriginalCategory = _selectedApparelCategory;
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Target Model',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickCustomPhoto();
                      },
                      icon: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryNeon, size: 18),
                      label: const Text(
                        'Upload Custom',
                        style: TextStyle(color: AppTheme.primaryNeon, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
              'Mix collections or upload your own garments to try them on instantly.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Recent Try-Ons Title & List
            if (_isLoadingHistory) ...[
              const Row(
                children: [
                  Text(
                    'RECENT TRY-ONS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else if (_recentTryOns.isNotEmpty) ...[
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
                          if (_selectedApparelTitle == 'Silk Evening Dress') {
                            _selectedApparelCategory = 'one_piece';
                          } else if (_selectedApparelTitle == 'Urban Cargo Pants') {
                            _selectedApparelCategory = 'lower_body';
                          } else {
                            _selectedApparelCategory = 'upper_body';
                          }
                          _selectedApparelOriginalCategory = _selectedApparelCategory;
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
                        child: _selectedModelImage.isEmpty
                            ? _buildModelPromptCard()
                            : GestureDetector(
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

                  // ── AI Size Advisor Panel (shown when model photo is selected) ──
                  if (_selectedModelImage.isNotEmpty)
                    SizeAdvisorPanel(
                      modelImageUrl: _selectedModelImage,
                      apparelTitle: _selectedApparelTitle,
                    ),

                  const SizedBox(height: 12),
                  // Body check status indicator
                  if (_isCheckingVisibility)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                          SizedBox(width: 10),
                          Text('AI scanning photo for body regions…',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: (_isProcessing || _isCheckingVisibility) ? null : AppTheme.instagramGradient,
                      color: (_isProcessing || _isCheckingVisibility) ? AppTheme.darkCard : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessing || _isCheckingVisibility) ? null : _triggerTryOn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 54),
                      ),
                      icon: Icon(
                        _isCheckingVisibility
                            ? Icons.manage_search_rounded
                            : Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isCheckingVisibility
                            ? 'Scanning Photo…'
                            : _isProcessing
                                ? 'Generating AI Fit…'
                                : 'Generate Virtual Try-On',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Try-On Output Status Viewer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Generated Result',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
                if (_generatedImageUrl != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: AppTheme.primaryNeon, size: 14),
                        SizedBox(width: 4),
                        Text('Tap to zoom',
                          style: TextStyle(color: AppTheme.primaryNeon, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _generatedImageUrl != null ? () => _openImageFullscreen(_generatedImageUrl!) : null,
              child: Container(
                // Taller portrait frame — fully scrollable, not clipped
                height: 460,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _generatedImageUrl != null
                        ? AppTheme.primaryNeon.withValues(alpha: 0.5)
                        : AppTheme.glassBorder,
                    width: _generatedImageUrl != null ? 1.5 : 1,
                  ),
                  boxShadow: _generatedImageUrl != null
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                            blurRadius: 20,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _isProcessing
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 48, height: 48,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryNeon),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text('Running Vertex AI try-on pipeline…',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              const SizedBox(height: 8),
                              const Text('This may take 15–30 seconds',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        )
                      : _generatedImageUrl != null
                          // ── Surprise reveal: fade + scale animation ──
                          ? FadeTransition(
                              opacity: _revealFade,
                              child: ScaleTransition(
                                scale: _revealScale,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      _generatedImageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image, size: 48,
                                              color: AppTheme.textSecondary),
                                    ),
                                    // Gold shimmer sweep (only on first reveal)
                                    if (!_hasPlayedReveal)
                                      AnimatedBuilder(
                                        animation: _revealController,
                                        builder: (context, _) {
                                          return Opacity(
                                            opacity: (1.0 - _revealController.value).clamp(0.0, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.transparent,
                                                    const Color(0xFFFFD700).withValues(alpha: 0.25),
                                                    Colors.transparent,
                                                  ],
                                                  stops: [
                                                    (_revealController.value - 0.3).clamp(0.0, 1.0),
                                                    _revealController.value.clamp(0.0, 1.0),
                                                    (_revealController.value + 0.3).clamp(0.0, 1.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    // Zoom icon overlay
                                    Positioned(
                                      bottom: 14, right: 14,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.zoom_in_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome_outlined, size: 52,
                                      color: AppTheme.textSecondary),
                                  SizedBox(height: 14),
                                  Text('Tap generate above to check fit.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                ),
              ),
            ),

            // ── Complete the Look section (shown after a result is generated) ──
            if (_generatedImageUrl != null)
              CompleteLookRow(
                currentApparelTitle: _selectedApparelTitle,
                currentApparelCategory: _selectedApparelCategory,
              ),

            // Bottom padding to clear floating glassmorphic nav bar (90px + 24px margin + 16px extra)
            const SizedBox(height: 140),
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
            child: _buildImageWidget(
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
