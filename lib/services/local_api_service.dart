import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import 'app_logger.dart';
import 'database_service.dart';
import 'lan_realtime_service.dart';
import 'qulop_service.dart';

/// Lightweight embedded REST + WebSocket API service inside Smart POS Desktop.
/// Enables Secondary LAN Counters (Salesman Counters -> Main Payment Counter)
/// and companion Mobile Apps to query stock, sync held/token bills, and push orders in real time.
class LocalApiService {
  static LocalApiService? _instance;
  static LocalApiService get instance => _instance ??= LocalApiService._();

  LocalApiService._();

  HttpServer? _server;
  final Set<WebSocket> _wsClients = <WebSocket>{};
  int _port = 8080;
  bool _isRunning = false;
  DateTime? _startedAt;

  static Map<String, dynamic> customerDisplayState = {
    'businessName': 'Smart POS',
    'customerName': 'Walk-in Customer',
    'items': <Map<String, dynamic>>[],
    'subtotal': 0.0,
    'discount': 0.0,
    'tax': 0.0,
    'grandTotal': 0.0,
    'amountPaid': 0.0,
    'changeDue': 0.0,
    'currency': 'Rs.',
    'status': 'idle',
  };

  /// Updates live cart state broadcasted to customer-facing dual screens.
  static void updateCustomerDisplayCart({
    required String businessName,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    double amountPaid = 0.0,
    double changeDue = 0.0,
    String currency = 'Rs.',
    String status = 'in_progress',
  }) {
    customerDisplayState = {
      'businessName': businessName,
      'customerName': customerName,
      'items': items,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'grandTotal': grandTotal,
      'amountPaid': amountPaid,
      'changeDue': changeDue,
      'currency': currency,
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    instance.broadcastEvent('customer_display_updated', customerDisplayState);
  }

  bool get isRunning => _isRunning;
  int get port => _server?.port ?? _port;
  DateTime? get startedAt => _startedAt;
  int get connectedClientCount => _wsClients.length;

  /// Broadcasts a real-time JSON event to all connected LAN WebSocket counters
  /// and notifies local listeners running in this Primary PC process.
  void broadcastEvent(String type, Map<String, dynamic> data) {
    final payload = <String, dynamic>{
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    LanRealtimeService.instance.notifyLocalEvent(type, data);
    if (_wsClients.isEmpty) return;

    final encoded = jsonEncode(payload);
    for (final client in _wsClients.toList()) {
      try {
        if (client.readyState == WebSocket.open) {
          client.add(encoded);
        } else {
          _wsClients.remove(client);
        }
      } catch (e, st) {
        AppLogger.warning(
            'LocalApiService', 'Dropping dead WS LAN counter client', e, st);
        _wsClients.remove(client);
      }
    }
  }

  /// Starts the embedded HTTP + WebSocket API server
  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      DatabaseService.onRealtimeEvent = broadcastEvent;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _port = _server!.port;
      _isRunning = true;
      _startedAt = DateTime.now();

      _server!.listen((HttpRequest request) async {
        _handleRequest(request);
      });

      return true;
    } catch (e, st) {
      AppLogger.error('LocalApiService',
          'Failed starting local API server on port $_port', e, st);
      _isRunning = false;
      return false;
    }
  }

