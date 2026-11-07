import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/currency_rate_service.dart';
import 'package:desktop_starter/services/regional_data_service.dart';
import 'package:desktop_starter/screens/pos/payment_modal.dart';

void main() {
  group('CurrencyRateService Unit Tests', () {
    test('1. Default rates for PKR base contain USD, SAR, AED with proper defaults', () {
      final rates = CurrencyRateService.defaultRatesForBase('PKR');
      expect(rates.isNotEmpty, isTrue);

      final usd = rates.firstWhere((r) => r.code == 'USD');
      expect(usd.symbol, equals('\$'));
      expect(usd.liveRate, greaterThan(200.0));
      expect(usd.effectiveRate, equals(280.00)); // Default custom counter rate

      final sar = rates.firstWhere((r) => r.code == 'SAR');
      expect(sar.symbol, equals('﷼'));
      expect(sar.effectiveRate, equals(74.50));

      final aed = rates.firstWhere((r) => r.code == 'AED');
      expect(aed.effectiveRate, equals(76.00));
    });

    test('2. Dual Tender Calculation converts foreign money accurately', () {
      // Bill: Rs 2,800. Rate: 1 USD = Rs 280.00
      // Customer pays $20 USD. Base equivalent = Rs 5,600.
      // Change in PKR = Rs 2,800. Change in USD = $10.00
      final result = CurrencyRateService.calculateTender(
        baseGrandTotal: 2800.00,
        foreignTendered: 20.00,
        effectiveRate: 280.00,
      );

      expect(result.foreignGrandTotal, equals(10.00));
      expect(result.baseEquivalentTendered, equals(5600.00));
      expect(result.baseChange, equals(2800.00));
      expect(result.foreignChange, equals(10.00));
      expect(result.baseBalanceDue, equals(0.0));
      expect(result.isFullyPaid, isTrue);
    });

    test('3. Dual Tender Calculation handles partial / underpaid amount', () {
      // Bill: Rs 2,800. Rate: 1 USD = Rs 280.00
      // Customer gives only $5 USD (worth Rs 1,400)
      final result = CurrencyRateService.calculateTender(
        baseGrandTotal: 2800.00,
        foreignTendered: 5.00,
        effectiveRate: 280.00,
      );

      expect(result.foreignGrandTotal, equals(10.00));
      expect(result.baseEquivalentTendered, equals(1400.00));
      expect(result.baseChange, equals(0.0));
      expect(result.baseBalanceDue, equals(1400.00));
      expect(result.foreignBalanceDue, equals(5.00));
      expect(result.isFullyPaid, isFalse);
    });

    test('4. Free Open API Exchange Rates Parser correctly computes cross rates from mock JSON', () async {
      final mockJson = jsonEncode({
        'result': 'success',
        'base_code': 'USD',
        'rates': {
          'USD': 1.0,
          'PKR': 276.50,
          'SAR': 3.75,
          'AED': 3.6725,
          'EUR': 0.90,
          'GBP': 0.75,
        }
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final syncRes = await CurrencyRateService.fetchLiveRates(
        baseCurrency: 'PKR',
        client: mockClient,
      );

      expect(syncRes.success, isTrue);
      expect(syncRes.rates.isNotEmpty, isTrue);

      final usd = syncRes.rates.firstWhere((r) => r.code == 'USD');
      // 1 USD = 276.50 / 1.0 = 276.50 PKR
      expect(usd.liveRate, closeTo(276.50, 0.01));

      final sar = syncRes.rates.firstWhere((r) => r.code == 'SAR');
      // 1 SAR = 276.50 / 3.75 = 73.73 PKR
      expect(sar.liveRate, closeTo(73.73, 0.05));

      final aed = syncRes.rates.firstWhere((r) => r.code == 'AED');
      // 1 AED = 276.50 / 3.6725 = 75.29 PKR
      expect(aed.liveRate, closeTo(75.29, 0.05));
    });

    test('5. JSON Serialization and Deserialization preserve custom rates and enable status', () {
      final original = [
        const CurrencyRate(
          code: 'USD',
          symbol: '\$',
          name: 'US Dollar',
          country: 'United States',
          liveRate: 276.45,
          customRate: 282.50,
          isEnabled: true,
        ),
        const CurrencyRate(
          code: 'SAR',
          symbol: '﷼',
          name: 'Saudi Riyal',
          country: 'Saudi Arabia',
          liveRate: 73.72,
          customRate: null,
          isEnabled: false,
        ),
      ];

      final jsonStr = CurrencyRateService.encodeRatesJson(original);
      final restored = CurrencyRateService.parseRatesJson(jsonStr, 'PKR');

      expect(restored.length, equals(2));
      expect(restored[0].code, equals('USD'));
      expect(restored[0].customRate, equals(282.50));
      expect(restored[0].effectiveRate, equals(282.50));
      expect(restored[0].isEnabled, isTrue);

      expect(restored[1].code, equals('SAR'));
      expect(restored[1].customRate, isNull);
      expect(restored[1].effectiveRate, equals(73.72));
      expect(restored[1].isEnabled, isFalse);
    });
  });

  group('Regional Currency Dataset Tests', () {
    test('RegionalDataService contains all major world currencies with flags and symbols', () {
      expect(RegionalDataService.allCurrencies.length, greaterThanOrEqualTo(100));

      final pkr = RegionalDataService.findCurrency('PKR');
      expect(pkr, isNotNull);
      expect(pkr!.symbol, equals('Rs'));
      expect(pkr.country, equals('Pakistan'));

      final sar = RegionalDataService.findCurrency('SAR');
      expect(sar, isNotNull);
      expect(sar!.country, equals('Saudi Arabia'));

      final aed = RegionalDataService.findCurrency('AED');
      expect(aed, isNotNull);
      expect(aed!.country, equals('United Arab Emirates'));
    });
  });

  group('PaymentModal Multi-Currency Widget Tests', () {
    testWidgets('PaymentModal displays multi-currency selector and calculates USD dual tender', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final rates = [
        const CurrencyRate(
          code: 'USD',
          symbol: '\$',
          name: 'US Dollar',
          country: 'United States',
          liveRate: 280.0,
          customRate: 280.0,
          isEnabled: true,
        ),
      ];

      Map<String, dynamic>? checkoutResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  checkoutResult = await showDialog<Map<String, dynamic>>(
                    context: ctx,
                    builder: (_) => PaymentModal(
                      grandTotal: 2800.00,
                      currencySymbol: 'Rs',
                      customerName: 'Haji Abdullah Traders',
                      isWalkIn: true,
                      currencyCode: 'PKR',
                      multiCurrencyEnabled: true,
                      availableRates: rates,
                    ),
                  );
                },
                child: const Text('Open Payment'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Payment'));
      await tester.pumpAndSettle();

      // Check header and grand total
      expect(find.text('TOTAL PAYABLE AMOUNT'), findsOneWidget);
      expect(find.text('Rs2800.00'), findsOneWidget);
      expect(find.text('PAYMENT CURRENCY (ادائیگی کی کرنسی)'), findsOneWidget);

      // Select USD Chip
      final usdChip = find.textContaining('\$ USD');
      expect(usdChip, findsOneWidget);
      await tester.tap(usdChip);
      await tester.pumpAndSettle();

      // Foreign Total display: 2800 / 280 = $10.00
      expect(find.text('TOTAL IN USD:'), findsOneWidget);
      expect(find.text('\$10.00'), findsOneWidget);

      // Tap quick $20 button
      final btn20 = find.text('\$ 20');
      expect(btn20, findsOneWidget);
      await tester.tap(btn20);
      await tester.pumpAndSettle();

      // Change in PKR: Rs 2800.00; Change in USD: $10.00
      expect(find.text('Rs2800.00'), findsWidgets);
      expect(find.text('or \$10.00 USD'), findsOneWidget);

      // Confirm payment
      final confirmBtn = find.text('FINALIZE PAYMENT');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(checkoutResult, isNotNull);
      expect(checkoutResult!['tenderCurrency'], equals('USD'));
      expect(checkoutResult!['foreignTendered'], equals(20.0));
      expect(checkoutResult!['change'], equals(2800.0));
      expect(checkoutResult!['exchangeRate'], equals(280.0));
      expect(checkoutResult!['note'], contains('Foreign Currency Tender: USD'));
    });
  });
}
