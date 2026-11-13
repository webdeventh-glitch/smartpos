import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/settings/invoice_layouts_manager.dart';
import 'package:desktop_starter/screens/settings/printer_management_section.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/pdf_export_service.dart';
import 'package:desktop_starter/services/thermal_printer_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    await AuthService.logout();
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseService.suppressSync = true;
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase4_');
    dbPath = p.join(tempDir.path, 'phase4_test.db');
    dbService = await DatabaseService.initialize(customPath: dbPath);
  });

  tearDown(() async {
    await AuthService.logout();
    DatabaseService.suppressSync = false;
    await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Sale buildSampleSale({String status = 'final'}) => Sale(
        id: 1,
        invoiceNo: status == 'quotation' ? 'QT-2026-09' : 'INV-2026-44',
        customerName: 'Ayesha Traders',
        subtotal: 2000.0,
        discount: 100.0,
        taxAmount: 95.0,
        taxBreakdownJson: '{"GST 5%": 95.0}',
        totalAmount: 1995.0,
        paidAmount: status == 'quotation' ? 0.0 : 2000.0,
        paymentMethod: status == 'quotation' ? 'none' : 'cash',
        paymentStatus: status == 'quotation' ? 'due' : 'paid',
        saleStatus: status,
        cashierName: 'Cashier #1',
        createdAt: '2026-11-11 19:00:00',
        items: [
          SaleItem(
            saleId: 1,
            productId: 10,
            productName: 'Paracetamol 500mg Box',
            sku: 'MED-500',
            quantity: 4,
            unitPrice: 500.0,
            discountType: 'percentage',
            discountValue: 5.0,
            subtotal: 1900.0,
            batchNumber: 'BN-88',
            expiryDate: '12/2027',
          ),
        ],
      );

  group('Phase 4 Step 4.1 - ESC/POS Thermal Printing & KOT', () {
    test('Builds valid 80mm and 58mm ESC/POS binary receipts and KOT tickets',
        () async {
      final settings = BusinessSettings(
        businessName: 'City Mart',
        branchName: 'Lahore Branch',
        currencySymbol: 'Rs',
        phone: '03001112233',
      );
      final sale = buildSampleSale();

      final bytes80 = await ThermalPrinterService.buildSaleReceiptBytes(
        sale: sale,
        settings: settings,
        paperWidth: '80mm',
        tenderedAmount: 2000.0,
        changeReturn: 5.0,
        openDrawer: true,
        autoCut: true,
      );
      final bytes58 = await ThermalPrinterService.buildSaleReceiptBytes(
        sale: sale,
        settings: settings,
        paperWidth: '58mm',
      );

      expect(bytes80.length, greaterThan(100));
      expect(bytes58.length, greaterThan(100));
      // ESC @ init command present
      expect(bytes80.take(2).toList(), [0x1B, 0x40]);
      // Contains merchant & invoice ASCII payload
      final ascii80 =
          String.fromCharCodes(bytes80.where((b) => b >= 32 && b <= 126));
      expect(ascii80, contains('CITY MART'));
      expect(ascii80, contains('INV-2026-44'));
      expect(ascii80, contains('Paracetamol 500mg Box'));

      final kotBytes = await ThermalPrinterService.buildKotTicketBytes(
        table: 'Table 04',
        waiter: 'Usman',
        diningMode: 'dine_in',
        items: [
          CartItem(
            product: Product(
              name: 'Chicken Biryani Full',
              sku: 'FOOD-1',
              barcode: 'FOOD-1',
              purchasePrice: 200,
              sellingPrice: 450,
              stockQuantity: 10,
            ),
            quantity: 2,
            unitPrice: 450,
          ),
        ],
        settings: settings,
        kotNumber: 'KOT-17',
      );
      final kotAscii =
          String.fromCharCodes(kotBytes.where((b) => b >= 32 && b <= 126));
      expect(kotAscii, contains('KITCHEN ORDER TICKET'));
      expect(kotAscii, contains('Table 04'));
      expect(kotAscii, contains('Chicken Biryani Full'));
    });

    test(
        'Persists ThermalPrinterConfig CRUD and dispatches raw ESC/POS bytes over TCP socket',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final receivedCompleter = Completer<List<int>>();
      final collected = <int>[];
      late StreamSubscription<Socket> sub;
      sub = server.listen((client) {
        client.listen(
          (chunk) => collected.addAll(chunk),
          onDone: () {
            if (!receivedCompleter.isCompleted) {
              receivedCompleter.complete(collected);
            }
          },
        );
      });

      try {
        final id = await dbService.savePrinter(
          ThermalPrinterConfig(
            name: 'TCP Thermal 80',
            connectionType: 'network',
            ipAddress: '127.0.0.1',
            port: server.port,
            paperWidth: '80mm',
            isDefault: true,
            isKotPrinter: true,
          ),
        );
        expect(id, greaterThan(0));

        final def = await dbService.getDefaultPrinter();
        final kot = await dbService.getKotPrinter();
        expect(def?.name, 'TCP Thermal 80');
        expect(kot?.id, id);

        final sent = await ThermalPrinterService.printSaleReceipt(
          sale: buildSampleSale(),
          settings: BusinessSettings(businessName: 'Socket Test Store'),
          tenderedAmount: 2000.0,
          changeReturn: 5.0,
        );
        expect(sent, isTrue);

        final received =
            await receivedCompleter.future.timeout(const Duration(seconds: 5));
        expect(received.length, greaterThan(100));
        final text =
            String.fromCharCodes(received.where((b) => b >= 32 && b <= 126));
        expect(text, contains('SOCKET TEST STORE'));
        expect(text, contains('INV-2026-44'));

        await dbService.deletePrinter(id);
        expect(await dbService.getPrinters(), isEmpty);
      } finally {
        await sub.cancel();
        await server.close();
      }
    });
  });

  group('Phase 4 Step 4.2 & 4.3 - PDF Export & Multiple Invoice Layouts', () {
    test(
        'Seeds default InvoiceLayouts and persists custom template fields cleanly',
        () async {
      final layouts = await dbService.getInvoiceLayouts();
      expect(layouts.length, greaterThanOrEqualTo(3));
      expect(layouts.any((l) => l.isDefault), isTrue);

      final customId = await dbService.saveInvoiceLayout(
        InvoiceLayout(
          name: 'Custom Landscape Wholesale',
          design: 'elegant',
          paperSize: 'a4',
          paperOrientation: 'landscape',
          fontSize: 11.0,
          highlightColor: '#047857',
          invoiceHeading: 'WHOLESALE TAX INVOICE',
          showSku: true,
          showBrand: true,
          showImage: true,
          showExpiry: true,
          showBatch: true,
          isDefault: true,
        ),
      );

      final loaded = await dbService.getDefaultInvoiceLayout();
      expect(loaded, isNotNull);
      expect(loaded!.id, customId);
      expect(loaded.paperOrientation, 'landscape');
      expect(loaded.fontSize, 11.0);
      expect(loaded.showImage, isTrue);
      expect(loaded.invoiceHeading, 'WHOLESALE TAX INVOICE');
    });

    test(
        'Generates valid PDF files for Sales, Quotations, Purchases, and Reports',
        () async {
      final settings = BusinessSettings(businessName: 'PDF Enterprise');
      final layout = await dbService.getDefaultInvoiceLayout();

      bool startsWithPdfHeader(Uint8List data) =>
          data.length > 100 &&
          data[0] == 0x25 && // %
          data[1] == 0x50 && // P
          data[2] == 0x44 && // D
          data[3] == 0x46 && // F
          data[4] == 0x2D; // -

      final saleA4 = await PdfExportService.generateSalePdf(
        sale: buildSampleSale(),
        settings: settings,
        layout: layout,
        paperSizeOverride: 'a4',
        customerPreviousBalance: 450.0,
      );
      expect(startsWithPdfHeader(saleA4), isTrue);

      final sale80 = await PdfExportService.generateSalePdf(
        sale: buildSampleSale(),
        settings: settings,
        paperSizeOverride: '80mm',
      );
      expect(startsWithPdfHeader(sale80), isTrue);

      final quotePdf = await PdfExportService.generateQuotationPdf(
        quotation: buildSampleSale(status: 'quotation'),
        settings: settings,
        layout: layout,
      );
      expect(startsWithPdfHeader(quotePdf), isTrue);

      final purchasePdf = await PdfExportService.generatePurchasePdf(
        purchase: Purchase(
          refNo: 'PO-2026-12',
          supplierName: 'MedSupply Co',
          totalAmount: 5000.0,
          paidAmount: 3000.0,
          paymentMethod: 'cash',
          status: 'received',
          paymentStatus: 'partial',
          createdAt: '2026-11-11 10:00:00',
          itemsJson:
              '[{"product_name":"Vitamin C","quantity":10,"purchase_price":500,"subtotal":5000}]',
        ),
        settings: settings,
      );
      expect(startsWithPdfHeader(purchasePdf), isTrue);

      final reportPdf = await PdfExportService.generateReportPdf(
        title: 'Monthly Sales & Profit Summary',
        subtitle: 'Nov 2026',
        headers: const ['Metric', 'Value'],
        rows: const [
          ['Sales Revenue', 'Rs 50,000'],
          ['Net Profit', 'Rs 12,500'],
        ],
        summaryMetrics: const {'Orders': '42', 'Net Profit': 'Rs 12,500'},
        settings: settings,
      );
      expect(startsWithPdfHeader(reportPdf), isTrue);

      final saved = await PdfExportService.savePdfFile(
        saleA4,
        'Test_Invoice_44',
        directoryOverride: tempDir,
      );
      expect(saved.existsSync(), isTrue);
      expect(saved.lengthSync(), saleA4.length);
    });

    testWidgets(
        'PrinterManagementSection & InvoiceLayoutsManager render configured profiles',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(
        () => dbService.savePrinter(
          ThermalPrinterConfig(
            name: 'Epson Kitchen Kot',
            connectionType: 'network',
            ipAddress: '192.168.1.55',
            port: 9100,
            isKotPrinter: true,
          ),
        ),
      );

      final settings = BusinessSettings(businessName: 'UI Print Shop');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PrinterManagementSection(
                    settings: settings,
                    onSettingsUpdated: (_) {},
                  ),
                  InvoiceLayoutsManager(
                    settings: settings,
                    onSettingsUpdated: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ESC/POS Thermal Printers & Auto-Print Setup'),
          findsOneWidget);
      expect(find.text('Epson Kitchen Kot'), findsOneWidget);
      expect(find.text('Saved Invoice Layout Templates (Multi-Template)'),
          findsOneWidget);
      expect(find.text('Detailed A4 Agency'), findsOneWidget);
    });
  });
}
