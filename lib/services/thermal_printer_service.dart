import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:ffi/ffi.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'database_service.dart';

// ===================== WIN32 WINSPOOL.DRV FFI BINDINGS =====================

final class _DocInfo1W extends ffi.Struct {
  external ffi.Pointer<Utf16> pDocName;
  external ffi.Pointer<Utf16> pOutputFile;
  external ffi.Pointer<Utf16> pDatatype;
}

typedef _OpenPrinterNative = ffi.Int32 Function(
  ffi.Pointer<Utf16> pPrinterName,
  ffi.Pointer<ffi.IntPtr> phPrinter,
  ffi.Pointer<ffi.Void> pDefault,
);
typedef _OpenPrinterDart = int Function(
  ffi.Pointer<Utf16> pPrinterName,
  ffi.Pointer<ffi.IntPtr> phPrinter,
  ffi.Pointer<ffi.Void> pDefault,
);

typedef _StartDocPrinterNative = ffi.Uint32 Function(
  ffi.IntPtr hPrinter,
  ffi.Uint32 level,
  ffi.Pointer<_DocInfo1W> pDocInfo,
);
typedef _StartDocPrinterDart = int Function(
  int hPrinter,
  int level,
  ffi.Pointer<_DocInfo1W> pDocInfo,
);

typedef _StartEndPageNative = ffi.Int32 Function(ffi.IntPtr hPrinter);
typedef _StartEndPageDart = int Function(int hPrinter);

typedef _WritePrinterNative = ffi.Int32 Function(
  ffi.IntPtr hPrinter,
  ffi.Pointer<ffi.Uint8> pBuf,
  ffi.Uint32 cbBuf,
  ffi.Pointer<ffi.Uint32> pcWritten,
);
typedef _WritePrinterDart = int Function(
  int hPrinter,
  ffi.Pointer<ffi.Uint8> pBuf,
  int cbBuf,
  ffi.Pointer<ffi.Uint32> pcWritten,
);

typedef _ClosePrinterNative = ffi.Int32 Function(ffi.IntPtr hPrinter);
typedef _ClosePrinterDart = int Function(int hPrinter);

typedef _GetDefaultPrinterNative = ffi.Int32 Function(
  ffi.Pointer<Utf16> pszBuffer,
  ffi.Pointer<ffi.Uint32> pcchBuffer,
);
typedef _GetDefaultPrinterDart = int Function(
  ffi.Pointer<Utf16> pszBuffer,
  ffi.Pointer<ffi.Uint32> pcchBuffer,
);

/// Handles ESC/POS thermal binary generation (58mm & 80mm) and delivery via
/// Network TCP socket (`ip:port`) or Windows RAW print spooler (`winspool.drv`).
class ThermalPrinterService {
  ThermalPrinterService._();

  static const List<String> capabilityProfiles = [
    'default',
    'simple',
    'SP2000',
    'TEP-200M',
    'P822D',
  ];

