import 'dart:async';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Simulates uploading a local image to Firebase Storage and returning a download URL
  Future<String> uploadUserPhoto(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Network delay
    // Return a gorgeous default portrait placeholder from Unsplash
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
  }

  Future<String> uploadProductImage(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
  }
}
