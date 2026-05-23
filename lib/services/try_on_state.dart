import 'package:flutter/material.dart';

class TryOnState {
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<Map<String, String>?> pendingTryOnNotifier = ValueNotifier<Map<String, String>?>(null);

  static void selectProductForTryOn(String title, String imageUrl) {
    String category = 'upper_body';
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('dress') || 
        lowerTitle.contains('skirt') || 
        lowerTitle.contains('one-piece') || 
        lowerTitle.contains('gown')) {
      category = 'one_piece';
    } else if (lowerTitle.contains('pants') || 
               lowerTitle.contains('cargo') || 
               lowerTitle.contains('shorts') || 
               lowerTitle.contains('trousers') || 
               lowerTitle.contains('chino') || 
               lowerTitle.contains('jean')) {
      category = 'lower_body';
    }

    pendingTryOnNotifier.value = {
      'title': title,
      'image': imageUrl,
      'category': category,
    };
    currentTabNotifier.value = 2; // Switch to the AI Try-On Studio (Index 2)
  }
}
