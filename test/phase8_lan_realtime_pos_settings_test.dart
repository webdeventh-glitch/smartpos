import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/lan_realtime_service.dart';
import 'package:desktop_starter/services/local_api_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_lan_pos_');
  });

  tearDown(() async {
    await LanRealtimeService.instance.disconnectClient(clearSettings: true);
    await LocalApiService.instance.stopServer();
    try {
      final inst = DatabaseService.instanceOrNull;
      if (inst != null &&
          inst.db.isOpen &&
          inst.dbFilePath != null &&
          inst.dbFilePath!.startsWith(tempDir.path)) {
        await DatabaseService.closeOpenInstanceIfPathMatches(inst.dbFilePath!);
      }
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Future<DatabaseService> openFreshDb(String name) async {
    final dbPath = p.join(tempDir.path, name);
    await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    return DatabaseService.initialize(customPath: dbPath);
  }

  test('Schema v10 persists all new POS terminal & superstore toggle flags',
      () async {
    final db = await openFreshDb('v10_toggles.db');
    final initial = await db.getBusinessSettings();
    expect(initial.showPosProductPanel, isTrue);
    expect(initial.compactPosProductList, isTrue);
    expect(initial.autoFocusBarcodeSearch, isTrue);
    expect(initial.confirmBeforeCancelSale, isTrue);
    expect(initial.enableCounterTokenQueue, isTrue);

    final updated = initial.copyWith(
      showPosProductPanel: false,
      compactPosProductList: false,
      autoFocusBarcodeSearch: false,
      confirmBeforeCancelSale: false,
      enableCounterTokenQueue: false,
      allowOverselling: true,
      autoPrintReceipt: true,
    );
    await db.updateBusinessSettings(updated);

    final reloaded = await db.getBusinessSettings();
    expect(reloaded.showPosProductPanel, isFalse);
    expect(reloaded.compactPosProductList, isFalse);
    expect(reloaded.autoFocusBarcodeSearch, isFalse);
    expect(reloaded.confirmBeforeCancelSale, isFalse);
    expect(reloaded.enableCounterTokenQueue, isFalse);
    expect(reloaded.allowOverselling, isTrue);
    expect(reloaded.autoPrintReceipt, isTrue);
  });

  test(
      'Real-time LAN multi-counter loopback syncs drafts tokens & stock via WebSocket',
      () async {
    final db = await openFreshDb('lan_hub.db');
    final prodId = await db.insertProduct(Product(
      name: 'Panadol Extra Strip',
      sku: 'MED-PAN-01',
      barcode: '89610110099',
      purchasePrice: 40,
      sellingPrice: 55,
      stockQuantity: 25,
    ));

    final started = await LocalApiService.instance.startServer(port: 0);
    expect(started, isTrue);
    final port = LocalApiService.instance.port;

    final receivedEvents = <Map<String, dynamic>>[];
    final sub = LanRealtimeService.instance.events.listen(receivedEvents.add);

    final connected = await LanRealtimeService.instance.connectToPrimary(
      host: '127.0.0.1',
      port: port,
    );
    expect(connected, isTrue);

    // 1. Secondary salesman counter queries live stock over LAN
    final lookup = await LanRealtimeService.instance.fetchLiveProductByCode(
      '89610110099',
      host: '127.0.0.1',
      port: port,
    );
    expect(lookup.reachable, isTrue);
    expect(lookup.product, isNotNull);
    expect(lookup.product!.stockQuantity, 25.0);

    // 2. Salesman counter pushes token bill -> Primary Main Cash Counter receives WS update
    final prod = lookup.product!;
    final cartItem = CartItem(product: prod, quantity: 3, unitPrice: 55);
    final parked = ParkedSale(
      customerName: 'Walk-in Customer',
      note: 'TKN-101 • Counter-3',
      total: 165,
      createdAt: '2026-11-12 16:00:00',
      itemsJson: jsonEncode([cartItem.toSavedStateMap()]),
    );

    final pushDraftRes = await LanRealtimeService.instance.pushCounterDraft(
      parked,
      counterName: 'Counter-3',
      host: '127.0.0.1',
      port: port,
    );
    expect(pushDraftRes.success, isTrue);
    expect(pushDraftRes.draftId, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(receivedEvents.any((e) => e['type'] == 'drafts_updated'), isTrue);

    final liveDrafts = await LanRealtimeService.instance.fetchCounterDrafts(
      host: '127.0.0.1',
      port: port,
    );
    expect(liveDrafts.length, 1);
    expect(liveDrafts.first.note, contains('TKN-101'));

    // 3. Payment counter deletes/settles token & processes final sale -> real-time stock_changed
    final deleted = await LanRealtimeService.instance.deleteCounterDraft(
      pushDraftRes.draftId!,
      host: '127.0.0.1',
      port: port,
    );
    expect(deleted, isTrue);

    final saleRes = await LanRealtimeService.instance.pushOrderToPrimary(
      sale: Sale(
        invoiceNo: '',
        customerName: 'Walk-in Customer',
        subtotal: 165,
        totalAmount: 165,
        paidAmount: 165,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: '2026-11-12 16:01:00',
      ),
      items: [
        CartItem(
          product: Product(
            id: prod.id,
            name: prod.name,
            sku: prod.sku,
            barcode: prod.barcode,
            purchasePrice: 40,
            sellingPrice: 55,
            stockQuantity: 25,
          ),
          quantity: 3,
          unitPrice: 55,
        ),
      ],
      host: '127.0.0.1',
      port: port,
    );
    expect(saleRes.success, isTrue);
    expect(saleRes.invoiceNo, isNotEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(receivedEvents.any((e) => e['type'] == 'stock_changed'), isTrue);

    // 4. Subsequent scan across any counter immediately reflects 25 - 3 = 22 left in stock
    final afterLookup =
        await LanRealtimeService.instance.fetchLiveProductByCode(
      '89610110099',
      host: '127.0.0.1',
      port: port,
    );
    expect(afterLookup.product?.id, prodId);
    expect(afterLookup.product?.stockQuantity, 22.0);

    await sub.cancel();
  });
}
