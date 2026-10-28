import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/print_service.dart';

void main() {
  group('Smart POS Universal Printing & Bill Customization Tests', () {
    late BusinessSettings testSettings;
    late Sale testSale;
    late Product testProduct;
    late Contact testCustomer;

    setUp(() {
      testSettings = BusinessSettings(
        businessName: 'Al-Madina Mart & Wholesale',
        branchName: 'Main Bazaar Branch',
        address: 'Shop # 12, Commercial Market, Lahore',
        phone: '+92 300 1234567',
        email: 'info@almadinamart.pk',
        taxNumber: 'NTN-9876543-1',
        currencySymbol: 'Rs. ',
        currencyCode: 'PKR',
        receiptPaperSize: '80mm',
        receiptHeaderTagline: 'Premier Quality & Wholesale Rates',
        receiptHeaderNote: 'Thank you for shopping with us!',
        receiptReturnPolicy: 'Exchange within 7 days with original receipt.',
        showLogoOnReceipt: true,
        showBarcodeOnReceipt: true,
        showQrOnReceipt: true,
        showCustomerBalanceOnReceipt: true,
        showTaxBreakdownOnReceipt: true,
        showCashierNameOnReceipt: true,
        invoicePrintCopies: 1,
      );

      testSale = Sale(
        id: 101,
        invoiceNo: 'INV-2026-0099',
        customerId: 5,
        customerName: 'Chaudhry Traders & Co',
        subtotal: 5000.0,
        discount: 200.0,
        taxAmount: 250.0,
        totalAmount: 5050.0,
        paidAmount: 3000.0,
        paymentMethod: 'cash',
        paymentStatus: 'partial',
        saleStatus: 'final',
        createdAt: '2026-10-27 18:30:00',
        userName: 'Zahid Mehmood',
        items: [
          SaleItem(
            id: 1,
            saleId: 101,
            productId: 10,
            productName: 'Basmati Rice 5kg Super Premium',
            sku: 'RICE-005',
            quantity: 2,
            unitPrice: 2000.0,
            subtotal: 4000.0,
          ),
          SaleItem(
            id: 2,
            saleId: 101,
            productId: 11,
            productName: 'Dal Chana Special 1kg',
            sku: 'DAL-001',
            quantity: 4,
            unitPrice: 250.0,
            subtotal: 1000.0,
          ),
        ],
      );

      testProduct = Product(
        id: 10,
        name: 'Basmati Rice 5kg Super Premium',
        sku: 'RICE-005',
        barcode: '896400012345',
        categoryName: 'Grains & Pulses',
        purchasePrice: 1750.0,
        sellingPrice: 2000.0,
        stockQuantity: 45.0,
        unit: 'Bag',
      );

      testCustomer = Contact(
        id: 5,
        name: 'Chaudhry Traders & Co',
        type: 'customer',
        phone: '0321-9876543',
        address: 'Grain Market Shop 45, Gujranwala',
        creditLimit: 50000.0,
        balance: 24500.0,
      );
    });

    test('1. Thermal Bill (80mm) generation contains brand, items, dues, and return policy', () {
      final html = PrintService.generateSaleInvoiceHtml(
        sale: testSale,
        settings: testSettings,
        tenderedAmount: 5000.0,
        changeReturn: 1950.0,
        paperSizeOverride: '80mm',
      );

      expect(html, contains('AL-MADINA MART &amp; WHOLESALE'));
      expect(html, contains('Main Bazaar Branch'));
      expect(html, contains('Premier Quality &amp; Wholesale Rates'));
      expect(html, contains('INV-2026-0099'));
      expect(html, contains('Basmati Rice 5kg Super Premium'));
      expect(html, contains('Dal Chana Special 1kg'));
      expect(html, contains('Chaudhry Traders &amp; Co'));
      expect(html, contains('Zahid Mehmood'));
      expect(html, contains('CURRENT BILL DUE:'));
      expect(html, contains('Exchange within 7 days with original receipt.'));
      expect(html, contains('window.print()'));
    });

    test('2. Quotation / Estimate generation outputs formal commercial estimate with terms', () {
      final html = PrintService.generateQuotationHtml(
        sale: testSale,
        settings: testSettings,
        validDays: '15',
      );

      expect(html, contains('COMMERCIAL QUOTATION'));
      expect(html, contains('REF: INV-2026-0099'));
      expect(html, contains('Chaudhry Traders &amp; Co'));
      expect(html, contains('VALIDITY: 15 Days'));
      expect(html, contains('TERMS & CONDITIONS OF QUOTATION:'));
      expect(html, contains('Authorized Signatory'));
    });

    test('3. Price List / Catalog generation renders structured price sheet with margins', () {
      final html = PrintService.generatePriceListHtml(
        products: [testProduct],
        settings: testSettings,
        categoryFilter: 'All Categories',
      );

      expect(html, contains('Official Product Rate Card & Price Catalog'));
      expect(html, contains('Basmati Rice 5kg Super Premium'));
      expect(html, contains('RICE-005'));
      expect(html, contains('Grains &amp; Pulses'));
      expect(html, contains('45 in stock'));
    });

    test('4. Defaulters List generation outputs recovery collection sheet with signatures', () {
      final html = PrintService.generateDefaultersListHtml(
        defaulters: [testCustomer],
        settings: testSettings,
      );

      expect(html, contains('CREDIT DEFAULTERS & OUTSTANDING RECEIVABLES RECOVERY SHEET'));
      expect(html, contains('Chaudhry Traders &amp; Co'));
      expect(html, contains('0321-9876543'));
      expect(html, contains('Grain Market Shop 45, Gujranwala'));
      expect(html, contains('Rs. 24500.00'));
      expect(html, contains('Recovery Officer Signature:'));
    });

    test('5. Executive Business Report outputs financial statements and metrics', () {
      final reportData = {
        'totalSales': 1500000.0,
        'netSales': 1450000.0,
        'totalPurchases': 900000.0,
        'totalExpenses': 85000.0,
        'grossProfit': 550000.0,
        'netProfit': 465000.0,
        'totalReceivable': 320000.0,
        'totalPayable': 150000.0,
        'totalStockCost': 2400000.0,
      };

      final html = PrintService.generateReportHtml(
        title: 'Monthly Financial Performance Statement',
        reportData: reportData,
        settings: testSettings,
        dateRange: '01 Oct 2026 - 31 Oct 2026',
      );

      expect(html, contains('AL-MADINA MART &amp; WHOLESALE'));
      expect(html, contains('Monthly Financial Performance Statement'));
      expect(html, contains('01 Oct 2026 - 31 Oct 2026'));
      expect(html, contains('Net Sales Revenue'));
      expect(html, contains('Total Purchases (Stock)'));
      expect(html, contains('Operating Expenses'));
      expect(html, contains('NET BUSINESS PROFIT'));
    });
  });
}
