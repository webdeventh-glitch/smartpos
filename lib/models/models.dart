import 'dart:convert';

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed != null) return parsed.toInt();
  }
  return fallback;
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed != null) return parsed.toDouble();
  }
  return fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return fallback;
}

String _asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

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
  final String purchaseKey;
  final String businessType; // 'general', 'pharmacy', 'solar', 'electronics', 'clothing'
  final String drugLicenseNo;
  final String dlWarrantor;
  final String timeZone;
  final String currencyPlacement; // 'before', 'after'
  final String financialYearStartMonth;
  final String stockAccountingMethod; // 'FIFO', 'LIFO', 'Average'
  final int transactionEditDays;
  final String dateFormat;
  final String timeFormat;
  final int currencyPrecision;
  final int quantityPrecision;
  final double defaultProfitPercent;
  final String startDate;
  final bool isConfigured;
  final String logoPath;
  final String trialStartDate;
  final String enabledModules;
  final String syncMode; // 'offline', 'hybrid', 'online'
  final String syncServerUrl;
  final String syncApiKey;
  final int syncBranchId;
  final int syncAutoIntervalMinutes;
  final String lastSyncTimestamp;
  final String loginBannerPath;
  final String loginSideTitle;
  final String loginSideSubtitle;

  final String taxNumber;
  final String hardwareId;
  final String deploymentMode; // 'offline_server', 'lan_secondary', 'cloud_hybrid'
  final String serverHost;
  final int serverPort;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final String primaryDbType; // 'mysql', 'postgresql', 'sqlite'
  final String industryPresets;
  final String receiptPaperSize; // '80mm', '58mm', 'a4'
  final String receiptHeaderTagline;
  final String receiptHeaderNote;
  final String receiptReturnPolicy;
  final bool showLogoOnReceipt;
  final bool showBarcodeOnReceipt;
  final bool showQrOnReceipt;
  final bool showCustomerBalanceOnReceipt;
  final bool showTaxBreakdownOnReceipt;
  final bool showCashierNameOnReceipt;
  final int invoicePrintCopies;

  BusinessSettings({
    this.id = 1,
    this.businessName = 'Smart POS System',
    this.branchName = 'Main Branch HQ',
    this.currencySymbol = 'Rs',
    this.currencyCode = 'PKR',
    this.defaultTaxRate = 5.0,
    this.phone = '+92 300 1234567',
    this.email = 'contact@smartpos.com',
    this.address = 'Commercial Plaza, Main Boulevard, Karachi',
    this.invoicePrefix = 'INV-',
    this.receiptFooter = 'Thank you for your business! Please visit again.',
    this.purchaseKey = '',
    this.businessType = 'general',
    this.drugLicenseNo = '',
    this.dlWarrantor = 'Irfan Khan',
    this.timeZone = 'Asia/Karachi',
    this.currencyPlacement = 'before',
    this.financialYearStartMonth = 'January',
    this.stockAccountingMethod = 'FIFO',
    this.transactionEditDays = 30,
    this.dateFormat = 'dd/mm/yyyy',
    this.timeFormat = '12 Hour',
    this.currencyPrecision = 2,
    this.quantityPrecision = 2,
    this.defaultProfitPercent = 25.0,
    this.startDate = '01/01/2026',
    this.isConfigured = false,
    this.logoPath = '',
    this.trialStartDate = '',
    this.enabledModules = '',
    this.syncMode = 'offline',
    this.syncServerUrl = '',
    this.syncApiKey = '',
    this.syncBranchId = 1,
    this.syncAutoIntervalMinutes = 5,
    this.lastSyncTimestamp = '',
    this.loginBannerPath = '',
    this.loginSideTitle = '',
    this.loginSideSubtitle = '',
    this.taxNumber = '',
    this.hardwareId = '',
    this.deploymentMode = 'offline_server',
    this.serverHost = '127.0.0.1',
    this.serverPort = 8080,
    this.primaryDbType = 'mysql',
    this.dbHost = 'localhost',
    this.dbPort = 3306,
    this.dbName = 'smartpos',
    this.dbUser = 'root',
    this.dbPassword = '',
    this.industryPresets = '',
    this.receiptPaperSize = '80mm',
    this.receiptHeaderTagline = 'Wholesale & Retail Distributor',
    this.receiptHeaderNote = 'Welcome to our store!',
    this.receiptReturnPolicy = 'Goods once sold can only be exchanged within 7 days with original receipt.',
    this.showLogoOnReceipt = true,
    this.showBarcodeOnReceipt = true,
    this.showQrOnReceipt = true,
    this.showCustomerBalanceOnReceipt = true,
    this.showTaxBreakdownOnReceipt = true,
    this.showCashierNameOnReceipt = true,
    this.invoicePrintCopies = 1,
  });

  String get effectiveLoginBanner {
    if (loginBannerPath.trim().isNotEmpty) {
      return loginBannerPath.trim();
    }
    if (isPharmacy) {
      return 'assets/images/medicine_agency_banner.jpg';
    }
    return '';
  }

  bool get isHybridSync => syncMode == 'hybrid';
  bool get isOnlineOnly => syncMode == 'online';
  bool get isOfflineOnly => syncMode == 'offline' || syncMode.isEmpty;
  bool get hasOnlineSync => isHybridSync || isOnlineOnly;

  bool get isMySql => primaryDbType.toLowerCase() == 'mysql';
  bool get isPostgreSql => primaryDbType.toLowerCase() == 'postgresql';
  bool get isSqlitePrimary => primaryDbType.toLowerCase() == 'sqlite';

  bool get isPharmacy => businessType == 'pharmacy' || isModuleEnabled(presetPharmacy);
  bool get isSolarOrElectronics => businessType == 'solar' || businessType == 'electronics' || businessType == 'mobile';
  bool get isGeneral => businessType == 'general' || businessType == 'general_store' || businessType == 'kiryana';
  bool get isSupermarket => businessType == 'supermarket';
  bool get isClothing => businessType == 'clothing' || businessType == 'garments';
  bool get isWholesale => businessType == 'wholesale';
  bool get isRestaurant => businessType == 'restaurant' || businessType == 'cafe';
  bool get isRepair => businessType == 'repair' || businessType == 'service';
  bool get isHotel => businessType == 'hotel';
  bool get isGym => businessType == 'gym';
  bool get isManufacturing => businessType == 'manufacturing';
  bool get isWooCommerce => businessType == 'woocommerce';
  bool get isHrm => businessType == 'hrm';
  bool get isAccountingCrm => businessType == 'accounting_crm';
  bool get isFruitWholesale => businessType == 'fruit_wholesale';
  bool get isPoultry => businessType == 'poultry';
  bool get isDairy => businessType == 'dairy_milk' || businessType == 'dairy';
  bool get isTyres => businessType == 'tyres_battery' || businessType == 'tyres';
  bool get isHardware => businessType == 'hardware_tools' || businessType == 'hardware';
  bool get isAutoParts => businessType == 'auto_parts';
  bool get isMeat => businessType == 'meat_butchery' || businessType == 'meat';
  bool get isFabrics => businessType == 'fabrics_textile' || businessType == 'fabrics';
  bool get isLubricants => businessType == 'lubricants_oil' || businessType == 'lubricants';
  bool get isSanitaryTiles => businessType == 'sanitary_tiles' || businessType == 'sanitary';
  bool get isUniversal => businessType == 'universal' || businessType == 'all_in_one';
  bool get isCustomOther => businessType == 'custom_other' || businessType == 'other' || businessType == 'custom';

  // Industry Preset Identifiers (Strictly 1 Active At A Time)
  static const String presetPharmacy = 'pharmacy';
  static const String presetRetailSuperStore = 'retail_supermarket';
  static const String presetMobileElectronics = 'mobile_electronics';
  static const String presetSolarHardware = 'solar_hardware';
  static const String presetRestaurantCafe = 'restaurant_cafe';

  bool get isRetailEnabled =>
      !isPharmacy &&
      !isRestaurant &&
      !isSolarOrElectronics &&
      (isModuleEnabled(presetRetailSuperStore) || isSupermarket || isGeneral);

  bool get isMobileElectronicsEnabled =>
      !isPharmacy &&
      !isRestaurant &&
      (isModuleEnabled(presetMobileElectronics) ||
          businessType == 'mobile' ||
          businessType == 'electronics');

  bool get isSolarHardwareEnabled =>
      !isPharmacy &&
      !isRestaurant &&
      (isModuleEnabled(presetSolarHardware) || businessType == 'solar');

  bool get isRestaurantEnabled =>
      !isPharmacy &&
      !isSolarOrElectronics &&
      (isModuleEnabled(presetRestaurantCafe) ||
          isModuleEnabled(moduleRestaurant) ||
          isRestaurant);

  bool get isPrimaryServer => deploymentMode == 'offline_server' || deploymentMode.isEmpty;
  bool get isLanSecondaryTerminal => deploymentMode == 'lan_secondary';
  bool get isHybridPrimary => deploymentMode == 'cloud_hybrid';

  String get businessTypeDisplayName {
    switch (businessType.toLowerCase()) {
      case 'general_store':
      case 'kiryana':
        return 'General Store / Kiryana';
      case 'supermarket':
        return 'Supermarket / Departmental Store';
      case 'garments':
      case 'clothing':
        return 'Apparel & Garments / Shoes / Boutique';
      case 'mobile':
      case 'electronics':
        return 'Mobile & Electronics Shop';
      case 'solar':
        return 'Solar & Inverter Systems';
      case 'wholesale':
        return 'Wholesale & Distribution';
      case 'pharmacy':
        return 'Pharmacy / Medical Store';
      case 'restaurant':
      case 'cafe':
        return 'Restaurant / Cafe';
      case 'repair':
      case 'service':
        return 'Repairing Shop / Service Center';
      case 'hotel':
        return 'Hotel Management';
      case 'gym':
        return 'Gym / Fitness Center';
      case 'manufacturing':
        return 'Manufacturing / Production';
      case 'woocommerce':
        return 'Online Store / WooCommerce';
      case 'hrm':
        return 'HR & Employee Management';
      case 'accounting_crm':
        return 'Accounting & CRM';
      case 'fruit_wholesale':
        return 'Fruit & Sabzi Wholesale / Mandi';
      case 'poultry':
        return 'Poultry Farm & Trading';
      case 'dairy_milk':
      case 'dairy':
        return 'Dairy, Milk & Eggs / دودھ، دہی اور انڈے';
      case 'tyres_battery':
      case 'tyres':
        return 'Tyre Shop, Rims & Battery / ٹائر، رمز اور بیٹری';
      case 'hardware_tools':
      case 'hardware':
        return 'Hardware, Tools & Paint / ہارڈویئر اور اوزار';
      case 'auto_parts':
        return 'Auto Spare Parts / آٹو سپیئر پارٹس';
      case 'meat_butchery':
      case 'meat':
        return 'Meat, Butchery & Poultry / گوشت، مرغی اور مچھلی';
      case 'fabrics_textile':
      case 'fabrics':
        return 'Fabrics & Cloth (Meter / Gazz) / کپڑا اور تھان';
      case 'lubricants_oil':
      case 'lubricants':
        return 'Mobile Oil & Lubricants / موبائل آئل اور لبریکنٹس';
      case 'sanitary_tiles':
      case 'sanitary':
        return 'Sanitary, Tiles & Bath / سینیٹری اور ٹائلز';
      case 'universal':
        return 'Universal Business (Wholesale & Retail / ہمہ جہت کاروبار - ہول سیل و ریٹیل)';
      case 'custom_other':
      case 'other':
      case 'custom':
        return 'Other / Custom Business (دیگر کسٹم کاروبار)';
      case 'general':
      default:
        return 'General Retail / Supermarket / Wholesale';
    }
  }

  // ==================== MODULAR ENGINE & FEATURE TOGGLES ====================
  static const String moduleRestaurant = 'restaurant';
  static const String moduleRepair = 'repair';
  static const String moduleHotel = 'hotel';
  static const String moduleGym = 'gym';
  static const String moduleManufacturing = 'manufacturing';
  static const String moduleWooCommerce = 'woocommerce';
  static const String moduleHrm = 'hrm';
  static const String moduleAccountingCrm = 'accounting_crm';
  static const String moduleFruitMandi = 'fruit_mandi';
  static const String modulePoultry = 'poultry';

  static const String moduleVariations = 'variations';
  static const String moduleBatchExpiry = 'batch_expiry';
  static const String moduleStockTransfers = 'stock_transfers';
  static const String moduleStockAudit = 'stock_audit';
  static const String moduleExpenses = 'expenses';
  static const String moduleReturns = 'returns';
  static const String moduleFiscalClosing = 'fiscal_closing';

  /// Default active modules list tailored specifically for each business type
  static List<String> defaultModulesForBusinessType(String type) {
    final base = <String>[
      moduleExpenses,
      moduleReturns,
      moduleStockTransfers,
      moduleStockAudit,
    ];

    switch (type.toLowerCase()) {
      case 'universal':
      case 'all_in_one':
      case 'custom_other':
      case 'other':
      case 'custom':
      case 'wholesale':
        // Universal & Unlisted custom businesses get ALL operational modules unlocked with zero restrictions!
        return [
          ...base,
          moduleVariations,
          moduleBatchExpiry,
          moduleAccountingCrm,
          moduleHrm,
          moduleFiscalClosing,
          presetRetailSuperStore,
        ];
      case 'restaurant':
      case 'cafe':
        return [...base, moduleRestaurant, moduleHrm, presetRestaurantCafe];
      case 'repair':
      case 'service':
        return [...base, moduleRepair];
      case 'hotel':
        return [...base, moduleHotel, moduleHrm, moduleAccountingCrm];
      case 'gym':
        return [...base, moduleGym, moduleHrm];
      case 'manufacturing':
        return [...base, moduleManufacturing, moduleAccountingCrm, moduleVariations];
      case 'woocommerce':
        return [...base, moduleWooCommerce, moduleVariations];
      case 'hrm':
        return [...base, moduleHrm, moduleAccountingCrm];
      case 'accounting_crm':
        return [...base, moduleAccountingCrm];
      case 'fruit_wholesale':
        return [...base, moduleFruitMandi, moduleAccountingCrm];
      case 'poultry':
        return [...base, modulePoultry, moduleAccountingCrm];
      case 'dairy_milk':
      case 'dairy':
      case 'meat_butchery':
      case 'meat':
      case 'fabrics_textile':
      case 'fabrics':
        return [...base, moduleVariations];
      case 'tyres_battery':
      case 'tyres':
      case 'auto_parts':
      case 'lubricants_oil':
      case 'lubricants':
      case 'hardware_tools':
      case 'hardware':
      case 'sanitary_tiles':
      case 'sanitary':
        return [...base, moduleRepair, moduleVariations];
      case 'pharmacy':
        return [...base, moduleBatchExpiry, presetPharmacy];
      case 'mobile':
      case 'electronics':
        return [...base, moduleRepair, moduleVariations, presetMobileElectronics];
      case 'solar':
        return [...base, moduleRepair, moduleVariations, presetSolarHardware];
      case 'clothing':
      case 'garments':
        return [...base, moduleVariations];
      case 'supermarket':
        return [...base, moduleVariations, moduleBatchExpiry, presetRetailSuperStore];
      case 'general_store':
      case 'kiryana':
      case 'general':
      default:
        return [...base, presetRetailSuperStore];
    }
  }

  /// Evaluates active modules as a Set.
  /// Includes enabledModules, industryPresets, and falls back to defaultModulesForBusinessType if empty.
  Set<String> get activeModules {
    final modules = <String>{};
    if (enabledModules.trim().isNotEmpty) {
      modules.addAll(enabledModules
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty));
    } else {
      modules.addAll(defaultModulesForBusinessType(businessType));
    }
    if (industryPresets.trim().isNotEmpty) {
      modules.addAll(industryPresets
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty));
    }
    return modules;
  }

  /// Checks if a specific feature or industry module is enabled
  bool isModuleEnabled(String moduleKey) {
    return activeModules.contains(moduleKey.toLowerCase());
  }

  /// Returns true if at least one specialized industry module is enabled
  bool get hasAnyIndustryModuleEnabled {
    const industryKeys = [
      moduleRestaurant,
      moduleRepair,
      moduleHotel,
      moduleGym,
      moduleManufacturing,
      moduleWooCommerce,
      moduleHrm,
      moduleAccountingCrm,
      moduleFruitMandi,
      modulePoultry,
      presetMobileElectronics,
      presetSolarHardware,
      presetRestaurantCafe,
    ];
    return industryKeys.any((key) => isModuleEnabled(key));
  }

  BusinessSettings copyWith({
    int? id,
    String? businessName,
    String? branchName,
    String? currencySymbol,
    String? currencyCode,
    double? defaultTaxRate,
    String? phone,
    String? email,
    String? address,
    String? invoicePrefix,
    String? receiptFooter,
    String? purchaseKey,
    String? businessType,
    String? drugLicenseNo,
    String? dlWarrantor,
    String? timeZone,
    String? currencyPlacement,
    String? financialYearStartMonth,
    String? stockAccountingMethod,
    int? transactionEditDays,
    String? dateFormat,
    String? timeFormat,
    int? currencyPrecision,
    int? quantityPrecision,
    double? defaultProfitPercent,
    String? startDate,
    bool? isConfigured,
    String? logoPath,
    String? trialStartDate,
    String? enabledModules,
    String? syncMode,
    String? syncServerUrl,
    String? syncApiKey,
    int? syncBranchId,
    int? syncAutoIntervalMinutes,
    String? lastSyncTimestamp,
    String? loginBannerPath,
    String? loginSideTitle,
    String? loginSideSubtitle,
    String? taxNumber,
    String? hardwareId,
    String? deploymentMode,
    String? serverHost,
    int? serverPort,
    String? dbHost,
    int? dbPort,
    String? dbName,
    String? dbUser,
    String? dbPassword,
    String? industryPresets,
    String? primaryDbType,
    String? receiptPaperSize,
    String? receiptHeaderTagline,
    String? receiptHeaderNote,
    String? receiptReturnPolicy,
    bool? showLogoOnReceipt,
    bool? showBarcodeOnReceipt,
    bool? showQrOnReceipt,
    bool? showCustomerBalanceOnReceipt,
    bool? showTaxBreakdownOnReceipt,
    bool? showCashierNameOnReceipt,
    int? invoicePrintCopies,
  }) {
    return BusinessSettings(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      branchName: branchName ?? this.branchName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      purchaseKey: purchaseKey ?? this.purchaseKey,
      businessType: businessType ?? this.businessType,
      drugLicenseNo: drugLicenseNo ?? this.drugLicenseNo,
      dlWarrantor: dlWarrantor ?? this.dlWarrantor,
      timeZone: timeZone ?? this.timeZone,
      currencyPlacement: currencyPlacement ?? this.currencyPlacement,
      financialYearStartMonth: financialYearStartMonth ?? this.financialYearStartMonth,
      stockAccountingMethod: stockAccountingMethod ?? this.stockAccountingMethod,
      transactionEditDays: transactionEditDays ?? this.transactionEditDays,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      currencyPrecision: currencyPrecision ?? this.currencyPrecision,
      quantityPrecision: quantityPrecision ?? this.quantityPrecision,
      defaultProfitPercent: defaultProfitPercent ?? this.defaultProfitPercent,
      startDate: startDate ?? this.startDate,
      isConfigured: isConfigured ?? this.isConfigured,
      logoPath: logoPath ?? this.logoPath,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      enabledModules: enabledModules ?? this.enabledModules,
      syncMode: syncMode ?? this.syncMode,
      syncServerUrl: syncServerUrl ?? this.syncServerUrl,
      syncApiKey: syncApiKey ?? this.syncApiKey,
      syncBranchId: syncBranchId ?? this.syncBranchId,
      syncAutoIntervalMinutes: syncAutoIntervalMinutes ?? this.syncAutoIntervalMinutes,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
      loginBannerPath: loginBannerPath ?? this.loginBannerPath,
      loginSideTitle: loginSideTitle ?? this.loginSideTitle,
      loginSideSubtitle: loginSideSubtitle ?? this.loginSideSubtitle,
      taxNumber: taxNumber ?? this.taxNumber,
      hardwareId: hardwareId ?? this.hardwareId,
      deploymentMode: deploymentMode ?? this.deploymentMode,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      primaryDbType: primaryDbType ?? this.primaryDbType,
      dbHost: dbHost ?? this.dbHost,
      dbPort: dbPort ?? this.dbPort,
      dbName: dbName ?? this.dbName,
      dbUser: dbUser ?? this.dbUser,
      dbPassword: dbPassword ?? this.dbPassword,
      industryPresets: industryPresets ?? this.industryPresets,
      receiptPaperSize: receiptPaperSize ?? this.receiptPaperSize,
      receiptHeaderTagline: receiptHeaderTagline ?? this.receiptHeaderTagline,
      receiptHeaderNote: receiptHeaderNote ?? this.receiptHeaderNote,
      receiptReturnPolicy: receiptReturnPolicy ?? this.receiptReturnPolicy,
      showLogoOnReceipt: showLogoOnReceipt ?? this.showLogoOnReceipt,
      showBarcodeOnReceipt: showBarcodeOnReceipt ?? this.showBarcodeOnReceipt,
      showQrOnReceipt: showQrOnReceipt ?? this.showQrOnReceipt,
      showCustomerBalanceOnReceipt: showCustomerBalanceOnReceipt ?? this.showCustomerBalanceOnReceipt,
      showTaxBreakdownOnReceipt: showTaxBreakdownOnReceipt ?? this.showTaxBreakdownOnReceipt,
      showCashierNameOnReceipt: showCashierNameOnReceipt ?? this.showCashierNameOnReceipt,
      invoicePrintCopies: invoicePrintCopies ?? this.invoicePrintCopies,
    );
  }

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
        'purchase_key': purchaseKey,
        'business_type': businessType,
        'drug_license_no': drugLicenseNo,
        'dl_warrantor': dlWarrantor,
        'time_zone': timeZone,
        'currency_placement': currencyPlacement,
        'financial_year_start_month': financialYearStartMonth,
        'stock_accounting_method': stockAccountingMethod,
        'transaction_edit_days': transactionEditDays,
        'date_format': dateFormat,
        'time_format': timeFormat,
        'currency_precision': currencyPrecision,
        'quantity_precision': quantityPrecision,
        'default_profit_percent': defaultProfitPercent,
        'start_date': startDate,
        'is_configured': isConfigured ? 1 : 0,
        'logo_path': logoPath,
        'trial_start_date': trialStartDate,
        'enabled_modules': enabledModules,
        'sync_mode': syncMode,
        'sync_server_url': syncServerUrl,
        'sync_api_key': syncApiKey,
        'sync_branch_id': syncBranchId,
        'sync_auto_interval_minutes': syncAutoIntervalMinutes,
        'last_sync_timestamp': lastSyncTimestamp,
        'login_banner_path': loginBannerPath,
        'login_side_title': loginSideTitle,
        'login_side_subtitle': loginSideSubtitle,
        'tax_number': taxNumber,
        'hardware_id': hardwareId,
        'deployment_mode': deploymentMode,
        'server_host': serverHost,
        'server_port': serverPort,
        'primary_db_type': primaryDbType,
        'db_host': dbHost,
        'db_port': dbPort,
        'db_name': dbName,
        'db_user': dbUser,
        'db_password': dbPassword,
        'industry_presets': industryPresets,
        'receipt_paper_size': receiptPaperSize,
        'receipt_header_tagline': receiptHeaderTagline,
        'receipt_header_note': receiptHeaderNote,
        'receipt_return_policy': receiptReturnPolicy,
        'show_logo_on_receipt': showLogoOnReceipt ? 1 : 0,
        'show_barcode_on_receipt': showBarcodeOnReceipt ? 1 : 0,
        'show_qr_on_receipt': showQrOnReceipt ? 1 : 0,
        'show_customer_balance_on_receipt': showCustomerBalanceOnReceipt ? 1 : 0,
        'show_tax_breakdown_on_receipt': showTaxBreakdownOnReceipt ? 1 : 0,
        'show_cashier_name_on_receipt': showCashierNameOnReceipt ? 1 : 0,
        'invoice_print_copies': invoicePrintCopies,
      };

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        id: _asInt(map['id'], 1),
        businessName: _asString(map['business_name'], 'Smart POS System'),
        branchName: _asString(map['branch_name'], 'Main Branch HQ'),
        currencySymbol: _asString(map['currency_symbol'], 'Rs'),
        currencyCode: _asString(map['currency_code'], 'PKR'),
        defaultTaxRate: _asDouble(map['default_tax_rate'], 5.0),
        phone: _asString(map['phone']),
        email: _asString(map['email']),
        address: _asString(map['address']),
        invoicePrefix: _asString(map['invoice_prefix'], 'INV-'),
        receiptFooter: _asString(map['receipt_footer']),
        purchaseKey: _asString(map['purchase_key']),
        businessType: _asString(map['business_type'], 'general'),
        drugLicenseNo: _asString(map['drug_license_no']),
        dlWarrantor: _asString(map['dl_warrantor']),
        timeZone: _asString(map['time_zone'], 'Asia/Karachi'),
        currencyPlacement: _asString(map['currency_placement'], 'before'),
        financialYearStartMonth: _asString(map['financial_year_start_month'], 'January'),
        stockAccountingMethod: _asString(map['stock_accounting_method'], 'FIFO'),
        transactionEditDays: _asInt(map['transaction_edit_days'], 30),
        dateFormat: _asString(map['date_format'], 'dd/mm/yyyy'),
        timeFormat: _asString(map['time_format'], '12 Hour'),
        currencyPrecision: _asInt(map['currency_precision'], 2),
        quantityPrecision: _asInt(map['quantity_precision'], 2),
        defaultProfitPercent: _asDouble(map['default_profit_percent'], 25.0),
        startDate: _asString(map['start_date'], '01/01/2026'),
        isConfigured: _asBool(map['is_configured'], false),
        logoPath: _asString(map['logo_path']),
        trialStartDate: _asString(map['trial_start_date']),
        enabledModules: _asString(map['enabled_modules']),
        syncMode: _asString(map['sync_mode'], 'offline'),
        syncServerUrl: _asString(map['sync_server_url']),
        syncApiKey: _asString(map['sync_api_key']),
        syncBranchId: _asInt(map['sync_branch_id'], 1),
        syncAutoIntervalMinutes: _asInt(map['sync_auto_interval_minutes'], 5),
        lastSyncTimestamp: _asString(map['last_sync_timestamp']),
        loginBannerPath: _asString(map['login_banner_path']),
        loginSideTitle: _asString(map['login_side_title']),
        loginSideSubtitle: _asString(map['login_side_subtitle']),
        taxNumber: _asString(map['tax_number']),
        hardwareId: _asString(map['hardware_id']),
        deploymentMode: _asString(map['deployment_mode'], 'offline_server'),
        serverHost: _asString(map['server_host'], '127.0.0.1'),
        serverPort: _asInt(map['server_port'], 8080),
        primaryDbType: _asString(map['primary_db_type'], 'mysql'),
        dbHost: _asString(map['db_host'], 'localhost'),
        dbPort: _asInt(map['db_port'], 3306),
        dbName: _asString(map['db_name'], 'smartpos'),
        dbUser: _asString(map['db_user'], 'root'),
        dbPassword: _asString(map['db_password']),
        industryPresets: _asString(map['industry_presets'], 'retail_supermarket'),
        receiptPaperSize: _asString(map['receipt_paper_size'], '80mm'),
        receiptHeaderTagline: _asString(map['receipt_header_tagline'], 'Wholesale & Retail Distributor'),
        receiptHeaderNote: _asString(map['receipt_header_note'], 'Welcome to our store!'),
        receiptReturnPolicy: _asString(map['receipt_return_policy'], 'Goods once sold can only be exchanged within 7 days with original receipt.'),
        showLogoOnReceipt: _asBool(map['show_logo_on_receipt'], true),
        showBarcodeOnReceipt: _asBool(map['show_barcode_on_receipt'], true),
        showQrOnReceipt: _asBool(map['show_qr_on_receipt'], true),
        showCustomerBalanceOnReceipt: _asBool(map['show_customer_balance_on_receipt'], true),
        showTaxBreakdownOnReceipt: _asBool(map['show_tax_breakdown_on_receipt'], true),
        showCashierNameOnReceipt: _asBool(map['show_cashier_name_on_receipt'], true),
        invoicePrintCopies: _asInt(map['invoice_print_copies'], 1),
      );
}

