import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/print_service.dart';

void main() {
  test(
      'PrintService generates A4 invoice HTML and converts to headless PDF bytes',
      () async {
    final settings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );
    final sale = Sale(
      invoiceNo: 'INV-1004',
      customerName: 'Walk-in Customer',
      subtotal: 93500.0,
      discount: 0.0,
      taxAmount: 0.0,
      taxRate: 0.0,
      shipping: 0.0,
      totalAmount: 93500.0,
      paidAmount: 93500.0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      saleStatus: 'final',
      createdAt: '2026-11-27 14:03:14',
      items: [
        SaleItem(
          saleId: 1,
          productId: 1,
          productName: 'Longi 750 watt A grade',
          sku: 'SOL-750',
          quantity: 4,
          unitPrice: 23375.0,
          subtotal: 93500.0,
          unitName: 'Pieces (Pc)',
        ),
      ],
    );

    final html = PrintService.generateSaleInvoiceHtml(
      sale: sale,
      settings: settings,
      paperSizeOverride: 'A4 Agency',
    );
    expect(html, contains('ALHAMD SOLAR AGENCY'));
    expect(html, contains('INV-1004'));

    final pdfBytes = await PrintService.htmlToPdfBytes(
      html,
      title: 'Invoice_INV-1004',
    );
    expect(pdfBytes, isNotNull);
    expect(pdfBytes!.length, greaterThan(1000));
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');

    final preview = await PrintService.buildWindowsPrintPreview(pdfBytes);
    expect(preview.pagePngs, isNotEmpty);
    expect(preview.pagePngs.first.take(4).toList(), [137, 80, 78, 71]);
    expect(preview.printers, isNotEmpty);
  });
}
