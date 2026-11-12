import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'app_logger.dart';
import 'backup_update_service.dart';
import 'database_encryption_service.dart';
import 'database_schema.dart';

/// Coordinator and backward-compatible facade for local SQLite storage.
///
/// Owns database lifecycle, versioned migrations, WAL maintenance, and exposes
/// focused domain repositories under lib/repositories/.
class DatabaseService {
  final Database db;
  final String? dbFilePath;
  DatabaseService(this.db, {this.dbFilePath});

  static const int currentSchemaVersion = 9;
  static DatabaseService? _instance;
  static DatabaseService? get instanceOrNull => _instance;
  static DatabaseService get instance =>
      _instance ??
      (throw StateError(
          'DatabaseService not initialized. Call initialize() first.'));

  static VoidCallback? onSyncQueueUpdated;
  static bool suppressSync = false;

  // Domain repositories bound to this database coordinator
  late final SettingsRepository settingsRepo = SettingsRepository(this);
  late final AuthRepository authRepo = AuthRepository(this);
  late final ProductRepository productRepo = ProductRepository(this);
  late final ContactsRepository contactsRepo = ContactsRepository(this);
  late final SalesRepository salesRepo = SalesRepository(this);
  late final PurchaseRepository purchaseRepo = PurchaseRepository(this);
  late final AccountingRepository accountingRepo = AccountingRepository(this);
  late final InventoryRepository inventoryRepo = InventoryRepository(this);
  late final ExpenseRepository expenseRepo = ExpenseRepository(this);
  late final RegisterRepository registerRepo = RegisterRepository(this);
  late final ReportRepository reportRepo = ReportRepository(this);
  late final SyncRepository syncRepo = SyncRepository(this);
  late final IndustryModulesRepository industryModulesRepo =
      IndustryModulesRepository(this);
  late final SeederRepository seederRepo = SeederRepository(this);
  late final AdvancedFeaturesRepository advancedRepo =
      AdvancedFeaturesRepository(this);

