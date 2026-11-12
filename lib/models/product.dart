import 'product_variation.dart';

/// Product representation in Smart POS (Single or Variable)
class Product {
  final int? id;
  final String name;
  final String sku;
  final String barcode;
  final String type; // 'single' or 'variable'
  final String barcodeType; // 'Code 128', 'EAN-13', 'UPC-A'
  final int? categoryId;
  final String categoryName;
  final int? brandId;
  final String brandName;
  final String unit; // 'Pc', 'Kg', 'Ltr', 'Box'
  final double purchasePrice;
  final double sellingPrice;
  final double stockQuantity;
  final double alertQuantity;
  final String? imageColor; // Hex string for visual tile fallback
  final String? imagePath; // Persistent local file path in product_images/
  final String? warranty;
  final List<ProductVariation>? variations;
  final String? batchNumber;
  final String? expiryDate; // e.g. "04-2028" or "2028-04"
  final double bonusQty; // Medication/Distributor Bonus free quantity
  final double packSize; // Units per pack/box
  final int? taxRateId;
  final int? taxGroupId;

  Product({
    this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    this.type = 'single',
    this.barcodeType = 'Code 128',
    this.categoryId,
    this.categoryName = 'General',
    this.brandId,
    this.brandName = 'Standard',
    this.unit = 'Pc',
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.alertQuantity = 5.0,
    this.imageColor,
    this.imagePath,
    this.warranty,
    this.variations,
    this.batchNumber,
    this.expiryDate,
    this.bonusQty = 0.0,
    this.packSize = 1.0,
    this.taxRateId,
    this.taxGroupId,
  });

  bool get isVariable => type == 'variable';
  bool get isLowStock => stockQuantity <= alertQuantity && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;

  String? get resolvedImagePath {
    final direct = imagePath?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final legacy = imageColor?.trim() ?? '';
    if (legacy.isNotEmpty && !legacy.startsWith('#')) return legacy;
    return null;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'type': type,
        'barcode_type': barcodeType,
        'category_id': categoryId,
        'category_name': categoryName,
        'brand_id': brandId,
        'brand_name': brandName,
        'unit': unit,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock_quantity': stockQuantity,
        'alert_quantity': alertQuantity,
        'image_color': imageColor ?? '#004EEB',
        'image_path': imagePath,
        'warranty': warranty ?? '',
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_qty': bonusQty,
        'pack_size': packSize,
        'tax_rate_id': taxRateId,
        'tax_group_id': taxGroupId,
      };

  factory Product.fromMap(Map<String, dynamic> map,
          {List<ProductVariation>? variations}) =>
      Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        sku: map['sku'] as String,
        barcode: map['barcode'] as String? ?? map['sku'] as String,
        type: map['type'] as String? ?? 'single',
        barcodeType: map['barcode_type'] as String? ?? 'Code 128',
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String? ?? 'General',
        brandId: map['brand_id'] as int?,
        brandName: map['brand_name'] as String? ?? 'Standard',
        unit: map['unit'] as String? ?? 'Pc',
        purchasePrice: (map['purchase_price'] as num).toDouble(),
        sellingPrice: (map['selling_price'] as num).toDouble(),
        stockQuantity: (map['stock_quantity'] as num).toDouble(),
        alertQuantity: (map['alert_quantity'] as num?)?.toDouble() ?? 5.0,
        imageColor: map['image_color'] as String?,
        imagePath: map['image_path'] as String?,
        warranty: map['warranty'] as String?,
        variations: variations,
        batchNumber: map['batch_number'] as String?,
        expiryDate: map['expiry_date'] as String?,
        bonusQty: (map['bonus_qty'] as num?)?.toDouble() ?? 0.0,
        packSize: (map['pack_size'] as num?)?.toDouble() ?? 1.0,
        taxRateId: map['tax_rate_id'] as int?,
        taxGroupId: map['tax_group_id'] as int?,
      );

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? type,
    String? barcodeType,
    int? categoryId,
    String? categoryName,
    int? brandId,
    String? brandName,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? stockQuantity,
    double? alertQuantity,
    String? imageColor,
    String? imagePath,
    bool clearImagePath = false,
    String? warranty,
    List<ProductVariation>? variations,
    String? batchNumber,
    String? expiryDate,
    double? bonusQty,
    double? packSize,
    int? taxRateId,
    int? taxGroupId,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        type: type ?? this.type,
        barcodeType: barcodeType ?? this.barcodeType,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        brandId: brandId ?? this.brandId,
        brandName: brandName ?? this.brandName,
        unit: unit ?? this.unit,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        alertQuantity: alertQuantity ?? this.alertQuantity,
        imageColor: imageColor ?? this.imageColor,
        imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
        warranty: warranty ?? this.warranty,
        variations: variations ?? this.variations,
        batchNumber: batchNumber ?? this.batchNumber,
        expiryDate: expiryDate ?? this.expiryDate,
        bonusQty: bonusQty ?? this.bonusQty,
        packSize: packSize ?? this.packSize,
        taxRateId: taxRateId ?? this.taxRateId,
        taxGroupId: taxGroupId ?? this.taxGroupId,
      );
}
