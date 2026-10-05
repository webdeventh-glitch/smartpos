import 'dart:convert';

/// Business settings and store configuration
class BusinessSettings {
  final int id;
  final String businessName;
  final String branchName;
  final String currencySymbol;
  final String currencyCode;
  final double defaultTaxRate;
  final String phone;
  final String email;
  final String address;
  final String invoicePrefix;
  final String receiptFooter;

  BusinessSettings({
    this.id = 1,
    this.businessName = 'Ultimate POS Superstore',
    this.branchName = 'Main Branch',
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
    this.defaultTaxRate = 5.0,
    this.phone = '+1 (800) 555-0199',
    this.email = 'contact@ultimatepos.com',
    this.address = 'Suite 400, Commerce Tower, Tech City',
    this.invoicePrefix = 'INV-',
    this.receiptFooter = 'Thank you for shopping with us! Please come again.',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'business_name': businessName,
        'branch_name': branchName,
        'currency_symbol': currencySymbol,
        'currency_code': currencyCode,
        'default_tax_rate': defaultTaxRate,
        'phone': phone,
        'email': email,
        'address': address,
        'invoice_prefix': invoicePrefix,
        'receipt_footer': receiptFooter,
      };

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        id: map['id'] as int? ?? 1,
        businessName: map['business_name'] as String? ?? 'Ultimate POS Superstore',
        branchName: map['branch_name'] as String? ?? 'Main Branch',
        currencySymbol: map['currency_symbol'] as String? ?? '\$',
        currencyCode: map['currency_code'] as String? ?? 'USD',
        defaultTaxRate: (map['default_tax_rate'] as num?)?.toDouble() ?? 5.0,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        address: map['address'] as String? ?? '',
        invoicePrefix: map['invoice_prefix'] as String? ?? 'INV-',
        receiptFooter: map['receipt_footer'] as String? ?? '',
      );
}

/// Business Location (Branch / Warehouse) in Ultimate POS
class BusinessLocation {
  final int? id;
  final String name;
  final String locationId;
  final String landmark;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final String mobile;
  final String email;
  final String invoiceScheme;
  final bool isActive;