/// Business Location (Branch / Warehouse) in Smart POS
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
    this.email = 'branch@smartpos.com',
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

/// Tax Rate representation in Smart POS (Single or Tax Group)
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

/// Invoice Scheme configuration in Smart POS
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
  final int? parentId;

  Category({this.id, required this.name, required this.code, this.description, this.parentId});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'description': description ?? '',
        'parent_id': parentId,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        description: map['description'] as String?,
        parentId: map['parent_id'] as int?,
      );
}

/// Variation Template in Smart POS (e.g. Size, Color)
class VariationTemplate {
  final int? id;
  final String name;
  final List<String> values;

  VariationTemplate({this.id, required this.name, required this.values});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'values_json': jsonEncode(values),
      };

  factory VariationTemplate.fromMap(Map<String, dynamic> map) {
    List<String> parsedValues = [];
    if (map['values_json'] != null) {
      try {
        final decoded = jsonDecode(map['values_json'] as String);
        if (decoded is List) {
          parsedValues = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return VariationTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
      values: parsedValues,
    );
  }
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

/// Unit representation in Smart POS (with sub-unit multipliers)
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

/// Product Variation for Variable Products (Smart POS `variations`)
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

/// Selling Price Group in Smart POS
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

/// Warranty in Smart POS
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
  final String? warranty;
  final List<ProductVariation>? variations;
  final String? batchNumber;
  final String? expiryDate; // e.g. "04-2028" or "2028-04"
  final double bonusQty; // Medication/Distributor Bonus free quantity
  final double packSize; // Units per pack/box

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
    this.batchNumber,
    this.expiryDate,
    this.bonusQty = 0.0,
    this.packSize = 1.0,
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
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_qty': bonusQty,
        'pack_size': packSize,
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
        batchNumber: map['batch_number'] as String?,
        expiryDate: map['expiry_date'] as String?,
        bonusQty: (map['bonus_qty'] as num?)?.toDouble() ?? 0.0,
        packSize: (map['pack_size'] as num?)?.toDouble() ?? 1.0,
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
    String? batchNumber,
    String? expiryDate,
    double? bonusQty,
    double? packSize,
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
        batchNumber: batchNumber ?? this.batchNumber,
        expiryDate: expiryDate ?? this.expiryDate,
        bonusQty: bonusQty ?? this.bonusQty,
        packSize: packSize ?? this.packSize,
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
  String? batchNumber;
  String? expiryDate;
  double bonusQuantity;
  double packDiscount; // percentage or fixed

  CartItem({
    required this.product,
    this.quantity = 1.0,
    required this.unitPrice,
    this.discount = 0.0,
    this.batchNumber,
    this.expiryDate,
    this.bonusQuantity = 0.0,
    this.packDiscount = 0.0,
  }) {
    batchNumber ??= product.batchNumber;
    expiryDate ??= product.expiryDate;
  }

  double get subtotal {
    final packVal = unitPrice * quantity;
    if (packDiscount > 0) {
      // packDiscount as percentage (e.g. 14.50%)
      final discAmt = (packVal * packDiscount) / 100.0;
      return packVal - discAmt - discount;
    }
    return packVal - discount;
  }

  double get packValue => unitPrice * quantity;

  double get calculatedDiscount {
    if (packDiscount > 0) {
      return (packValue * packDiscount) / 100.0 + discount;
    }
    return discount;
  }

  Map<String, dynamic> toMap(int saleId) => {
        'sale_id': saleId,
        'product_id': product.id,
        'product_name': product.name,
        'sku': product.sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'discount': calculatedDiscount,
        'subtotal': subtotal,
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
      };

  Map<String, dynamic> toSavedStateMap() => {
        'product': product.toMap(),
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
      };

  factory CartItem.fromSavedStateMap(Map<String, dynamic> map) => CartItem(
        product: Product.fromMap(map['product'] as Map<String, dynamic>),
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        batchNumber: map['batch_number'] as String?,
        expiryDate: map['expiry_date'] as String?,
        bonusQuantity: (map['bonus_quantity'] as num?)?.toDouble() ?? 0.0,
        packDiscount: (map['pack_discount'] as num?)?.toDouble() ?? 0.0,
      );
}

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
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque', 'split'
  final String paymentStatus; // 'paid', 'partial', 'due'
  final String saleStatus; // 'final', 'draft', 'quotation', 'suspended'
  final String note;
  final String createdAt;
  final List<SaleItem>? items;
  final String? userName;

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
  }) : this.cashierName = cashierName ?? userName ?? 'Cashier';

  final String cashierName;

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
        'user_name': userName ?? cashierName,
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
  final String? batchNumber;
  final String? expiryDate;
  final double bonusQuantity;
  final double packDiscount;

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
    this.batchNumber,
    this.expiryDate,
    this.bonusQuantity = 0.0,
    this.packDiscount = 0.0,
  });

  double get packValue => unitPrice * quantity;

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
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
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
        batchNumber: map['batch_number'] as String?,
        expiryDate: map['expiry_date'] as String?,
        bonusQuantity: (map['bonus_quantity'] as num?)?.toDouble() ?? 0.0,
        packDiscount: (map['pack_discount'] as num?)?.toDouble() ?? 0.0,
      );
}

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
  });

  double get dueAmount => totalAmount > paidAmount ? totalAmount - paidAmount : 0.0;
  double get finalTotal => totalAmount;
  String get referenceNo => refNo;

  List<Map<String, dynamic>> getItems() {
    try {
      if (itemsJson.isEmpty || itemsJson == '[]') return [];
      final list = jsonDecode(itemsJson);
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
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
      };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: map['id'] as int?,
        refNo: map['ref_no'] as String,
        supplierId: map['supplier_id'] as int?,
        supplierName: map['supplier_name'] as String,
        locationId: map['location_id'] as int? ?? 1,
        locationName: map['location_name'] as String? ?? 'Main Branch',
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        status: map['status'] as String? ?? 'received',
        paymentStatus: map['payment_status'] as String? ?? 'paid',
        createdAt: map['created_at'] as String,
        note: map['note'] as String? ?? '',
        itemsJson: map['items_json'] as String? ?? '[]',
      );
}

