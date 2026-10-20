import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/try_on_provider.dart';
import '../../services/try_on_state.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/analytics_service.dart';
import 'components/try_on_studio_preview.dart';
import 'components/try_on_tier_selector.dart';
import 'components/try_on_background_selector.dart';
import 'components/try_on_apparel_picker.dart';
import 'components/try_on_model_picker.dart';
import 'components/try_on_history_sheet.dart';
import 'complete_look_row.dart';

/// Clean orchestrator screen for the AI Try-On Studio.
/// Modularized architecture with Provider-based state management.
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Sync external pending try-ons from Explore / Catalog feeds
    TryOnState.pendingTryOnNotifier.addListener(_syncPendingTryOn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingTryOn();
      context.read<TryOnProvider>().loadRecentTryOns();
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    TryOnState.pendingTryOnNotifier.removeListener(_syncPendingTryOn);
    super.dispose();
  }

  void _syncPendingTryOn() {
    final pending = TryOnState.pendingTryOnNotifier.value;
    if (pending != null && mounted) {
      final provider = context.read<TryOnProvider>();
      provider.selectApparel(
        title: pending['title'] ?? '',
        image: pending['image'] ?? '',
        category: pending['category'] ?? 'upper_body',
        renderTier: pending['renderTier'] ?? '2d',
      );
      TryOnState.pendingTryOnNotifier.value = null;
    }
  }

  Future<void> _handleTriggerTryOn() async {
    final provider = context.read<TryOnProvider>();

    if (provider.selectedModelImage.isEmpty) {
      AppTheme.showErrorSnackbar(context, 'Please select or upload a target photo first.');
      return;
    }

    if (provider.selectedRenderTier == '3d') {
      await _execute3DWorkflow(provider);
      return;
    }

    if (provider.selectedApparelCategory == 'saree') {
      await _executeSareeWorkflow(provider);
      return;
    }

    await _executeStandardVTONWorkflow(provider);
  }

  Future<void> _execute3DWorkflow(TryOnProvider provider) async {
    provider.set3DProcessing(true);
    final isFirebaseEnabled = StorageService().isFirebaseEnabled;

    if (isFirebaseEnabled) {
      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generate3DRender');
        final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'personImageUrl': provider.selectedModelImage,
          'productImageUrl': provider.selectedApparelImage,
          'category': provider.selectedApparelCategory,
          'backgroundStyle': provider.selectedBackgroundStyle,
        });

        final String renderId = result.data['renderId'] as String;
        provider.set3DProcessing(true, renderId);

        FirebaseFirestore.instance
            .collection('3d_renders')
            .doc(renderId)
            .snapshots()
            .listen((snapshot) {
          if (!snapshot.exists) return;
          final snapData = snapshot.data();
          if (snapData == null) return;

          final String status = snapData['status'] ?? 'pending';
          final String? outputUrl = snapData['outputUrl'] as String?;

          if (status == 'completed' && outputUrl != null) {
            final currentUser = FirebaseAuthService().currentUser;
            final userId = currentUser?.uid ?? 'mock_uid_12345';
            final apparelId = provider.selectedApparelTitle.toLowerCase().replaceAll(' ', '_');

            AnalyticsService().logTryOnEvent(
              apparelId: apparelId,
              category: provider.selectedApparelCategory,
              success: true,
            );

            FirestoreService().logTryOnTransaction(
              userId: userId,
              apparelId: apparelId,
              apparelTitle: provider.selectedApparelTitle,
              apparelImageUrl: provider.selectedApparelImage,
              userPhotoUrl: provider.selectedModelImage,
              resultImageUrl: outputUrl,
              status: 'success',
            );

            provider.setGeneratedImageUrl(outputUrl);
            provider.addRecentTryOn({
              'apparelTitle': provider.selectedApparelTitle,
              'apparelImage': provider.selectedApparelImage,
              'modelTitle': provider.selectedModelTitle,
              'modelImage': provider.selectedModelImage,
              'resultImage': outputUrl,
            });
            provider.set3DProcessing(false);
            _revealController.forward(from: 0);
          } else if (status == 'failed') {
            provider.set3DProcessing(false);
            if (mounted) {
              AppTheme.showErrorSnackbar(context, snapData['error'] ?? '3D render task failed.');
            }
          }
        });
      } catch (e) {
        provider.set3DProcessing(false);
        if (mounted) AppTheme.showErrorSnackbar(context, '3D Render initiation error: $e');
      }
    } else {
      // Mock 3D Workflow
      await Future.delayed(const Duration(seconds: 4));
      const mockResult = 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=500';
      provider.setGeneratedImageUrl(mockResult);
      provider.addRecentTryOn({
        'apparelTitle': provider.selectedApparelTitle,
        'apparelImage': provider.selectedApparelImage,
        'modelTitle': provider.selectedModelTitle,
        'modelImage': provider.selectedModelImage,
        'resultImage': mockResult,
      });
      provider.set3DProcessing(false);
      _revealController.forward(from: 0);
    }
  }

  Future<void> _executeSareeWorkflow(TryOnProvider provider) async {
    provider.setProcessing(true);
    final isFirebaseEnabled = StorageService().isFirebaseEnabled;

    if (isFirebaseEnabled) {
      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateSareeDraping');
        final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'personImageUrl': provider.selectedModelImage,
          'sareeImageUrl': provider.selectedApparelImage,
          'drapingStyle': 'nivi',
          'backgroundStyle': provider.selectedBackgroundStyle,
        });

        final outputUrl = result.data['outputUrl'] as String;
        final currentUser = FirebaseAuthService().currentUser;
        final userId = currentUser?.uid ?? 'mock_uid_12345';
        final apparelId = provider.selectedApparelTitle.toLowerCase().replaceAll(' ', '_');

        AnalyticsService().logTryOnEvent(
          apparelId: apparelId,
          category: 'saree',
          success: true,
        );

        await FirestoreService().logTryOnTransaction(
          userId: userId,
          apparelId: apparelId,
          apparelTitle: provider.selectedApparelTitle,
          apparelImageUrl: provider.selectedApparelImage,
          userPhotoUrl: provider.selectedModelImage,
          resultImageUrl: outputUrl,
          status: 'success',
        );

        provider.setGeneratedImageUrl(outputUrl);
        provider.addRecentTryOn({
          'apparelTitle': provider.selectedApparelTitle,
          'apparelImage': provider.selectedApparelImage,
          'modelTitle': provider.selectedModelTitle,
          'modelImage': provider.selectedModelImage,
          'resultImage': outputUrl,
        });
        provider.setProcessing(false);
        _revealController.forward(from: 0);
      } catch (e) {
        provider.setProcessing(false);
        if (mounted) AppTheme.showErrorSnackbar(context, 'Saree draping failed: $e');
      }
    } else {
      await Future.delayed(const Duration(seconds: 3));
      const mockResult = 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=500';
      provider.setGeneratedImageUrl(mockResult);
      provider.addRecentTryOn({
        'apparelTitle': provider.selectedApparelTitle,
        'apparelImage': provider.selectedApparelImage,
        'modelTitle': provider.selectedModelTitle,
        'modelImage': provider.selectedModelImage,
        'resultImage': mockResult,
      });
      provider.setProcessing(false);
      _revealController.forward(from: 0);
    }
  }

  Future<void> _executeStandardVTONWorkflow(TryOnProvider provider) async {
    provider.setProcessing(true);
    final isFirebaseEnabled = StorageService().isFirebaseEnabled;

    if (isFirebaseEnabled) {
      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateTryOn');
        final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'personImage': provider.selectedModelImage,
          'apparelImage': provider.selectedApparelImage,
          'apparelTitle': provider.selectedApparelTitle,
          'category': provider.selectedApparelCategory,
          'originalCategory': provider.selectedApparelOriginalCategory,
          'backgroundStyle': provider.selectedBackgroundStyle,
        });

        final outputUrl = result.data['outputUrl'] as String;
        final currentUser = FirebaseAuthService().currentUser;
        final userId = currentUser?.uid ?? 'mock_uid_12345';
        final apparelId = provider.selectedApparelTitle.toLowerCase().replaceAll(' ', '_');

        AnalyticsService().logTryOnEvent(
          apparelId: apparelId,
          category: provider.selectedApparelCategory,
          success: true,
        );

        await FirestoreService().logTryOnTransaction(
          userId: userId,
          apparelId: apparelId,
          apparelTitle: provider.selectedApparelTitle,
          apparelImageUrl: provider.selectedApparelImage,
          userPhotoUrl: provider.selectedModelImage,
          resultImageUrl: outputUrl,
          status: 'success',
        );

        provider.setGeneratedImageUrl(outputUrl);
        provider.addRecentTryOn({
          'apparelTitle': provider.selectedApparelTitle,
          'apparelImage': provider.selectedApparelImage,
          'modelTitle': provider.selectedModelTitle,
          'modelImage': provider.selectedModelImage,
          'resultImage': outputUrl,
        });
        provider.setProcessing(false);
        _revealController.forward(from: 0);
      } catch (e) {
        provider.setProcessing(false);
        if (mounted) AppTheme.showErrorSnackbar(context, 'Virtual try-on error: $e');
      }
    } else {
      await Future.delayed(const Duration(seconds: 2));
      String mockResult = 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=500';
      if (provider.selectedApparelTitle.contains('Jacket')) {
        mockResult = 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=500';
      } else if (provider.selectedApparelTitle.contains('Pants')) {
        mockResult = 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=500';
      }

      provider.setGeneratedImageUrl(mockResult);
      provider.addRecentTryOn({
        'apparelTitle': provider.selectedApparelTitle,
        'apparelImage': provider.selectedApparelImage,
        'modelTitle': provider.selectedModelTitle,
        'modelImage': provider.selectedModelImage,
        'resultImage': mockResult,
      });
      provider.setProcessing(false);
      _revealController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TryOnProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Studio Preview Canvas
              TryOnStudioPreview(
                revealController: _revealController,
                pulseController: _pulseController,
                onTriggerTryOn: _handleTriggerTryOn,
              ),

              // Complete Look cross-sell suggestions when result is ready
              if (provider.generatedImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: CompleteLookRow(
                    currentApparelTitle: provider.selectedApparelTitle,
                    currentApparelCategory: provider.selectedApparelCategory,
                  ),
                ),

              const SizedBox(height: 24),

              // 2D vs 3D Tier Switcher
              const TryOnTierSelector(),

              // Background Environment Selector
              const TryOnBackgroundSelector(),

              // Garment Catalog Selector
              const TryOnApparelPicker(),

              // Target Model / Photo Selector
              const TryOnModelPicker(),

              // Previous Sessions History Archive
              const TryOnHistorySection(),

              const SizedBox(height: 80), // Padding above bottom nav bar
            ],
          ),
        ),
      ),
    );
  }
}
