import 'dart:convert';
import '../services/app_logger.dart';
import 'sale_item.dart';

/// Sale Invoice in Smart POS
class Sale {
  final int? id;
  final String invoiceNo;
  final int? customerId;
  final String customerName;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double taxRate;
  final double shipping;
  final double totalAmount;
  final double paidAmount;
  final String
      paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque', 'split'
  final String paymentStatus; // 'paid', 'partial', 'due'
  final String saleStatus; // 'final', 'draft', 'quotation', 'suspended'
  final String note;
  final String createdAt;
  final List<SaleItem>? items;
  final String? userName;
  final int? convertedFromQuotationId;
  final int? convertedToSaleId;
  final int? taxGroupId;
  final String taxBreakdownJson;

  Sale({
    this.id,
    required this.invoiceNo,
    this.customerId,
    this.customerName = 'Walk-in Customer',
    required this.subtotal,
    this.discount = 0.0,
    this.taxAmount = 0.0,
    this.taxRate = 0.0,
    this.shipping = 0.0,
    required this.totalAmount,
    required this.paidAmount,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'paid',
    this.saleStatus = 'final',
    this.note = '',
    required this.createdAt,
    this.items,
    this.userName,
    String? cashierName,
    this.convertedFromQuotationId,
    this.convertedToSaleId,
    this.taxGroupId,
    this.taxBreakdownJson = '',
  }) : cashierName = cashierName ?? userName ?? 'Cashier';

  final String cashierName;

  double get dueAmount => totalAmount - paidAmount;
  bool get isQuotation => saleStatus == 'quotation';
  bool get isConvertedQuotation =>
      isQuotation && convertedToSaleId != null && convertedToSaleId! > 0;

  Map<String, double> get taxBreakdownMap {
    if (taxBreakdownJson.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(taxBreakdownJson) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
      );
    } catch (e, st) {
      AppLogger.warning('Sale', 'Failed to parse tax_breakdown_json for $invoiceNo', e, st);
      return const {};
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'tax_amount': taxAmount,
        'tax_rate': taxRate,
        'shipping': shipping,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'sale_status': saleStatus,
        'note': note,
        'created_at': createdAt,
        'user_name': userName ?? cashierName,
        if (convertedFromQuotationId != null)
          'converted_from_quotation_id': convertedFromQuotationId,
        if (convertedToSaleId != null)
          'converted_to_sale_id': convertedToSaleId,
        if (taxGroupId != null) 'tax_group_id': taxGroupId,
        'tax_breakdown_json': taxBreakdownJson,
      };

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem>? items}) =>
      Sale(
        id: map['id'] as int?,
        invoiceNo: map['invoice_no'] as String,
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
        subtotal: (map['subtotal'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
        shipping: (map['shipping'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        paymentStatus: map['payment_status'] as String? ?? 'paid',
        saleStatus: map['sale_status'] as String? ?? 'final',
        note: map['note'] as String? ?? '',
        createdAt: map['created_at'] as String,
        items: items,
        userName: map['user_name'] as String?,
        convertedFromQuotationId: map['converted_from_quotation_id'] as int?,
        convertedToSaleId: map['converted_to_sale_id'] as int?,
        taxGroupId: map['tax_group_id'] as int?,
        taxBreakdownJson: map['tax_breakdown_json'] as String? ?? '',
      );
}
