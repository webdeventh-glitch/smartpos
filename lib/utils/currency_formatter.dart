import 'package:intl/intl.dart';
import '../models/business_settings.dart';
import '../services/localization_service.dart';
import 'amount_in_words.dart';

/// Utility for formatting currency and large numeric values with comma separators
/// and human-readable localized words (no Lakh/Million abbreviations).
class CurrencyFormatter {
  static final NumberFormat _commaDecimalFmt =
      NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _commaIntFmt = NumberFormat('#,##0', 'en_US');

  /// Formats an amount with standard thousand separators (e.g. `Rs 1,100,000.00`).
  static String exact(double amount, {String currency = ''}) {
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();
    return '$sign$currency${_commaDecimalFmt.format(abs)}';
  }

  /// Formats an integer/quantity with commas (e.g. `1,250`).
  static String count(num value) {
    return _commaIntFmt.format(value);
  }

  /// Formats amounts with clear comma separators (e.g. `Rs 5,610,000.00`)
  /// instead of abbreviated Lakh/Million labels.
  static String compact(double amount, {String currency = ''}) {
    return exact(amount, currency: currency);
  }

  /// Formats as exact comma-separated currency.
  static String withCompactHint(double amount, {String currency = ''}) {
    return exact(amount, currency: currency);
  }

  /// Converts [amount] into words in [languageCode] (e.g. `Ten Thousand` or `دس ہزار`).
  static String inWords(double amount, {String languageCode = 'en'}) {
    return AmountInWords.convert(amount, languageCode: languageCode);
  }

  /// Converts [amount] into words using the secondary language when enabled,
  /// otherwise the primary language.
  static String inActiveWords(double amount, {BusinessSettings? settings}) {
    final active = settings ?? PosLocalization.currentSettings;
    final lang = (active != null && active.hasEffectiveSecondaryLanguage)
        ? active.secondaryLanguage
        : (active?.activePrimaryLanguage ?? 'en');
    return AmountInWords.convert(amount, languageCode: lang);
  }
}
