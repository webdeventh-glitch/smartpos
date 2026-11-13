import 'model_helpers.dart';

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
  final String
      businessType; // 'general', 'pharmacy', 'solar', 'electronics', 'clothing'
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
  final String
      deploymentMode; // 'offline_server', 'lan_secondary', 'cloud_hybrid'
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
  final bool multiCurrencyEnabled;
  final String exchangeRatesJson;
  final String customRatesJson;
  final String lastRatesSync;
  final String invoiceLayoutDesign; // 'detailed', 'classic', 'elegant', 'slim'
  final bool showBatchOnInvoice;
  final bool showExpiryOnInvoice;
  final bool showBrandOnInvoice;
  final bool showSkuOnInvoice;
  final bool showWarrantyOnInvoice;
  final bool showTotalInWords;
  final String primaryLanguage;
  final String totalInWordsLanguage;
  final bool enableSecondaryLanguage;
  final String secondaryLanguage;
  final String invoiceHeading;
  final int sessionTimeoutMinutes;
  final bool autoPrintReceipt;
  final bool autoPrintKot;
  final int? defaultPrinterId;
  final int? defaultInvoiceLayoutId;
  final bool autoBackupEnabled;
  final String backupFrequency; // 'daily', 'weekly', 'custom'
  final int backupIntervalHours;
  final int backupRetentionCount;
  final String lastAutoBackupAt;
  final bool touchFriendlyMode;
  final String keyboardShortcutsJson;
  final bool allowOverselling;
  final bool showPosProductPanel;
  final bool compactPosProductList;
  final bool autoFocusBarcodeSearch;
  final bool confirmBeforeCancelSale;
  final bool enableCounterTokenQueue;

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
    this.receiptReturnPolicy =
        'Goods once sold can only be exchanged within 7 days with original receipt.',
    this.showLogoOnReceipt = true,
    this.showBarcodeOnReceipt = true,
    this.showQrOnReceipt = true,
    this.showCustomerBalanceOnReceipt = true,
    this.showTaxBreakdownOnReceipt = true,
    this.showCashierNameOnReceipt = true,
    this.invoicePrintCopies = 1,
    this.multiCurrencyEnabled = true,
    this.exchangeRatesJson = '',
    this.customRatesJson = '',
    this.lastRatesSync = '',
    this.invoiceLayoutDesign = 'detailed',
    this.showBatchOnInvoice = true,
    this.showExpiryOnInvoice = true,
    this.showBrandOnInvoice = true,
    this.showSkuOnInvoice = true,
    this.showWarrantyOnInvoice = true,
    this.showTotalInWords = true,
    this.primaryLanguage = 'en',
    this.totalInWordsLanguage = 'ur',
    this.enableSecondaryLanguage = false,
    this.secondaryLanguage = 'ur',
    this.invoiceHeading = 'TAX INVOICE',
    this.sessionTimeoutMinutes = 480,
    this.autoPrintReceipt = false,
    this.autoPrintKot = false,
    this.defaultPrinterId,
    this.defaultInvoiceLayoutId,
    this.autoBackupEnabled = false,
    this.backupFrequency = 'daily',
    this.backupIntervalHours = 24,
    this.backupRetentionCount = 10,
    this.lastAutoBackupAt = '',
    this.touchFriendlyMode = false,
    this.keyboardShortcutsJson = '',
    this.allowOverselling = false,
    this.showPosProductPanel = true,
    this.compactPosProductList = true,
    this.autoFocusBarcodeSearch = true,
    this.confirmBeforeCancelSale = true,
    this.enableCounterTokenQueue = true,
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

  /// Secondary language is ONLY allowed when Primary Language is English ('en')
  bool get isSecondaryLanguageAllowed =>
      primaryLanguage.toLowerCase().trim() == 'en';

  /// Effective secondary language check: strictly requires primary to be 'en' and secondary enabled
  bool get hasEffectiveSecondaryLanguage =>
      isSecondaryLanguageAllowed &&
      enableSecondaryLanguage &&
      secondaryLanguage.trim().isNotEmpty &&
      secondaryLanguage.toLowerCase().trim() != 'en';

  /// Active primary language code (e.g. 'en', 'ur', 'fa', 'ar', 'ps')
  String get activePrimaryLanguage => primaryLanguage.trim().isNotEmpty
      ? primaryLanguage.toLowerCase().trim()
      : 'en';

  /// Effective secondary language code (null if primary is not 'en' or secondary disabled)
  String? get effectiveSecondaryLanguage => hasEffectiveSecondaryLanguage
      ? secondaryLanguage.toLowerCase().trim()
      : null;

  bool get isHybridSync => syncMode == 'hybrid';
  bool get isOnlineOnly => syncMode == 'online';
  bool get isOfflineOnly => syncMode == 'offline' || syncMode.isEmpty;
  bool get hasOnlineSync => isHybridSync || isOnlineOnly;

  bool get isMySql => primaryDbType.toLowerCase() == 'mysql';
  bool get isPostgreSql => primaryDbType.toLowerCase() == 'postgresql';
  bool get isSqlitePrimary => primaryDbType.toLowerCase() == 'sqlite';

  bool get isPharmacy =>
      businessType == 'pharmacy' || isModuleEnabled(presetPharmacy);
  bool get isSolarOrElectronics =>
      businessType == 'solar' ||
      businessType == 'electronics' ||
      businessType == 'mobile';
  bool get isGeneral =>
      businessType == 'general' ||
      businessType == 'general_store' ||
      businessType == 'kiryana';
  bool get isSupermarket => businessType == 'supermarket';
  bool get isClothing =>
      businessType == 'clothing' || businessType == 'garments';
  bool get isWholesale => businessType == 'wholesale';
  bool get isRestaurant =>
      businessType == 'restaurant' || businessType == 'cafe';
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
  bool get isTyres =>
      businessType == 'tyres_battery' || businessType == 'tyres';
  bool get isHardware =>
      businessType == 'hardware_tools' || businessType == 'hardware';
  bool get isAutoParts => businessType == 'auto_parts';
  bool get isMeat => businessType == 'meat_butchery' || businessType == 'meat';
  bool get isFabrics =>
      businessType == 'fabrics_textile' || businessType == 'fabrics';
  bool get isLubricants =>
      businessType == 'lubricants_oil' || businessType == 'lubricants';
  bool get isSanitaryTiles =>
      businessType == 'sanitary_tiles' || businessType == 'sanitary';
  bool get isUniversal =>
      businessType == 'universal' || businessType == 'all_in_one';
  bool get isCustomOther =>
      businessType == 'custom_other' ||
      businessType == 'other' ||
      businessType == 'custom';

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

  bool get isBatchExpiryEnabled =>
      isPharmacy || isModuleEnabled(moduleBatchExpiry);
  bool get isVariationsEnabled =>
      isClothing || isModuleEnabled(moduleVariations);
  bool get isWarrantyEnabled =>
      isSolarOrElectronics || isModuleEnabled('warranty');
  bool get isImeiSerialEnabled =>
      isMobileElectronicsEnabled || isModuleEnabled('imei_serial');

  bool get isPrimaryServer =>
      deploymentMode == 'offline_server' || deploymentMode.isEmpty;
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
        return 'Dairy, Milk & Eggs';
      case 'tyres_battery':
      case 'tyres':
        return 'Tyre Shop, Rims & Battery';
      case 'hardware_tools':
      case 'hardware':
        return 'Hardware, Tools & Paint';
      case 'auto_parts':
        return 'Auto Spare Parts';
      case 'meat_butchery':
      case 'meat':
        return 'Meat, Butchery & Poultry';
      case 'fabrics_textile':
      case 'fabrics':
        return 'Fabrics & Cloth (Meter / Gazz)';
      case 'lubricants_oil':
      case 'lubricants':
        return 'Mobile Oil & Lubricants';
      case 'sanitary_tiles':
      case 'sanitary':
        return 'Sanitary, Tiles & Bath';
      case 'universal':
        return 'Universal Business (Wholesale & Retail)';
      case 'custom_other':
      case 'other':
      case 'custom':
        return 'Other / Custom Business';
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
        return [
          ...base,
          moduleManufacturing,
          moduleAccountingCrm,
          moduleVariations
        ];
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
        return [
          ...base,
          moduleRepair,
          moduleVariations,
          presetMobileElectronics
        ];
      case 'solar':
        return [...base, moduleRepair, moduleVariations, presetSolarHardware];
      case 'clothing':
      case 'garments':
        return [...base, moduleVariations];
      case 'supermarket':
        return [
          ...base,
          moduleVariations,
          moduleBatchExpiry,
          presetRetailSuperStore
        ];
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
    bool? multiCurrencyEnabled,
    String? exchangeRatesJson,
    String? customRatesJson,
    String? lastRatesSync,
    String? invoiceLayoutDesign,
    bool? showBatchOnInvoice,
    bool? showExpiryOnInvoice,
    bool? showBrandOnInvoice,
    bool? showSkuOnInvoice,
    bool? showWarrantyOnInvoice,
    bool? showTotalInWords,
    String? primaryLanguage,
    String? totalInWordsLanguage,
    bool? enableSecondaryLanguage,
    String? secondaryLanguage,
    String? invoiceHeading,
    int? sessionTimeoutMinutes,
    bool? autoPrintReceipt,
    bool? autoPrintKot,
    int? defaultPrinterId,
    int? defaultInvoiceLayoutId,
    bool? autoBackupEnabled,
    String? backupFrequency,
    int? backupIntervalHours,
    int? backupRetentionCount,
    String? lastAutoBackupAt,
    bool? touchFriendlyMode,
    String? keyboardShortcutsJson,
    bool? allowOverselling,
    bool? showPosProductPanel,
    bool? compactPosProductList,
    bool? autoFocusBarcodeSearch,
    bool? confirmBeforeCancelSale,
    bool? enableCounterTokenQueue,
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
      financialYearStartMonth:
          financialYearStartMonth ?? this.financialYearStartMonth,
      stockAccountingMethod:
          stockAccountingMethod ?? this.stockAccountingMethod,
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
      syncAutoIntervalMinutes:
          syncAutoIntervalMinutes ?? this.syncAutoIntervalMinutes,
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
      showCustomerBalanceOnReceipt:
          showCustomerBalanceOnReceipt ?? this.showCustomerBalanceOnReceipt,
      showTaxBreakdownOnReceipt:
          showTaxBreakdownOnReceipt ?? this.showTaxBreakdownOnReceipt,
      showCashierNameOnReceipt:
          showCashierNameOnReceipt ?? this.showCashierNameOnReceipt,
      invoicePrintCopies: invoicePrintCopies ?? this.invoicePrintCopies,
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
      exchangeRatesJson: exchangeRatesJson ?? this.exchangeRatesJson,
      customRatesJson: customRatesJson ?? this.customRatesJson,
      lastRatesSync: lastRatesSync ?? this.lastRatesSync,
      invoiceLayoutDesign: invoiceLayoutDesign ?? this.invoiceLayoutDesign,
      showBatchOnInvoice: showBatchOnInvoice ?? this.showBatchOnInvoice,
      showExpiryOnInvoice: showExpiryOnInvoice ?? this.showExpiryOnInvoice,
      showBrandOnInvoice: showBrandOnInvoice ?? this.showBrandOnInvoice,
      showSkuOnInvoice: showSkuOnInvoice ?? this.showSkuOnInvoice,
      showWarrantyOnInvoice:
          showWarrantyOnInvoice ?? this.showWarrantyOnInvoice,
      showTotalInWords: showTotalInWords ?? this.showTotalInWords,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      totalInWordsLanguage: totalInWordsLanguage ?? this.totalInWordsLanguage,
      enableSecondaryLanguage:
          enableSecondaryLanguage ?? this.enableSecondaryLanguage,
      secondaryLanguage: secondaryLanguage ?? this.secondaryLanguage,
      invoiceHeading: invoiceHeading ?? this.invoiceHeading,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      autoPrintKot: autoPrintKot ?? this.autoPrintKot,
      defaultPrinterId: defaultPrinterId ?? this.defaultPrinterId,
      defaultInvoiceLayoutId:
          defaultInvoiceLayoutId ?? this.defaultInvoiceLayoutId,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      backupIntervalHours: backupIntervalHours ?? this.backupIntervalHours,
      backupRetentionCount: backupRetentionCount ?? this.backupRetentionCount,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
      touchFriendlyMode: touchFriendlyMode ?? this.touchFriendlyMode,
      keyboardShortcutsJson:
          keyboardShortcutsJson ?? this.keyboardShortcutsJson,
      allowOverselling: allowOverselling ?? this.allowOverselling,
      showPosProductPanel: showPosProductPanel ?? this.showPosProductPanel,
      compactPosProductList:
          compactPosProductList ?? this.compactPosProductList,
      autoFocusBarcodeSearch:
          autoFocusBarcodeSearch ?? this.autoFocusBarcodeSearch,
      confirmBeforeCancelSale:
          confirmBeforeCancelSale ?? this.confirmBeforeCancelSale,
      enableCounterTokenQueue:
          enableCounterTokenQueue ?? this.enableCounterTokenQueue,
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
        'show_customer_balance_on_receipt':
            showCustomerBalanceOnReceipt ? 1 : 0,
        'show_tax_breakdown_on_receipt': showTaxBreakdownOnReceipt ? 1 : 0,
        'show_cashier_name_on_receipt': showCashierNameOnReceipt ? 1 : 0,
        'invoice_print_copies': invoicePrintCopies,
        'multi_currency_enabled': multiCurrencyEnabled ? 1 : 0,
        'exchange_rates_json': exchangeRatesJson,
        'custom_rates_json': customRatesJson,
        'last_rates_sync': lastRatesSync,
        'invoice_layout_design': invoiceLayoutDesign,
        'show_batch_on_invoice': showBatchOnInvoice ? 1 : 0,
        'show_expiry_on_invoice': showExpiryOnInvoice ? 1 : 0,
        'show_brand_on_invoice': showBrandOnInvoice ? 1 : 0,
        'show_sku_on_invoice': showSkuOnInvoice ? 1 : 0,
        'show_warranty_on_invoice': showWarrantyOnInvoice ? 1 : 0,
        'show_total_in_words': showTotalInWords ? 1 : 0,
        'primary_language': primaryLanguage,
        'total_in_words_language': totalInWordsLanguage,
        'enable_secondary_language': enableSecondaryLanguage ? 1 : 0,
        'secondary_language': secondaryLanguage,
        'invoice_heading': invoiceHeading,
        'session_timeout_minutes': sessionTimeoutMinutes,
        'auto_print_receipt': autoPrintReceipt ? 1 : 0,
        'auto_print_kot': autoPrintKot ? 1 : 0,
        'default_printer_id': defaultPrinterId,
        'default_invoice_layout_id': defaultInvoiceLayoutId,
        'auto_backup_enabled': autoBackupEnabled ? 1 : 0,
        'backup_frequency': backupFrequency,
        'backup_interval_hours': backupIntervalHours,
        'backup_retention_count': backupRetentionCount,
        'last_auto_backup_at': lastAutoBackupAt,
        'touch_friendly_mode': touchFriendlyMode ? 1 : 0,
        'keyboard_shortcuts_json': keyboardShortcutsJson,
        'allow_overselling': allowOverselling ? 1 : 0,
        'show_pos_product_panel': showPosProductPanel ? 1 : 0,
        'compact_pos_product_list': compactPosProductList ? 1 : 0,
        'auto_focus_barcode_search': autoFocusBarcodeSearch ? 1 : 0,
        'confirm_before_cancel_sale': confirmBeforeCancelSale ? 1 : 0,
        'enable_counter_token_queue': enableCounterTokenQueue ? 1 : 0,
      };

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        id: modelAsInt(map['id'], 1),
        businessName: modelAsString(map['business_name'], 'Smart POS System'),
        branchName: modelAsString(map['branch_name'], 'Main Branch HQ'),
        currencySymbol: modelAsString(map['currency_symbol'], 'Rs'),
        currencyCode: modelAsString(map['currency_code'], 'PKR'),
        defaultTaxRate: modelAsDouble(map['default_tax_rate'], 5.0),
        phone: modelAsString(map['phone']),
        email: modelAsString(map['email']),
        address: modelAsString(map['address']),
        invoicePrefix: modelAsString(map['invoice_prefix'], 'INV-'),
        receiptFooter: modelAsString(map['receipt_footer']),
        purchaseKey: modelAsString(map['purchase_key']),
        businessType: modelAsString(map['business_type'], 'general'),
        drugLicenseNo: modelAsString(map['drug_license_no']),
        dlWarrantor: modelAsString(map['dl_warrantor']),
        timeZone: modelAsString(map['time_zone'], 'Asia/Karachi'),
        currencyPlacement: modelAsString(map['currency_placement'], 'before'),
        financialYearStartMonth:
            modelAsString(map['financial_year_start_month'], 'January'),
        stockAccountingMethod:
            modelAsString(map['stock_accounting_method'], 'FIFO'),
        transactionEditDays: modelAsInt(map['transaction_edit_days'], 30),
        dateFormat: modelAsString(map['date_format'], 'dd/mm/yyyy'),
        timeFormat: modelAsString(map['time_format'], '12 Hour'),
        currencyPrecision: modelAsInt(map['currency_precision'], 2),
        quantityPrecision: modelAsInt(map['quantity_precision'], 2),
        defaultProfitPercent:
            modelAsDouble(map['default_profit_percent'], 25.0),
        startDate: modelAsString(map['start_date'], '01/01/2026'),
        isConfigured: modelAsBool(map['is_configured'], false),
        logoPath: modelAsString(map['logo_path']),
        trialStartDate: modelAsString(map['trial_start_date']),
        enabledModules: modelAsString(map['enabled_modules']),
        syncMode: modelAsString(map['sync_mode'], 'offline'),
        syncServerUrl: modelAsString(map['sync_server_url']),
        syncApiKey: modelAsString(map['sync_api_key']),
        syncBranchId: modelAsInt(map['sync_branch_id'], 1),
        syncAutoIntervalMinutes:
            modelAsInt(map['sync_auto_interval_minutes'], 5),
        lastSyncTimestamp: modelAsString(map['last_sync_timestamp']),
        loginBannerPath: modelAsString(map['login_banner_path']),
        loginSideTitle: modelAsString(map['login_side_title']),
        loginSideSubtitle: modelAsString(map['login_side_subtitle']),
        taxNumber: modelAsString(map['tax_number']),
        hardwareId: modelAsString(map['hardware_id']),
        deploymentMode: modelAsString(map['deployment_mode'], 'offline_server'),
        serverHost: modelAsString(map['server_host'], '127.0.0.1'),
        serverPort: modelAsInt(map['server_port'], 8080),
        primaryDbType: modelAsString(map['primary_db_type'], 'mysql'),
        dbHost: modelAsString(map['db_host'], 'localhost'),
        dbPort: modelAsInt(map['db_port'], 3306),
        dbName: modelAsString(map['db_name'], 'smartpos'),
        dbUser: modelAsString(map['db_user'], 'root'),
        dbPassword: modelAsString(map['db_password']),
        industryPresets:
            modelAsString(map['industry_presets'], 'retail_supermarket'),
        receiptPaperSize: modelAsString(map['receipt_paper_size'], '80mm'),
        receiptHeaderTagline: modelAsString(
            map['receipt_header_tagline'], 'Wholesale & Retail Distributor'),
        receiptHeaderNote:
            modelAsString(map['receipt_header_note'], 'Welcome to our store!'),
        receiptReturnPolicy: modelAsString(map['receipt_return_policy'],
            'Goods once sold can only be exchanged within 7 days with original receipt.'),
        showLogoOnReceipt: modelAsBool(map['show_logo_on_receipt'], true),
        showBarcodeOnReceipt: modelAsBool(map['show_barcode_on_receipt'], true),
        showQrOnReceipt: modelAsBool(map['show_qr_on_receipt'], true),
        showCustomerBalanceOnReceipt:
            modelAsBool(map['show_customer_balance_on_receipt'], true),
        showTaxBreakdownOnReceipt:
            modelAsBool(map['show_tax_breakdown_on_receipt'], true),
        showCashierNameOnReceipt:
            modelAsBool(map['show_cashier_name_on_receipt'], true),
        invoicePrintCopies: modelAsInt(map['invoice_print_copies'], 1),
        multiCurrencyEnabled: modelAsBool(map['multi_currency_enabled'], true),
        exchangeRatesJson: modelAsString(map['exchange_rates_json']),
        customRatesJson: modelAsString(map['custom_rates_json']),
        lastRatesSync: modelAsString(map['last_rates_sync']),
        invoiceLayoutDesign:
            modelAsString(map['invoice_layout_design'], 'detailed'),
        showBatchOnInvoice: modelAsBool(map['show_batch_on_invoice'], true),
        showExpiryOnInvoice: modelAsBool(map['show_expiry_on_invoice'], true),
        showBrandOnInvoice: modelAsBool(map['show_brand_on_invoice'], true),
        showSkuOnInvoice: modelAsBool(map['show_sku_on_invoice'], true),
        showWarrantyOnInvoice:
            modelAsBool(map['show_warranty_on_invoice'], true),
        showTotalInWords: modelAsBool(map['show_total_in_words'], true),
        primaryLanguage: modelAsString(map['primary_language'], 'en'),
        totalInWordsLanguage:
            modelAsString(map['total_in_words_language'], 'ur'),
        enableSecondaryLanguage:
            modelAsBool(map['enable_secondary_language'], false),
        secondaryLanguage: modelAsString(map['secondary_language'], 'ur'),
        invoiceHeading: modelAsString(map['invoice_heading'], 'TAX INVOICE'),
        sessionTimeoutMinutes: modelAsInt(map['session_timeout_minutes'], 480),
        autoPrintReceipt: modelAsBool(map['auto_print_receipt'], false),
        autoPrintKot: modelAsBool(map['auto_print_kot'], false),
        defaultPrinterId: map['default_printer_id'] as int?,
        defaultInvoiceLayoutId: map['default_invoice_layout_id'] as int?,
        autoBackupEnabled: modelAsBool(map['auto_backup_enabled'], false),
        backupFrequency: modelAsString(map['backup_frequency'], 'daily'),
        backupIntervalHours: modelAsInt(map['backup_interval_hours'], 24),
        backupRetentionCount: modelAsInt(map['backup_retention_count'], 10),
        lastAutoBackupAt: modelAsString(map['last_auto_backup_at']),
        touchFriendlyMode: modelAsBool(map['touch_friendly_mode'], false),
        keyboardShortcutsJson: modelAsString(map['keyboard_shortcuts_json']),
        allowOverselling: modelAsBool(map['allow_overselling'], false),
        showPosProductPanel: modelAsBool(map['show_pos_product_panel'], true),
        compactPosProductList:
            modelAsBool(map['compact_pos_product_list'], true),
        autoFocusBarcodeSearch:
            modelAsBool(map['auto_focus_barcode_search'], true),
        confirmBeforeCancelSale:
            modelAsBool(map['confirm_before_cancel_sale'], true),
        enableCounterTokenQueue:
            modelAsBool(map['enable_counter_token_queue'], true),
      );
}
