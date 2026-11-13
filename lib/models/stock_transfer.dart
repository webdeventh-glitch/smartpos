import 'dart:convert';
import '../services/app_logger.dart';

/// Stock Transfer item
class StockTransferItem {
  final int productId;
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;

  StockTransferItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory StockTransferItem.fromMap(Map<String, dynamic> map) =>
      StockTransferItem(
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        sku: map['sku'] as String? ?? '',
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
      );
}

/// Stock Transfer between business locations
class StockTransfer {
  final int? id;
  final String refNo;
  final int fromLocationId;
  final String fromLocationName;
  final int toLocationId;
  final String toLocationName;
  final String status; // 'pending', 'in_transit', 'completed'
  final double shippingCharges;
  final double finalTotal;
  final String date;
  final String note;
  final String itemsJson;

  StockTransfer({
    this.id,
    required this.refNo,
    required this.fromLocationId,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationName,
    this.status = 'completed',
    this.shippingCharges = 0.0,
    required this.finalTotal,
    required this.date,
    this.note = '',
    required this.itemsJson,
  });

  List<StockTransferItem> getItems() {
    try {
      final list = jsonDecode(itemsJson) as List<dynamic>;
      return list
          .map((e) => StockTransferItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.warning(
          'Models', 'Failed parsing StockTransfer itemsJson', e, st);
      return [];
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': refNo,
        'from_location_id': fromLocationId,
        'from_location_name': fromLocationName,
        'to_location_id': toLocationId,
        'to_location_name': toLocationName,
        'status': status,
        'shipping_charges': shippingCharges,
        'final_total': finalTotal,
        'date': date,
        'note': note,
        'items_json': itemsJson,
      };

  factory StockTransfer.fromMap(Map<String, dynamic> map) => StockTransfer(
        id: map['id'] as int?,
        refNo: map['ref_no'] as String,
        fromLocationId: map['from_location_id'] as int? ?? 1,
        fromLocationName: map['from_location_name'] as String? ?? 'Main Branch',
        toLocationId: map['to_location_id'] as int? ?? 2,
        toLocationName: map['to_location_name'] as String? ?? 'Warehouse',
        status: map['status'] as String? ?? 'completed',
        shippingCharges: (map['shipping_charges'] as num?)?.toDouble() ?? 0.0,
        finalTotal: (map['final_total'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] as String,
        note: map['note'] as String? ?? '',
        itemsJson: map['items_json'] as String? ?? '[]',
      );
}
