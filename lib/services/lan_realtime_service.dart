import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'app_logger.dart';
import 'database_service.dart';
import 'local_api_service.dart';

/// Coordinates real-time LAN multi-counter synchronization between:
/// - Salesman Counters (Secondary LAN Terminals generating bills/tokens & querying live stock)
/// - Main Payment Counter / Primary PC (hosting the authoritative DB + WebSocket broadcast hub)
class LanRealtimeService {
  static LanRealtimeService? _instance;
  static LanRealtimeService get instance =>
      _instance ??= LanRealtimeService._();

  LanRealtimeService._();

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final ValueNotifier<bool> wsConnected = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingDraftsCount = ValueNotifier<int>(0);

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  BusinessSettings? _settings;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  String get _host => _settings?.serverHost.trim().isNotEmpty == true
      ? _settings!.serverHost.trim()
      : '127.0.0.1';
  int get _port => (_settings?.serverPort ?? 8080) > 0
      ? (_settings?.serverPort ?? 8080)
      : 8080;
  String get _apiKey => _settings?.syncApiKey.trim() ?? '';

  /// Configures the client according to [settings].
  /// Connects WebSocket when running as a Secondary LAN Terminal (`lan_client`).
  Future<void> configure(BusinessSettings settings,
      {bool autoConnectInTest = false}) async {
    _settings = settings;
    _disposed = false;

    if (settings.isLanSecondaryTerminal &&
        settings.serverHost.trim().isNotEmpty) {
      if (!autoConnectInTest &&
          Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      await connectToPrimary(
        host: settings.serverHost.trim(),
        port: settings.serverPort > 0 ? settings.serverPort : 8080,
        apiKey: settings.syncApiKey.trim(),
      );
    } else {
      await disconnectClient();
    }
  }

  /// Broadcasts an event raised locally on the Primary PC to in-process listeners.
  void notifyLocalEvent(String type, Map<String, dynamic> data) {
    final evt = <String, dynamic>{
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    if (!_eventController.isClosed) {
      _eventController.add(evt);
    }
    if (type == 'drafts_updated') {
      unawaited(refreshPendingCount());
    }
  }

  /// Refreshes the held/counter queue count from Primary LAN server (if secondary) or local DB.
  Future<int> refreshPendingCount() async {
    try {
      if (_settings?.isLanSecondaryTerminal == true &&
          _settings!.serverHost.trim().isNotEmpty) {
        final remoteDrafts = await fetchCounterDrafts();
        pendingDraftsCount.value = remoteDrafts.length;
        return remoteDrafts.length;
      }
      final db = DatabaseService.instanceOrNull;
      if (db != null) {
        final local = await db.getParkedSales();
        pendingDraftsCount.value = local.length;
        return local.length;
      }
    } catch (e, st) {
      AppLogger.warning('LanRealtimeService',
          'Failed refreshing counter drafts count', e, st);
    }
    return pendingDraftsCount.value;
  }

  Uri _buildUri(
    String path, {
    String? host,
    int? port,
    Map<String, String>? queryParameters,
    bool webSocket = false,
  }) {
    final resolvedHost = (host ?? _host).trim();
    final resolvedPort = port ?? _port;
    return Uri(
      scheme: webSocket ? 'ws' : 'http',
      host: resolvedHost,
      port: resolvedPort,
      path: path,
      queryParameters: queryParameters,
    );
  }

  Map<String, String> _headers([String? apiKeyOverride]) {
    final key = (apiKeyOverride ?? _apiKey).trim();
    return <String, String>{
      'Content-Type': 'application/json',
      if (key.isNotEmpty) 'Authorization': 'Bearer $key',
    };
  }

  /// Opens a persistent WebSocket listener to the Primary Server `/ws` hub.
  Future<bool> connectToPrimary({
    required String host,
    required int port,
    String apiKey = '',
  }) async {
    await disconnectClient(clearSettings: false);
    _disposed = false;
    try {
      final token = apiKey.trim();
      final uri = _buildUri(
        '/ws',
        host: host,
        port: port,
        queryParameters: token.isNotEmpty ? {'token': token} : null,
        webSocket: true,
      );
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 4));
      _socket = socket;
      _reconnectAttempts = 0;
      wsConnected.value = true;

      socket.listen(
        (dynamic raw) {
          if (raw is! String) return;
          try {
            final parsed = jsonDecode(raw) as Map<String, dynamic>;
            final type = parsed['type'] as String? ?? '';
            if (type == 'drafts_updated') {
              unawaited(refreshPendingCount());
            }
            if (!_eventController.isClosed) {
              _eventController.add(parsed);
            }
          } catch (_) {}
        },
        onDone: () {
          wsConnected.value = false;
          _scheduleReconnect(host: host, port: port, apiKey: apiKey);
        },
        onError: (_) {
          wsConnected.value = false;
          _scheduleReconnect(host: host, port: port, apiKey: apiKey);
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      wsConnected.value = false;
      _scheduleReconnect(host: host, port: port, apiKey: apiKey);
      return false;
    }
  }

  void _scheduleReconnect({
    required String host,
    required int port,
    required String apiKey,
  }) {
    if (_disposed || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final seconds =
        _reconnectAttempts <= 2 ? 2 : (_reconnectAttempts <= 5 ? 5 : 10);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed) {
        unawaited(connectToPrimary(host: host, port: port, apiKey: apiKey));
      }
    });
  }

