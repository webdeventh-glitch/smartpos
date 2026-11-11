import 'dart:convert';
import '../services/app_logger.dart';

/// Stock Adjustment item
class StockAdjustmentItem {
  final int productId;
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;

  StockAdjustmentItem({
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

  factory StockAdjustmentItem.fromMap(Map<String, dynamic> map) =>
      StockAdjustmentItem(
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        sku: map['sku'] as String? ?? '',
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
      );
}

/// Stock Adjustment record
class StockAdjustment {
  final int? id;
  final String refNo;
  final int locationId;
  final String locationName;
  final String adjustmentType; // 'normal', 'abnormal'
  final double totalAmount;
  final double recoveredAmount;
  final String reason;
  final String date;
  final String itemsJson;

  StockAdjustment({
    this.id,
    required this.refNo,
    this.locationId = 1,
    this.locationName = 'Main Branch',
    this.adjustmentType = 'normal',
    required this.totalAmount,
    this.recoveredAmount = 0.0,
    this.reason = '',
    required this.date,
    required this.itemsJson,
  });

  List<StockAdjustmentItem> getItems() {
    try {
      final list = jsonDecode(itemsJson) as List<dynamic>;
      return list
          .map((e) => StockAdjustmentItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.warning('Models', 'Failed parsing StockAdjustment itemsJson', e, st);
      return [];
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': refNo,
        'location_id': locationId,
        'location_name': locationName,
        'adjustment_type': adjustmentType,
        'total_amount': totalAmount,
        'recovered_amount': recoveredAmount,
        'reason': reason,
        'date': date,
        'items_json': itemsJson,
      };

  factory StockAdjustment.fromMap(Map<String, dynamic> map) => StockAdjustment(
        id: map['id'] as int?,
        refNo: map['ref_no'] as String,
        locationId: map['location_id'] as int? ?? 1,
        locationName: map['location_name'] as String? ?? 'Main Branch',
        adjustmentType: map['adjustment_type'] as String? ?? 'normal',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        recoveredAmount: (map['recovered_amount'] as num?)?.toDouble() ?? 0.0,
        reason: map['reason'] as String? ?? '',
        date: map['date'] as String,
        itemsJson: map['items_json'] as String? ?? '[]',
      );
}
