import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Data model representing a foreign exchange rate for cash counter & POS dual tender.
class CurrencyRate {
  final String code; // ISO code: USD, SAR, AED, EUR, GBP, etc.
  final String symbol; // $, ﷼, د.إ, €, £, etc.
  final String name; // US Dollar, Saudi Riyal, UAE Dirham, etc.
  final String country; // United States, Saudi Arabia, etc.
  final double liveRate; // Live interbank rate (1 Foreign Unit = X Base Units)
  final double? customRate; // Merchant custom counter rate (e.g. cash market rate)
  final bool isEnabled; // Active for POS checkout tender

  const CurrencyRate({
    required this.code,
    required this.symbol,
    required this.name,
    required this.country,
    required this.liveRate,
    this.customRate,
    this.isEnabled = true,
  });

  /// The effective exchange rate applied at POS cash counter:
  /// Uses merchant's custom rate if configured (> 0), otherwise falls back to live interbank rate.
  double get effectiveRate {
    if (customRate != null && customRate! > 0) {
      return customRate!;
    }
    return liveRate > 0 ? liveRate : 1.0;
  }

  CurrencyRate copyWith({
    String? code,
    String? symbol,
    String? name,
    String? country,
    double? liveRate,
    double? customRate,
    bool? isEnabled,
  }) {
    return CurrencyRate(
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      country: country ?? this.country,
      liveRate: liveRate ?? this.liveRate,
      customRate: customRate ?? this.customRate,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'symbol': symbol,
        'name': name,
        'country': country,
        'live_rate': liveRate,
        'custom_rate': customRate,
        'is_enabled': isEnabled ? 1 : 0,
      };

  factory CurrencyRate.fromMap(Map<String, dynamic> map) => CurrencyRate(
        code: (map['code'] as String?)?.toUpperCase() ?? 'USD',
        symbol: map['symbol'] as String? ?? '\$',
        name: map['name'] as String? ?? '',
        country: map['country'] as String? ?? '',
        liveRate: (map['live_rate'] as num?)?.toDouble() ?? 1.0,
        customRate: (map['custom_rate'] as num?)?.toDouble(),
        isEnabled: map['is_enabled'] == 1 || map['is_enabled'] == true,
      );
}

/// Service managing Live Exchange Rates via free Open API & Multi-Currency Sales Calculations
class CurrencyRateService {
  /// Completely free open exchange rate API endpoints (No API key required, 100% free)
  static const String openErApiUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String fallbackApiUrl = 'https://api.exchangerate-api.com/v4/latest/USD';

  /// Standard curated trade currencies for cash counter checkout
  static List<CurrencyRate> defaultRatesForBase(String baseCurrency) {
    final base = baseCurrency.toUpperCase();
    final isPkr = base == 'PKR';

    // Baseline offline rates for PKR base
    return [
      CurrencyRate(
        code: 'USD',
        symbol: '\$',
        name: 'US Dollar',
        country: 'United States',
        liveRate: isPkr ? 277.50 : 1.0,
        customRate: isPkr ? 280.00 : null,
        isEnabled: true,
      ),
      CurrencyRate(
        code: 'SAR',
        symbol: '﷼',
        name: 'Saudi Riyal',
        country: 'Saudi Arabia',
        liveRate: isPkr ? 74.00 : 0.27,
        customRate: isPkr ? 74.50 : null,
        isEnabled: true,
      ),
      CurrencyRate(
        code: 'AED',
        symbol: 'د.إ',
        name: 'UAE Dirham',
        country: 'United Arab Emirates',
        liveRate: isPkr ? 75.50 : 0.27,
        customRate: isPkr ? 76.00 : null,
        isEnabled: true,
      ),
      CurrencyRate(
        code: 'EUR',
        symbol: '€',
        name: 'Euro',
        country: 'European Union',
        liveRate: isPkr ? 302.00 : 1.09,
        customRate: isPkr ? 305.00 : null,
        isEnabled: true,
      ),
      CurrencyRate(
        code: 'GBP',
        symbol: '£',
        name: 'British Pound',
        country: 'United Kingdom',
        liveRate: isPkr ? 355.00 : 1.30,
        customRate: isPkr ? 360.00 : null,
        isEnabled: true,
      ),
      CurrencyRate(
        code: 'AFN',
        symbol: '؋',
        name: 'Afghan Afghani',
        country: 'Afghanistan',
        liveRate: isPkr ? 4.10 : 0.015,
        customRate: isPkr ? 4.25 : null,
        isEnabled: isPkr,
      ),
      CurrencyRate(
        code: 'CNY',
        symbol: '¥',
        name: 'Chinese Yuan',
        country: 'China',
        liveRate: isPkr ? 38.50 : 0.14,
        customRate: isPkr ? 39.00 : null,
        isEnabled: false,
      ),
      CurrencyRate(
        code: 'CAD',
        symbol: 'C\$',
        name: 'Canadian Dollar',
        country: 'Canada',
        liveRate: isPkr ? 198.00 : 0.72,
        customRate: isPkr ? 200.00 : null,
        isEnabled: false,
      ),
    ];
  }

  /// Parses saved JSON into list of CurrencyRates with fallback to defaults
  static List<CurrencyRate> parseRatesJson(String? jsonStr, String baseCurrency) {
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return defaultRatesForBase(baseCurrency);
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final list = decoded.map((e) => CurrencyRate.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Error parsing currency rates JSON: $e');
    }
    return defaultRatesForBase(baseCurrency);
  }

