import 'business_settings.dart';
import 'model_helpers.dart';

/// Customizable multi-template invoice/receipt layout matching UltimatePOS `InvoiceLayout`.
class InvoiceLayout {
  final int? id;
  final String name;
  final String design; // 'detailed', 'classic', 'elegant', 'slim'
  final String paperSize; // 'a4', '80mm', '58mm'
  final String paperOrientation; // 'portrait', 'landscape'
  final double fontSize;
  final String highlightColor;
  final String invoiceHeading;
  final String headerText;
  final String subTotalLabel;
  final String discountLabel;
  final String taxLabel;
  final String totalLabel;
  final String footerText;
  final String termsText;
  final String signatureLabel;

  // Header visibility flags
  final bool showLogo;
  final bool showBusinessName;
  final bool showAddress;
  final bool showPhone;
  final bool showEmail;
  final bool showTaxNumber;

  // Product table column visibility flags
  final bool showSku;
  final bool showBrand;
  final bool showImage;
  final bool showExpiry;
  final bool showBatch;
  final bool showWarranty;

  // Totals / verification visibility flags
  final bool showBarcode;
  final bool showQrCode;
  final bool showCustomerBalance;
  final bool showSignature;
  final bool showTotalInWords;

  final bool isDefault;
  final String createdAt;