  /// Stops the embedded server and closes any live WebSocket connections.
  Future<void> stopServer() async {
    for (final ws in _wsClients.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _wsClients.clear();
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    _startedAt = null;
  }

  bool _isAuthorized(HttpRequest request, String configuredKey) {
    if (configuredKey.isEmpty) return true;
    final authHeader =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final xApiKey = request.headers.value('x-api-key') ?? '';
    final queryToken = request.uri.queryParameters['token'] ?? '';
    final provided = authHeader.toLowerCase().startsWith('bearer ')
        ? authHeader.substring(7).trim()
        : (xApiKey.trim().isNotEmpty ? xApiKey.trim() : queryToken.trim());
    return provided == configuredKey;
  }

  Future<void> _sendJson(
      HttpResponse response, int statusCode, Object body) async {
    response.statusCode = statusCode;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _handleWebSocketUpgrade(
    HttpRequest request,
    String configuredKey,
  ) async {
    if (!_isAuthorized(request, configuredKey)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response
          .write(jsonEncode({'success': false, 'error': 'Unauthorized'}));
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _wsClients.add(socket);
      socket.add(jsonEncode({
        'type': 'connected',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {'client_count': _wsClients.length},
      }));
      socket.listen(
        (dynamic message) {
          if (message is String && message.trim() == 'ping') {
            socket.add(jsonEncode({'type': 'pong'}));
          }
        },
        onDone: () => _wsClients.remove(socket),
        onError: (_) => _wsClients.remove(socket),
        cancelOnError: true,
      );
    } catch (e, st) {
      AppLogger.warning('LocalApiService', 'WebSocket upgrade error', e, st);
    }
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;
    final method = request.method;
    final normalizedPath =
        path.replaceAll('/api/v1', '').replaceAll('/api', '');

    try {
      final db = await DatabaseService.initialize();
      final settings = await db.getBusinessSettings();
      final configuredKey = settings.syncApiKey.trim();

      // WebSocket real-time hub: ws://<primary-host>:<port>/ws
      if ((normalizedPath == '/ws' || path == '/ws') &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        await _handleWebSocketUpgrade(request, configuredKey);
        return;
      }

      // Apply CORS headers for Flutter Mobile & Web companion clients
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set(
          'Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      response.headers.set('Access-Control-Allow-Headers',
          'Origin, Content-Type, Authorization, Accept, X-Api-Key');
      response.headers.contentType = ContentType.json;

      if (method == 'OPTIONS') {
        response.statusCode = HttpStatus.ok;
        await response.close();
        return;
      }

      // Route: GET /health (intentionally unauthenticated health probe)
      if (method == 'GET' && normalizedPath == '/health') {
        final hwid = await QulopService.getHardwareId();
        await _sendJson(response, HttpStatus.ok, {
          'status': 'ok',
          'app': 'Smart POS',
          'version': '2.5.0',
          'uptime_seconds': _startedAt != null
              ? DateTime.now().difference(_startedAt!).inSeconds
              : 0,
          'ws_clients': _wsClients.length,
          'hardware_id': hwid,
          'server_time': DateTime.now().toIso8601String(),
        });
        return;
      }

      // Route: GET /customer-display (HTML for customer pole / secondary screen)
      if (method == 'GET' &&
          (path == '/customer-display' ||
              normalizedPath == '/customer-display')) {
        response.headers.contentType = ContentType.html;
        response.statusCode = HttpStatus.ok;
        response.write(_renderCustomerDisplayHtml());
        await response.close();
        return;
      }

      // Route: GET /api/customer-display (Live JSON cart state for pole/secondary display)
      if (method == 'GET' &&
          (path == '/api/customer-display' ||
              normalizedPath == '/customer-display-data')) {
        await _sendJson(response, HttpStatus.ok, customerDisplayState);
        return;
      }

      // Enforce API key authentication on protected LAN endpoints when configured
      if (!_isAuthorized(request, configuredKey)) {
        AppLogger.warning(
            'LocalApiService', 'Unauthorized API call to $normalizedPath');
        await _sendJson(response, HttpStatus.unauthorized,
            {'success': false, 'error': 'Unauthorized'});
        return;
      }

      // Route: GET /products
      if (method == 'GET' && normalizedPath == '/products') {
        final query = request.uri.queryParameters['q'];
        final products = await db.getProducts(search: query);
        final list = products
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'sku': p.sku,
                  'barcode': p.barcode,
                  'selling_price': p.sellingPrice,
                  'stock_quantity': p.stockQuantity,
                  'category_name': p.categoryName,
                })
            .toList();

        await _sendJson(response, HttpStatus.ok,
            {'success': true, 'count': list.length, 'data': list});
        return;
      }

      // Route: GET /products/by-code?code=... (live barcode/SKU stock lookup for LAN counters)
      if (method == 'GET' && normalizedPath == '/products/by-code') {
        final code = (request.uri.queryParameters['code'] ?? '').trim();
        if (code.isEmpty) {
          await _sendJson(response, HttpStatus.badRequest,
              {'success': false, 'error': 'Missing code query parameter'});
          return;
        }
        final match = await db.getProductWithMatchedVariationByCode(code);
        if (match == null) {
          await _sendJson(response, HttpStatus.notFound,
              {'success': false, 'error': 'Product not found'});
          return;
        }
        await _sendJson(response, HttpStatus.ok, {
          'success': true,
          'product': match.$1.toMap(),
          'variation': match.$2?.toMap(match.$1.id),
        });
        return;
      }

      // Route: POST /stock/delta (LAN terminal adjusts or decrements stock atomically)
      if (method == 'POST' &&
          (normalizedPath == '/stock/delta' ||
              normalizedPath == '/products/stock/delta')) {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final productId = (data['product_id'] as num?)?.toInt();
        if (productId == null) {
          await _sendJson(response, HttpStatus.badRequest,
              {'success': false, 'error': 'Missing product_id'});
          return;
        }
        final delta = (data['delta'] as num?)?.toDouble() ?? 0.0;
        final variationId = (data['variation_id'] as num?)?.toInt();
        final locationId = (data['location_id'] as num?)?.toInt();

        final newStock = await db.applyRemoteStockDelta(
          productId: productId,
          variationId: variationId,
          delta: delta,
          locationId: locationId,
        );

        broadcastEvent('stock_delta', {
          'product_id': productId,
          'variation_id': variationId,
          'delta': delta,
          'location_id': locationId,
          'new_stock': newStock,
        });

        await _sendJson(response, HttpStatus.ok, {
          'success': true,
          'product_id': productId,
          'variation_id': variationId,
          'delta': delta,
          'location_id': locationId,
          'new_stock': newStock,
        });
        return;
      }

      // Route: GET /drafts (live Salesman Counter Tokens / Held Bills)
      if (method == 'GET' && normalizedPath == '/drafts') {
        final drafts = await db.getParkedSales();
        final list = drafts.map((d) => d.toMap()).toList();
        await _sendJson(response, HttpStatus.ok,
            {'success': true, 'count': list.length, 'data': list});
        return;
      }

      // Route: GET /drafts/<id> & DELETE /drafts/<id>
      if (normalizedPath.startsWith('/drafts/')) {
        final idStr = normalizedPath.substring('/drafts/'.length).trim();
        final id = int.tryParse(idStr);
        if (id == null) {
          await _sendJson(response, HttpStatus.badRequest,
              {'success': false, 'error': 'Invalid draft id'});
          return;
        }

        if (method == 'GET') {
          final drafts = await db.getParkedSales();
          final found = drafts
              .cast<ParkedSale?>()
              .firstWhere((d) => d?.id == id, orElse: () => null);
          if (found == null) {
            await _sendJson(response, HttpStatus.notFound,
                {'success': false, 'error': 'Draft not found'});
            return;
          }
          await _sendJson(response, HttpStatus.ok,
              {'success': true, 'data': found.toMap()});
          return;
        }

        if (method == 'DELETE') {
          final deleted = await db.deleteParkedSale(id);
          if (deleted > 0) {
            broadcastEvent('drafts_updated', {'action': 'deleted', 'id': id});
          }
          await _sendJson(response, HttpStatus.ok,
              {'success': deleted > 0, 'deleted': deleted});
          return;
        }
      }

      // Route: POST /drafts (Salesman Counter sends bill token to Main Payment Counter)
      if (method == 'POST' && normalizedPath == '/drafts') {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final rawNote = (data['note'] as String? ?? '').trim();
        final counterLabel = (data['counter_name'] as String? ?? '').trim();
        final generatedToken =
            'TKN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        final resolvedNote = rawNote.isNotEmpty
            ? rawNote
            : (counterLabel.isNotEmpty
                ? '$generatedToken • $counterLabel'
                : generatedToken);

        final parked = ParkedSale(
          customerId: data['customer_id'] as int?,
          customerName: data['customer_name'] as String? ?? 'Walk-in Customer',
          note: resolvedNote,
          total: (data['total'] as num?)?.toDouble() ?? 0.0,
          discountType: data['discount_type'] as String? ?? 'fixed',
          discountValue: (data['discount_value'] as num?)?.toDouble() ?? 0.0,
          orderTax: (data['order_tax'] as num?)?.toDouble() ?? 0.0,
          shippingCharge: (data['shipping_charge'] as num?)?.toDouble() ?? 0.0,
          isWholesale: data['is_wholesale'] == true ||
              (data['is_wholesale'] as int? ?? 0) == 1,
          commissionAgentId: data['commission_agent_id'] as int?,
          commissionAgentName: data['commission_agent_name'] as String? ?? '',
          createdAt: (data['created_at'] as String?)?.isNotEmpty == true
              ? data['created_at'] as String
              : DateTime.now().toIso8601String(),
          itemsJson: data['items_json'] is String
              ? data['items_json'] as String
              : jsonEncode(data['items'] ?? const []),
        );

        final insertedId = await db.parkSale(parked);
        broadcastEvent('drafts_updated', {
          'action': 'created',
          'id': insertedId,
          'note': resolvedNote,
          'customer_name': parked.customerName,
          'total': parked.total,
        });

        await _sendJson(response, HttpStatus.created, {
          'success': true,
          'id': insertedId,
          'token_note': resolvedNote,
          'total': parked.total,
        });
        return;
      }

      // Route: GET /contacts
      if (method == 'GET' && normalizedPath == '/contacts') {
        final type = request.uri.queryParameters['type'];
        final contacts = await db.getContacts(type: type);
        final list = contacts
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'type': c.type,
                  'phone': c.phone,
                  'balance': c.balance,
                  'credit_limit': c.creditLimit,
                })
            .toList();

        await _sendJson(response, HttpStatus.ok,
            {'success': true, 'count': list.length, 'data': list});
        return;
      }