  Future<void> disconnectClient({bool clearSettings = false}) async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
    wsConnected.value = false;
    if (clearSettings) _settings = null;
  }

  /// Queries live stock and variation match from Primary LAN Server by barcode/SKU.
  Future<({bool reachable, Product? product, ProductVariation? variation})>
      fetchLiveProductByCode(
    String code, {
    String? host,
    int? port,
    String? apiKey,
  }) async {
    try {
      final uri = _buildUri(
        '/api/v1/products/by-code',
        host: host,
        port: port,
        queryParameters: {'code': code},
      );
      final resp = await http
          .get(uri, headers: _headers(apiKey))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final pMap = decoded['product'] as Map<String, dynamic>?;
        final vMap = decoded['variation'] as Map<String, dynamic>?;
        return (
          reachable: true,
          product: pMap != null ? Product.fromMap(pMap) : null,
          variation: vMap != null ? ProductVariation.fromMap(vMap) : null,
        );
      }
      if (resp.statusCode == 404) {
        return (reachable: true, product: null, variation: null);
      }
      return (reachable: false, product: null, variation: null);
    } catch (_) {
      return (reachable: false, product: null, variation: null);
    }
  }

  /// Pushes a Salesman Counter token / held bill directly to Primary Server queue.
  Future<({bool success, int? draftId, String? tokenNote, String? error})>
      pushCounterDraft(
    ParkedSale parked, {
    String counterName = '',
    String? host,
    int? port,
    String? apiKey,
  }) async {
    try {
      final uri = _buildUri('/api/v1/drafts', host: host, port: port);
      final payload = <String, dynamic>{
        ...parked.toMap(),
        'counter_name': counterName,
      }..remove('id');

      final resp = await http
          .post(uri, headers: _headers(apiKey), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 4));
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 201 && decoded['success'] == true) {
        await refreshPendingCount();
        return (
          success: true,
          draftId: (decoded['id'] as num?)?.toInt(),
          tokenNote: decoded['token_note'] as String?,
          error: null,
        );
      }
      return (
        success: false,
        draftId: null,
        tokenNote: null,
        error: decoded['error'] as String? ?? 'HTTP ${resp.statusCode}',
      );
    } catch (e) {
      return (
        success: false,
        draftId: null,
        tokenNote: null,
        error: e.toString(),
      );
    }
  }

  /// Fetches live pending counter tokens / held bills from Primary Server.
  Future<List<ParkedSale>> fetchCounterDrafts({
    String? host,
    int? port,
    String? apiKey,
  }) async {
    try {
      final uri = _buildUri('/api/v1/drafts', host: host, port: port);
      final resp = await http
          .get(uri, headers: _headers(apiKey))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return const [];
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final rows = (decoded['data'] as List<dynamic>? ?? const []);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(ParkedSale.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Removes a settled/resumed token from Primary Server queue.
  Future<bool> deleteCounterDraft(
    int id, {
    String? host,
    int? port,
    String? apiKey,
  }) async {
    try {
      final uri = _buildUri('/api/v1/drafts/$id', host: host, port: port);
      final resp = await http
          .delete(uri, headers: _headers(apiKey))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        await refreshPendingCount();
        return decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Pushes a finalized sale from a Secondary LAN Counter straight to Primary Server
  /// so stock and registers stay 100% real-time across all store counters.
  Future<({bool success, String? invoiceNo, int? saleId, String? error})>
      pushOrderToPrimary({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
    String? host,
    int? port,
    String? apiKey,
  }) async {
    try {
      final uri = _buildUri('/api/v1/orders', host: host, port: port);
      final body = {
        'customer_id': sale.customerId,
        'customer_name': sale.customerName,
        'location_id': sale.locationId,
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'tax_amount': sale.taxAmount,
        'shipping': sale.shipping,
        'total_amount': sale.totalAmount,
        'paid_amount': sale.paidAmount,
        'payment_method': sale.paymentMethod,
        'sale_status': sale.saleStatus,
        'note': sale.note,
        'split_tenders': splitTenders,
        'items': items
            .map((i) => {
                  'product_id': i.product.id,
                  'product_name': i.product.name,
                  'sku': i.product.sku,
                  'barcode': i.product.barcode,
                  'variation_id': i.variationId,
                  'variation_name': i.variationName,
                  'unit_name': i.selectedUnitName,
                  'unit_multiplier': i.unitMultiplier,
                  'purchase_price': i.product.purchasePrice,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'discount': i.discount,
                  'discount_type': i.discountType,
                  'discount_value': i.discountValue,
                })
            .toList(),
      };
      final resp = await http
          .post(uri, headers: _headers(apiKey), body: jsonEncode(body))
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          decoded['success'] == true) {
        return (
          success: true,
          invoiceNo: decoded['invoice_no'] as String?,
          saleId: (decoded['sale_id'] as num?)?.toInt(),
          error: null,
        );
      }
      return (
        success: false,
        invoiceNo: null,
        saleId: null,
        error: decoded['error'] as String? ?? 'HTTP ${resp.statusCode}',
      );
    } catch (e) {
      return (
        success: false,
        invoiceNo: null,
        saleId: null,
        error: e.toString(),
      );
    }
  }

  /// Helper called whenever local Primary DB finishes a sale, return, or parked bill mutation.
  static void emitPrimaryMutation(String type, Map<String, dynamic> data) {
    LocalApiService.instance.broadcastEvent(type, data);
  }
}
