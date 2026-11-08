import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/print_service.dart';

void main() {
  group('Invoice Layout & A4 Customization Tests', () {
    test('1. BusinessSettings serialization preserves Invoice Layout toggles', () {
      final settings = BusinessSettings(
        invoiceLayoutDesign: 'detailed',
        showBatchOnInvoice: true,
        showExpiryOnInvoice: true,
        showBrandOnInvoice: true,
        showSkuOnInvoice: true,
        showWarrantyOnInvoice: true,
        showTotalInWords: true,
        invoiceHeading: 'COMMERCIAL INVOICE',
      );

      final map = settings.toMap();
      expect(map['invoice_layout_design'], 'detailed');
      expect(map['show_batch_on_invoice'], 1);
      expect(map['show_expiry_on_invoice'], 1);
      expect(map['show_brand_on_invoice'], 1);
      expect(map['show_sku_on_invoice'], 1);
      expect(map['show_warranty_on_invoice'], 1);
      expect(map['show_total_in_words'], 1);
      expect(map['invoice_heading'], 'COMMERCIAL INVOICE');

      final reconstructed = BusinessSettings.fromMap(map);
      expect(reconstructed.invoiceLayoutDesign, 'detailed');
      expect(reconstructed.showBatchOnInvoice, true);
      expect(reconstructed.showExpiryOnInvoice, true);
      expect(reconstructed.showBrandOnInvoice, true);
      expect(reconstructed.showSkuOnInvoice, true);
      expect(reconstructed.showWarrantyOnInvoice, true);
      expect(reconstructed.showTotalInWords, true);
      expect(reconstructed.invoiceHeading, 'COMMERCIAL INVOICE');
    });

    test('2. generateA4AgencyInvoiceHtml includes Batch and Expiry when enabled', () {
      final settings = BusinessSettings(
        businessName: 'Al-Madina Pharma & Distribution',
        branchName: 'Main Agency HQ',
        businessType: 'pharmacy',
        receiptPaperSize: 'a4',
        showBatchOnInvoice: true,
        showExpiryOnInvoice: true,
        showWarrantyOnInvoice: true,
        showTotalInWords: true,
        showCustomerBalanceOnReceipt: true,
        isConfigured: true,
      );

      final sale = Sale(
        id: 101,
        invoiceNo: 'AGY-2026-901',
        customerName: 'Khyber Medicos',
        customerId: 5,
        subtotal: 1000.0,
        totalAmount: 1000.0,
        paidAmount: 800.0,
        createdAt: '2026-11-08 12:00:00',
        items: [
          SaleItem(
            saleId: 101,
            productName: 'Amoxil 500mg Caps',
            sku: 'AMX-500',
            unitPrice: 250.0,
            quantity: 4,
            subtotal: 1000.0,
            batchNumber: 'LOT-9988',
            expiryDate: '10/2028',
          ),
        ],
      );

      final html = PrintService.generateA4AgencyInvoiceHtml(
        sale: sale,
        settings: settings,
        customerPreviousBalance: 500.0,
      );

      expect(html.contains('BATCH'), true);
      expect(html.contains('EXP-DATE'), true);
      expect(html.contains('LOT-9988'), true);
      expect(html.contains('10/2028'), true);
      expect(html.contains('PREVIOUS BALANCE'), true);
      expect(html.contains('WARRANTY :-'), true);
      expect(html.contains('Amount in Words:'), true);
    });

    test('3. generateA4AgencyInvoiceHtml excludes Batch and Expiry when disabled in Classic mode', () {
      final settings = BusinessSettings(
        businessName: 'General Store Wholesale',
        branchName: 'Warehouse 1',
        receiptPaperSize: 'a4',
        showBatchOnInvoice: false,
        showExpiryOnInvoice: false,
        showWarrantyOnInvoice: false,
        showTotalInWords: false,
        showCustomerBalanceOnReceipt: false,
        isConfigured: true,
      );

      final sale = Sale(
        id: 102,
        invoiceNo: 'INV-1002',
        customerName: 'Walk-in Cash Customer',
        customerId: 1,
        subtotal: 500.0,
        totalAmount: 500.0,
        paidAmount: 500.0,
        createdAt: '2026-11-08 12:00:00',
        items: [
          SaleItem(
            saleId: 102,
            productName: 'T-Shirt Cotton Large',
            sku: 'TSH-001',
            unitPrice: 500.0,
            quantity: 1,
            subtotal: 500.0,
          ),
        ],
      );

      final html = PrintService.generateA4AgencyInvoiceHtml(
        sale: sale,
        settings: settings,
      );

      expect(html.contains('<th>BATCH</th>'), false);
      expect(html.contains('<th>EXP-DATE</th>'), false);
      expect(html.contains('WARRANTY :-'), false);
    });
  });
}
