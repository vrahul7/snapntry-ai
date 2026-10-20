import 'package:flutter_test/flutter_test.dart';
import 'package:b2b_gena2z/services/try_on_provider.dart';

void main() {
  group('TryOnProvider Unit Tests', () {
    late TryOnProvider provider;

    setUp(() {
      provider = TryOnProvider();
    });

    test('Initial default state is correct', () {
      expect(provider.selectedRenderTier, equals('2d'));
      expect(provider.selectedBackgroundStyle, equals('studio'));
      expect(provider.isProcessing, isFalse);
      expect(provider.is3DProcessing, isFalse);
      expect(provider.generatedImageUrl, isNull);
      expect(provider.apparelList.isNotEmpty, isTrue);
      expect(provider.modelList.isNotEmpty, isTrue);
    });

    test('Changing render tier updates state and notifies listeners', () {
      bool notified = false;
      provider.addListener(() => notified = true);

      provider.setRenderTier('3d');
      expect(provider.selectedRenderTier, equals('3d'));
      expect(notified, isTrue);
    });

    test('Changing background style updates state and notifies listeners', () {
      bool notified = false;
      provider.addListener(() => notified = true);

      provider.setBackgroundStyle('palace');
      expect(provider.selectedBackgroundStyle, equals('palace'));
      expect(notified, isTrue);
    });

    test('Selecting apparel updates apparel state and resets generated image', () {
      provider.setGeneratedImageUrl('https://example.com/result.png');
      expect(provider.generatedImageUrl, isNotNull);

      provider.selectApparel(
        title: 'Banarasi Saree',
        image: 'https://example.com/saree.png',
        category: 'saree',
        renderTier: '2d',
      );

      expect(provider.selectedApparelTitle, equals('Banarasi Saree'));
      expect(provider.selectedApparelImage, equals('https://example.com/saree.png'));
      expect(provider.selectedApparelCategory, equals('saree'));
      expect(provider.generatedImageUrl, isNull);
    });

    test('Selecting model updates model state and resets generated image', () {
      provider.setGeneratedImageUrl('https://example.com/result.png');

      provider.selectModel(
        title: 'Model Gamma',
        image: 'https://example.com/gamma.png',
      );

      expect(provider.selectedModelTitle, equals('Model Gamma'));
      expect(provider.selectedModelImage, equals('https://example.com/gamma.png'));
      expect(provider.generatedImageUrl, isNull);
    });

    test('addRecentTryOn inserts at the top of history', () {
      final initialCount = provider.recentTryOns.length;
      final testItem = {
        'apparelTitle': 'Test Blazer',
        'apparelImage': 'https://example.com/blazer.png',
        'modelTitle': 'Custom Model',
        'modelImage': 'https://example.com/custom.png',
        'resultImage': 'https://example.com/result123.png',
      };

      provider.addRecentTryOn(testItem);

      expect(provider.recentTryOns.length, equals(initialCount + 1));
      expect(provider.recentTryOns.first['apparelTitle'], equals('Test Blazer'));
    });
  });
}
