import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import 'database_service.dart';
import 'qulop_service.dart';

/// Lightweight embedded REST API service inside Smart POS Desktop.
/// Enables companion Flutter Mobile Apps (Waiter KOT, Field Quotations, Owner Dashboard)
/// and Secondary LAN Terminals to query stock, ledgers, and push orders over Wi-Fi.
class LocalApiService {
  static LocalApiService? _instance;
  static LocalApiService get instance => _instance ??= LocalApiService._();

  LocalApiService._();

  HttpServer? _server;
  int _port = 8080;
  bool _isRunning = false;
  DateTime? _startedAt;

  bool get isRunning => _isRunning;
  int get port => _port;
  DateTime? get startedAt => _startedAt;

  /// Starts the embedded HTTP API server
  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      _startedAt = DateTime.now();

      _server!.listen((HttpRequest request) async {
        _handleRequest(request);
      });

      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  /// Stops the embedded server
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    _startedAt = null;
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;
    final method = request.method;

    // Apply CORS headers for Flutter Mobile & Web companion clients
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization, Accept');
    response.headers.contentType = ContentType.json;

    if (method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    try {
      final db = await DatabaseService.initialize();

      // Normalize path (strip /api/v1 or /api if present)
      final normalizedPath = path.replaceAll('/api/v1', '').replaceAll('/api', '');

      // Route: GET /health
      if (method == 'GET' && normalizedPath == '/health') {
        final hwid = await QulopService.getHardwareId();
        final body = {
          'status': 'ok',
          'app': 'Smart POS',
          'version': '2.5.0',
          'uptime_seconds': _startedAt != null ? DateTime.now().difference(_startedAt!).inSeconds : 0,
          'hardware_id': hwid,
          'server_time': DateTime.now().toIso8601String(),
        };
        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode(body));
        await response.close();
        return;
      }

      // Route: GET /products
      if (method == 'GET' && normalizedPath == '/products') {
        final query = request.uri.queryParameters['q'];
        final products = await db.getProducts(search: query);
        final list = products.map((p) => {
          'id': p.id,
          'name': p.name,
          'sku': p.sku,
          'barcode': p.barcode,
          'selling_price': p.sellingPrice,
          'stock_quantity': p.stockQuantity,
          'category_name': p.categoryName,
        }).toList();

        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({'success': true, 'count': list.length, 'data': list}));
        await response.close();
        return;
      }

      // Route: GET /contacts
      if (method == 'GET' && normalizedPath == '/contacts') {
        final type = request.uri.queryParameters['type'];
        final contacts = await db.getContacts(type: type);
        final list = contacts.map((c) => {
          'id': c.id,
          'name': c.name,
          'type': c.type,
          'phone': c.phone,
          'balance': c.balance,
          'credit_limit': c.creditLimit,
        }).toList();

        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({'success': true, 'count': list.length, 'data': list}));
        await response.close();
        return;
      }

      // Route: GET /reports/summary
      if (method == 'GET' && normalizedPath == '/reports/summary') {
        final reg = await db.getActiveRegister();
        final sales = await db.getSales();
        final totalSales = sales.fold<double>(0.0, (acc, s) => acc + s.totalAmount);
        final totalPaid = sales.fold<double>(0.0, (acc, s) => acc + s.paidAmount);

        final body = {
          'success': true,
          'active_shift': reg != null ? {
            'id': reg.id,
            'cashier': reg.cashierName,
            'opened_at': reg.openedAt,
            'cash_in_drawer': reg.totalCashInRegister,
          } : null,
          'lifetime_sales_count': sales.length,
          'lifetime_sales_volume': totalSales,
          'lifetime_collected': totalPaid,
        };

        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode(body));
        await response.close();
        return;
      }

      // Route: POST /orders (Mobile Waiter / Field Sales Order Push)
      if (method == 'POST' && normalizedPath == '/orders') {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content) as Map<String, dynamic>;

        final customerName = data['customer_name'] as String? ?? 'Mobile Order';
        final customerId = data['customer_id'] as int?;
        final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paid_amount'] as num?)?.toDouble() ?? total;
        final paymentMethod = data['payment_method'] as String? ?? 'cash';
        final itemsData = (data['items'] as List<dynamic>?) ?? [];

        final invoiceNo = await db.generateNextInvoiceNo();
        final sale = Sale(
          invoiceNo: invoiceNo,
          customerId: customerId,
          customerName: customerName,
          subtotal: total,
          totalAmount: total,
          paidAmount: paid,
          paymentMethod: paymentMethod,
          paymentStatus: paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'due'),
          saleStatus: 'final',
          createdAt: DateTime.now().toIso8601String(),
          note: data['note'] as String? ?? 'Pushed from Smart POS Mobile App',
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
              purchasePrice: 0.0,
              sellingPrice: (pMap['unit_price'] as num?)?.toDouble() ?? 0.0,
              stockQuantity: 100.0,
            ),
            quantity: (pMap['quantity'] as num?)?.toDouble() ?? 1.0,
            unitPrice: (pMap['unit_price'] as num?)?.toDouble() ?? 0.0,
          ));
        }

        final completed = await db.createSale(sale: sale, items: cartItems);

        response.statusCode = HttpStatus.created;
        response.write(jsonEncode({
          'success': true,
          'message': 'Order processed successfully on primary server',
          'invoice_no': completed.invoiceNo,
          'sale_id': completed.id,
        }));
        await response.close();
        return;
      }

      // Default Not Found
      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({'success': false, 'error': 'Endpoint not found'}));
      await response.close();
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'success': false, 'error': e.toString()}));
      await response.close();
    }
  }
}