  /// Flushes WAL pages into the main .db file so backups and vault snapshots are complete.
  Future<void> checkpointWal() async {
    if (!db.isOpen ||
        dbFilePath == null ||
        dbFilePath == inMemoryDatabasePath) {
      return;
    }
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'WAL checkpoint skipped', e, st);
    }
  }

  /// Closes the open singleton DB handle if it points to [targetPath] so file restore succeeds cleanly on Windows.
  static Future<void> closeOpenInstanceIfPathMatches(String targetPath) async {
    final inst = _instance;
    if (inst == null) return;
    final openPath = inst.dbFilePath;
    if (openPath == null) return;
    if (p.normalize(openPath).toLowerCase() ==
        p.normalize(targetPath).toLowerCase()) {
      await inst.checkpointWal();
      if (inst.db.isOpen) {
        await inst.db.close();
      }
      _instance = null;
    }
  }

  static Future<DatabaseService> initialize({String? customPath}) async {
    if (customPath == null && _instance != null && _instance!.db.isOpen) {
      return _instance!;
    }

    sqfliteFfiInit();
    String dbPath = customPath ?? '';
    if (dbPath.isEmpty) {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      final folder = Directory(p.join(base, 'SmartPOS'));
      await folder.create(recursive: true);
      dbPath = p.join(folder.path, 'smart_pos.db');
    }

    await DatabaseEncryptionService.unsealVaultIfNeeded(dbPath);

    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onCreate: (db, version) async {
          AppLogger.info('DatabaseService',
              'Creating Smart POS SQLite schema v$version at $dbPath');
          await DatabaseSchema.createTables(db);
          await DatabaseSchema.seedInitialData(db);
          await DatabaseSchema.runMigrations(db,
              fromVersion: 0, toVersion: version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          AppLogger.info(
            'DatabaseService',
            'Upgrading Smart POS SQLite schema from v$oldVersion to v$newVersion',
          );
          await BackupUpdateService.instance.createPreMigrationBackupIfNeeded(
            dbPath: dbPath,
            oldVersion: oldVersion,
            newVersion: newVersion,
          );
          await DatabaseSchema.runMigrations(db,
              fromVersion: oldVersion, toVersion: newVersion);
        },
        onOpen: (db) async {
          final ver = await db.getVersion();
          if (ver < currentSchemaVersion) {
            await BackupUpdateService.instance.createPreMigrationBackupIfNeeded(
              dbPath: dbPath,
              oldVersion: ver,
              newVersion: currentSchemaVersion,
            );
            await DatabaseSchema.runMigrations(db,
                fromVersion: ver, toVersion: currentSchemaVersion);
            await db.setVersion(currentSchemaVersion);
          } else {
            await DatabaseSchema.ensureMigrationTable(db);
          }
          await DatabaseSchema.migrateLegacyPlaintextPasswords(db);
          await DatabaseEncryptionService.migratePlaintextSecrets(db,
              dbPath: dbPath);
          await DatabaseSchema.importLegacySimpleStockIfPresent(db, dbPath);
        },
      ),
    );

    _instance = DatabaseService(db, dbFilePath: dbPath);
    return _instance!;
  }

  /// Public method to safely trigger schema updates and migrations during online/offline patching.
  Future<void> ensureSchemaMigration() async {
    await DatabaseSchema.runMigrations(db,
        fromVersion: 0, toVersion: currentSchemaVersion);
    await db.setVersion(currentSchemaVersion);
    await DatabaseSchema.migrateLegacyPlaintextPasswords(db);
    await DatabaseEncryptionService.migratePlaintextSecrets(db,
        dbPath: dbFilePath);
  }

  /// Triggers background synchronization of queued records into MySQL.
  void triggerAsyncMySqlSync() => syncRepo.triggerAsyncMySqlSync();

  // ===================== REPOSITORY DELEGATIONS =====================

  Future<BusinessSettings> getBusinessSettings() =>
      settingsRepo.getBusinessSettings();
  Future<void> updateBusinessSettings(
    BusinessSettings settings, {
    bool allowBusinessTypeChange = false,
  }) =>
      settingsRepo.updateBusinessSettings(
        settings,
        allowBusinessTypeChange: allowBusinessTypeChange,
      );
  Future<List<BusinessLocation>> getBusinessLocations() =>
      settingsRepo.getBusinessLocations();
  Future<int> addBusinessLocation(BusinessLocation location) =>
      settingsRepo.addBusinessLocation(location);
  Future<void> updateBusinessLocation(BusinessLocation location) =>
      settingsRepo.updateBusinessLocation(location);
  Future<void> deleteBusinessLocation(int id) =>
      settingsRepo.deleteBusinessLocation(id);
  Future<List<TaxRate>> getTaxRates() => settingsRepo.getTaxRates();
  Future<int> addTaxRate(TaxRate taxRate) => settingsRepo.addTaxRate(taxRate);
  Future<void> deleteTaxRate(int id) => settingsRepo.deleteTaxRate(id);
  Future<List<SmsGateway>> getSmsGateways() => settingsRepo.getSmsGateways();
  Future<SmsGateway?> getActiveSmsGateway() =>
      settingsRepo.getActiveSmsGateway();
  Future<int> addSmsGateway(SmsGateway gateway) =>
      settingsRepo.addSmsGateway(gateway);
  Future<void> updateSmsGateway(SmsGateway gateway) =>
      settingsRepo.updateSmsGateway(gateway);
  Future<void> deleteSmsGateway(int id) => settingsRepo.deleteSmsGateway(id);
  Future<List<MessageLog>> getMessageLogs({int limit = 100}) =>
      settingsRepo.getMessageLogs(limit: limit);
  Future<int> addMessageLog(MessageLog log) => settingsRepo.addMessageLog(log);
  Future<AiSettings> getAiSettings() => settingsRepo.getAiSettings();
  Future<void> saveAiSettings(AiSettings settings) =>
      settingsRepo.saveAiSettings(settings);
  Future<List<InvoiceScheme>> getInvoiceSchemes() =>
      settingsRepo.getInvoiceSchemes();
  Future<int> addInvoiceScheme(InvoiceScheme scheme) =>
      settingsRepo.addInvoiceScheme(scheme);
  Future<void> updateInvoiceScheme(InvoiceScheme scheme) =>
      settingsRepo.updateInvoiceScheme(scheme);
  Future<void> deleteInvoiceScheme(int id) =>
      settingsRepo.deleteInvoiceScheme(id);
  Future<String> generateNextInvoiceNumber({int? schemeId}) =>
      settingsRepo.generateNextInvoiceNumber(schemeId: schemeId);
  Future<List<ThermalPrinterConfig>> getPrinters() =>
      settingsRepo.getPrinters();
  Future<ThermalPrinterConfig?> getDefaultPrinter() =>
      settingsRepo.getDefaultPrinter();
  Future<ThermalPrinterConfig?> getKotPrinter() => settingsRepo.getKotPrinter();
  Future<int> savePrinter(ThermalPrinterConfig printer) =>
      settingsRepo.savePrinter(printer);
  Future<void> setDefaultPrinter(int id) => settingsRepo.setDefaultPrinter(id);
  Future<void> deletePrinter(int id) => settingsRepo.deletePrinter(id);
  Future<List<InvoiceLayout>> getInvoiceLayouts() =>
      settingsRepo.getInvoiceLayouts();
  Future<InvoiceLayout?> getDefaultInvoiceLayout() =>
      settingsRepo.getDefaultInvoiceLayout();
  Future<int> saveInvoiceLayout(InvoiceLayout layout) =>
      settingsRepo.saveInvoiceLayout(layout);
  Future<void> setDefaultInvoiceLayout(int id) =>
      settingsRepo.setDefaultInvoiceLayout(id);
  Future<void> deleteInvoiceLayout(int id) =>
      settingsRepo.deleteInvoiceLayout(id);
  Future<List<Unit>> getUnits() => productRepo.getUnits();
  Future<int> addUnit(Unit unit) => productRepo.addUnit(unit);
  Future<int> updateUnit(Unit unit) => productRepo.updateUnit(unit);
  Future<void> deleteUnit(int id) => productRepo.deleteUnit(id);
  Future<List<Unit>> getConversionUnitsForProduct(Product product) =>
      productRepo.getConversionUnitsForProduct(product);
  Future<List<SellingPriceGroup>> getSellingPriceGroups() =>
      productRepo.getSellingPriceGroups();
  Future<int> addSellingPriceGroup(SellingPriceGroup group) =>
      productRepo.addSellingPriceGroup(group);
  Future<int> updateSellingPriceGroup(SellingPriceGroup group) =>
      productRepo.updateSellingPriceGroup(group);
  Future<void> deleteSellingPriceGroup(int id) =>
      productRepo.deleteSellingPriceGroup(id);
  Future<List<Warranty>> getWarranties() => productRepo.getWarranties();
  Future<int> addWarranty(Warranty warranty) =>
      productRepo.addWarranty(warranty);
  Future<int> updateWarranty(Warranty warranty) =>
      productRepo.updateWarranty(warranty);
  Future<void> deleteWarranty(int id) => productRepo.deleteWarranty(id);
  Future<List<VariationTemplate>> getVariationTemplates() =>
      productRepo.getVariationTemplates();
  Future<int> addVariationTemplate(VariationTemplate template) =>
      productRepo.addVariationTemplate(template);
  Future<int> updateVariationTemplate(VariationTemplate template) =>
      productRepo.updateVariationTemplate(template);
  Future<void> deleteVariationTemplate(int id) =>
      productRepo.deleteVariationTemplate(id);
  Future<List<ProductVariation>> getProductVariations(int productId) =>
      productRepo.getProductVariations(productId);
  Future<int> addProductWithVariations(
          Product product, List<ProductVariation> variations) =>
      productRepo.addProductWithVariations(product, variations);
  Future<void> updateProductWithVariations(
          Product product, List<ProductVariation> variations) =>
      productRepo.updateProductWithVariations(product, variations);
  Future<List<Product>> getProducts(
          {int? categoryId, int? brandId, String? search}) =>
      productRepo.getProducts(
          categoryId: categoryId, brandId: brandId, search: search);
  Future<Product?> getProductByCode(String code) =>
      productRepo.getProductByCode(code);
  Future<int> addProduct(Product product) => productRepo.addProduct(product);
  Future<int> insertProduct(Product product) =>
      productRepo.insertProduct(product);
  Future<Product?> getProduct(int id) => productRepo.getProduct(id);
  Future<Product?> getProductById(int id) => productRepo.getProductById(id);
  Future<int> updateProduct(Product product) =>
      productRepo.updateProduct(product);
  Future<int> deleteProduct(int id) => productRepo.deleteProduct(id);
  Future<List<Product>> getLowStockProducts() =>
      productRepo.getLowStockProducts();
  Future<List<Category>> getCategories() => productRepo.getCategories();
  Future<int> addCategory(Category cat) => productRepo.addCategory(cat);
  Future<int> insertCategory(Category cat) => productRepo.insertCategory(cat);
  Future<int> updateCategory(Category cat) => productRepo.updateCategory(cat);
  Future<int> deleteCategory(int id) => productRepo.deleteCategory(id);
  Future<List<Brand>> getBrands() => productRepo.getBrands();
  Future<int> addBrand(Brand brand) => productRepo.addBrand(brand);
  Future<int> insertBrand(Brand brand) => productRepo.insertBrand(brand);
  Future<int> updateBrand(Brand brand) => productRepo.updateBrand(brand);
  Future<int> deleteBrand(int id) => productRepo.deleteBrand(id);
  Future<List<Contact>> getContacts({String? type, String? search}) =>
      contactsRepo.getContacts(type: type, search: search);
  Future<int> deleteContact(int id) => contactsRepo.deleteContact(id);
  Future<int> addContact(Contact contact) => contactsRepo.addContact(contact);
  Future<int> updateContact(Contact contact) =>
      contactsRepo.updateContact(contact);
  Future<Contact?> getContactById(int id) => contactsRepo.getContactById(id);
  Future<String> generateNextInvoiceNo() => salesRepo.generateNextInvoiceNo();
  Future<Sale> createSale({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
    int pointsRedeemed = 0,
    int pointsEarned = 0,
    bool enforceStock = false,
  }) =>
      salesRepo.createSale(
        sale: sale,
        items: items,
        splitTenders: splitTenders,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
        pointsRedeemed: pointsRedeemed,
        pointsEarned: pointsEarned,
        enforceStock: enforceStock,
      );
  Future<Sale> updateSale({
    required int saleId,
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
  }) =>
      salesRepo.updateSale(
          saleId: saleId, sale: sale, items: items, splitTenders: splitTenders);
  Future<void> deleteSale(int saleId) => salesRepo.deleteSale(saleId);
  Future<List<Sale>> getSales({String? status, String? search}) =>
      salesRepo.getSales(status: status, search: search);
  Future<List<SaleItem>> getSaleItems(int saleId) =>
      salesRepo.getSaleItems(saleId);
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) =>
      salesRepo.getSaleByInvoiceNo(invoiceNo);
  Future<void> settleSalePayment({
    required int saleId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) =>
      salesRepo.settleSalePayment(
          saleId: saleId,
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
          accountName: accountName,
          refNo: refNo,
          note: note,
          createdBy: createdBy);
  Future<void> settlePurchasePayment({
    required int purchaseId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) =>
      purchaseRepo.settlePurchasePayment(
        purchaseId: purchaseId,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        accountName: accountName,
        refNo: refNo,
        note: note,
        createdBy: createdBy,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
      );
  Future<void> recordContactPayment({
    required int contactId,
    required double amount,
    required String paymentMethod,
    String transactionType = 'customer_payment',
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) =>
      contactsRepo.recordContactPayment(
        contactId: contactId,
        amount: amount,
        paymentMethod: paymentMethod,
        transactionType: transactionType,
        accountName: accountName,
        refNo: refNo,
        note: note,
        createdBy: createdBy,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
      );
  Future<Map<String, dynamic>> getContactLedger({
    required int contactId,
    required String contactType,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      accountingRepo.getContactLedger(
          contactId: contactId,
          contactType: contactType,
          startDate: startDate,
          endDate: endDate);
  Future<Map<String, dynamic>> getPaymentAccountStatement({
    required int accountId,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      accountingRepo.getPaymentAccountStatement(
          accountId: accountId,
          accountName: accountName,
          startDate: startDate,
          endDate: endDate);
  Future<Map<String, dynamic>> getFinancialTrialBalance() =>
      accountingRepo.getFinancialTrialBalance();
  Future<int> addJournalVoucher({
    required String narration,
    required String debitAccount,
    required String creditAccount,
    required double amount,
    String? refNo,
  }) =>
      accountingRepo.addJournalVoucher(
          narration: narration,
          debitAccount: debitAccount,
          creditAccount: creditAccount,
          amount: amount,
          refNo: refNo);
  Future<List<Map<String, dynamic>>> getJournalVouchers() =>
      accountingRepo.getJournalVouchers();
  Future<int> parkSale(ParkedSale parked) => salesRepo.parkSale(parked);
  Future<List<ParkedSale>> getParkedSales() => salesRepo.getParkedSales();
  Future<int> deleteParkedSale(int id) => salesRepo.deleteParkedSale(id);
  Future<String> generateNextPurchaseRef() =>
      purchaseRepo.generateNextPurchaseRef();
  Future<int> createPurchase({
    required Purchase purchase,
    required List<Map<String, dynamic>> items,
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) =>
      purchaseRepo.createPurchase(
        purchase: purchase,
        items: items,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
      );
  Future<bool> updatePurchaseStatus(int purchaseId, String newStatus) =>
      purchaseRepo.updatePurchaseStatus(purchaseId, newStatus);
  Future<bool> deletePurchase(int purchaseId) =>
      purchaseRepo.deletePurchase(purchaseId);
  Future<List<Purchase>> getPurchases() => purchaseRepo.getPurchases();
  Future<String> generateNextTransferRef() =>
      inventoryRepo.generateNextTransferRef();
  Future<List<StockTransfer>> getStockTransfers() =>
      inventoryRepo.getStockTransfers();
  Future<int> createStockTransfer(StockTransfer transfer) =>
      inventoryRepo.createStockTransfer(transfer);
  Future<bool> updateStockTransferStatus(int transferId, String newStatus) =>
      inventoryRepo.updateStockTransferStatus(transferId, newStatus);
  Future<int> deleteStockTransfer(int id) =>
      inventoryRepo.deleteStockTransfer(id);
  Future<String> generateNextAdjustmentRef() =>
      inventoryRepo.generateNextAdjustmentRef();
  Future<List<StockAdjustment>> getStockAdjustments() =>
      inventoryRepo.getStockAdjustments();
  Future<int> createStockAdjustment(StockAdjustment adjustment) =>
      inventoryRepo.createStockAdjustment(adjustment);
  Future<int> deleteStockAdjustment(int id) =>
      inventoryRepo.deleteStockAdjustment(id);
  Future<String> generateNextPaymentRef() =>
      contactsRepo.generateNextPaymentRef();
  Future<int> addContactPayment(ContactPayment payment) =>
      contactsRepo.addContactPayment(payment);
  Future<List<ContactPayment>> getContactPayments(int contactId) =>
      contactsRepo.getContactPayments(contactId);
  Future<List<Expense>> getExpenses() => expenseRepo.getExpenses();
  Future<int> addExpense(Expense expense) => expenseRepo.addExpense(expense);
  Future<String> generateNextAccountTransferRef() =>
      accountingRepo.generateNextAccountTransferRef();
  Future<List<PaymentAccount>> getPaymentAccounts() =>
      accountingRepo.getPaymentAccounts();
  Future<int> addPaymentAccount(PaymentAccount account) =>
      accountingRepo.addPaymentAccount(account);
  Future<List<AccountTransfer>> getAccountTransfers() =>
      accountingRepo.getAccountTransfers();
  Future<int> transferAccountFunds(AccountTransfer transfer) =>
      accountingRepo.transferAccountFunds(transfer);
  Future<bool> deleteAccountTransfer(int transferId) =>
      accountingRepo.deleteAccountTransfer(transferId);
  Future<int> depositToAccount({
    required int accountId,
    required double amount,
    required String note,
    String paymentMethod = 'cash',
  }) =>
      accountingRepo.depositToAccount(
          accountId: accountId,
          amount: amount,
          note: note,
          paymentMethod: paymentMethod);
  Future<CashRegister?> getActiveRegister() => registerRepo.getActiveRegister();
  Future<void> openRegister(String cashierName, double openingAmount) =>
      registerRepo.openRegister(cashierName, openingAmount);
  Future<void> closeRegister(
    int id,
    double closingAmount,
    String note, {
    Map<int, int>? denominations,
    double coinsAmount = 0.0,
  }) =>
      registerRepo.closeRegister(
        id,
        closingAmount,
        note,
        denominations: denominations,
        coinsAmount: coinsAmount,
      );
  Future<Map<int, double>> getProductLocationStocks(int productId) =>
      inventoryRepo.getProductLocationStocks(productId);
  Future<Map<int, double>> getReturnedQuantitiesForSale(int saleId) =>
      salesRepo.getReturnedQuantitiesForSale(saleId);
  Future<List<Map<String, dynamic>>> getModuleRecords(
    String moduleKey, {
    String? recordType,
  }) =>
      industryModulesRepo.getModuleRecords(moduleKey, recordType: recordType);
  Future<int> saveModuleRecord({
    int? id,
    required String moduleKey,
    required String recordType,
    String title = '',
    String status = 'active',
    required Map<String, dynamic> data,
  }) =>
      industryModulesRepo.saveModuleRecord(
        id: id,
        moduleKey: moduleKey,
        recordType: recordType,
        title: title,
        status: status,
        data: data,
      );
  Future<int> deleteModuleRecord(int id) =>
      industryModulesRepo.deleteModuleRecord(id);
  Future<List<Map<String, dynamic>>> getRegisterReport({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? cashierName,
  }) =>
      reportRepo.getRegisterReport(
          startDate: startDate,
          endDate: endDate,
          status: status,
          cashierName: cashierName);
  Future<List<Map<String, dynamic>>> getStockExpiryReport({
    String? filter,
    String? searchQuery,
  }) =>
      reportRepo.getStockExpiryReport(filter: filter, searchQuery: searchQuery);
  Future<Map<String, dynamic>> getDashboardMetrics({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) =>
      reportRepo.getDashboardMetrics(
        startDate: startDate,
        endDate: endDate,
        forceRefresh: forceRefresh,
      );
  void invalidateReportCache() => ReportRepository.clearCache();
  Future<Map<String, dynamic>> getProfitAndLossReport() =>
      reportRepo.getProfitAndLossReport();
  Future<Map<String, dynamic>> getStockValuationReport() =>
      reportRepo.getStockValuationReport();
  Future<Map<String, dynamic>> getComprehensiveBusinessReport({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      reportRepo.getComprehensiveBusinessReport(
          startDate: startDate, endDate: endDate);
  Future<List<Product>> getDeadStockProducts({int daysThreshold = 30}) =>
      reportRepo.getDeadStockProducts(daysThreshold: daysThreshold);
  Future<List<Product>> getExpiringProducts({int monthsAhead = 6}) =>
      reportRepo.getExpiringProducts(monthsAhead: monthsAhead);
  Future<List<Contact>> getCustomers() => contactsRepo.getCustomers();
  Future<List<Contact>> getSuppliers() => contactsRepo.getSuppliers();
  Future<List<Map<String, dynamic>>> getRestaurantTables({String? section}) =>
      industryModulesRepo.getRestaurantTables(section: section);
  Future<int> addRestaurantTable(Map<String, dynamic> table) =>
      industryModulesRepo.addRestaurantTable(table);
  Future<int> updateRestaurantTable(int id, Map<String, dynamic> table) =>
      industryModulesRepo.updateRestaurantTable(id, table);
  Future<int> deleteRestaurantTable(int id) =>
      industryModulesRepo.deleteRestaurantTable(id);
  Future<List<Map<String, dynamic>>> getRestaurantKotOrders() =>
      industryModulesRepo.getRestaurantKotOrders();
  Future<int> addRestaurantKotOrder(Map<String, dynamic> order) =>
      industryModulesRepo.addRestaurantKotOrder(order);
  Future<int> updateRestaurantKotStatus(int id, String status) =>
      industryModulesRepo.updateRestaurantKotStatus(id, status);
  Future<int> deleteRestaurantKotOrder(int id) =>
      industryModulesRepo.deleteRestaurantKotOrder(id);
  Future<Map<String, int>> seedInitialDataForBusinessType({
    required String businessType,
    int? pharmacyProductTarget,
  }) =>
      seederRepo.seedInitialDataForBusinessType(
          businessType: businessType,
          pharmacyProductTarget: pharmacyProductTarget);
  Future<List<Map<String, dynamic>>> getDailySalesTrend({
    int days = 7,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      reportRepo.getDailySalesTrend(
        days: days,
        startDate: startDate,
        endDate: endDate,
      );
  Future<Map<String, double>> getPaymentMethodBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      reportRepo.getPaymentMethodBreakdown(
        startDate: startDate,
        endDate: endDate,
      );
  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      reportRepo.getTopSellingProducts(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
  Future<Map<String, dynamic>> getTodaySalesMetrics() =>
      reportRepo.getTodaySalesMetrics();
  Future<List<User>> getUsers() => authRepo.getUsers();
  Future<int> addUser(User user, {bool replaceExisting = false}) =>
      authRepo.addUser(user, replaceExisting: replaceExisting);
  Future<void> updateUser(User user) => authRepo.updateUser(user);
  Future<void> deleteUser(int id) => authRepo.deleteUser(id);
  Future<List<SaleReturn>> getSaleReturns() => salesRepo.getSaleReturns();
  Future<String> generateNextSaleReturnRef() =>
      salesRepo.generateNextSaleReturnRef();
  Future<int> addSaleReturn(SaleReturn sr, {int locationId = 1}) =>
      salesRepo.addSaleReturn(sr, locationId: locationId);
  Future<List<PurchaseReturn>> getPurchaseReturns() =>
      purchaseRepo.getPurchaseReturns();
  Future<String> generateNextPurchaseReturnRef() =>
      purchaseRepo.generateNextPurchaseReturnRef();
  Future<int> addPurchaseReturn(PurchaseReturn pr) =>
      purchaseRepo.addPurchaseReturn(pr);
  Future<List<FinancialYear>> getFinancialYears() =>
      accountingRepo.getFinancialYears();
  Future<int> closeFinancialYear(FinancialYear fy) =>
      accountingRepo.closeFinancialYear(fy);
  Future<void> purgeAllBusinessData() => seederRepo.purgeAllBusinessData();
  Future<BusinessSettings> factoryResetForNewBusiness() =>
      seederRepo.factoryResetForNewBusiness();
  Future<Map<String, int>> seedMedicineAgencyData({
    int productTarget = 2500,
    int customerTarget = 1500,
    int supplierTarget = 100,
    int salesmanTarget = 15,
  }) =>
      seederRepo.seedMedicineAgencyData(
          productTarget: productTarget,
          customerTarget: customerTarget,
          supplierTarget: supplierTarget,
          salesmanTarget: salesmanTarget);
  Future<Map<String, dynamic>> benchmarkTransactions({int count = 10000}) =>
      seederRepo.benchmarkTransactions(count: count);
  Future<int> queueSyncItem({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) =>
      syncRepo.queueSyncItem(
          entityType: entityType,
          entityId: entityId,
          action: action,
          payload: payload);
  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 100}) =>
      syncRepo.getPendingSyncItems(limit: limit);
  Future<void> markSyncItemsDone(List<int> ids) =>
      syncRepo.markSyncItemsDone(ids);
  Future<void> markSyncItemFailed(int id, String error) =>
      syncRepo.markSyncItemFailed(id, error);
  Future<int> getPendingSyncCount() => syncRepo.getPendingSyncCount();
  Future<List<Map<String, dynamic>>> getRecentSyncLogs({int limit = 50}) =>
      syncRepo.getRecentSyncLogs(limit: limit);
  Future<void> clearCompletedSyncLogs() => syncRepo.clearCompletedSyncLogs();
  Future<Map<String, dynamic>> resolveSyncConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> remoteRecord,
    String localUpdatedAt = '',
    String remoteUpdatedAt = '',
  }) =>
      syncRepo.resolveSyncConflict(
        entityType: entityType,
        entityId: entityId,
        localRecord: localRecord,
        remoteRecord: remoteRecord,
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      );
  Future<List<Map<String, dynamic>>> getGymMembers({String? status}) =>
      industryModulesRepo.getGymMembers(status: status);
  Future<int> addGymMember(Map<String, dynamic> member) =>
      industryModulesRepo.addGymMember(member);
  Future<int> updateGymMember(int id, Map<String, dynamic> member) =>
      industryModulesRepo.updateGymMember(id, member);
  Future<int> deleteGymMember(int id) =>
      industryModulesRepo.deleteGymMember(id);
  Future<List<Map<String, dynamic>>> getHotelRooms({String? status}) =>
      industryModulesRepo.getHotelRooms(status: status);
  Future<int> addHotelRoom(Map<String, dynamic> room) =>
      industryModulesRepo.addHotelRoom(room);
  Future<int> updateHotelRoom(int id, Map<String, dynamic> room) =>
      industryModulesRepo.updateHotelRoom(id, room);
  Future<int> deleteHotelRoom(int id) =>
      industryModulesRepo.deleteHotelRoom(id);
  Future<List<Map<String, dynamic>>> getRepairJobs({String? status}) =>
      industryModulesRepo.getRepairJobs(status: status);
  Future<int> addRepairJob(Map<String, dynamic> job) =>
      industryModulesRepo.addRepairJob(job);
  Future<int> updateRepairJob(int id, Map<String, dynamic> job) =>
      industryModulesRepo.updateRepairJob(id, job);
  Future<int> deleteRepairJob(int id) =>
      industryModulesRepo.deleteRepairJob(id);
  Future<int> addPaymentTransaction(PaymentTransaction transaction) =>
      contactsRepo.addPaymentTransaction(transaction);
  Future<List<PaymentTransaction>> getPaymentTransactionsForSale(int saleId) =>
      contactsRepo.getPaymentTransactionsForSale(saleId);
  Future<List<PaymentTransaction>> getPaymentTransactionsForPurchase(
          int purchaseId) =>
      contactsRepo.getPaymentTransactionsForPurchase(purchaseId);
  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(
          int contactId) =>
      contactsRepo.getPaymentTransactionsForContact(contactId);
  Future<List<PaymentTransaction>> getAllPaymentTransactions(
          {int limit = 100}) =>
      contactsRepo.getAllPaymentTransactions(limit: limit);
  Future<int> deletePaymentTransaction(int id) =>
      contactsRepo.deletePaymentTransaction(id);
  Future<int> addProductSerialBatch(ProductSerialBatch item) =>
      inventoryRepo.addProductSerialBatch(item);
  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId,
          {String? status}) =>
      inventoryRepo.getProductSerialsBatches(productId, status: status);
  Future<ProductSerialBatch?> getProductSerialByImei(String imei) =>
      inventoryRepo.getProductSerialByImei(imei);
  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId) =>
      inventoryRepo.getActiveBatchesForProduct(productId);
  Future<void> updateProductSerialStatus(int id, String status,
          {int? saleId, int? purchaseId}) =>
      inventoryRepo.updateProductSerialStatus(id, status,
          saleId: saleId, purchaseId: purchaseId);
  Future<int> deleteProductSerialBatch(int id) =>
      inventoryRepo.deleteProductSerialBatch(id);
  Future<int> addProductBundleItem(ProductBundleItem item) =>
      inventoryRepo.addProductBundleItem(item);
  Future<List<ProductBundleItem>> getBundleItems(int parentProductId) =>
      inventoryRepo.getBundleItems(parentProductId);
  Future<void> saveBundleItems(
          int parentProductId, List<ProductBundleItem> items) =>
      inventoryRepo.saveBundleItems(parentProductId, items);
  Future<int> deleteBundleItem(int id) => inventoryRepo.deleteBundleItem(id);
  Future<int> logAuditAction({
    required String action,
    required String entityType,
    String? entityId,
    int? userId,
    required String userName,
    String? details,
    String? oldValues,
    String? newValues,
    String? ipAddress,
  }) =>
      authRepo.logAuditAction(
          action: action,
          entityType: entityType,
          entityId: entityId,
          userId: userId,
          userName: userName,
          details: details,
          oldValues: oldValues,
          newValues: newValues,
          ipAddress: ipAddress);
  Future<List<AuditLog>> getAuditLogs({int limit = 100, String? entityType}) =>
      authRepo.getAuditLogs(limit: limit, entityType: entityType);
  Future<int> updateRestaurantTableStatus(
    int id,
    String status, {
    double? orderTotal,
    String? kotTime,
    String? waiterName,
    int? waiterId,
    int? currentSaleId,
  }) =>
      industryModulesRepo.updateRestaurantTableStatus(id, status,
          orderTotal: orderTotal,
          kotTime: kotTime,
          waiterName: waiterName,
          waiterId: waiterId,
          currentSaleId: currentSaleId);
  Future<void> updateContactBalance(int contactId, double deltaAmount) =>
      contactsRepo.updateContactBalance(contactId, deltaAmount);
  Future<void> updateContactLoyaltyPoints(int contactId, double deltaPoints) =>
      contactsRepo.updateContactLoyaltyPoints(contactId, deltaPoints);
  Future<bool> isWalkInCustomer(int? customerId) =>
      contactsRepo.isWalkInCustomer(customerId);
  Future<void> resetToFreshInstallation() =>
      seederRepo.resetToFreshInstallation();

  // ===================== PHASE 3 DELEGATORS =====================
  // Tax Groups (Compound & Additive)
  Future<List<TaxGroup>> getTaxGroups() => settingsRepo.getTaxGroups();
  Future<int> addTaxGroup(TaxGroup group) => settingsRepo.addTaxGroup(group);
  Future<void> updateTaxGroup(TaxGroup group) =>
      settingsRepo.updateTaxGroup(group);
  Future<void> deleteTaxGroup(int id) => settingsRepo.deleteTaxGroup(id);

  // Customer Groups & Tiered Pricing
  Future<List<CustomerGroup>> getCustomerGroups() =>
      contactsRepo.getCustomerGroups();
  Future<CustomerGroup?> getCustomerGroupById(int id) =>
      contactsRepo.getCustomerGroupById(id);
  Future<int> addCustomerGroup(CustomerGroup group) =>
      contactsRepo.addCustomerGroup(group);
  Future<int> updateCustomerGroup(CustomerGroup group) =>
      contactsRepo.updateCustomerGroup(group);
  Future<int> deleteCustomerGroup(int id) =>
      contactsRepo.deleteCustomerGroup(id);
  Future<void> assignCustomerToGroup(int contactId, int? groupId) =>
      contactsRepo.assignCustomerToGroup(contactId, groupId);

  // Quotations & Invoice Conversion
  Future<List<Sale>> getQuotations({
    String? search,
    String conversionFilter = 'all',
  }) =>
      salesRepo.getQuotations(
        search: search,
        conversionFilter: conversionFilter,
      );
  Future<Sale> convertQuotationToInvoice({
    required int quotationId,
    String paymentMethod = 'cash',
    double? paidAmount,
    String note = '',
  }) =>
      salesRepo.convertQuotationToInvoice(
        quotationId: quotationId,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        note: note,
      );
  Future<Map<String, dynamic>> getQuotationConversionStats() =>
      reportRepo.getQuotationConversionStats();

  // RBAC Roles & Permissions
  Future<List<AppRole>> getRoles() => authRepo.getRoles();
  Future<AppRole?> getRoleByName(String name) => authRepo.getRoleByName(name);
  Future<List<String>> getRolePermissions(int roleId) =>
      authRepo.getRolePermissions(roleId);
  Future<int> saveRole(AppRole role) => authRepo.saveRole(role);
  Future<void> setRolePermissions(int roleId, List<String> permissionKeys) =>
      authRepo.setRolePermissions(roleId, permissionKeys);
  Future<bool> deleteRole(int roleId) => authRepo.deleteRole(roleId);
  Future<List<String>> getEffectivePermissionsForUser(User user) =>
      authRepo.getEffectivePermissionsForUser(user);

  // Activity Log / Audit Trail
  Future<int> logActivity({
    required String action,
    required String entityType,
    int? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? userName,
    int? userId,
    String ipAddress = '127.0.0.1',
  }) =>
      authRepo.logActivity(
        action: action,
        entityType: entityType,
        entityId: entityId,
        oldValues: oldValues,
        newValues: newValues,
        userName: userName,
        userId: userId,
        ipAddress: ipAddress,
      );
  Future<List<ActivityLogEntry>> getActivityLogs({
    int limit = 200,
    String? entityType,
    String? action,
    String? search,
  }) =>
      authRepo.getActivityLogs(
        limit: limit,
        entityType: entityType,
        action: action,
        search: search,
      );

  // ===================== PHASE 5 DELEGATORS =====================
  Future<PagedResult<Product>> getProductsPaged({
    int? categoryId,
    int? brandId,
    String? search,
    String stockFilter = 'all',
    String productType = 'all',
    bool featuredOnly = false,
    int page = 1,
    int pageSize = 25,
    String? cursorName,
    int? cursorId,
    bool includeTotalCount = true,
  }) =>
      productRepo.getProductsPaged(
        categoryId: categoryId,
        brandId: brandId,
        search: search,
        stockFilter: stockFilter,
        productType: productType,
        featuredOnly: featuredOnly,
        page: page,
        pageSize: pageSize,
        cursorName: cursorName,
        cursorId: cursorId,
        includeTotalCount: includeTotalCount,
      );

  Future<Map<String, num>> getProductCatalogStats() =>
      productRepo.getProductCatalogStats();

  Future<Map<int, String>> getProductImagePathsByIds(
          Iterable<int> productIds) =>
      productRepo.getProductImagePathsByIds(productIds);

  Future<(Product, ProductVariation?)?> getProductWithMatchedVariationByCode(
    String code,
  ) =>
      productRepo.getProductWithMatchedVariationByCode(code);

  Future<PagedResult<Sale>> getSalesPaged({
    String? status,
    String? search,
    String conversionFilter = 'all',
    int? locationId,
    int? customerId,
    String? paymentStatus,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  }) =>
      salesRepo.getSalesPaged(
        status: status,
        search: search,
        conversionFilter: conversionFilter,
        locationId: locationId,
        customerId: customerId,
        paymentStatus: paymentStatus,
        page: page,
        pageSize: pageSize,
        cursorId: cursorId,
        includeTotalCount: includeTotalCount,
      );

  Future<Map<String, int>> getSalesTabCounts() => salesRepo.getSalesTabCounts();

  Future<PagedResult<Purchase>> getPurchasesPaged({
    String? status,
    String? paymentStatus,
    String? search,
    bool? purchaseOrdersOnly,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  }) =>
      purchaseRepo.getPurchasesPaged(
        status: status,
        paymentStatus: paymentStatus,
        search: search,
        purchaseOrdersOnly: purchaseOrdersOnly,
        page: page,
        pageSize: pageSize,
        cursorId: cursorId,
        includeTotalCount: includeTotalCount,
      );

  Future<Map<String, num>> getPurchaseSummaryStats() =>
      purchaseRepo.getPurchaseSummaryStats();

  Future<PagedResult<Contact>> getContactsPaged({
    String? type,
    String? search,
    String balanceFilter = 'all',
    int page = 1,
    int pageSize = 25,
    String? cursorName,
    int? cursorId,
    bool includeTotalCount = true,
  }) =>
      contactsRepo.getContactsPaged(
        type: type,
        search: search,
        balanceFilter: balanceFilter,
        page: page,
        pageSize: pageSize,
        cursorName: cursorName,
        cursorId: cursorId,
        includeTotalCount: includeTotalCount,
      );

  Future<Map<String, num>> getContactSummaryStats({required String type}) =>
      contactsRepo.getContactSummaryStats(type: type);

  // ===================== PHASE 6: ADVANCED BUSINESS FEATURES =====================

  // Step 6.1: Sales Orders Workflow
  Future<String> generateNextSalesOrderNo() =>
      salesRepo.generateNextSalesOrderNo();
  Future<Map<String, dynamic>> getPendingSalesOrdersSummary({int limit = 5}) =>
      salesRepo.getPendingSalesOrdersSummary(limit: limit);
  Future<Sale> convertSalesOrderToInvoice({
    required int orderId,
    Map<int, double>? fulfillQuantitiesByItemId,
    String paymentMethod = 'cash',
    double? paidAmount,
    String note = '',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) =>
      salesRepo.convertSalesOrderToInvoice(
        orderId: orderId,
        fulfillQuantitiesByItemId: fulfillQuantitiesByItemId,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        note: note,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
      );

  // Step 6.2: Purchase Orders Workflow
  Future<String> generateNextPurchaseOrderRef() =>
      purchaseRepo.generateNextPurchaseOrderRef();
  Future<Map<String, dynamic>> getPendingPurchaseOrdersSummary(
          {int limit = 5}) =>
      purchaseRepo.getPendingPurchaseOrdersSummary(limit: limit);
  Future<int> receivePurchaseOrderItems({
    required int poId,
    Map<int, double>? receiveQtyByLineIndex,
    String supplierInvoiceRef = '',
    double paidNow = 0.0,
    String paymentMethod = 'cash',
    int? paymentAccountId,
    String note = '',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) =>
      purchaseRepo.receivePurchaseOrderItems(
        poId: poId,
        receiveQtyByLineIndex: receiveQtyByLineIndex,
        supplierInvoiceRef: supplierInvoiceRef,
        paidNow: paidNow,
        paymentMethod: paymentMethod,
        paymentAccountId: paymentAccountId,
        note: note,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDueDate: chequeDueDate,
      );

  // Step 6.3: Cheque Management
  Future<List<PaymentTransaction>> getCheques({
    String? status,
    String? transactionType,
    String? search,
  }) =>
      advancedRepo.getCheques(
        status: status,
        transactionType: transactionType,
        search: search,
      );
  Future<Map<String, num>> getChequeSummary() =>
      advancedRepo.getChequeSummary();
  Future<void> updateChequeStatus({
    required int transactionId,
    required String newStatus,
    String? clearedDate,
    String? note,
  }) =>
      advancedRepo.updateChequeStatus(
        transactionId: transactionId,
        newStatus: newStatus,
        clearedDate: clearedDate,
        note: note,
      );

  // Step 6.4: Commission Agents
  Future<List<CommissionAgent>> getCommissionAgents(
          {bool activeOnly = false}) =>
      advancedRepo.getCommissionAgents(activeOnly: activeOnly);
  Future<int> addCommissionAgent(CommissionAgent agent) =>
      advancedRepo.addCommissionAgent(agent);
  Future<int> updateCommissionAgent(CommissionAgent agent) =>
      advancedRepo.updateCommissionAgent(agent);
  Future<int> deleteCommissionAgent(int id) =>
      advancedRepo.deleteCommissionAgent(id);
  Future<List<Map<String, dynamic>>> getCommissionReport({
    DateTime? startDate,
    DateTime? endDate,
    int? agentId,
  }) =>
      advancedRepo.getCommissionReport(
        startDate: startDate,
        endDate: endDate,
        agentId: agentId,
      );
  Future<List<Sale>> getSalesByCommissionAgent(
    int agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      advancedRepo.getSalesByCommissionAgent(
        agentId,
        startDate: startDate,
        endDate: endDate,
      );

  // Step 6.5: Discount Schedules
  Future<List<DiscountRule>> getDiscountRules({bool activeOnly = false}) =>
      advancedRepo.getDiscountRules(activeOnly: activeOnly);
  Future<int> addDiscountRule(DiscountRule rule) =>
      advancedRepo.addDiscountRule(rule);
  Future<int> updateDiscountRule(DiscountRule rule) =>
      advancedRepo.updateDiscountRule(rule);
  Future<int> deleteDiscountRule(int id) => advancedRepo.deleteDiscountRule(id);
  Future<DiscountEvaluationResult> evaluateCartDiscounts(
    List<CartItem> items, {
    DateTime? now,
  }) =>
      advancedRepo.evaluateCartDiscounts(items, now: now);
}
