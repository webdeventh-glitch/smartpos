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
}
