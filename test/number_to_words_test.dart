import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/services/number_to_words_service.dart';

void main() {
  group('NumberToWordsService Tests', () {
    test('1. Urdu (اردو) Number Conversion', () {
      // 865 - matches user screenshot
      expect(
        NumberToWordsService.convert(865.0, language: 'ur'),
        'آٹھ سو پینسٹھ روپے۔',
      );

      // 1255 - matches user example ("ایک ہزرا دو سو پچپن روپے۔")
      expect(
        NumberToWordsService.convert(1255.0, language: 'ur'),
        'ایک ہزار دو سو پچپن روپے۔',
      );

      // 0
      expect(
        NumberToWordsService.convert(0.0, language: 'ur'),
        'صفر روپے۔',
      );

      // Large Lakhs & Crores
      expect(
        NumberToWordsService.convert(150000.0, language: 'ur'),
        'ایک لاکھ پچاس ہزار روپے۔',
      );
      expect(
        NumberToWordsService.convert(10000000.0, language: 'ur'),
        'ایک کروڑ روپے۔',
      );

      // With decimals / paisas
      expect(
        NumberToWordsService.convert(865.50, language: 'ur'),
        'آٹھ سو پینسٹھ روپے اور پچاس پیسے۔',
      );
    });

    test('2. Pashto (پښتو) Number Conversion', () {
      final p865 = NumberToWordsService.convert(865.0, language: 'ps');
      expect(p865.contains('روپۍ'), true);
      expect(p865.contains('اته سوه'), true);

      final p1255 = NumberToWordsService.convert(1255.0, language: 'ps');
      expect(p1255.contains('زر'), true);
      expect(p1255.contains('دوه سوه'), true);
    });

    test('3. Farsi (فارسی) Number Conversion', () {
      final f865 = NumberToWordsService.convert(865.0, language: 'fa');
      expect(f865.contains('هشتصد'), true);
      expect(f865.contains('تومان'), true);

      // Selected currency: PKR / Rs (Matches user POS screen)
      final fPkr = NumberToWordsService.convert(3650.0, language: 'fa', currencySymbol: 'Rs', currencyCode: 'PKR');
      expect(fPkr.contains('سه هزار و ششصد و پنجاه'), true);
      expect(fPkr.contains('روپیه'), true);

      // Selected currency: USD
      final fUsd = NumberToWordsService.convert(100.0, language: 'fa', currencySymbol: '\$', currencyCode: 'USD');
      expect(fUsd.contains('دلار'), true);

      final f1255 = NumberToWordsService.convert(1255.0, language: 'fa');
      expect(f1255.contains('هزار'), true);
      expect(f1255.contains('دویست'), true);
    });

    test('4. Spanish (Español) Number Conversion', () {
      final s865 = NumberToWordsService.convert(865.0, language: 'es');
      expect(s865, 'ochocientos sesenta y cinco pesos');

      final s1255 = NumberToWordsService.convert(1255.0, language: 'es');
      expect(s1255, 'mil doscientos cincuenta y cinco pesos');
    });

    test('5. Dutch (Nederlands) Number Conversion', () {
      final d865 = NumberToWordsService.convert(865.0, language: 'nl');
      expect(d865, 'achthonderdvijfenzestig roepie');

      final d1255 = NumberToWordsService.convert(1255.0, language: 'nl');
      expect(d1255, 'duizend tweehonderdvijfenvijftig roepie');
    });

    test('6. English Number Conversion', () {
      expect(
        NumberToWordsService.convert(865.0, language: 'en'),
        'Eight Hundred and Sixty Five Rupees Only',
      );
      expect(
        NumberToWordsService.convert(1255.0, language: 'en'),
        'One Thousand Two Hundred and Fifty Five Rupees Only',
      );
    });

    test('7. RTL Detection', () {
      expect(NumberToWordsService.isRtl('ur'), true);
      expect(NumberToWordsService.isRtl('ps'), true);
      expect(NumberToWordsService.isRtl('fa'), true);
      expect(NumberToWordsService.isRtl('en'), false);
      expect(NumberToWordsService.isRtl('es'), false);
      expect(NumberToWordsService.isRtl('nl'), false);
    });
  });
}
