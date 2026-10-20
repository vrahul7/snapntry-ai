import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';
import 'storage_service.dart';

/// Centralized state provider for the AI Try-On Studio.
/// Replaces sprawling local setState blocks with reactive, clean architecture.
class TryOnProvider extends ChangeNotifier {
  // Processing States
  bool _isProcessing = false;
  bool _isCheckingVisibility = false;
  bool _is3DProcessing = false;
  String? _errorMessage;
  String? _generatedImageUrl;
  String? _active3DJobId;

  // Selected State
  String _selectedApparelTitle = 'Tech Jacket Pro';
  String _selectedApparelImage = 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
  String _selectedApparelCategory = 'upper_body';
  String _selectedApparelOriginalCategory = 'upper_body';
  String _selectedModelTitle = 'Model Alpha';
  String _selectedModelImage = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';

  // 3D Rendering Tier State
  String _selectedRenderTier = '2d'; // '2d' | '3d'
  String _selectedBackgroundStyle = 'studio'; // 'studio' | 'boutique' | 'palace' | 'courtyard' | 'showroom'

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

  // Mock presets
  final List<Map<String, String>> _apparelList = [
    {
      'title': 'Tech Jacket Pro',
      'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500',
      'category': 'upper_body',
      'renderTier': '2d',
    },
    {
      'title': 'Silk Evening Dress',
      'image': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=500',
      'category': 'one_piece',
      'renderTier': '2d',
    },
    {
      'title': 'Urban Cargo Pants',
      'image': 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=500',
      'category': 'lower_body',
      'renderTier': '2d',
    },
    {
      'title': 'Premium Linen Shirt',
      'image': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=500',
      'category': 'upper_body',
      'renderTier': '2d',
    },
    {
      'title': 'Banarasi Silk Saree',
      'image': 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=500',
      'category': 'saree',
      'renderTier': '2d',
    },
    {
      'title': 'Kanjeevaram Saree',
      'image': 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=500',
      'category': 'saree',
      'renderTier': '2d',
    },
    {
      'title': 'Sabyasachi Bridal Lehenga',
      'image': 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=500',
      'category': 'bridal_lehenga',
      'renderTier': '3d',
    },
    {
      'title': 'Varnam Heavy Kanjivaram',
      'image': 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=500',
      'category': 'kanjeevaram_heavy',
      'renderTier': '3d',
    },
    {
      'title': 'Anamika Khanna Fusion Set',
      'image': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=500',
      'category': 'fusion_ethnic',
      'renderTier': '3d',
    },
  ];

  final List<Map<String, String>> _modelList = [
    {
      'title': 'Model Alpha',
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
    },
    {
      'title': 'Model Beta',
      'image': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=500',
    },
    {
      'title': 'Model Gamma',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500',
    },
  ];

  // Getters
  bool get isProcessing => _isProcessing;
  bool get isCheckingVisibility => _isCheckingVisibility;
  bool get is3DProcessing => _is3DProcessing;
  String? get errorMessage => _errorMessage;
  String? get generatedImageUrl => _generatedImageUrl;
  String? get active3DJobId => _active3DJobId;

  String get selectedApparelTitle => _selectedApparelTitle;
  String get selectedApparelImage => _selectedApparelImage;
  String get selectedApparelCategory => _selectedApparelCategory;
  String get selectedApparelOriginalCategory => _selectedApparelOriginalCategory;
  String get selectedModelTitle => _selectedModelTitle;
  String get selectedModelImage => _selectedModelImage;
  String get selectedRenderTier => _selectedRenderTier;
  String get selectedBackgroundStyle => _selectedBackgroundStyle;

  List<Map<String, String>> get recentTryOns => List.unmodifiable(_recentTryOns);
  List<Map<String, String>> get apparelList => List.unmodifiable(_apparelList);
  List<Map<String, String>> get modelList => List.unmodifiable(_modelList);

  // Setters & Actions
  void setRenderTier(String tier) {
    if (_selectedRenderTier != tier) {
      _selectedRenderTier = tier;
      notifyListeners();
    }
  }

  void setBackgroundStyle(String style) {
    if (_selectedBackgroundStyle != style) {
      _selectedBackgroundStyle = style;
      notifyListeners();
    }
  }

  void setGeneratedImageUrl(String? url) {
    _generatedImageUrl = url;
    notifyListeners();
  }

  void selectApparel({
    required String title,
    required String image,
    required String category,
    String renderTier = '2d',
  }) {
    _selectedApparelTitle = title;
    _selectedApparelImage = image;
    _selectedApparelCategory = category;
    _selectedApparelOriginalCategory = category;
    _selectedRenderTier = renderTier;
    _generatedImageUrl = null;
    notifyListeners();
  }

  void selectModel({
    required String title,
    required String image,
  }) {
    _selectedModelTitle = title;
    _selectedModelImage = image;
    _generatedImageUrl = null;
    notifyListeners();
  }

  void setCustomModel({
    required String title,
    required String image,
  }) {
    _selectedModelTitle = title;
    _selectedModelImage = image;
    _generatedImageUrl = null;
    notifyListeners();
  }

  void setCustomApparel({
    required String title,
    required String image,
    required String category,
  }) {
    _selectedApparelTitle = title;
    _selectedApparelImage = image;
    _selectedApparelCategory = category;
    _selectedApparelOriginalCategory = category;
    _generatedImageUrl = null;
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void set3DProcessing(bool value, [String? jobId]) {
    _is3DProcessing = value;
    _active3DJobId = jobId;
    notifyListeners();
  }

  void setCheckingVisibility(bool value) {
    _isCheckingVisibility = value;
    notifyListeners();
  }

  void setErrorMessage(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  /// Loads the authenticated user's recent try-on results from Firestore.
  Future<void> loadRecentTryOns() async {
    final user = FirebaseAuthService().currentUser;
    if (user == null || !StorageService().isFirebaseEnabled) return;
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

      _recentTryOns.clear();
      _recentTryOns.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading try-on history: $e');
    }
  }

  /// Appends a new successful try-on result to the local history list.
  void addRecentTryOn(Map<String, String> item) {
    _recentTryOns.insert(0, item);
    notifyListeners();
  }
}
