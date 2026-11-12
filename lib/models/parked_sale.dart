import 'dart:convert';
import '../services/app_logger.dart';
import 'cart_item.dart';

/// Parked / Suspended cart
class ParkedSale {
  final int? id;
  final int? customerId;
  final String customerName;
  final String note;
  final double total;
  final String discountType;
  final double discountValue;
  final double orderTax;
  final double shippingCharge;
  final bool isWholesale;
  final int? commissionAgentId;
  final String commissionAgentName;
  final String createdAt;
  final String itemsJson;

  ParkedSale({
    this.id,
    this.customerId,
    required this.customerName,
    this.note = '',
    required this.total,
    this.discountType = 'fixed',
    this.discountValue = 0.0,
    this.orderTax = 0.0,
    this.shippingCharge = 0.0,
    this.isWholesale = false,
    this.commissionAgentId,
    this.commissionAgentName = '',
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
        'customer_id': customerId,
        'customer_name': customerName,
        'note': note,
        'total': total,
        'discount_type': discountType,
        'discount_value': discountValue,
        'order_tax': orderTax,
        'shipping_charge': shippingCharge,
        'is_wholesale': isWholesale ? 1 : 0,
        'commission_agent_id': commissionAgentId,
        'commission_agent_name': commissionAgentName,
        'created_at': createdAt,
        'items_json': itemsJson,
      };

  factory ParkedSale.fromMap(Map<String, dynamic> map) => ParkedSale(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
        note: map['note'] as String? ?? '',
        total: (map['total'] as num).toDouble(),
        discountType: map['discount_type'] as String? ?? 'fixed',
        discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
        orderTax: (map['order_tax'] as num?)?.toDouble() ?? 0.0,
        shippingCharge: (map['shipping_charge'] as num?)?.toDouble() ?? 0.0,
        isWholesale: (map['is_wholesale'] as int? ?? 0) == 1,
        commissionAgentId: map['commission_agent_id'] as int?,
        commissionAgentName: map['commission_agent_name'] as String? ?? '',
        createdAt: map['created_at'] as String,
        itemsJson: map['items_json'] as String,
      );
}