  /// Encodes list of CurrencyRates into JSON string for SQLite/MySQL storage
  static String encodeRatesJson(List<CurrencyRate> rates) {
    return jsonEncode(rates.map((r) => r.toMap()).toList());
  }

  /// Fetches live exchange rates from the free Open API without requiring an API key.
  /// Formula: 1 ForeignUnit = (Rates[BaseCurrency] / Rates[ForeignCurrency]) BaseUnits.
  static Future<LiveRateSyncResult> fetchLiveRates({
    required String baseCurrency,
    List<CurrencyRate>? existingRates,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final base = baseCurrency.toUpperCase();
    final currentList = existingRates ?? defaultRatesForBase(base);

    try {
      // 1. Try Primary Open ER-API endpoint
      http.Response response;
      try {
        response = await httpClient
            .get(Uri.parse(openErApiUrl))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Fallback to secondary mirror
        response = await httpClient
            .get(Uri.parse(fallbackApiUrl))
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>? ?? {};

        // Rates are USD-based.
        // Base currency factor: how many units of BaseCurrency per 1 USD
        final baseRatePerUsd = (rawRates[base] as num?)?.toDouble() ?? 1.0;

        final updatedList = <CurrencyRate>[];
        for (final item in currentList) {
          final targetCode = item.code.toUpperCase();
          final targetRatePerUsd = (rawRates[targetCode] as num?)?.toDouble();

          double computedRate = item.liveRate;
          if (targetRatePerUsd != null && targetRatePerUsd > 0) {
            // 1 Unit of Target = (baseRatePerUsd / targetRatePerUsd) Units of Base
            computedRate = double.parse((baseRatePerUsd / targetRatePerUsd).toStringAsFixed(4));
          }

          updatedList.add(item.copyWith(liveRate: computedRate));
        }

        final nowIso = DateTime.now().toIso8601String();
        return LiveRateSyncResult(
          success: true,
          rates: updatedList,
          timestamp: nowIso,
          message: 'Live exchange rates successfully synchronized from open API.',
        );
      } else {
        return LiveRateSyncResult(
          success: false,
          rates: currentList,
          timestamp: DateTime.now().toIso8601String(),
          message: 'HTTP ${response.statusCode}: Failed to fetch live exchange rates.',
        );
      }
    } catch (e) {
      return LiveRateSyncResult(
        success: false,
        rates: currentList,
        timestamp: DateTime.now().toIso8601String(),
        message: 'Network offline or connection failed: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Calculates equivalent amount in foreign currency
  /// Example: Bill is Rs 2800. Rate is 1 USD = Rs 280. Foreign Total = 2800 / 280 = $10.00
  static double calculateForeignAmount({
    required double baseAmount,
    required double effectiveRate,
  }) {
    if (effectiveRate <= 0) return baseAmount;
    return double.parse((baseAmount / effectiveRate).toStringAsFixed(2));
  }

  /// Calculates dual-currency payment change & balance
  static DualTenderResult calculateTender({
    required double baseGrandTotal,
    required double foreignTendered,
    required double effectiveRate,
  }) {
    final rate = effectiveRate > 0 ? effectiveRate : 1.0;
    final baseEquivalentTendered = double.parse((foreignTendered * rate).toStringAsFixed(2));
    final foreignGrandTotal = double.parse((baseGrandTotal / rate).toStringAsFixed(2));

    final baseChange = baseEquivalentTendered > baseGrandTotal
        ? double.parse((baseEquivalentTendered - baseGrandTotal).toStringAsFixed(2))
        : 0.0;
    final foreignChange = rate > 0
        ? double.parse((baseChange / rate).toStringAsFixed(2))
        : 0.0;

    final baseBalanceDue = baseGrandTotal > baseEquivalentTendered
        ? double.parse((baseGrandTotal - baseEquivalentTendered).toStringAsFixed(2))
        : 0.0;
    final foreignBalanceDue = rate > 0
        ? double.parse((baseBalanceDue / rate).toStringAsFixed(2))
        : 0.0;

    return DualTenderResult(
      baseGrandTotal: baseGrandTotal,
      foreignGrandTotal: foreignGrandTotal,
      foreignTendered: foreignTendered,
      baseEquivalentTendered: baseEquivalentTendered,
      baseChange: baseChange,
      foreignChange: foreignChange,
      baseBalanceDue: baseBalanceDue,
      foreignBalanceDue: foreignBalanceDue,
      effectiveRate: rate,
    );
  }
}

/// Result object for live rate synchronization
class LiveRateSyncResult {
  final bool success;
  final List<CurrencyRate> rates;
  final String timestamp;
  final String message;

  LiveRateSyncResult({
    required this.success,
    required this.rates,
    required this.timestamp,
    required this.message,
  });
}

/// Calculation outcome for dual-currency payment checkout
class DualTenderResult {
  final double baseGrandTotal;
  final double foreignGrandTotal;
  final double foreignTendered;
  final double baseEquivalentTendered;
  final double baseChange;
  final double foreignChange;
  final double baseBalanceDue;
  final double foreignBalanceDue;
  final double effectiveRate;

  DualTenderResult({
    required this.baseGrandTotal,
    required this.foreignGrandTotal,
    required this.foreignTendered,
    required this.baseEquivalentTendered,
    required this.baseChange,
    required this.foreignChange,
    required this.baseBalanceDue,
    required this.foreignBalanceDue,
    required this.effectiveRate,
  });

  bool get isFullyPaid => baseBalanceDue <= 0.001;
}
