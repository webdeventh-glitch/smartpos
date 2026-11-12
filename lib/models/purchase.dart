import 'dart:convert';
import '../services/app_logger.dart';

/// Purchase record
class Purchase {
  final int? id;
  final String refNo;
  final int? supplierId;
  final String supplierName;
  final int locationId;
  final String locationName;
  final double totalAmount;
  final double paidAmount;
  final String status; // 'received', 'pending', 'ordered'
  final String paymentStatus; // 'paid', 'due', 'partial'
  final String createdAt;
  final String note;
  final String itemsJson;
  final String discountType; // 'none', 'fixed', 'percentage'
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double shippingCharges;
  final String shippingDetails;
  final double additionalExpenses;
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque'
  final int? paymentAccountId;
  final String paymentNote;
  final int? payTermNumber;
  final String payTermType; // 'days', 'months'
  final String documentPath;
  final String purchaseDate;
  final bool isPurchaseOrder;
  final int? convertedFromPoId;

  Purchase({
    this.id,
    required this.refNo,
    this.supplierId,
    required this.supplierName,
    this.locationId = 1,
    this.locationName = 'Main Branch',
    required this.totalAmount,
    required this.paidAmount,
    this.status = 'received',
    this.paymentStatus = 'paid',
    required this.createdAt,
    this.note = '',
    this.itemsJson = '[]',
    this.discountType = 'none',
    this.discountAmount = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.shippingCharges = 0.0,
    this.shippingDetails = '',
    this.additionalExpenses = 0.0,
    this.paymentMethod = 'cash',
    this.paymentAccountId,
    this.paymentNote = '',
    this.payTermNumber,
    this.payTermType = 'days',
    this.documentPath = '',
    String? purchaseDate,
    this.isPurchaseOrder = false,
    this.convertedFromPoId,
  }) : purchaseDate = purchaseDate ?? createdAt;

  double get dueAmount =>
      totalAmount > paidAmount ? totalAmount - paidAmount : 0.0;
  double get finalTotal => totalAmount;
  String get referenceNo => refNo;

  List<Map<String, dynamic>> getItems() {
    try {
      if (itemsJson.isEmpty || itemsJson == '[]') return [];
      final list = jsonDecode(itemsJson);
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e, st) {
      AppLogger.warning('Models', 'Failed parsing Purchase itemsJson', e, st);
    }
    return [];
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': refNo,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'location_id': locationId,
        'location_name': locationName,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'status': status,
        'payment_status': paymentStatus,
        'created_at': createdAt,
        'note': note,
        'items_json': itemsJson,
        'discount_type': discountType,
        'discount_amount': discountAmount,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'shipping_charges': shippingCharges,
        'shipping_details': shippingDetails,
        'additional_expenses': additionalExpenses,
        'payment_method': paymentMethod,
        'payment_account_id': paymentAccountId,
        'payment_note': paymentNote,
        'pay_term_number': payTermNumber,
        'pay_term_type': payTermType,
        'document_path': documentPath,
        'purchase_date': purchaseDate,
        'is_purchase_order': isPurchaseOrder ? 1 : 0,
        if (convertedFromPoId != null)
          'converted_from_po_id': convertedFromPoId,
      };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: map['id'] as int?,
        refNo: map['ref_no'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
        supplierName: map['supplier_name'] as String? ?? 'General Supplier',
        locationId: map['location_id'] as int? ?? 1,
        locationName: map['location_name'] as String? ?? 'Main Branch',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] as String? ?? 'received',
        paymentStatus: map['payment_status'] as String? ?? 'paid',
        createdAt: map['created_at'] as String? ?? '',
        note: map['note'] as String? ?? '',
        itemsJson: map['items_json'] as String? ?? '[]',
        discountType: map['discount_type'] as String? ?? 'none',
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
        shippingCharges: (map['shipping_charges'] as num?)?.toDouble() ?? 0.0,
        shippingDetails: map['shipping_details'] as String? ?? '',
        additionalExpenses:
            (map['additional_expenses'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        paymentAccountId: map['payment_account_id'] as int?,
        paymentNote: map['payment_note'] as String? ?? '',
        payTermNumber: map['pay_term_number'] as int?,
        payTermType: map['pay_term_type'] as String? ?? 'days',
        documentPath: map['document_path'] as String? ?? '',
        purchaseDate: map['purchase_date'] as String? ??
            (map['created_at'] as String? ?? ''),
        isPurchaseOrder: (map['is_purchase_order'] as int? ?? 0) == 1,
        convertedFromPoId: map['converted_from_po_id'] as int?,
      );
}
