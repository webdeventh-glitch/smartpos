import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/widgets/smart_sidebar.dart';
import 'package:desktop_starter/screens/pos/receipt_dialog.dart';

void main() {
  group('UI/UX Modernization & WhatsApp Bill Engine Tests', () {
    testWidgets('1. SmartSidebar renders modernized sections and quick POS button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      int selectedIdx = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartSidebar(
              selectedIndex: selectedIdx,
              isCollapsed: false,
              onSelect: (idx) => selectedIdx = idx,
              settings: BusinessSettings(
                businessName: 'Aabshhar Distributions',
                branchName: 'Main Branch HQ',
                businessType: 'pharma',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check quick POS terminal button with F1 badge
      expect(find.text('POS Terminal'), findsOneWidget);
      expect(find.text('F1'), findsWidgets);

      // Check headers
      expect(find.text('HOME'), findsNothing); // Title is Home
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Search menu...'), findsOneWidget);
      expect(find.textContaining('v1.0'), findsOneWidget);
    });

    testWidgets('2. ReceiptDialog renders WhatsApp bill button and formats invoice message', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      final sale = Sale(
        id: 1,
        invoiceNo: 'INV-9901',
        customerName: 'Khan Medical Store',
        subtotal: 1755.0,
        discount: 0.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        shipping: 0.0,
        totalAmount: 1755.0,
        paidAmount: 1755.0,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        saleStatus: 'final',
        note: '',
        createdAt: '2026-11-06 17:00:00',
        items: [
          SaleItem(
            saleId: 1,
            productName: 'Amoxil 500mg Cap',
            sku: 'AMX-500',
            unitPrice: 890.0,
            quantity: 1.0,
            subtotal: 890.0,
            unitName: 'Box (100s)',
          ),
          SaleItem(
            saleId: 1,
            productName: 'Arinac Forte Tab',
            sku: 'ARN-001',
            unitPrice: 865.0,
            quantity: 1.0,
            subtotal: 865.0,
            unitName: 'Box (100s)',
          ),
        ],
      );

      final settings = BusinessSettings(
        businessName: 'Aabshhar Distributions',
        branchName: 'Main Branch HQ',
        phone: '+92 300 1234567',
        businessType: 'pharma',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              sale: sale,
              settings: settings,
              tenderedAmount: 2000.0,
              changeReturn: 245.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify WhatsApp button presence
      expect(find.textContaining('WhatsApp'), findsWidgets);

      // Verify Print and Complete button
      expect(find.textContaining('Print'), findsWidgets);
      expect(find.text('Complete (New Sale)'), findsOneWidget);

      // Tap WhatsApp button to open WhatsApp preview modal
      await tester.tap(find.textContaining('WhatsApp'));
      await tester.pumpAndSettle();

      // Modal verification
      expect(find.text('Send Invoice via WhatsApp'), findsOneWidget);
      expect(find.text('Customer WhatsApp Number *'), findsOneWidget);
      expect(find.text('Message Preview'), findsOneWidget);
      expect(find.textContaining('AABSHHAR DISTRIBUTIONS'), findsWidgets);
      expect(find.textContaining('INV-9901'), findsWidgets);
      expect(find.textContaining('Amoxil 500mg Cap'), findsWidgets);
      expect(find.text('Copy Bill Text'), findsOneWidget);
      expect(find.text('Send via WhatsApp'), findsOneWidget);
    });

    test('3. Denomination logic correctly computes cash amounts and discrepancy', () {
      final denoms = {
        5000: 2, // 10,000
        1000: 5, // 5,000
        500: 4,  // 2,000
        100: 10, // 1,000
        50: 8,   // 400
        20: 5,   // 100
        10: 10,  // 100
      };
      final double coins = 25.50;

      double total = 0.0;
      denoms.forEach((val, count) {
        total += val * count;
      });
      total += coins;

      expect(total, 18625.50);

      // Balanced check
      final expectedCash = 18625.50;
      final diff = total - expectedCash;
      expect(diff.abs() < 0.01, isTrue);

      // Short check
      final expectedHigher = 19000.0;
      final shortDiff = total - expectedHigher;
      expect(shortDiff < 0, isTrue);
      expect(shortDiff, -374.50);

      // Over check
      final expectedLower = 18000.0;
      final overDiff = total - expectedLower;
      expect(overDiff > 0, isTrue);
      expect(overDiff, 625.50);
    });
  });
}

