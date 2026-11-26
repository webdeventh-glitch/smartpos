import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/business_settings.dart';
import 'package:desktop_starter/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter & AmountInWords', () {
    test(
        'formats amounts with commas and never uses Lakh/Million abbreviations',
        () {
      expect(CurrencyFormatter.exact(10000, currency: 'Rs '), 'Rs 10,000.00');
      expect(
          CurrencyFormatter.compact(654500, currency: 'Rs '), 'Rs 654,500.00');
      expect(CurrencyFormatter.compact(5610000, currency: 'Rs '),
          'Rs 5,610,000.00');
      expect(CurrencyFormatter.compact(5610000, currency: 'Rs '),
          isNot(contains('Million')));
      expect(CurrencyFormatter.compact(654500, currency: 'Rs '),
          isNot(contains('Lakh')));
    });

    test('converts amounts to English and Urdu words accurately', () {
      expect(
          CurrencyFormatter.inWords(10000, languageCode: 'en'), 'Ten Thousand');
      expect(CurrencyFormatter.inWords(654500, languageCode: 'en'),
          'Six Hundred Fifty-Four Thousand Five Hundred');
      expect(CurrencyFormatter.inWords(5610000, languageCode: 'en'),
          'Five Million Six Hundred Ten Thousand');

      expect(CurrencyFormatter.inWords(10000, languageCode: 'ur'), 'دس ہزار');
      expect(CurrencyFormatter.inWords(654500, languageCode: 'ur'),
          'چھ لاکھ چون ہزار پانچ سو');
      expect(CurrencyFormatter.inWords(5610000, languageCode: 'ur'),
          'چھپن لاکھ دس ہزار');
    });

    test('inActiveWords uses secondary language when enabled', () {
      final enOnly = BusinessSettings(
        primaryLanguage: 'en',
        secondaryLanguage: 'none',
        enableSecondaryLanguage: false,
      );
      expect(CurrencyFormatter.inActiveWords(10000, settings: enOnly),
          'Ten Thousand');

      final withUrduSecondary = BusinessSettings(
        primaryLanguage: 'en',
        secondaryLanguage: 'ur',
        enableSecondaryLanguage: true,
      );
      expect(
          CurrencyFormatter.inActiveWords(10000, settings: withUrduSecondary),
          'دس ہزار');
    });
  });
}
