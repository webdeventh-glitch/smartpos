import 'package:intl/intl.dart';

/// Utility for formatting currency and large numeric values with comma separators
/// and human-readable Lakh / Million / Billion suffixes.
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

  /// Formats large amounts into Lakh, Million, or Billion for quick reading:
  /// - >= 1,000,000,000 -> Billion (e.g. `Rs 1.25 Billion`)
  /// - >= 1,000,000     -> Million (e.g. `Rs 1.10 Million`)
  /// - >= 100,000       -> Lakh    (e.g. `Rs 5.50 Lakh`)
  /// - <  100,000       -> Comma-formatted exact (e.g. `Rs 45,500.00`)
  static String compact(double amount, {String currency = ''}) {
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();
    if (abs >= 1e9) {
      return '$sign$currency${(abs / 1e9).toStringAsFixed(2)} Billion';
    }
    if (abs >= 1e6) {
      return '$sign$currency${(abs / 1e6).toStringAsFixed(2)} Million';
    }
    if (abs >= 1e5) {
      return '$sign$currency${(abs / 1e5).toStringAsFixed(2)} Lakh';
    }
    return '$sign$currency${_commaDecimalFmt.format(abs)}';
  }

  /// Formats as exact with compact scale in parentheses for detailed report rows
  /// (e.g. `Rs 1,100,000.00 (1.10 Million)`), or just exact if under 1 Lakh.
  static String withCompactHint(double amount, {String currency = ''}) {
    final abs = amount.abs();
    final exactStr = exact(amount, currency: currency);
    if (abs >= 1e5) {
      final compactOnly = compact(amount, currency: '').replaceFirst('-', '');
      return '$exactStr ($compactOnly)';
    }
    return exactStr;
  }
}