  InvoiceLayout({
    this.id,
    required this.name,
    this.design = 'detailed',
    this.paperSize = 'a4',
    this.paperOrientation = 'portrait',
    this.fontSize = 10.0,
    this.highlightColor = '#0F172A',
    this.invoiceHeading = 'TAX INVOICE',
    this.headerText = '',
    this.subTotalLabel = 'Subtotal',
    this.discountLabel = 'Discount',
    this.taxLabel = 'Tax',
    this.totalLabel = 'Grand Total',
    this.footerText = 'Thank you for shopping with us!',
    this.termsText =
        'Goods once sold can only be exchanged within 7 days with original receipt.',
    this.signatureLabel = 'Authorized Signature',
    this.showLogo = true,
    this.showBusinessName = true,
    this.showAddress = true,
    this.showPhone = true,
    this.showEmail = true,
    this.showTaxNumber = true,
    this.showSku = true,
    this.showBrand = true,
    this.showImage = false,
    this.showExpiry = true,
    this.showBatch = true,
    this.showWarranty = true,
    this.showBarcode = true,
    this.showQrCode = true,
    this.showCustomerBalance = true,
    this.showSignature = true,
    this.showTotalInWords = true,
    this.isDefault = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory InvoiceLayout.fromBusinessSettings(BusinessSettings s) => InvoiceLayout(
        name: 'Store Default Layout',
        design: s.invoiceLayoutDesign,
        paperSize: s.receiptPaperSize,
        paperOrientation: 'portrait',
        fontSize: s.receiptPaperSize == '58mm' ? 8.5 : 10.0,
        invoiceHeading: s.invoiceHeading.isNotEmpty ? s.invoiceHeading : 'TAX INVOICE',
        headerText: s.receiptHeaderNote,
        footerText: s.receiptFooter,
        termsText: s.receiptReturnPolicy,
        showLogo: s.showLogoOnReceipt,
        showSku: s.showSkuOnInvoice,
        showBrand: s.showBrandOnInvoice,
        showExpiry: s.showExpiryOnInvoice,
        showBatch: s.showBatchOnInvoice,
        showWarranty: s.showWarrantyOnInvoice,
        showBarcode: s.showBarcodeOnReceipt,
        showQrCode: s.showQrOnReceipt,
        showCustomerBalance: s.showCustomerBalanceOnReceipt,
        showTotalInWords: s.showTotalInWords,
        isDefault: true,
      );

  InvoiceLayout copyWith({
    int? id,
    String? name,
    String? design,
    String? paperSize,
    String? paperOrientation,
    double? fontSize,
    String? highlightColor,
    String? invoiceHeading,
    String? headerText,
    String? subTotalLabel,
    String? discountLabel,
    String? taxLabel,
    String? totalLabel,
    String? footerText,
    String? termsText,
    String? signatureLabel,
    bool? showLogo,
    bool? showBusinessName,
    bool? showAddress,
    bool? showPhone,
    bool? showEmail,
    bool? showTaxNumber,
    bool? showSku,
    bool? showBrand,
    bool? showImage,
    bool? showExpiry,
    bool? showBatch,
    bool? showWarranty,
    bool? showBarcode,
    bool? showQrCode,
    bool? showCustomerBalance,
    bool? showSignature,
    bool? showTotalInWords,
    bool? isDefault,
    String? createdAt,
  }) {
    return InvoiceLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      design: design ?? this.design,
      paperSize: paperSize ?? this.paperSize,
      paperOrientation: paperOrientation ?? this.paperOrientation,
      fontSize: fontSize ?? this.fontSize,
      highlightColor: highlightColor ?? this.highlightColor,
      invoiceHeading: invoiceHeading ?? this.invoiceHeading,
      headerText: headerText ?? this.headerText,
      subTotalLabel: subTotalLabel ?? this.subTotalLabel,
      discountLabel: discountLabel ?? this.discountLabel,
      taxLabel: taxLabel ?? this.taxLabel,
      totalLabel: totalLabel ?? this.totalLabel,
      footerText: footerText ?? this.footerText,
      termsText: termsText ?? this.termsText,
      signatureLabel: signatureLabel ?? this.signatureLabel,
      showLogo: showLogo ?? this.showLogo,
      showBusinessName: showBusinessName ?? this.showBusinessName,
      showAddress: showAddress ?? this.showAddress,
      showPhone: showPhone ?? this.showPhone,
      showEmail: showEmail ?? this.showEmail,
      showTaxNumber: showTaxNumber ?? this.showTaxNumber,
      showSku: showSku ?? this.showSku,
      showBrand: showBrand ?? this.showBrand,
      showImage: showImage ?? this.showImage,
      showExpiry: showExpiry ?? this.showExpiry,
      showBatch: showBatch ?? this.showBatch,
      showWarranty: showWarranty ?? this.showWarranty,
      showBarcode: showBarcode ?? this.showBarcode,
      showQrCode: showQrCode ?? this.showQrCode,
      showCustomerBalance: showCustomerBalance ?? this.showCustomerBalance,
      showSignature: showSignature ?? this.showSignature,
      showTotalInWords: showTotalInWords ?? this.showTotalInWords,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'design': design,
        'paper_size': paperSize,
        'paper_orientation': paperOrientation,
        'font_size': fontSize,
        'highlight_color': highlightColor,
        'invoice_heading': invoiceHeading,
        'header_text': headerText,
        'sub_total_label': subTotalLabel,
        'discount_label': discountLabel,
        'tax_label': taxLabel,
        'total_label': totalLabel,
        'footer_text': footerText,
        'terms_text': termsText,
        'signature_label': signatureLabel,
        'show_logo': showLogo ? 1 : 0,
        'show_business_name': showBusinessName ? 1 : 0,
        'show_address': showAddress ? 1 : 0,
        'show_phone': showPhone ? 1 : 0,
        'show_email': showEmail ? 1 : 0,
        'show_tax_number': showTaxNumber ? 1 : 0,
        'show_sku': showSku ? 1 : 0,
        'show_brand': showBrand ? 1 : 0,
        'show_image': showImage ? 1 : 0,
        'show_expiry': showExpiry ? 1 : 0,
        'show_batch': showBatch ? 1 : 0,
        'show_warranty': showWarranty ? 1 : 0,
        'show_barcode': showBarcode ? 1 : 0,
        'show_qr_code': showQrCode ? 1 : 0,
        'show_customer_balance': showCustomerBalance ? 1 : 0,
        'show_signature': showSignature ? 1 : 0,
        'show_total_in_words': showTotalInWords ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt,
      };

  factory InvoiceLayout.fromMap(Map<String, dynamic> map) => InvoiceLayout(
        id: map['id'] as int?,
        name: modelAsString(map['name'], 'Default Layout'),
        design: modelAsString(map['design'], 'detailed'),
        paperSize: modelAsString(map['paper_size'], 'a4'),
        paperOrientation: modelAsString(map['paper_orientation'], 'portrait'),
        fontSize: modelAsDouble(map['font_size'], 10.0),
        highlightColor: modelAsString(map['highlight_color'], '#0F172A'),
        invoiceHeading: modelAsString(map['invoice_heading'], 'TAX INVOICE'),
        headerText: modelAsString(map['header_text']),
        subTotalLabel: modelAsString(map['sub_total_label'], 'Subtotal'),
        discountLabel: modelAsString(map['discount_label'], 'Discount'),
        taxLabel: modelAsString(map['tax_label'], 'Tax'),
        totalLabel: modelAsString(map['total_label'], 'Grand Total'),
        footerText:
            modelAsString(map['footer_text'], 'Thank you for shopping with us!'),
        termsText: modelAsString(
          map['terms_text'],
          'Goods once sold can only be exchanged within 7 days with original receipt.',
        ),
        signatureLabel:
            modelAsString(map['signature_label'], 'Authorized Signature'),
        showLogo: modelAsBool(map['show_logo'], true),
        showBusinessName: modelAsBool(map['show_business_name'], true),
        showAddress: modelAsBool(map['show_address'], true),
        showPhone: modelAsBool(map['show_phone'], true),
        showEmail: modelAsBool(map['show_email'], true),
        showTaxNumber: modelAsBool(map['show_tax_number'], true),
        showSku: modelAsBool(map['show_sku'], true),
        showBrand: modelAsBool(map['show_brand'], true),
        showImage: modelAsBool(map['show_image'], false),
        showExpiry: modelAsBool(map['show_expiry'], true),
        showBatch: modelAsBool(map['show_batch'], true),
        showWarranty: modelAsBool(map['show_warranty'], true),
        showBarcode: modelAsBool(map['show_barcode'], true),
        showQrCode: modelAsBool(map['show_qr_code'], true),
        showCustomerBalance: modelAsBool(map['show_customer_balance'], true),
        showSignature: modelAsBool(map['show_signature'], true),
        showTotalInWords: modelAsBool(map['show_total_in_words'], true),
        isDefault: modelAsBool(map['is_default'], false),
        createdAt: modelAsString(map['created_at'], DateTime.now().toIso8601String()),
      );
}

