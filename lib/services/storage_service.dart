import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  bool get isFirebaseEnabled => Firebase.apps.isNotEmpty;

  // Simulates uploading a local image to Firebase Storage and returning a download URL
  Future<String> uploadUserPhoto(String filePath) async {
    if (isFirebaseEnabled) {
      try {
        final userId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        final fileName = 'user_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = fb_storage.FirebaseStorage.instance.ref().child('users/photos/$userId/$fileName');
        
        if (kIsWeb) {
          // Web fallback since File(path) is not supported, return standard mock
          return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
        } else {
          final file = File(filePath);
          final uploadTask = await ref.putFile(file);
          return await uploadTask.ref.getDownloadURL();
        }
      } catch (e) {
        debugPrint('Firebase Storage user photo upload error: $e');
        return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 1500)); // Network delay
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
    }
  }

  Future<String> uploadProductImage(String filePath) async {
    if (isFirebaseEnabled) {
      try {
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = fb_storage.FirebaseStorage.instance.ref().child('products/$fileName');
        
        if (kIsWeb) {
          return 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
        } else {
          final file = File(filePath);
          final uploadTask = await ref.putFile(file);
          return await uploadTask.ref.getDownloadURL();
        }
      } catch (e) {
        debugPrint('Firebase Storage product image upload error: $e');
        return 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 1000));
      return 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
    }
  }
}

