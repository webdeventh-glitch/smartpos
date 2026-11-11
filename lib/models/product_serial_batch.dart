import 'model_helpers.dart';

/// Serial Number, IMEI & Batch Tracking for Mobile, Electronics & Pharmacy
class ProductSerialBatch {
  final int? id;
  final int productId;
  final String productName;
  final String sku;
  final String serialNumber1; // IMEI 1 / Primary Serial
  final String serialNumber2; // IMEI 2 / Secondary Serial
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final int warrantyMonths;
  final String warrantyExpiryDate;
  final String
      status; // 'in_stock', 'sold', 'returned', 'defective', 'transferred'
  final int? purchaseId;
  final int? saleId;
  final int locationId;
  final double purchasePrice;
  final double sellingPrice;
  final String notes;
  final String createdAt;

  ProductSerialBatch({
    this.id,
    required this.productId,
    required this.productName,
    this.sku = '',
    this.serialNumber1 = '',
    this.serialNumber2 = '',
    this.batchNumber = '',
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.warrantyMonths = 0,
    this.warrantyExpiryDate = '',
    this.status = 'in_stock',
    this.purchaseId,
    this.saleId,
    this.locationId = 1,
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    this.notes = '',
    required this.createdAt,
  });

  bool get isInStock => status == 'in_stock';
  bool get isSold => status == 'sold';
  bool get isExpired {
    if (expiryDate.isEmpty) return false;
    final exp = parseExpiryDate(expiryDate);
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'serial_number_1': serialNumber1,
        'serial_number_2': serialNumber2,
        'batch_number': batchNumber,
        'manufacturing_date': manufacturingDate,
        'expiry_date': expiryDate,
        'warranty_months': warrantyMonths,
        'warranty_expiry_date': warrantyExpiryDate,
        'status': status,
        'purchase_id': purchaseId,
        'sale_id': saleId,
        'location_id': locationId,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'notes': notes,
        'created_at': createdAt,
      };

  factory ProductSerialBatch.fromMap(Map<String, dynamic> map) =>
      ProductSerialBatch(
        id: map['id'] as int?,
        productId: map['product_id'] as int? ?? 0,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        serialNumber1: map['serial_number_1'] as String? ?? '',
        serialNumber2: map['serial_number_2'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        manufacturingDate: map['manufacturing_date'] as String? ?? '',
        expiryDate: map['expiry_date'] as String? ?? '',
        warrantyMonths: (map['warranty_months'] as num?)?.toInt() ?? 0,
        warrantyExpiryDate: map['warranty_expiry_date'] as String? ?? '',
        status: map['status'] as String? ?? 'in_stock',
        purchaseId: map['purchase_id'] as int?,
        saleId: map['sale_id'] as int?,
        locationId: (map['location_id'] as num?)?.toInt() ?? 1,
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
        notes: map['notes'] as String? ?? '',
        createdAt: map['created_at'] as String? ?? '',
      );
}