/// Expense record in Smart POS
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

  factory StockTransferItem.fromMap(Map<String, dynamic> map) => StockTransferItem(
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
    } catch (_) {
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

  factory StockAdjustmentItem.fromMap(Map<String, dynamic> map) => StockAdjustmentItem(
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
    } catch (_) {
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

/// Contact Payment (Customer payment collection or Supplier payment payout)
class ContactPayment {
  final int? id;
  final int contactId;
  final String contactName;
  final String paymentType; // 'receive' (customer paid due), 'pay' (paid to supplier)
  final double amount;
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque'
  final String date;
  final String refNo;
  final String note;

  ContactPayment({
    this.id,
    required this.contactId,
    required this.contactName,
    required this.paymentType,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.date,
    required this.refNo,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contact_id': contactId,
        'contact_name': contactName,
        'payment_type': paymentType,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': date,
        'ref_no': refNo,
        'note': note,
      };

  factory ContactPayment.fromMap(Map<String, dynamic> map) => ContactPayment(
        id: map['id'] as int?,
        contactId: map['contact_id'] as int,
        contactName: map['contact_name'] as String,
        paymentType: map['payment_type'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        date: map['date'] as String,
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );
}

/// Payment Account (Bank account, Cash drawer, Merchant POS)
class PaymentAccount {
  final int? id;
  final String name;
  final String accountNumber;
  final String accountType; // 'cash', 'bank', 'pos_terminal'
  final double openingBalance;
  final double currentBalance;
  final String note;

  PaymentAccount({
    this.id,
    required this.name,
    this.accountNumber = '',
    this.accountType = 'bank',
    this.openingBalance = 0.0,
    required this.currentBalance,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'account_number': accountNumber,
        'account_type': accountType,
        'opening_balance': openingBalance,
        'current_balance': currentBalance,
        'note': note,
      };

  factory PaymentAccount.fromMap(Map<String, dynamic> map) => PaymentAccount(
        id: map['id'] as int?,
        name: map['name'] as String,
        accountNumber: map['account_number'] as String? ?? '',
        accountType: map['account_type'] as String? ?? 'bank',
        openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
        note: map['note'] as String? ?? '',
      );
}

/// Fund Transfer between Payment Accounts
class AccountTransfer {
  final int? id;
  final int fromAccountId;
  final String fromAccountName;
  final int toAccountId;
  final String toAccountName;
  final double amount;
  final String date;
  final String refNo;
  final String note;

  AccountTransfer({
    this.id,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.date,
    required this.refNo,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'from_account_id': fromAccountId,
        'from_account_name': fromAccountName,
        'to_account_id': toAccountId,
        'to_account_name': toAccountName,
        'amount': amount,
        'date': date,
        'ref_no': refNo,
        'note': note,
      };

  factory AccountTransfer.fromMap(Map<String, dynamic> map) => AccountTransfer(
        id: map['id'] as int?,
        fromAccountId: map['from_account_id'] as int,
        fromAccountName: map['from_account_name'] as String,
        toAccountId: map['to_account_id'] as int,
        toAccountName: map['to_account_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: map['date'] as String,
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );
}

/// Modern Double-Entry Ledger Transaction Model
class LedgerEntry {
  final String date;
  final String transactionType; // 'sale_invoice', 'customer_payment', 'purchase_bill', 'supplier_payment', 'sale_return', 'purchase_return', 'expense', 'transfer_in', 'transfer_out', 'opening_balance'
  final String refNo;
  final String description;
  final String paymentMethod;
  final String accountName;
  final double debit; // Dr (Money in / Receivable increased / Asset debited)
  final double credit; // Cr (Money out / Payable increased / Liability credited)
  final double runningBalance; // Calculated progressive balance
  final int? parentId;

  LedgerEntry({
    required this.date,
    required this.transactionType,
    required this.refNo,
    required this.description,
    this.paymentMethod = 'cash',
    this.accountName = 'Main Till',
    this.debit = 0.0,
    this.credit = 0.0,
    this.runningBalance = 0.0,
    this.parentId,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'transaction_type': transactionType,
        'ref_no': refNo,
        'description': description,
        'payment_method': paymentMethod,
        'account_name': accountName,
        'debit': debit,
        'credit': credit,
        'running_balance': runningBalance,
        if (parentId != null) 'parent_id': parentId,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        date: map['date'] as String? ?? '',
        transactionType: map['transaction_type'] as String? ?? 'general',
        refNo: map['ref_no'] as String? ?? '',
        description: map['description'] as String? ?? '',
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        accountName: map['account_name'] as String? ?? '',
        debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
        credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
        runningBalance: (map['running_balance'] as num?)?.toDouble() ?? 0.0,
        parentId: map['parent_id'] as int?,
      );
}

/// User & Authorization Model
class User {
  final int? id;
  final String name;
  final String username;
  final String password;
  final String email;
  final String role; // 'superadmin', 'admin', 'manager', 'salesman', 'cashier'
  final String status; // 'active', 'inactive'
  final int branchId;
  final String branchName;
  final String phone;

  // Granular Operational Authorization Matrix
  final bool canEditPrice; // Can change unit selling price on POS counter
  final bool canGiveDiscount; // Can apply discounts on sales
  final double maxDiscountPercent; // Maximum discount allowed (e.g. 5.0%)
  final bool canViewCostPrice; // Can view product purchase/cost prices & profit margins
  final bool canDeleteSale; // Can void or delete past sales invoices
  final bool canProcessReturn; // Can accept customer returns & issue cash refunds
  final bool canAccessKhata; // Can access customer credit ledger & khata
  final bool canAccessInventory; // Can manage stock transfers & adjustments
  final bool canAccessReports; // Can view sales and profit/loss reports
  final bool canAccessSettings; // Can modify store configuration & business settings
  final bool canManageUsers; // Can create or modify salesman authorizations
  final String permissions; // Raw comma-separated string for custom permissions

  User({
    this.id,
    required this.name,
    required this.username,
    required this.password,
    this.email = '',
    this.role = 'salesman',
    this.status = 'active',
    this.branchId = 1,
    this.branchName = 'Main Branch HQ',
    this.phone = '',
    this.canEditPrice = false,
    this.canGiveDiscount = true,
    this.maxDiscountPercent = 5.0,
    this.canViewCostPrice = false,
    this.canDeleteSale = false,
    this.canProcessReturn = false,
    this.canAccessKhata = true,
    this.canAccessInventory = false,
    this.canAccessReports = false,
    this.canAccessSettings = false,
    this.canManageUsers = false,
    this.permissions = '',
  });

  bool get isSuperAdmin => role.toLowerCase() == 'superadmin' || role.toLowerCase() == 'owner';
  bool get isAdmin => isSuperAdmin || role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager' || role.toLowerCase() == 'store manager';
  bool get isSalesman => role.toLowerCase() == 'salesman';
  bool get isCashier => role.toLowerCase() == 'cashier';

  /// Permission checker: Owner & Admin bypass all restrictions
  bool hasPermission(String perm) {
    if (isSuperAdmin || isAdmin) return true;
    final list = permissions.split(',').map((p) => p.trim().toLowerCase()).toList();
    if (list.contains(perm.toLowerCase())) return true;

    switch (perm.toLowerCase()) {
      case 'pos.edit_price':
      case 'edit_price':
        return canEditPrice;
      case 'pos.give_discount':
      case 'give_discount':
        return canGiveDiscount;
      case 'products.view_cost':
      case 'view_cost_price':
        return canViewCostPrice;
      case 'sales.delete':
      case 'delete_sale':
        return canDeleteSale;
      case 'sales.returns':
      case 'process_return':
        return canProcessReturn;
      case 'contacts.khata':
      case 'access_khata':
        return canAccessKhata;
      case 'inventory.manage':
      case 'access_inventory':
        return canAccessInventory;
      case 'reports.view':
      case 'access_reports':
        return canAccessReports;
      case 'settings.manage':
      case 'access_settings':
        return canAccessSettings;
      case 'users.manage':
      case 'manage_users':
        return canManageUsers;
      default:
        return false;
    }
  }

  User copyWith({
    int? id,
    String? name,
    String? username,
    String? password,
    String? email,
    String? role,
    String? status,
    int? branchId,
    String? branchName,
    String? phone,
    bool? canEditPrice,
    bool? canGiveDiscount,
    double? maxDiscountPercent,
    bool? canViewCostPrice,
    bool? canDeleteSale,
    bool? canProcessReturn,
    bool? canAccessKhata,
    bool? canAccessInventory,
    bool? canAccessReports,
    bool? canAccessSettings,
    bool? canManageUsers,
    String? permissions,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      phone: phone ?? this.phone,
      canEditPrice: canEditPrice ?? this.canEditPrice,
      canGiveDiscount: canGiveDiscount ?? this.canGiveDiscount,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      canViewCostPrice: canViewCostPrice ?? this.canViewCostPrice,
      canDeleteSale: canDeleteSale ?? this.canDeleteSale,
      canProcessReturn: canProcessReturn ?? this.canProcessReturn,
      canAccessKhata: canAccessKhata ?? this.canAccessKhata,
      canAccessInventory: canAccessInventory ?? this.canAccessInventory,
      canAccessReports: canAccessReports ?? this.canAccessReports,
      canAccessSettings: canAccessSettings ?? this.canAccessSettings,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'username': username,
        'password': password,
        'email': email,
        'role': role,
        'status': status,
        'branch_id': branchId,
        'branch_name': branchName,
        'phone': phone,
        'can_edit_price': canEditPrice ? 1 : 0,
        'can_give_discount': canGiveDiscount ? 1 : 0,
        'max_discount_percent': maxDiscountPercent,
        'can_view_cost_price': canViewCostPrice ? 1 : 0,
        'can_delete_sale': canDeleteSale ? 1 : 0,
        'can_process_return': canProcessReturn ? 1 : 0,
        'can_access_khata': canAccessKhata ? 1 : 0,
        'can_access_inventory': canAccessInventory ? 1 : 0,
        'can_access_reports': canAccessReports ? 1 : 0,
        'can_access_settings': canAccessSettings ? 1 : 0,
        'can_manage_users': canManageUsers ? 1 : 0,
        'permissions': permissions,
      };

  factory User.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['role'] as String? ?? 'salesman').toLowerCase();
    final isAdm = roleStr == 'superadmin' || roleStr == 'admin' || roleStr == 'owner';

    return User(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'salesman',
      status: map['status'] as String? ?? 'active',
      branchId: map['branch_id'] as int? ?? 1,
      branchName: map['branch_name'] as String? ?? 'Main Branch HQ',
      phone: map['phone'] as String? ?? '',
      canEditPrice: (map['can_edit_price'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canGiveDiscount: (map['can_give_discount'] as int? ?? 1) == 1,
      maxDiscountPercent: (map['max_discount_percent'] as num?)?.toDouble() ?? (isAdm ? 100.0 : 5.0),
      canViewCostPrice: (map['can_view_cost_price'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canDeleteSale: (map['can_delete_sale'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canProcessReturn: (map['can_process_return'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessKhata: (map['can_access_khata'] as int? ?? 1) == 1,
      canAccessInventory: (map['can_access_inventory'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessReports: (map['can_access_reports'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessSettings: (map['can_access_settings'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canManageUsers: (map['can_manage_users'] as int? ?? (isAdm ? 1 : 0)) == 1,
      permissions: map['permissions'] as String? ?? '',
    );
  }
}

/// Sales Return Model
class SaleReturn {
  final int? id;
  final String returnNo;
  final int? saleId;
  final String invoiceNo;
  final int? customerId;
  final String customerName;
  final String date;
  final double totalAmount;
  final double refundAmount;
  final String refundStatus; // 'completed', 'pending'
  final String paymentMethod; // 'cash', 'credit_note', 'bank'
  final String reason;
  final String note;
  final String createdBy;
  final List<SaleReturnItem> items;

  SaleReturn({
    this.id,
    required this.returnNo,
    this.saleId,
    required this.invoiceNo,
    this.customerId,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.refundAmount,
    this.refundStatus = 'completed',
    this.paymentMethod = 'cash',
    this.reason = 'Customer Return',
    this.note = '',
    this.createdBy = 'Admin',
    this.items = const [],
  });

  String get refNo => returnNo;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_no': returnNo,
        'ref_no': returnNo,
        'sale_id': saleId ?? 0,
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'date': date,
        'total_amount': totalAmount,
        'refund_amount': refundAmount,
        'refund_status': refundStatus,
        'status': refundStatus,
        'payment_method': paymentMethod,
        'refund_method': paymentMethod,
        'reason': reason,
        'note': note,
        'created_by': createdBy,
      };

  factory SaleReturn.fromMap(Map<String, dynamic> map, {List<SaleReturnItem> items = const []}) => SaleReturn(
        id: map['id'] as int?,
        returnNo: (map['return_no'] ?? map['ref_no']) as String? ?? '',
        saleId: map['sale_id'] as int?,
        invoiceNo: map['invoice_no'] as String? ?? '',
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0.0,
        refundStatus: (map['refund_status'] ?? map['status']) as String? ?? 'completed',
        paymentMethod: (map['payment_method'] ?? map['refund_method']) as String? ?? 'cash',
        reason: map['reason'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? 'Admin',
        items: items,
      );
}

class SaleReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final String productName;
  final String sku;
  final String batchNumber;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  SaleReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    required this.productName,
    this.sku = '',
    this.batchNumber = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_id': returnId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'batch_number': batchNumber,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };

  factory SaleReturnItem.fromMap(Map<String, dynamic> map) => SaleReturnItem(
        id: map['id'] as int?,
        returnId: map['return_id'] as int? ?? 0,
        productId: map['product_id'] as int? ?? 0,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Purchase Return Model
class PurchaseReturn {
  final int? id;
  final String returnNo;
  final int? purchaseId;
  final String purchaseRef;
  final int? supplierId;
  final String supplierName;
  final String date;
  final double totalAmount;
  final double refundAmount;
  final String status;
  final String reason;
  final String note;
  final List<PurchaseReturnItem> items;

  PurchaseReturn({
    this.id,
    required this.returnNo,
    this.purchaseId,
    required this.purchaseRef,
    this.supplierId,
    required this.supplierName,
    required this.date,
    required this.totalAmount,
    required this.refundAmount,
    this.status = 'completed',
    this.reason = 'Near Expiry / Damaged',
    this.note = '',
    this.items = const [],
  });

  String get refNo => returnNo;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_no': returnNo,
        'ref_no': returnNo,
        'purchase_id': purchaseId ?? 0,
        'purchase_ref': purchaseRef,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'date': date,
        'total_amount': totalAmount,
        'refund_amount': refundAmount,
        'refund_method': 'cash',
        'status': status,
        'reason': reason,
        'note': note,
      };

  factory PurchaseReturn.fromMap(Map<String, dynamic> map, {List<PurchaseReturnItem> items = const []}) => PurchaseReturn(
        id: map['id'] as int?,
        returnNo: (map['return_no'] ?? map['ref_no']) as String? ?? '',
        purchaseId: map['purchase_id'] as int?,
        purchaseRef: map['purchase_ref'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
        supplierName: map['supplier_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] as String? ?? 'completed',
        reason: map['reason'] as String? ?? '',
        note: map['note'] as String? ?? '',
        items: items,
      );
}

class PurchaseReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final String productName;
  final String sku;
  final String batchNumber;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  PurchaseReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    required this.productName,
    this.sku = '',
    this.batchNumber = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_id': returnId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'batch_number': batchNumber,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };

  factory PurchaseReturnItem.fromMap(Map<String, dynamic> map) => PurchaseReturnItem(
        id: map['id'] as int?,
        returnId: map['return_id'] as int? ?? 0,
        productId: map['product_id'] as int? ?? 0,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Financial Year End Closing Model
class FinancialYear {
  final int? id;
  final String yearTitle;
  final String startDate;
  final String endDate;
  final String closingDate;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double netProfit;
  final double stockValuation;
  final double receivables;
  final double payables;
  final String closedBy;
  final String status;
  final String notes;

  FinancialYear({
    this.id,
    required this.yearTitle,
    required this.startDate,
    required this.endDate,
    required this.closingDate,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.netProfit,
    required this.stockValuation,
    required this.receivables,
    required this.payables,
    required this.closedBy,
    this.status = 'closed',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'year_title': yearTitle,
        'start_date': startDate,
        'end_date': endDate,
        'closing_date': closingDate,
        'total_sales': totalSales,
        'total_purchases': totalPurchases,
        'total_expenses': totalExpenses,
        'net_profit': netProfit,
        'stock_valuation': stockValuation,
        'receivables': receivables,
        'payables': payables,
        'closed_by': closedBy,
        'status': status,
        'notes': notes,
      };

  factory FinancialYear.fromMap(Map<String, dynamic> map) => FinancialYear(
        id: map['id'] as int?,
        yearTitle: map['year_title'] as String? ?? '',
        startDate: map['start_date'] as String? ?? '',
        endDate: map['end_date'] as String? ?? '',
        closingDate: map['closing_date'] as String? ?? '',
        totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0.0,
        totalPurchases: (map['total_purchases'] as num?)?.toDouble() ?? 0.0,
        totalExpenses: (map['total_expenses'] as num?)?.toDouble() ?? 0.0,
        netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
        stockValuation: (map['stock_valuation'] as num?)?.toDouble() ?? 0.0,
        receivables: (map['receivables'] as num?)?.toDouble() ?? 0.0,
        payables: (map['payables'] as num?)?.toDouble() ?? 0.0,
        closedBy: map['closed_by'] as String? ?? 'SuperAdmin',
        status: map['status'] as String? ?? 'closed',
        notes: map['notes'] as String? ?? '',
      );
}

/// Multi-tender & Split Payment Transaction Ledger Record
class PaymentTransaction {
  final int? id;
  final String transactionType; // 'sale', 'purchase', 'sale_due_collection', 'purchase_due_payment', 'customer_advance', 'supplier_advance'
  final int? parentId; // sale_id or purchase_id
  final int? contactId;
  final String contactName;
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque', 'custom'
  final double amount;
  final int? accountId;
  final String accountName;
  final String transactionDate;
  final String refNo;
  final String note;
  final String createdBy;
  final String createdAt;

  PaymentTransaction({
    this.id,
    required this.transactionType,
    this.parentId,
    this.contactId,
    required this.contactName,
    this.paymentMethod = 'cash',
    required this.amount,
    this.accountId,
    this.accountName = 'Cash Till',
    required this.transactionDate,
    this.refNo = '',
    this.note = '',
    this.createdBy = 'Cashier',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'transaction_type': transactionType,
        'parent_id': parentId,
        'contact_id': contactId,
        'contact_name': contactName,
        'payment_method': paymentMethod,
        'amount': amount,
        'account_id': accountId,
        'account_name': accountName,
        'transaction_date': transactionDate,
        'ref_no': refNo,
        'note': note,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) => PaymentTransaction(
        id: map['id'] as int?,
        transactionType: map['transaction_type'] as String? ?? 'sale',
        parentId: map['parent_id'] as int?,
        contactId: map['contact_id'] as int?,
        contactName: map['contact_name'] as String? ?? 'Walk-in Customer',
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: map['account_id'] as int?,
        accountName: map['account_name'] as String? ?? 'Cash Till',
        transactionDate: map['transaction_date'] as String? ?? '',
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? 'System',
        createdAt: map['created_at'] as String? ?? '',
      );
}

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
  final String status; // 'in_stock', 'sold', 'returned', 'defective', 'transferred'
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
    final exp = DateTime.tryParse(expiryDate);
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

  factory ProductSerialBatch.fromMap(Map<String, dynamic> map) => ProductSerialBatch(
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

/// Composite / Bundle Product Bill of Materials (BOM) Item for Solar & Systems
class ProductBundleItem {
  final int? id;
  final int parentProductId;
  final int subProductId;
  final String subProductName;
  final String subSku;
  final double quantity;
  final double unitPrice;
  final bool isOptional;
  final int sortOrder;
  final String notes;

  ProductBundleItem({
    this.id,
    required this.parentProductId,
    required this.subProductId,
    required this.subProductName,
    this.subSku = '',
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.isOptional = false,
    this.sortOrder = 0,
    this.notes = '',
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'parent_product_id': parentProductId,
        'sub_product_id': subProductId,
        'sub_product_name': subProductName,
        'sub_sku': subSku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'is_optional': isOptional ? 1 : 0,
        'sort_order': sortOrder,
        'notes': notes,
      };

  factory ProductBundleItem.fromMap(Map<String, dynamic> map) => ProductBundleItem(
        id: map['id'] as int?,
        parentProductId: map['parent_product_id'] as int? ?? 0,
        subProductId: map['sub_product_id'] as int? ?? 0,
        subProductName: map['sub_product_name'] as String? ?? '',
        subSku: map['sub_sku'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        isOptional: (map['is_optional'] as int? ?? 0) == 1,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        notes: map['notes'] as String? ?? '',
      );
}

/// Audit Trail Record for Critical POS and Administrative Events
class AuditLog {
  final int? id;
  final String action; // 'item_deleted', 'price_override', 'bill_voided', 'sale_return', 'settings_changed', etc.
  final String entityType; // 'sale', 'purchase', 'product', 'contact', 'settings', 'auth'
  final String? entityId;
  final int? userId;
  final String userName;
  final String details;
  final String oldValues;
  final String newValues;
  final String ipAddress;
  final String timestamp;

  AuditLog({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.userId,
    required this.userName,
    this.details = '',
    this.oldValues = '',
    this.newValues = '',
    this.ipAddress = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'user_id': userId,
        'user_name': userName,
        'details': details,
        'old_values': oldValues,
        'new_values': newValues,
        'ip_address': ipAddress,
        'timestamp': timestamp,
      };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id'] as int?,
        action: map['action'] as String? ?? '',
        entityType: map['entity_type'] as String? ?? '',
        entityId: map['entity_id'] as String?,
        userId: map['user_id'] as int?,
        userName: map['user_name'] as String? ?? 'System',
        details: map['details'] as String? ?? '',
        oldValues: map['old_values'] as String? ?? '',
        newValues: map['new_values'] as String? ?? '',
        ipAddress: map['ip_address'] as String? ?? '',
        timestamp: map['timestamp'] as String? ?? '',
      );
}