      // Route: GET /reports/summary
      if (method == 'GET' && normalizedPath == '/reports/summary') {
        final reg = await db.getActiveRegister();
        final sales = await db.getSales();
        final totalSales =
            sales.fold<double>(0.0, (acc, s) => acc + s.totalAmount);
        final totalPaid =
            sales.fold<double>(0.0, (acc, s) => acc + s.paidAmount);

        await _sendJson(response, HttpStatus.ok, {
          'success': true,
          'active_shift': reg != null
              ? {
                  'id': reg.id,
                  'cashier': reg.cashierName,
                  'opened_at': reg.openedAt,
                  'cash_in_drawer': reg.totalCashInRegister,
                }
              : null,
          'lifetime_sales_count': sales.length,
          'lifetime_sales_volume': totalSales,
          'lifetime_collected': totalPaid,
        });
        return;
      }

      // Route: POST /orders (Secondary LAN Counter or Mobile Waiter checkout on Primary Server)
      if (method == 'POST' && normalizedPath == '/orders') {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content) as Map<String, dynamic>;

        final customerName = data['customer_name'] as String? ?? 'Mobile Order';
        final customerId = data['customer_id'] as int?;
        final locationId = (data['location_id'] as num?)?.toInt() ?? 1;
        final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
        final subtotal = (data['subtotal'] as num?)?.toDouble() ?? total;
        final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
        final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0.0;
        final shipping = (data['shipping'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paid_amount'] as num?)?.toDouble() ?? total;
        final paymentMethod = data['payment_method'] as String? ?? 'cash';
        final saleStatus = data['sale_status'] as String? ?? 'final';
        final itemsData = (data['items'] as List<dynamic>?) ?? [];
        final splitTendersRaw = data['split_tenders'] as List<dynamic>?;
        final splitTenders = splitTendersRaw
            ?.whereType<Map<String, dynamic>>()
            .toList(growable: false);

        final invoiceNo = await db.generateNextInvoiceNo();
        final sale = Sale(
          invoiceNo: invoiceNo,
          customerId: customerId,
          customerName: customerName,
          locationId: locationId,
          subtotal: subtotal,
          discount: discount,
          taxAmount: taxAmount,
          shipping: shipping,
          totalAmount: total,
          paidAmount: paid,
          paymentMethod: paymentMethod,
          paymentStatus:
              paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'due'),
          saleStatus: saleStatus,
          createdAt: DateTime.now().toIso8601String(),
          note: data['note'] as String? ?? 'Pushed from LAN / Mobile Terminal',
        );

        final cartItems = <CartItem>[];
        for (final item in itemsData) {
          final pMap = item as Map<String, dynamic>;
          cartItems.add(CartItem(
            product: Product(
              id: pMap['product_id'] as int?,
              name: pMap['product_name'] as String? ?? 'Item',
              sku: pMap['sku'] as String? ?? 'SKU',
              barcode: pMap['barcode'] as String? ?? 'BC',
              purchasePrice:
                  (pMap['purchase_price'] as num?)?.toDouble() ?? 0.0,
              sellingPrice: (pMap['unit_price'] as num?)?.toDouble() ?? 0.0,
              stockQuantity: 100.0,
            ),
            variationId: pMap['variation_id'] as int?,
            variationName: pMap['variation_name'] as String?,
            selectedUnitName: pMap['unit_name'] as String?,
            unitMultiplier:
                (pMap['unit_multiplier'] as num?)?.toDouble() ?? 1.0,
            quantity: (pMap['quantity'] as num?)?.toDouble() ?? 1.0,
            unitPrice: (pMap['unit_price'] as num?)?.toDouble() ?? 0.0,
            discount: (pMap['discount'] as num?)?.toDouble() ?? 0.0,
            discountType: pMap['discount_type'] as String? ?? 'fixed',
            discountValue: (pMap['discount_value'] as num?)?.toDouble() ?? 0.0,
          ));
        }

        final completed = await db.createSale(
          sale: sale,
          items: cartItems,
          splitTenders: splitTenders,
          enforceStock: !settings.allowOverselling,
        );

        if (saleStatus == 'final') {
          for (final item in cartItems) {
            if (item.product.id != null) {
              final itemQty = item.quantity *
                  (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
              broadcastEvent('stock_delta', {
                'product_id': item.product.id,
                'variation_id': item.variationId,
                'delta': -itemQty,
                'location_id': locationId,
              });
            }
          }
          broadcastEvent('stock_changed', {
            'invoice_no': completed.invoiceNo,
            'location_id': locationId,
            'product_ids':
                cartItems.map((i) => i.product.id).whereType<int>().toList(),
          });
        }

        await _sendJson(response, HttpStatus.created, {
          'success': true,
          'message': 'Order processed successfully on primary server',
          'invoice_no': completed.invoiceNo,
          'sale_id': completed.id,
        });
        return;
      }

      // Default Not Found
      await _sendJson(response, HttpStatus.notFound,
          {'success': false, 'error': 'Endpoint not found'});
    } catch (e, st) {
      AppLogger.error(
          'LocalApiService', 'API request error on $method $path', e, st);
      await _sendJson(response, HttpStatus.internalServerError,
          {'success': false, 'error': e.toString()});
    }
  }

  String _renderCustomerDisplayHtml() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Customer Display - Smart POS</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    body { background-color: #0b0f19; color: #f8fafc; height: 100vh; display: flex; flex-direction: column; overflow: hidden; }
    header { background: #1e293b; padding: 18px 28px; display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #334155; }
    .store-info h1 { font-size: 24px; font-weight: 900; color: #ffffff; letter-spacing: -0.5px; }
    .store-info p { font-size: 13px; color: #94a3b8; font-weight: 500; margin-top: 2px; }
    .badge { background: #4f46e5; color: white; padding: 6px 14px; border-radius: 999px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
    .main-content { display: flex; flex: 1; height: calc(100vh - 80px); }
    .items-pane { flex: 3; background: #0f172a; border-right: 1px solid #1e293b; display: flex; flex-direction: column; overflow: hidden; }
    .table-header { display: flex; background: #1e293b; padding: 12px 24px; font-size: 12px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #334155; }
    .col-name { flex: 5; }
    .col-qty { flex: 2; text-align: center; }
    .col-price { flex: 2; text-align: right; }
    .col-total { flex: 2; text-align: right; }
    .items-list { flex: 1; overflow-y: auto; padding: 12px 24px; }
    .item-row { display: flex; padding: 14px 0; border-bottom: 1px solid #1e293b; font-size: 15px; align-items: center; }
    .item-row .col-name { font-weight: 600; color: #f1f5f9; }
    .item-row .col-qty { color: #38bdf8; font-weight: 700; }
    .item-row .col-price { color: #94a3b8; }
    .item-row .col-total { font-weight: 800; color: #10b981; font-size: 16px; }
    .empty-state { height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #64748b; }
    .empty-state svg { width: 64px; height: 64px; margin-bottom: 16px; opacity: 0.5; stroke: currentColor; fill: none; }
    .summary-pane { flex: 2; background: #182234; padding: 28px; display: flex; flex-direction: column; justify-content: space-between; }
    .summary-card { background: #0f172a; border: 1px solid #334155; border-radius: 16px; padding: 22px; margin-bottom: 16px; }
    .summary-line { display: flex; justify-content: space-between; font-size: 15px; color: #94a3b8; margin-bottom: 12px; }
    .summary-line.highlight { color: #34d399; font-weight: 600; }
    .total-box { background: linear-gradient(135deg, #4f46e5 0%, #3b82f6 100%); border-radius: 16px; padding: 24px; text-align: center; box-shadow: 0 10px 25px -5px rgba(79, 70, 229, 0.4); margin-bottom: 16px; }
    .total-label { font-size: 14px; text-transform: uppercase; font-weight: 800; letter-spacing: 1px; color: rgba(255, 255, 255, 0.85); }
    .total-amount { font-size: 40px; font-weight: 900; color: #ffffff; margin-top: 6px; letter-spacing: -0.5px; }
    .payment-box { background: #0f172a; border: 1px solid #059669; border-radius: 12px; padding: 16px; }
    .payment-box .summary-line { margin-bottom: 8px; font-size: 16px; font-weight: bold; color: #f8fafc; }
    .change-highlight { color: #10b981 !important; font-size: 20px !important; }
    .status-banner { text-align: center; font-size: 14px; font-weight: 700; padding: 12px; border-radius: 8px; background: #334155; color: #94a3b8; }
    .status-banner.completed { background: #064e3b; color: #34d399; }
  </style>
</head>
<body>
  <header>
    <div class="store-info">
      <h1 id="storeName">Smart POS</h1>
      <p id="customerGreeting">Welcome • Walk-in Customer</p>
    </div>
    <div class="badge" id="statusBadge">Live POS Display</div>
  </header>
  <div class="main-content">
    <div class="items-pane">
      <div class="table-header">
        <div class="col-name">Product Name</div>
        <div class="col-qty">Quantity</div>
        <div class="col-price">Unit Price</div>
        <div class="col-total">Total</div>
      </div>
      <div class="items-list" id="itemsList">
        <div class="empty-state">
          <svg viewBox="0 0 24 24" stroke-width="1.5"><path d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"/></svg>
          <p>Ready for next transaction</p>
        </div>
      </div>
    </div>
    <div class="summary-pane">
      <div>
        <div class="total-box">
          <div class="total-label">Total Amount Due</div>
          <div class="total-amount" id="grandTotal">Rs. 0.00</div>
        </div>
        <div class="summary-card">
          <div class="summary-line">
            <span>Subtotal</span>
            <span id="subtotal">Rs. 0.00</span>
          </div>
          <div class="summary-line highlight" id="discountRow" style="display:none;">
            <span>Discount Applied</span>
            <span id="discount">-Rs. 0.00</span>
          </div>
          <div class="summary-line" id="taxRow" style="display:none;">
            <span>Order Tax</span>
            <span id="tax">Rs. 0.00</span>
          </div>
        </div>
        <div class="payment-box" id="paymentBox" style="display:none;">
          <div class="summary-line">
            <span>Amount Paid</span>
            <span id="amountPaid">Rs. 0.00</span>
          </div>
          <div class="summary-line">
            <span>Change Due</span>
            <span id="changeDue" class="change-highlight">Rs. 0.00</span>
          </div>
        </div>
      </div>
      <div class="status-banner" id="statusBanner">
        Scanning Items...
      </div>
    </div>
  </div>
  <script>
    async function updateDisplay() {
      try {
        const res = await fetch('/api/customer-display');
        if (res.ok) {
          const d = await res.json();
          document.getElementById('storeName').textContent = d.businessName || 'Smart POS';
          document.getElementById('customerGreeting').textContent = (d.customerName ? 'Customer: ' + d.customerName : 'Welcome Customer');
          const cur = d.currency || 'Rs.';
          document.getElementById('grandTotal').textContent = cur + ' ' + Number(d.grandTotal || 0).toFixed(2);
          document.getElementById('subtotal').textContent = cur + ' ' + Number(d.subtotal || 0).toFixed(2);
          
          if (d.discount > 0) {
            document.getElementById('discountRow').style.display = 'flex';
            document.getElementById('discount').textContent = '-' + cur + ' ' + Number(d.discount).toFixed(2);
          } else {
            document.getElementById('discountRow').style.display = 'none';
          }

          if (d.tax > 0) {
            document.getElementById('taxRow').style.display = 'flex';
            document.getElementById('tax').textContent = cur + ' ' + Number(d.tax).toFixed(2);
          } else {
            document.getElementById('taxRow').style.display = 'none';
          }

          if (d.amountPaid > 0) {
            document.getElementById('paymentBox').style.display = 'block';
            document.getElementById('amountPaid').textContent = cur + ' ' + Number(d.amountPaid).toFixed(2);
            document.getElementById('changeDue').textContent = cur + ' ' + Number(d.changeDue).toFixed(2);
          } else {
            document.getElementById('paymentBox').style.display = 'none';
          }

          const banner = document.getElementById('statusBanner');
          if (d.status === 'completed') {
            banner.className = 'status-banner completed';
            banner.textContent = 'Transaction Complete • Thank You!';
            document.getElementById('statusBadge').textContent = 'Completed';
          } else if (d.items && d.items.length > 0) {
            banner.className = 'status-banner';
            banner.textContent = 'Scanning Items (' + d.items.length + ' in cart)';
            document.getElementById('statusBadge').textContent = 'In Progress';
          } else {
            banner.className = 'status-banner';
            banner.textContent = 'Welcome! Ready for your purchase.';
            document.getElementById('statusBadge').textContent = 'Ready';
          }

          const listEl = document.getElementById('itemsList');
          if (!d.items || d.items.length === 0) {
            listEl.innerHTML = '<div class="empty-state"><svg viewBox="0 0 24 24" stroke-width="1.5"><path d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"/></svg><p>Ready for next transaction</p></div>';
          } else {
            let html = '';
            for (const it of d.items) {
              const q = Number(it.quantity || 1);
              const qStr = (q % 1 === 0 ? q : q.toFixed(2)) + (it.unit ? ' ' + it.unit : '');
              html += '<div class="item-row">' +
                '<div class="col-name">' + (it.name || 'Item') + '</div>' +
                '<div class="col-qty">' + qStr + '</div>' +
                '<div class="col-price">' + cur + ' ' + Number(it.price || 0).toFixed(2) + '</div>' +
                '<div class="col-total">' + cur + ' ' + Number(it.subtotal || 0).toFixed(2) + '</div>' +
                '</div>';
            }
            listEl.innerHTML = html;
          }
        }
      } catch (err) {}
      setTimeout(updateDisplay, 600);
    }
    updateDisplay();
  </script>
</body>
</html>''';
  }
}