  BusinessLocation({
    this.id,
    required this.name,
    this.locationId = 'BL0001',
    this.landmark = '',
    this.city = 'New York',
    this.state = 'NY',
    this.country = 'USA',
    this.zipCode = '10001',
    this.mobile = '+1 (800) 555-0199',
    this.email = 'branch@ultimatepos.com',
    this.invoiceScheme = 'INV-',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'location_id': locationId,
        'landmark': landmark,
        'city': city,
        'state': state,
        'country': country,
        'zip_code': zipCode,
        'mobile': mobile,
        'email': email,
        'invoice_scheme': invoiceScheme,
        'is_active': isActive ? 1 : 0,
      };

  factory BusinessLocation.fromMap(Map<String, dynamic> map) => BusinessLocation(
        id: map['id'] as int?,
        name: map['name'] as String,
        locationId: map['location_id'] as String? ?? 'BL0001',
        landmark: map['landmark'] as String? ?? '',
        city: map['city'] as String? ?? '',
        state: map['state'] as String? ?? '',
        country: map['country'] as String? ?? '',
        zipCode: map['zip_code'] as String? ?? '',
        mobile: map['mobile'] as String? ?? '',
        email: map['email'] as String? ?? '',
        invoiceScheme: map['invoice_scheme'] as String? ?? 'INV-',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

/// Tax Rate representation in Ultimate POS (Single or Tax Group)
class TaxRate {
  final int? id;
  final String name;
  final double amount;
  final bool isTaxGroup;

  TaxRate({
    this.id,
    required this.name,
    required this.amount,
    this.isTaxGroup = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'is_tax_group': isTaxGroup ? 1 : 0,
      };

  factory TaxRate.fromMap(Map<String, dynamic> map) => TaxRate(
        id: map['id'] as int?,
        name: map['name'] as String,
        amount: (map['amount'] as num).toDouble(),
        isTaxGroup: (map['is_tax_group'] as int? ?? 0) == 1,
      );
}

/// Invoice Scheme configuration in Ultimate POS
class InvoiceScheme {
  final int? id;
  final String name;
  final String schemeType; // 'blank', 'year'
  final String prefix;
  final int startNumber;
  final int invoiceCount;
  final int totalDigits;
  final bool isDefault;

  InvoiceScheme({
    this.id,
    required this.name,
    this.schemeType = 'blank',
    this.prefix = 'INV-',
    this.startNumber = 1,
    this.invoiceCount = 0,
    this.totalDigits = 4,
    this.isDefault = false,
  });

  String get previewExample {
    final nextNum = (startNumber + invoiceCount).toString().padLeft(totalDigits, '0');
    if (schemeType == 'year') {
      final year = DateTime.now().year;
      return '$prefix$year-$nextNum';
    }
    return '$prefix$nextNum';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'scheme_type': schemeType,
        'prefix': prefix,
        'start_number': startNumber,
        'invoice_count': invoiceCount,
        'total_digits': totalDigits,
        'is_default': isDefault ? 1 : 0,
      };

  factory InvoiceScheme.fromMap(Map<String, dynamic> map) => InvoiceScheme(
        id: map['id'] as int?,
        name: map['name'] as String,
        schemeType: map['scheme_type'] as String? ?? 'blank',
        prefix: map['prefix'] as String? ?? 'INV-',
        startNumber: map['start_number'] as int? ?? 1,
        invoiceCount: map['invoice_count'] as int? ?? 0,
        totalDigits: map['total_digits'] as int? ?? 4,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
      );
}

/// Category representation
class Category {
  final int? id;
  final String name;
  final String code;
  final String? description;

  Category({this.id, required this.name, required this.code, this.description});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'description': description ?? '',
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        description: map['description'] as String?,
      );
}

/// Brand representation
class Brand {
  final int? id;
  final String name;
  final String? description;

  Brand({this.id, required this.name, this.description});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description ?? '',
      };

  factory Brand.fromMap(Map<String, dynamic> map) => Brand(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
      );
}

/// Unit representation in Ultimate POS (with sub-unit multipliers)
class Unit {
  final int? id;
  final String actualName;
  final String shortName;
  final bool allowDecimal;
  final int? baseUnitId;
  final double baseUnitMultiplier;

  Unit({
    this.id,
    required this.actualName,
    required this.shortName,
    this.allowDecimal = false,
    this.baseUnitId,
    this.baseUnitMultiplier = 1.0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'actual_name': actualName,
        'short_name': shortName,
        'allow_decimal': allowDecimal ? 1 : 0,
        'base_unit_id': baseUnitId,
        'base_unit_multiplier': baseUnitMultiplier,
      };

  factory Unit.fromMap(Map<String, dynamic> map) => Unit(
        id: map['id'] as int?,
        actualName: map['actual_name'] as String,
        shortName: map['short_name'] as String,
        allowDecimal: (map['allow_decimal'] as int? ?? 0) == 1,
        baseUnitId: map['base_unit_id'] as int?,
        baseUnitMultiplier: (map['base_unit_multiplier'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Product Variation for Variable Products (Ultimate POS `variations`)
class ProductVariation {
  final int? id;
  final int? productId;
  final String name; // e.g. "Small", "Medium", "Large" or "Red / XL"
  final String subSku;
  final double purchasePrice;
  final double sellingPrice;
  final double stockQuantity;

  ProductVariation({
    this.id,
    this.productId,
    required this.name,
    required this.subSku,
    required this.purchasePrice,
    required this.sellingPrice,
    this.stockQuantity = 0.0,
  });

  Map<String, dynamic> toMap(int? prodId) => {
        if (id != null) 'id': id,
        'product_id': prodId ?? productId,
        'name': name,
        'sub_sku': subSku,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock_quantity': stockQuantity,
      };

  factory ProductVariation.fromMap(Map<String, dynamic> map) => ProductVariation(
        id: map['id'] as int?,
        productId: map['product_id'] as int?,
        name: map['name'] as String,
        subSku: map['sub_sku'] as String? ?? '',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Selling Price Group in Ultimate POS
class SellingPriceGroup {
  final int? id;
  final String name; // e.g. "Wholesale Price", "VIP Retail", "Distributor"
  final String description;
  final bool isActive;

  SellingPriceGroup({
    this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'is_active': isActive ? 1 : 0,
      };

  factory SellingPriceGroup.fromMap(Map<String, dynamic> map) => SellingPriceGroup(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

/// Warranty in Ultimate POS
class Warranty {
  final int? id;
  final String name;
  final String description;
  final int duration;
  final String durationType; // 'days', 'months', 'years'

  Warranty({
    this.id,
    required this.name,
    this.description = '',
    required this.duration,
    this.durationType = 'months',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'duration': duration,
        'duration_type': durationType,
      };

  factory Warranty.fromMap(Map<String, dynamic> map) => Warranty(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        duration: map['duration'] as int? ?? 12,
        durationType: map['duration_type'] as String? ?? 'months',
      );
}

/// Product representation in Ultimate POS (Single or Variable)
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
  final String? warranty;
  final List<ProductVariation>? variations;

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
    this.warranty,
    this.variations,
  });

  bool get isVariable => type == 'variable';
  bool get isLowStock => stockQuantity <= alertQuantity && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;

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
        'warranty': warranty ?? '',
      };

  factory Product.fromMap(Map<String, dynamic> map, {List<ProductVariation>? variations}) => Product(
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
        warranty: map['warranty'] as String?,
        variations: variations,
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
    String? warranty,
    List<ProductVariation>? variations,
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
        warranty: warranty ?? this.warranty,
        variations: variations ?? this.variations,
      );
}

/// Contact: Customer or Supplier
class Contact {
  final int? id;
  final String type; // 'customer' or 'supplier'
  final String name;
  final String? businessName;
  final String phone;
  final String email;
  final String address;
  final double balance; // Receivable for customer, Payable for supplier
  final double creditLimit;

  Contact({
    this.id,
    required this.type,
    required this.name,
    this.businessName,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.balance = 0.0,
    this.creditLimit = 1000.0,
  });

  bool get isCustomer => type == 'customer';
  bool get isSupplier => type == 'supplier';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'name': name,
        'business_name': businessName ?? '',
        'phone': phone,
        'email': email,
        'address': address,
        'balance': balance,
        'credit_limit': creditLimit,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        type: map['type'] as String,
        name: map['name'] as String,
        businessName: map['business_name'] as String?,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        address: map['address'] as String? ?? '',
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 1000.0,
      );
}

/// Single item in POS Cart / Sale Invoice
class CartItem {
  final Product product;
  double quantity;
  double unitPrice;
  double discount; // amount in currency

  CartItem({
    required this.product,
    this.quantity = 1.0,
    required this.unitPrice,
    this.discount = 0.0,
  });

  double get subtotal => (unitPrice * quantity) - discount;

  Map<String, dynamic> toMap(int saleId) => {
        'sale_id': saleId,
        'product_id': product.id,
        'product_name': product.name,
        'sku': product.sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'discount': discount,
        'subtotal': subtotal,
      };

  Map<String, dynamic> toSavedStateMap() => {
        'product': product.toMap(),
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
      };

  factory CartItem.fromSavedStateMap(Map<String, dynamic> map) => CartItem(
        product: Product.fromMap(map['product'] as Map<String, dynamic>),
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Sale Invoice in Ultimate POS
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
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque', 'split'
  final String paymentStatus; // 'paid', 'partial', 'due'
  final String saleStatus; // 'final', 'draft', 'quotation', 'suspended'
  final String note;
  final String createdAt;
  final List<SaleItem>? items;

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
  });

  double get dueAmount => totalAmount - paidAmount;

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
      );
}

/// Sale item record in SQLite
class SaleItem {
  final int? id;
  final int saleId;
  final int? productId;
  final String productName;
  final String sku;
  final double unitPrice;
  final double quantity;
  final double discount;
  final double subtotal;

  SaleItem({
    this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'discount': discount,
        'subtotal': subtotal,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int,
        productId: map['product_id'] as int?,
        productName: map['product_name'] as String,
        sku: map['sku'] as String? ?? '',
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        subtotal: (map['subtotal'] as num).toDouble(),
      );
}

/// Purchase record
class Purchase {
  final int? id;
  final String refNo;
  final int? supplierId;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final String status; // 'received', 'pending', 'ordered'
  final String paymentStatus; // 'paid', 'due', 'partial'
  final String createdAt;
  final String note;

  Purchase({
    this.id,
    required this.refNo,
    this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    this.status = 'received',
    this.paymentStatus = 'paid',
    required this.createdAt,
    this.note = '',
  });

  double get dueAmount => totalAmount - paidAmount;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': refNo,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'status': status,
        'payment_status': paymentStatus,
        'created_at': createdAt,
        'note': note,
      };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: map['id'] as int?,
        refNo: map['ref_no'] as String,
        supplierId: map['supplier_id'] as int?,
        supplierName: map['supplier_name'] as String,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        status: map['status'] as String? ?? 'received',
        paymentStatus: map['payment_status'] as String? ?? 'paid',
        createdAt: map['created_at'] as String,
        note: map['note'] as String? ?? '',
      );
}

/// Expense record in Ultimate POS
class Expense {
  final int? id;
  final String category;
  final double amount;
  final String refNo;
  final String note;
  final String date;

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.refNo,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'amount': amount,
        'ref_no': refNo,
        'note': note,
        'date': date,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
        date: map['date'] as String,
      );
}

/// Cash register session for the cashier
class CashRegister {
  final int? id;
  final String cashierName;
  final double openingAmount;
  final double closingAmount;
  final double totalSalesCash;
  final double totalSalesCard;
  final double totalSalesOther;
  final String status; // 'open', 'closed'
  final String openedAt;
  final String? closedAt;
  final String note;

  CashRegister({
    this.id,
    this.cashierName = 'Admin Cashier',
    this.openingAmount = 250.0,
    this.closingAmount = 0.0,
    this.totalSalesCash = 0.0,
    this.totalSalesCard = 0.0,
    this.totalSalesOther = 0.0,
    this.status = 'open',
    required this.openedAt,
    this.closedAt,
    this.note = '',
  });

  double get totalCashInRegister => openingAmount + totalSalesCash;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cashier_name': cashierName,
        'opening_amount': openingAmount,
        'closing_amount': closingAmount,
        'total_sales_cash': totalSalesCash,
        'total_sales_card': totalSalesCard,
        'total_sales_other': totalSalesOther,
        'status': status,
        'opened_at': openedAt,
        'closed_at': closedAt,
        'note': note,
      };

  factory CashRegister.fromMap(Map<String, dynamic> map) => CashRegister(
        id: map['id'] as int?,
        cashierName: map['cashier_name'] as String? ?? 'Admin Cashier',
        openingAmount: (map['opening_amount'] as num?)?.toDouble() ?? 0.0,
        closingAmount: (map['closing_amount'] as num?)?.toDouble() ?? 0.0,
        totalSalesCash: (map['total_sales_cash'] as num?)?.toDouble() ?? 0.0,
        totalSalesCard: (map['total_sales_card'] as num?)?.toDouble() ?? 0.0,
        totalSalesOther: (map['total_sales_other'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] as String? ?? 'open',
        openedAt: map['opened_at'] as String,
        closedAt: map['closed_at'] as String?,
        note: map['note'] as String? ?? '',
      );
}

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
    } catch (_) {
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
