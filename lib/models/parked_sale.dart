import 'dart:convert';
import '../services/app_logger.dart';
import 'cart_item.dart';

/// Parked / Suspended cart
class ParkedSale {
  final int? id;
  final String customerName;
  final String note;
  final double total;
  final String createdAt;
  final String itemsJson;

  ParkedSale({
    this.id,
    required this.customerName,
    this.note = '',
    required this.total,
    required this.createdAt,
    required this.itemsJson,
  });

  List<CartItem> getItems() {
    try {
      final list = jsonDecode(itemsJson) as List<dynamic>;
      return list
          .map((e) => CartItem.fromSavedStateMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.warning('Models', 'Failed parsing ParkedSale itemsJson', e, st);
      return [];
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'customer_name': customerName,
        'note': note,
        'total': total,
        'created_at': createdAt,
        'items_json': itemsJson,
      };

  factory ParkedSale.fromMap(Map<String, dynamic> map) => ParkedSale(
        id: map['id'] as int?,
        customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
        note: map['note'] as String? ?? '',
        total: (map['total'] as num).toDouble(),
        createdAt: map['created_at'] as String,
        itemsJson: map['items_json'] as String,
      );
}