  static String _asciiSafe(String input) {
    final buf = StringBuffer();
    for (final code in input.runes) {
      if (code >= 32 && code <= 126) {
        buf.writeCharCode(code);
      } else if (code == 10 || code == 13 || code == 9) {
        buf.writeCharCode(code);
      } else {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  static PaperSize _resolvePaperSize(String width) =>
      width.trim().toLowerCase() == '58mm' ? PaperSize.mm58 : PaperSize.mm80;

  static Future<CapabilityProfile> _loadProfile(String name) async {
    try {
      return await CapabilityProfile.load(name: name);
    } catch (e, st) {
      AppLogger.warning(
        'ThermalPrinterService',
        'Capability profile "$name" unavailable; falling back to default.',
        e,
        st,
      );
      return await CapabilityProfile.load(name: 'default');
    }
  }

  /// Generates ESC/POS binary bytes for a [Sale] invoice / receipt on 58mm or 80mm roll.
  static Future<List<int>> buildSaleReceiptBytes({
    required Sale sale,
    required BusinessSettings settings,
    InvoiceLayout? layout,
    String paperWidth = '80mm',
    String capabilityProfile = 'default',
    double tenderedAmount = 0.0,
    double changeReturn = 0.0,
    double? customerPreviousBalance,
    bool autoCut = true,
    bool openDrawer = false,
  }) async {
    final profile = await _loadProfile(capabilityProfile);
    final paperSize = _resolvePaperSize(paperWidth);
    final generator = Generator(paperSize, profile);
    final is58 = paperSize == PaperSize.mm58;
    final chars = is58 ? 32 : 48;
    final cur = _asciiSafe(settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs');
    final activeLayout = layout ?? InvoiceLayout.fromBusinessSettings(settings);

    final List<int> bytes = [];
    bytes.addAll(generator.reset());

    // Header
    if (activeLayout.showBusinessName) {
      bytes.addAll(
        generator.text(
          _asciiSafe(settings.businessName.toUpperCase()),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      );
    }
    if (settings.branchName.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _asciiSafe(settings.branchName),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }
    if (activeLayout.showAddress && settings.address.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _asciiSafe(settings.address),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (activeLayout.showPhone && settings.phone.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _asciiSafe('Tel: ${settings.phone}'),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (activeLayout.showTaxNumber && settings.taxNumber.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _asciiSafe('NTN/Tax: ${settings.taxNumber}'),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (activeLayout.headerText.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _asciiSafe(activeLayout.headerText),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes.addAll(generator.hr(ch: '=', len: chars));

    final heading = sale.isQuotation
        ? 'QUOTATION / ESTIMATE'
        : (activeLayout.invoiceHeading.isNotEmpty
            ? activeLayout.invoiceHeading
            : 'SALES RECEIPT');
    bytes.addAll(
      generator.text(
        _asciiSafe(heading),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    // Meta rows
    bytes.addAll(generator.text(_asciiSafe('Invoice : ${sale.invoiceNo}')));
    bytes.addAll(generator.text(_asciiSafe('Date    : ${sale.createdAt}')));
    bytes.addAll(generator.text(_asciiSafe('Customer: ${sale.customerName}')));
    if (settings.showCashierNameOnReceipt && sale.cashierName.isNotEmpty) {
      bytes.addAll(generator.text(_asciiSafe('Cashier : ${sale.cashierName}')));
    }
    bytes.addAll(
      generator.text(
        _asciiSafe('Payment : ${sale.paymentMethod.toUpperCase()} (${sale.paymentStatus.toUpperCase()})'),
      ),
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    // Columns header
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    // Line items
    final items = sale.items ?? const <SaleItem>[];
    for (final item in items) {
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(2);
      bytes.addAll(
        generator.row([
          PosColumn(text: _asciiSafe(item.productName), width: 6),
          PosColumn(
            text: qtyStr,
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: item.subtotal.toStringAsFixed(2),
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]),
      );

      final detailParts = <String>['@ ${item.unitPrice.toStringAsFixed(2)}'];
      if (activeLayout.showSku && item.sku.isNotEmpty) {
        detailParts.add('SKU:${item.sku}');
      }
      if (activeLayout.showBatch &&
          item.batchNumber != null &&
          item.batchNumber!.isNotEmpty) {
        detailParts.add('B:${item.batchNumber}');
      }
      if (activeLayout.showExpiry &&
          item.expiryDate != null &&
          item.expiryDate!.isNotEmpty) {
        detailParts.add('Exp:${item.expiryDate}');
      }
      if (item.resolvedDiscountAmount > 0) {
        detailParts.add('Disc:${item.formatDiscountTag(cur)}');
      }
      bytes.addAll(
        generator.text(
          _asciiSafe('  ${detailParts.join(' | ')}'),
          styles: const PosStyles(fontType: PosFontType.fontB),
        ),
      );
    }

    bytes.addAll(generator.hr(ch: '-', len: chars));

    void addSummaryLine(String label, String value, {bool bold = false, bool large = false}) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: _asciiSafe(label),
            width: 6,
            styles: PosStyles(
              bold: bold,
              height: large ? PosTextSize.size2 : PosTextSize.size1,
            ),
          ),
          PosColumn(
            text: _asciiSafe(value),
            width: 6,
            styles: PosStyles(
              align: PosAlign.right,
              bold: bold,
              height: large ? PosTextSize.size2 : PosTextSize.size1,
            ),
          ),
        ]),
      );
    }

    addSummaryLine(activeLayout.subTotalLabel, '$cur ${sale.subtotal.toStringAsFixed(2)}');
    if (sale.discount > 0) {
      addSummaryLine(activeLayout.discountLabel, '-$cur ${sale.discount.toStringAsFixed(2)}');
    }
    if (sale.taxAmount > 0) {
      if (settings.showTaxBreakdownOnReceipt && sale.taxBreakdownMap.isNotEmpty) {
        for (final entry in sale.taxBreakdownMap.entries) {
          addSummaryLine(entry.key, '+$cur ${entry.value.toStringAsFixed(2)}');
        }
      }
      addSummaryLine(activeLayout.taxLabel, '+$cur ${sale.taxAmount.toStringAsFixed(2)}');
    }

    bytes.addAll(generator.hr(ch: '=', len: chars));
    addSummaryLine(
      activeLayout.totalLabel.toUpperCase(),
      '$cur ${sale.totalAmount.toStringAsFixed(2)}',
      bold: true,
      large: true,
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    addSummaryLine('Paid', '$cur ${sale.paidAmount.toStringAsFixed(2)}');
    if (tenderedAmount > 0) {
      addSummaryLine('Tendered', '$cur ${tenderedAmount.toStringAsFixed(2)}');
    }
    if (changeReturn > 0) {
      addSummaryLine('Change Return', '$cur ${changeReturn.toStringAsFixed(2)}');
    }
    if (sale.dueAmount > 0) {
      addSummaryLine('Balance Due', '$cur ${sale.dueAmount.toStringAsFixed(2)}', bold: true);
    }
    if (activeLayout.showCustomerBalance &&
        customerPreviousBalance != null &&
        customerPreviousBalance > 0) {
      addSummaryLine(
        'Customer Khata Bal',
        '$cur ${customerPreviousBalance.toStringAsFixed(2)}',
      );
    }

    // Barcode / QR Verification
    final cleanCode = sale.invoiceNo.replaceAll(RegExp(r'[^0-9A-Za-z\-]'), '');
    if (activeLayout.showBarcode && cleanCode.length >= 2 && cleanCode.length <= 24) {
      try {
        bytes.addAll(generator.feed(1));
        bytes.addAll(generator.barcode(Barcode.code128('{B$cleanCode'.split(''))));
      } catch (e, st) {
        AppLogger.warning('ThermalPrinterService', 'Skipped ESC/POS barcode', e, st);
      }
    }
    if (activeLayout.showQrCode) {
      try {
        bytes.addAll(generator.feed(1));
        bytes.addAll(
          generator.qrcode(
            'INV:${sale.invoiceNo}|TOTAL:${sale.totalAmount.toStringAsFixed(2)}|DATE:${sale.createdAt}',
            size: is58 ? QRSize.size3 : QRSize.size4,
          ),
        );
      } catch (e, st) {
        AppLogger.warning('ThermalPrinterService', 'Skipped ESC/POS QR code', e, st);
      }
    }

    if (activeLayout.termsText.trim().isNotEmpty) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(
        generator.text(
          _asciiSafe(activeLayout.termsText),
          styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
        ),
      );
    }
    if (activeLayout.footerText.trim().isNotEmpty) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(
        generator.text(
          _asciiSafe(activeLayout.footerText),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    bytes.addAll(generator.feed(2));
    if (openDrawer) {
      bytes.addAll(generator.drawer());
    }
    if (autoCut) {
      bytes.addAll(generator.cut());
    }
    return bytes;
  }

  /// Generates ESC/POS Kitchen Order Ticket (KOT) bytes for Restaurant / Cafe mode.
  static Future<List<int>> buildKotTicketBytes({
    required String table,
    required String waiter,
    required String diningMode,
    required List<CartItem> items,
    required BusinessSettings settings,
    String paperWidth = '80mm',
    String capabilityProfile = 'default',
    String? kotNumber,
    String? orderNote,
    bool autoCut = true,
  }) async {
    final profile = await _loadProfile(capabilityProfile);
    final paperSize = _resolvePaperSize(paperWidth);
    final generator = Generator(paperSize, profile);
    final chars = paperSize == PaperSize.mm58 ? 32 : 48;

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'KITCHEN ORDER TICKET',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        _asciiSafe(settings.businessName),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr(ch: '=', len: chars));

    if (kotNumber != null && kotNumber.isNotEmpty) {
      bytes.addAll(generator.text(_asciiSafe('KOT #  : $kotNumber'), styles: const PosStyles(bold: true)));
    }
    bytes.addAll(
      generator.text(
        _asciiSafe('Table  : $table (${diningMode.toUpperCase()})'),
        styles: const PosStyles(bold: true),
      ),
    );
    bytes.addAll(generator.text(_asciiSafe('Waiter : $waiter')));
    bytes.addAll(
      generator.text(_asciiSafe('Time   : ${DateTime.now().toString().substring(0, 16)}')),
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    bytes.addAll(
      generator.row([
        PosColumn(text: 'QTY', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(text: 'ITEM / INSTRUCTIONS', width: 9, styles: const PosStyles(bold: true)),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-', len: chars));

    for (final it in items) {
      final qStr = it.quantity % 1 == 0
          ? it.quantity.toInt().toString()
          : it.quantity.toStringAsFixed(2);
      bytes.addAll(
        generator.row([
          PosColumn(
            text: '${qStr}x',
            width: 3,
            styles: const PosStyles(bold: true, height: PosTextSize.size2),
          ),
          PosColumn(
            text: _asciiSafe(it.product.name),
            width: 9,
            styles: const PosStyles(bold: true),
          ),
        ]),
      );
    }

    if (orderNote != null && orderNote.trim().isNotEmpty) {
      bytes.addAll(generator.hr(ch: '-', len: chars));
      bytes.addAll(generator.text(_asciiSafe('Note: $orderNote'), styles: const PosStyles(bold: true)));
    }

    bytes.addAll(generator.hr(ch: '=', len: chars));
    bytes.addAll(generator.feed(2));
    if (autoCut) {
      bytes.addAll(generator.cut());
    }
    return bytes;
  }

  /// Generates a diagnostic test ticket for [printer].
  static Future<List<int>> buildTestPageBytes({
    required ThermalPrinterConfig printer,
    required BusinessSettings settings,
  }) async {
    final profile = await _loadProfile(printer.capabilityProfile);
    final paperSize = _resolvePaperSize(printer.paperWidth);
    final generator = Generator(paperSize, profile);
    final chars = paperSize == PaperSize.mm58 ? 32 : 48;

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'SMART POS PRINTER TEST',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr(ch: '=', len: chars));
    bytes.addAll(generator.text(_asciiSafe('Store   : ${settings.businessName}')));
    bytes.addAll(generator.text(_asciiSafe('Printer : ${printer.name}')));
    bytes.addAll(generator.text(_asciiSafe('Mode    : ${printer.connectionType.toUpperCase()}')));
    bytes.addAll(generator.text(_asciiSafe('Target  : ${printer.endpointLabel}')));
    bytes.addAll(generator.text(_asciiSafe('Width   : ${printer.paperWidth} (${printer.charPerLine} chars)')));
    bytes.addAll(generator.hr(ch: '-', len: chars));
    bytes.addAll(
      generator.text(
        'ESC/POS connection verified OK!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.feed(2));
    if (printer.autoCut) {
      bytes.addAll(generator.cut());
    }
    return bytes;
  }

  /// Sends raw ESC/POS bytes to a configured [ThermalPrinterConfig].
  static Future<void> sendBytes(
    ThermalPrinterConfig printer,
    List<int> bytes,
  ) async {
    if (printer.connectionType == 'windows') {
      await _sendToWindowsRawPrinter(printer.windowsPrinterPath, bytes);
      return;
    }

    final host = printer.ipAddress.trim();
    if (host.isEmpty) {
      throw ArgumentError('Thermal printer IP address is empty.');
    }
    final socket = await Socket.connect(
      host,
      printer.port,
      timeout: const Duration(seconds: 4),
    );
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  /// Returns default Windows printer name via `winspool.drv`, or empty string if unavailable.
  static String getDefaultWindowsPrinterName() {
    if (!Platform.isWindows) return '';
    return using((arena) {
      final winspool = ffi.DynamicLibrary.open('winspool.drv');
      final getDefault = winspool.lookupFunction<_GetDefaultPrinterNative, _GetDefaultPrinterDart>(
        'GetDefaultPrinterW',
      );
      final sizePtr = arena<ffi.Uint32>();
      sizePtr.value = 0;
      getDefault(ffi.nullptr.cast<Utf16>(), sizePtr);
      final needed = sizePtr.value;
      if (needed <= 1) return '';
      final buf = arena<ffi.Uint16>(needed).cast<Utf16>();
      final ok = getDefault(buf, sizePtr);
      if (ok == 0) return '';
      return buf.toDartString();
    });
  }

  static Future<void> _sendToWindowsRawPrinter(
    String configuredName,
    List<int> bytes,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows RAW printer spooling is only supported on Windows.');
    }
    final printerName = configuredName.trim().isNotEmpty
        ? configuredName.trim()
        : getDefaultWindowsPrinterName();
    if (printerName.isEmpty) {
      throw StateError('No Windows printer path provided and no Windows default printer found.');
    }

    using((arena) {
      final winspool = ffi.DynamicLibrary.open('winspool.drv');
      final openPrinter = winspool.lookupFunction<_OpenPrinterNative, _OpenPrinterDart>('OpenPrinterW');
      final startDoc = winspool.lookupFunction<_StartDocPrinterNative, _StartDocPrinterDart>('StartDocPrinterW');
      final startPage = winspool.lookupFunction<_StartEndPageNative, _StartEndPageDart>('StartPagePrinter');
      final writePrinter = winspool.lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
      final endPage = winspool.lookupFunction<_StartEndPageNative, _StartEndPageDart>('EndPagePrinter');
      final endDoc = winspool.lookupFunction<_StartEndPageNative, _StartEndPageDart>('EndDocPrinter');
      final closePrinter = winspool.lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');

      final pName = printerName.toNativeUtf16(allocator: arena);
      final hPrinterPtr = arena<ffi.IntPtr>();
      if (openPrinter(pName, hPrinterPtr, ffi.nullptr) == 0) {
        throw StateError('OpenPrinterW failed for "$printerName".');
      }
      final hPrinter = hPrinterPtr.value;

      try {
        final docInfo = arena<_DocInfo1W>();
        docInfo.ref.pDocName = 'SmartPOS ESC/POS Receipt'.toNativeUtf16(allocator: arena);
        docInfo.ref.pOutputFile = ffi.nullptr.cast<Utf16>();
        docInfo.ref.pDatatype = 'RAW'.toNativeUtf16(allocator: arena);

        final jobId = startDoc(hPrinter, 1, docInfo);
        if (jobId == 0) {
          throw StateError('StartDocPrinterW failed for "$printerName".');
        }
        try {
          if (startPage(hPrinter) == 0) {
            throw StateError('StartPagePrinter failed for "$printerName".');
          }
          try {
            final nativeBuf = arena<ffi.Uint8>(bytes.length);
            nativeBuf.asTypedList(bytes.length).setAll(0, Uint8List.fromList(bytes));
            final writtenPtr = arena<ffi.Uint32>();
            if (writePrinter(hPrinter, nativeBuf, bytes.length, writtenPtr) == 0) {
              throw StateError('WritePrinter failed for "$printerName".');
            }
          } finally {
            endPage(hPrinter);
          }
        } finally {
          endDoc(hPrinter);
        }
      } finally {
        closePrinter(hPrinter);
      }
    });
  }

  /// High-level helper to build & dispatch a [Sale] receipt to the configured default
  /// ESC/POS thermal printer using the active [InvoiceLayout] template.
  static Future<bool> printSaleReceipt({
    required Sale sale,
    required BusinessSettings settings,
    double tenderedAmount = 0.0,
    double changeReturn = 0.0,
    double? customerPreviousBalance,
    ThermalPrinterConfig? printerOverride,
  }) async {
    final db = await DatabaseService.initialize();
    final printer = printerOverride ?? await db.getDefaultPrinter();
    if (printer == null) return false;
    final layout = await db.getDefaultInvoiceLayout();
    final bytes = await buildSaleReceiptBytes(
      sale: sale,
      settings: settings,
      layout: layout,
      paperWidth: printer.paperWidth,
      capabilityProfile: printer.capabilityProfile,
      tenderedAmount: tenderedAmount,
      changeReturn: changeReturn,
      customerPreviousBalance: customerPreviousBalance,
      autoCut: printer.autoCut,
      openDrawer: printer.openCashDrawer,
    );
    await sendBytes(printer, bytes);
    return true;
  }

  /// High-level helper to build & dispatch a Kitchen Order Ticket (KOT) to the
  /// configured KOT printer (or fallback default thermal printer).
  static Future<bool> printKotTicket({
    required String table,
    required String waiter,
    required String diningMode,
    required List<CartItem> items,
    required BusinessSettings settings,
    String? kotNumber,
    String? orderNote,
    ThermalPrinterConfig? printerOverride,
  }) async {
    final db = await DatabaseService.initialize();
    final printer = printerOverride ?? await db.getKotPrinter();
    if (printer == null) return false;
    final bytes = await buildKotTicketBytes(
      table: table,
      waiter: waiter,
      diningMode: diningMode,
      items: items,
      settings: settings,
      paperWidth: printer.paperWidth,
      capabilityProfile: printer.capabilityProfile,
      kotNumber: kotNumber,
      orderNote: orderNote,
      autoCut: printer.autoCut,
    );
    await sendBytes(printer, bytes);
    return true;
  }
}
