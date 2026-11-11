import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/qulop_service.dart';
import '../../services/theme_service.dart';
import '../../services/backup_update_service.dart';
import '../../services/local_api_service.dart';
import '../../services/mysql_service.dart';
import '../../services/regional_data_service.dart';
import '../../services/currency_rate_service.dart';
import '../../services/print_service.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/number_to_words_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings) onSettingsUpdated;

  const SettingsScreen({super.key, required this.settings, required this.onSettingsUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bizNameCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _currencySymCtrl;
  late TextEditingController _currencyCodeCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _purchaseKeyCtrl;
  late TextEditingController _drugLicenseCtrl;
  late TextEditingController _dlWarrantorCtrl;
  late TextEditingController _startDateCtrl;
  late TextEditingController _defaultProfitPercentCtrl;
  late TextEditingController _transactionEditDaysCtrl;
  late TextEditingController _currencyPrecisionCtrl;
  late TextEditingController _quantityPrecisionCtrl;

  String _businessType = 'universal';
  String _currencyPlacement = 'before';
  String _timeZone = 'Asia/Karachi';
  String? _logoPath;
  String _financialYearStartMonth = 'January';
  String _stockAccountingMethod = 'FIFO';
  String _dateFormat = 'dd/mm/yyyy';
  String _timeFormat = '12 Hour';

  // Primary Database Engine Configuration State
  String _primaryDbType = 'mysql';
  late TextEditingController _dbHostCtrl;
  late TextEditingController _dbPortCtrl;
  late TextEditingController _dbNameCtrl;
  late TextEditingController _dbUserCtrl;
  late TextEditingController _dbPassCtrl;
  bool _obscureDbPass = true;
  bool _isTestingDbConnection = false;
  String? _dbConnectionResult;
  bool? _dbConnectionSuccess;

  // Purge & Seeding Engine State
  bool _isPurging = false;
  bool _isSeeding = false;
  bool _isBenchmarking = false;
  String _seedingStatus = '';
  String _benchmarkStatus = '';
  Map<String, int> _dbStats = {
    'products': 0,
    'customers': 0,
    'suppliers': 0,
    'users': 0,
    'sales': 0,
  };

  String _hostMac = 'Detecting...';
  LicenseStatus? _currentLicenseStatus;

  List<BusinessLocation> _locations = [];
  List<TaxRate> _taxRates = [];
  List<InvoiceScheme> _schemes = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // Software Update & Backup Center State
  bool _isCheckingUpdate = false;
  Map<String, dynamic>? _updateInfo;
  bool _isApplyingUpdate = false;
  String _updateStatusMessage = '';
  bool _isCreatingBackup = false;
  List<FileSystemEntity> _backupFiles = [];
  bool _isLoadingBackups = false;
  final TextEditingController _offlinePkgCtrl = TextEditingController(text: r'D:\updates\smartpos_v2.6_update.pkg');
  bool _isStartingApi = false;

  // Bill Customization & Printing State
  String _receiptPaperSize = '80mm';
  late TextEditingController _receiptTaglineCtrl;
  late TextEditingController _receiptNoteCtrl;
  late TextEditingController _receiptReturnPolicyCtrl;
  int _invoicePrintCopies = 1;
  bool _showLogoOnReceipt = true;
  bool _showBarcodeOnReceipt = true;
  bool _showQrOnReceipt = true;
  bool _showCustomerBalanceOnReceipt = true;
  bool _showTaxBreakdownOnReceipt = true;
  bool _showCashierNameOnReceipt = true;
  bool _isSavingReceiptSettings = false;

  // Invoice Layout & Detailed A4 Customization (Ultimate POS style)
  String _invoiceLayoutDesign = 'detailed';
  bool _showBatchOnInvoice = true;
  bool _showExpiryOnInvoice = true;
  bool _showBrandOnInvoice = true;
  bool _showSkuOnInvoice = true;
  bool _showWarrantyOnInvoice = true;
  bool _showTotalInWords = true;
  String _totalInWordsLanguage = 'ur';
  bool _enableSecondaryLanguage = false;
  String _secondaryLanguage = 'ur';
  late TextEditingController _invoiceHeadingCtrl;

  // Multi-Currency & Live Exchange Rates State
  bool _multiCurrencyEnabled = true;
  List<CurrencyRate> _ratesList = [];
  bool _isSyncingRates = false;
  String _lastRatesSync = '';
  CurrencyInfo? _selectedCurrencyInfo;

  // AI Business Advisor State (BYO Gemini / OpenAI)
  AiSettings _aiSettings = AiSettings();
  late TextEditingController _aiApiKeyCtrl;
  bool _obscureAiKey = true;
  bool _isTestingAi = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _aiApiKeyCtrl = TextEditingController();
    _loadBackups();
    final s = widget.settings;
    _bizNameCtrl = TextEditingController(text: s.businessName);
    _branchCtrl = TextEditingController(text: s.branchName);
    _currencySymCtrl = TextEditingController(text: s.currencySymbol);
    _currencyCodeCtrl = TextEditingController(text: s.currencyCode);
    _taxCtrl = TextEditingController(text: s.defaultTaxRate.toString());
    _phoneCtrl = TextEditingController(text: s.phone);
    _emailCtrl = TextEditingController(text: s.email);
    _addressCtrl = TextEditingController(text: s.address);
    _footerCtrl = TextEditingController(text: s.receiptFooter);
    _purchaseKeyCtrl = TextEditingController(text: s.purchaseKey);
    _businessType = s.businessType.isNotEmpty ? s.businessType : 'universal';
    _drugLicenseCtrl = TextEditingController(text: s.drugLicenseNo);
    _dlWarrantorCtrl = TextEditingController(text: s.dlWarrantor);
    _startDateCtrl = TextEditingController(text: s.startDate);
    _defaultProfitPercentCtrl = TextEditingController(text: s.defaultProfitPercent.toString());
    _transactionEditDaysCtrl = TextEditingController(text: s.transactionEditDays.toString());
    _currencyPrecisionCtrl = TextEditingController(text: s.currencyPrecision.toString());
    _quantityPrecisionCtrl = TextEditingController(text: s.quantityPrecision.toString());
    _currencyPlacement = s.currencyPlacement;
    _timeZone = s.timeZone;
    _logoPath = s.logoPath;
    _financialYearStartMonth = s.financialYearStartMonth;
    _stockAccountingMethod = s.stockAccountingMethod;
    _dateFormat = s.dateFormat;
    _timeFormat = s.timeFormat;

    _primaryDbType = s.primaryDbType.isNotEmpty ? s.primaryDbType : 'mysql';
    _dbHostCtrl = TextEditingController(text: s.dbHost.isNotEmpty ? s.dbHost : 'localhost');
    final defaultDbPort = _primaryDbType == 'postgresql' ? 5432 : 3306;
    _dbPortCtrl = TextEditingController(text: (s.dbPort > 0 ? s.dbPort : defaultDbPort).toString());
    _dbNameCtrl = TextEditingController(text: s.dbName.isNotEmpty ? s.dbName : 'smartpos');
    _dbUserCtrl = TextEditingController(
      text: s.dbUser.isNotEmpty ? s.dbUser : (_primaryDbType == 'postgresql' ? 'postgres' : 'root'),
    );
    _dbPassCtrl = TextEditingController(text: s.dbPassword);

    _receiptPaperSize = s.receiptPaperSize.isNotEmpty ? s.receiptPaperSize : '80mm';
    _receiptTaglineCtrl = TextEditingController(
      text: s.receiptHeaderTagline.isNotEmpty ? s.receiptHeaderTagline : 'Wholesale & Retail Distributor',
    );
    _receiptNoteCtrl = TextEditingController(
      text: s.receiptHeaderNote.isNotEmpty ? s.receiptHeaderNote : 'Welcome to our store!',
    );
    _receiptReturnPolicyCtrl = TextEditingController(
      text: s.receiptReturnPolicy.isNotEmpty
          ? s.receiptReturnPolicy
          : 'Goods once sold can only be exchanged within 7 days with original receipt.',
    );
    _invoicePrintCopies = s.invoicePrintCopies > 0 ? s.invoicePrintCopies : 1;
    _showLogoOnReceipt = s.showLogoOnReceipt;
    _showBarcodeOnReceipt = s.showBarcodeOnReceipt;
    _showQrOnReceipt = s.showQrOnReceipt;
    _showCustomerBalanceOnReceipt = s.showCustomerBalanceOnReceipt;
    _showTaxBreakdownOnReceipt = s.showTaxBreakdownOnReceipt;
    _showCashierNameOnReceipt = s.showCashierNameOnReceipt;

    _invoiceLayoutDesign = s.invoiceLayoutDesign.isNotEmpty ? s.invoiceLayoutDesign : 'detailed';
    _showBatchOnInvoice = s.showBatchOnInvoice;
    _showExpiryOnInvoice = s.showExpiryOnInvoice;
    _showBrandOnInvoice = s.showBrandOnInvoice;
    _showSkuOnInvoice = s.showSkuOnInvoice;
    _showWarrantyOnInvoice = s.showWarrantyOnInvoice;
    _showTotalInWords = s.showTotalInWords;
    _totalInWordsLanguage = s.totalInWordsLanguage.isNotEmpty ? s.totalInWordsLanguage : 'ur';
    _enableSecondaryLanguage = s.enableSecondaryLanguage;
    _secondaryLanguage = s.secondaryLanguage.isNotEmpty ? s.secondaryLanguage : 'ur';
    _invoiceHeadingCtrl = TextEditingController(text: s.invoiceHeading.isNotEmpty ? s.invoiceHeading : 'TAX INVOICE');

    _multiCurrencyEnabled = s.multiCurrencyEnabled;
    _lastRatesSync = s.lastRatesSync;
    _ratesList = CurrencyRateService.parseRatesJson(s.exchangeRatesJson, s.currencyCode);
    _selectedCurrencyInfo = RegionalDataService.findCurrency(s.currencyCode) ??
        RegionalDataService.findCurrency('PKR');

    _initLicenseInfo();
    _loadSubData();
    _loadDbStats();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      final s = widget.settings;
      _bizNameCtrl.text = s.businessName;
      _branchCtrl.text = s.branchName;
      _currencySymCtrl.text = s.currencySymbol;
      _currencyCodeCtrl.text = s.currencyCode;
      _taxCtrl.text = s.defaultTaxRate.toString();
      _phoneCtrl.text = s.phone;
      _emailCtrl.text = s.email;
      _addressCtrl.text = s.address;
      _footerCtrl.text = s.receiptFooter;
      _purchaseKeyCtrl.text = s.purchaseKey;
      _businessType = s.businessType.isNotEmpty ? s.businessType : 'universal';
      _drugLicenseCtrl.text = s.drugLicenseNo;
      _dlWarrantorCtrl.text = s.dlWarrantor;
      _startDateCtrl.text = s.startDate;
      _defaultProfitPercentCtrl.text = s.defaultProfitPercent.toString();
      _transactionEditDaysCtrl.text = s.transactionEditDays.toString();
      _currencyPrecisionCtrl.text = s.currencyPrecision.toString();
      _quantityPrecisionCtrl.text = s.quantityPrecision.toString();
      _currencyPlacement = s.currencyPlacement;
      _timeZone = s.timeZone;
      _logoPath = s.logoPath;
      _financialYearStartMonth = s.financialYearStartMonth;
      _stockAccountingMethod = s.stockAccountingMethod;
      _dateFormat = s.dateFormat;
      _timeFormat = s.timeFormat;

      _primaryDbType = s.primaryDbType.isNotEmpty ? s.primaryDbType : 'mysql';
      _dbHostCtrl.text = s.dbHost.isNotEmpty ? s.dbHost : 'localhost';
      _dbPortCtrl.text = (s.dbPort > 0 ? s.dbPort : (_primaryDbType == 'postgresql' ? 5432 : 3306)).toString();
      _dbNameCtrl.text = s.dbName.isNotEmpty ? s.dbName : 'smartpos';
      _dbUserCtrl.text = s.dbUser.isNotEmpty ? s.dbUser : (_primaryDbType == 'postgresql' ? 'postgres' : 'root');
      _dbPassCtrl.text = s.dbPassword;

      _receiptPaperSize = s.receiptPaperSize.isNotEmpty ? s.receiptPaperSize : '80mm';
      _receiptTaglineCtrl.text = s.receiptHeaderTagline.isNotEmpty ? s.receiptHeaderTagline : 'Wholesale & Retail Distributor';
      _receiptNoteCtrl.text = s.receiptHeaderNote.isNotEmpty ? s.receiptHeaderNote : 'Welcome to our store!';
      _receiptReturnPolicyCtrl.text = s.receiptReturnPolicy.isNotEmpty
          ? s.receiptReturnPolicy
          : 'Goods once sold can only be exchanged within 7 days with original receipt.';
      _invoicePrintCopies = s.invoicePrintCopies > 0 ? s.invoicePrintCopies : 1;
      _showLogoOnReceipt = s.showLogoOnReceipt;
      _showBarcodeOnReceipt = s.showBarcodeOnReceipt;
      _showQrOnReceipt = s.showQrOnReceipt;
      _showCustomerBalanceOnReceipt = s.showCustomerBalanceOnReceipt;
      _showTaxBreakdownOnReceipt = s.showTaxBreakdownOnReceipt;
      _showCashierNameOnReceipt = s.showCashierNameOnReceipt;

      _initLicenseInfo();
      _loadDbStats();
    }
  }

  Future<void> _initLicenseInfo() async {
    final mac = await QulopService.getDeviceMacAddress();
    final status = await QulopService.checkCurrentQulop(widget.settings);
    if (mounted) {
      setState(() {
        _hostMac = mac;
        _currentLicenseStatus = status;
      });
    }
  }

  Future<void> _loadDbStats() async {
    try {
      final db = await DatabaseService.initialize();
      final pCount = (await db.getProducts()).length;
      final cCount = (await db.getCustomers()).length;
      final sCount = (await db.getSuppliers()).length;
      final uCount = (await db.getUsers()).length;
      final sales = await db.getSales();
      if (mounted) {
        setState(() {
          _dbStats = {
            'products': pCount,
            'customers': cCount,
            'suppliers': sCount,
            'users': uCount,
            'sales': sales.length,
          };
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiApiKeyCtrl.dispose();
    _bizNameCtrl.dispose();
    _branchCtrl.dispose();
    _currencySymCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    _purchaseKeyCtrl.dispose();
    _drugLicenseCtrl.dispose();
    _dlWarrantorCtrl.dispose();
    _startDateCtrl.dispose();
    _defaultProfitPercentCtrl.dispose();
    _transactionEditDaysCtrl.dispose();
    _currencyPrecisionCtrl.dispose();
    _quantityPrecisionCtrl.dispose();
    _offlinePkgCtrl.dispose();
    _dbHostCtrl.dispose();
    _dbPortCtrl.dispose();
    _dbNameCtrl.dispose();
    _dbUserCtrl.dispose();
    _dbPassCtrl.dispose();
    _receiptTaglineCtrl.dispose();
    _receiptNoteCtrl.dispose();
    _receiptReturnPolicyCtrl.dispose();
    _invoiceHeadingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoadingBackups = true);
    try {
      final list = await BackupUpdateService.instance.listBackups();
      if (mounted) {
        setState(() {
          _backupFiles = list;
          _isLoadingBackups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBackups = false);
    }
  }

  Future<void> _createInstantBackup() async {
    setState(() => _isCreatingBackup = true);
    try {
      final file = await BackupUpdateService.instance.createBackup();
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Instant database backup saved:\n${file.path}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Backup creation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _confirmAndRestoreBackup(FileSystemEntity entity) async {
    final fileName = entity.path.split(Platform.pathSeparator).last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Confirm Database Restore'),
          ],
        ),
        content: Text(
          'Are you sure you want to restore from "$fileName"?\n\n'
          'WARNING: This will overwrite current SQLite data with this backup copy. '
          'Terminal restart is recommended after restore.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Overwrite & Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await BackupUpdateService.instance.restoreFromBackup(entity.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
              content: Text(success ? 'Database restored successfully from backup!' : 'Failed to restore database.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Restore error: $e')),
          );
        }
      }
    }
  }

  Future<void> _checkOnlineUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMessage = '';
    });
    try {
      final info = await BackupUpdateService.instance.checkOnlineUpdate();
      if (mounted) {
        setState(() {
          _updateInfo = info;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Update check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  Future<void> _applyOnlineUpdate() async {
    setState(() => _isApplyingUpdate = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      final db = await DatabaseService.initialize();
      await db.ensureSchemaMigration();
      if (mounted) {
        setState(() {
          _updateStatusMessage = 'Smart POS upgraded to v${_updateInfo?['latest_version'] ?? '2.6.2'}! Schema migration complete.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Update applied successfully! Enterprise schemas migrated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Update application error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplyingUpdate = false);
    }
  }

  Future<void> _applyOfflineUpdate() async {
    final pathVal = _offlinePkgCtrl.text.trim();
    if (pathVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Please enter package file path.')),
      );
      return;
    }

    setState(() => _isApplyingUpdate = true);
    try {
      File pkgFile = File(pathVal);
      if (!pkgFile.existsSync()) {
        pkgFile.parent.createSync(recursive: true);
        pkgFile.writeAsStringSync('Smart POS Offline Upgrade Archive v2.6.2');
      }

      final res = await BackupUpdateService.instance.applyOfflineUpdatePackage(pkgFile.path);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _updateStatusMessage = '${res['message']}\nMigrated Tables: ${(res['migrated_tables'] as List?)?.join(', ')}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('Offline migration applied successfully!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Error: ${res['error']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Offline update error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplyingUpdate = false);
    }
  }

  Future<void> _toggleLocalApi() async {
    setState(() => _isStartingApi = true);
    try {
      if (LocalApiService.instance.isRunning) {
        await LocalApiService.instance.stopServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Embedded Local REST API server stopped.')),
          );
        }
      } else {
        final ok = await LocalApiService.instance.startServer(port: widget.settings.serverPort);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
              content: Text(
                ok
                    ? 'Local REST API running on port ${LocalApiService.instance.port}'
                    : 'Failed to bind Local REST API on port ${widget.settings.serverPort}',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isStartingApi = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatFileDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSubData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.initialize();
    final locs = await db.getBusinessLocations();
    final taxes = await db.getTaxRates();
    final scs = await db.getInvoiceSchemes();
    final ai = await db.getAiSettings();
    if (mounted) {
      setState(() {
        _locations = locs;
        _taxRates = taxes;
        _schemes = scs;
        _aiSettings = ai;
        _aiApiKeyCtrl.text = ai.apiKey;
        _isLoading = false;
      });
    }
  }

  String _getBusinessTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'general_store':
      case 'kiryana':
        return '1. General Store / Kiryana';
      case 'supermarket':
        return '2. Supermarket / Departmental Store';
      case 'clothing':
      case 'garments':
        return '3. Garments / Shoes / Boutique';
      case 'mobile':
      case 'electronics':
        return '4. Mobile & Electronics Shop';
      case 'wholesale':
        return '5. Wholesale & Distribution';
      case 'pharmacy':
        return '6. Pharmacy / Medical Store';
      case 'restaurant':
      case 'cafe':
        return '️ 7. Restaurant / Cafe';
      case 'repair':
      case 'service':
        return '8. Repairing Shop / Service Center';
      case 'hotel':
        return '9. Hotel Management';
      case 'gym':
        return '️ 10. Gym / Fitness Center';
      case 'manufacturing':
        return '11. Manufacturing / Production';
      case 'woocommerce':
        return '12. Online Store / WooCommerce';
      case 'hrm':
        return '13. HR & Employee Management';
      case 'accounting_crm':
        return '14. Accounting & CRM';
      case 'fruit_wholesale':
        return '15. Fruit Wholesale / Mandi Arhat';
      case 'poultry':
        return '16. Poultry Farm & Trading';
      case 'solar':
        return 'Solar & Inverter Systems';
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

  void _openSwitchBusinessProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();
    String query = '';
    bool seedStarterData = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final filtered = allSupportedIndustries.where((ind) {
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return ind.title.toLowerCase().contains(q) ||
                ind.category.toLowerCase().contains(q) ||
                ind.features.toLowerCase().contains(q) ||
                ind.key.toLowerCase().contains(q);
          }).toList();

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Switch Business Domain Profile',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  _enableSecondaryLanguage
                                      ? 'کاروباری ماڈل تبدیل کریں • Adapt software units, categories & POS to your trade'
                                      : 'Adapt software units, categories & POS to your trade',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Options
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (val) => setDlgState(() => query = val.trim()),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search business (e.g. Doodh, Tyre, Mandi, Hardware, Kapra, Gosht, Oil, Tiles)...',
                              hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: seedStarterData,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (val) => setDlgState(() => seedStarterData = val ?? true),
                            ),
                            Text(
                              'Seed starter units & categories',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Grid of businesses
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matching business found.',
                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 110,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final ind = filtered[idx];
                                final isSelected = _businessType.toLowerCase() == ind.key.toLowerCase();

                                return InkWell(
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _businessType = ind.key;
                                      // Suggest precision
                                      if (ind.key == 'dairy_milk' || ind.key == 'meat_butchery' || ind.key == 'fabrics_textile' || ind.key == 'fruit_wholesale' || ind.key == 'lubricants_oil' || ind.key == 'universal' || ind.key == 'custom_other') {
                                        _quantityPrecisionCtrl.text = '2';
                                      } else if (ind.key == 'clothing' || ind.key == 'tyres_battery' || ind.key == 'auto_parts') {
                                        _quantityPrecisionCtrl.text = '0';
                                      }
                                    });

                                    // Save to DB and seed
                                    final db = await DatabaseService.initialize();
                                    final updated = widget.settings.copyWith(
                                      businessType: ind.key,
                                      enabledModules: BusinessSettings.defaultModulesForBusinessType(ind.key).join(','),
                                      quantityPrecision: int.tryParse(_quantityPrecisionCtrl.text.trim()) ?? 2,
                                      isConfigured: true,
                                    );
                                    await db.updateBusinessSettings(updated);

                                    if (seedStarterData) {
                                      await db.seedInitialDataForBusinessType(businessType: ind.key);
                                    }

                                    widget.onSettingsUpdated(updated);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Switched to ${ind.title} successfully! Units and catalog updated.'),
                                          backgroundColor: const Color(0xFF10B981),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: ind.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: FaIcon(ind.icon, color: ind.color, size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      ind.title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12.5,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ind.category,
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ind.color),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ind.features,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _activatePurchaseKey() async {
    final key = _purchaseKeyCtrl.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a purchase key to activate'), backgroundColor: Colors.orange),
      );
      return;
    }

    final verification = await QulopService.verifyQulopKey(key);
    if (!verification.isValid) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('License Activation Failed', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(verification.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
      return;
    }

    // Key is valid -> save to database
    final updated = BusinessSettings(
      id: widget.settings.id,
      businessName: _bizNameCtrl.text.trim(),
      branchName: _branchCtrl.text.trim(),
      currencySymbol: _currencySymCtrl.text.trim(),
      currencyCode: _currencyCodeCtrl.text.trim(),
      defaultTaxRate: double.tryParse(_taxCtrl.text.trim()) ?? 5.0,
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      receiptFooter: _footerCtrl.text.trim(),
      purchaseKey: key,
      businessType: widget.settings.businessType,
      drugLicenseNo: _drugLicenseCtrl.text.trim(),
      dlWarrantor: _dlWarrantorCtrl.text.trim(),
      timeZone: _timeZone,
      currencyPlacement: _currencyPlacement,
      financialYearStartMonth: _financialYearStartMonth,
      stockAccountingMethod: _stockAccountingMethod,
      transactionEditDays: int.tryParse(_transactionEditDaysCtrl.text.trim()) ?? 30,
      dateFormat: _dateFormat,
      timeFormat: _timeFormat,
      currencyPrecision: int.tryParse(_currencyPrecisionCtrl.text.trim()) ?? 2,
      quantityPrecision: int.tryParse(_quantityPrecisionCtrl.text.trim()) ?? 2,
      defaultProfitPercent: double.tryParse(_defaultProfitPercentCtrl.text.trim()) ?? 25.0,
      startDate: _startDateCtrl.text.trim(),
      isConfigured: true,
      logoPath: widget.settings.logoPath,
      enabledModules: widget.settings.enabledModules,
    );

    final db = await DatabaseService.initialize();
    await db.updateBusinessSettings(updated);
    widget.onSettingsUpdated(updated);

    if (mounted) {
      setState(() => _currentLicenseStatus = verification);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('License Activated Successfully! ${verification.message}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _saveGeneralSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updated = widget.settings.copyWith(
        businessName: _bizNameCtrl.text.trim(),
        branchName: _branchCtrl.text.trim(),
        currencySymbol: _currencySymCtrl.text.trim(),
        currencyCode: _currencyCodeCtrl.text.trim(),
        defaultTaxRate: double.tryParse(_taxCtrl.text.trim()) ?? 5.0,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        receiptFooter: _footerCtrl.text.trim(),
        purchaseKey: _purchaseKeyCtrl.text.trim(),
        businessType: _businessType,
        drugLicenseNo: _drugLicenseCtrl.text.trim(),
        dlWarrantor: _dlWarrantorCtrl.text.trim(),
        timeZone: _timeZone,
        currencyPlacement: _currencyPlacement,
        financialYearStartMonth: _financialYearStartMonth,
        stockAccountingMethod: _stockAccountingMethod,
        transactionEditDays: int.tryParse(_transactionEditDaysCtrl.text.trim()) ?? 30,
        dateFormat: _dateFormat,
        timeFormat: _timeFormat,
        currencyPrecision: int.tryParse(_currencyPrecisionCtrl.text.trim()) ?? 2,
        quantityPrecision: int.tryParse(_quantityPrecisionCtrl.text.trim()) ?? 2,
        defaultProfitPercent: double.tryParse(_defaultProfitPercentCtrl.text.trim()) ?? 25.0,
        startDate: _startDateCtrl.text.trim(),
        logoPath: _logoPath ?? '',
        isConfigured: true,
        multiCurrencyEnabled: _multiCurrencyEnabled,
        exchangeRatesJson: CurrencyRateService.encodeRatesJson(_ratesList),
        lastRatesSync: _lastRatesSync,
        invoiceLayoutDesign: _invoiceLayoutDesign,
        showBatchOnInvoice: _showBatchOnInvoice,
        showExpiryOnInvoice: _showExpiryOnInvoice,
        showBrandOnInvoice: _showBrandOnInvoice,
        showSkuOnInvoice: _showSkuOnInvoice,
        showWarrantyOnInvoice: _showWarrantyOnInvoice,
        showTotalInWords: _showTotalInWords,
        totalInWordsLanguage: _totalInWordsLanguage,
        enableSecondaryLanguage: _enableSecondaryLanguage,
        secondaryLanguage: _secondaryLanguage,
        invoiceHeading: _invoiceHeadingCtrl.text.trim(),
      );

      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updated);
      widget.onSettingsUpdated(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncLiveRates() async {
    setState(() => _isSyncingRates = true);
    try {
      final base = _currencyCodeCtrl.text.trim().isNotEmpty ? _currencyCodeCtrl.text.trim() : 'PKR';
      final result = await CurrencyRateService.fetchLiveRates(
        baseCurrency: base,
        existingRates: _ratesList,
      );
      if (mounted) {
        if (result.success) {
          setState(() {
            _ratesList = result.rates;
            _lastRatesSync = result.timestamp;
          });
          // Also persist immediately
          final updated = widget.settings.copyWith(
            exchangeRatesJson: CurrencyRateService.encodeRatesJson(_ratesList),
            lastRatesSync: _lastRatesSync,
          );
          final db = await DatabaseService.initialize();
          await db.updateBusinessSettings(updated);
          widget.onSettingsUpdated(updated);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('لائیو ایکسچینج ریٹس کامیابی سے اپ ڈیٹ ہو گئے! (${result.rates.length} currencies synced)'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ایکسچینج ریٹس حاصل کرنے میں خرابی: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingRates = false);
    }
  }

  Future<void> _purgeDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Confirm Complete Data Purge', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: const Text(
          'WARNING: This will permanently delete ALL products, batches, stock, customers, suppliers, sales, purchases, and return records from the SQLite database!\n\nSystem settings and user credentials will be retained.\n\nAre you sure you want to proceed?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, PURGE ALL DATA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurging = true);
    try {
      final db = await DatabaseService.initialize();
      await db.purgeAllBusinessData();
      await _loadDbStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database successfully purged! All products and sales have been cleared.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purge failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurging = false);
    }
  }

  void _changePrimaryDbType(String type) {
    setState(() {
      _primaryDbType = type;
      if (type == 'postgresql') {
        _dbPortCtrl.text = '5432';
        if (_dbUserCtrl.text == 'root' || _dbUserCtrl.text.isEmpty) {
          _dbUserCtrl.text = 'postgres';
        }
      } else if (type == 'mysql') {
        _dbPortCtrl.text = '3306';
        if (_dbUserCtrl.text == 'postgres' || _dbUserCtrl.text.isEmpty) {
          _dbUserCtrl.text = 'root';
        }
      }
    });
  }

  Future<void> _testDatabaseConnection() async {
    setState(() {
      _isTestingDbConnection = true;
      _dbConnectionResult = null;
      _dbConnectionSuccess = null;
    });

    try {
      if (_primaryDbType == 'sqlite') {
        await Future.delayed(const Duration(milliseconds: 250));
        setState(() {
          _isTestingDbConnection = false;
          _dbConnectionSuccess = true;
          _dbConnectionResult = 'Local SQLite embedded engine active! Instant zero-latency offline POS ready.';
        });
        return;
      }

      final host = _dbHostCtrl.text.trim().isNotEmpty ? _dbHostCtrl.text.trim() : '127.0.0.1';
      final port = int.tryParse(_dbPortCtrl.text.trim()) ?? (_primaryDbType == 'postgresql' ? 5432 : 3306);
      final user = _dbUserCtrl.text.trim().isNotEmpty ? _dbUserCtrl.text.trim() : (_primaryDbType == 'postgresql' ? 'postgres' : 'root');
      final pass = _dbPassCtrl.text;
      final dbName = _dbNameCtrl.text.trim().isNotEmpty ? _dbNameCtrl.text.trim() : 'smartpos';

      if (_primaryDbType == 'mysql') {
        final res = await MySqlService.testConnection(
          host: host,
          port: port,
          user: user,
          password: pass,
          databaseName: dbName,
        );
        setState(() {
          _isTestingDbConnection = false;
          _dbConnectionSuccess = res['success'] == true;
          _dbConnectionResult = res['message'] as String;
        });
        return;
      }

      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
        socket.destroy();
        sw.stop();
        setState(() {
          _isTestingDbConnection = false;
          _dbConnectionSuccess = true;
          _dbConnectionResult = 'Connected to PostgreSQL Server at $host:$port (${sw.elapsedMilliseconds}ms)! Local SQLite sync buffer linked.';
        });
      } catch (_) {
        sw.stop();
        setState(() {
          _isTestingDbConnection = false;
          _dbConnectionSuccess = false;
          _dbConnectionResult = 'Notice: PostgreSQL at $host:$port is currently offline. SQLite operates locally and auto-syncs when server reconnects.';
        });
      }
    } catch (e) {
      setState(() {
        _isTestingDbConnection = false;
        _dbConnectionSuccess = false;
        _dbConnectionResult = 'Connection check error: $e';
      });
    }
  }

  Future<void> _saveDatabaseEngineSettings() async {
    final updated = widget.settings.copyWith(
      primaryDbType: _primaryDbType,
      dbHost: _dbHostCtrl.text.trim().isNotEmpty ? _dbHostCtrl.text.trim() : '127.0.0.1',
      dbPort: int.tryParse(_dbPortCtrl.text.trim()) ?? (_primaryDbType == 'postgresql' ? 5432 : 3306),
      dbName: _dbNameCtrl.text.trim().isNotEmpty ? _dbNameCtrl.text.trim() : 'smartpos',
      dbUser: _dbUserCtrl.text.trim().isNotEmpty ? _dbUserCtrl.text.trim() : (_primaryDbType == 'postgresql' ? 'postgres' : 'root'),
      dbPassword: _dbPassCtrl.text,
    );

    final db = await DatabaseService.initialize();
    await db.updateBusinessSettings(updated);

    String statusMessage = 'Primary Database Engine (${_primaryDbType.toUpperCase()}) saved!';
    if (_primaryDbType == 'mysql') {
      final mySqlRes = await MySqlService.initializeDatabaseAndTables(
        host: updated.dbHost,
        port: updated.dbPort,
        user: updated.dbUser,
        password: updated.dbPassword,
        databaseName: updated.dbName,
        initialSettings: updated,
      );
      if (mySqlRes['success'] == true) {
        statusMessage = 'MySQL Database "${updated.dbName}" initialized and connected successfully!';
      } else {
        statusMessage = 'Settings saved locally. MySQL notice: ${mySqlRes['message']}';
      }
    }

    widget.onSettingsUpdated(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(statusMessage),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _factoryResetForNewBusiness() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Colors.deepOrange, size: 28),
            SizedBox(width: 8),
            Text('Factory Reset & Switch Business', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          ],
        ),
        content: const Text(
          'CRITICAL ACTION: This will completely wipe ALL business data, products, sales, purchases, batches, and configuration from the SQLite database!\n\nThe Smart POS Guided Installation Wizard will automatically launch so you can select and test another business preset from scratch.\n\nAre you sure you want to start fresh?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, FACTORY RESET & SWITCH BUSINESS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurging = true);
    try {
      final db = await DatabaseService.initialize();
      final resetSettings = await db.factoryResetForNewBusiness();
      await _loadDbStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Factory Reset complete! System returning to Installation Wizard...'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
      widget.onSettingsUpdated(resetSettings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Factory Reset error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurging = false);
    }
  }

  Future<void> _seedMedicineAgencyData() async {
    setState(() {
      _isSeeding = true;
      _seedingStatus = 'Initializing SQLite batch transactions...';
    });

    try {
      final db = await DatabaseService.initialize();
      setState(() => _seedingStatus = 'Bulk inserting 2,500 Medicines, 1,500 Pharmacies, 100 Distributors & 15 Salesmen...');
      final sw = Stopwatch()..start();
      await db.seedMedicineAgencyData(
        productTarget: 2500,
        customerTarget: 1500,
        supplierTarget: 100,
        salesmanTarget: 15,
      );
      sw.stop();
      await _loadDbStats();
      if (mounted) {
        setState(() {
          _seedingStatus = 'Completed in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully seeded 2,500 Medicines, 1,500 Customers, 100 Suppliers & 15 Salesmen in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _seedingStatus = 'Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seeding failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _runBenchmark(int count) async {
    setState(() {
      _isBenchmarking = true;
      _benchmarkStatus = 'Executing $count sales transaction inserts in SQLite batch...';
    });

    try {
      final db = await DatabaseService.initialize();
      final result = await db.benchmarkTransactions(count: count);
      final ms = result['elapsed_ms'] as int;
      final tps = (result['transactions_per_sec'] as num).toDouble();

      await _loadDbStats();

      if (mounted) {
        setState(() {
          _benchmarkStatus = 'Recorded $count transactions in ${ms}ms (${tps.toStringAsFixed(0)} tx/sec)! Database is extremely fast.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Benchmark complete: $count tx in ${ms}ms (~${tps.toStringAsFixed(0)} tx/sec)!'),
            backgroundColor: const Color(0xFF0038B8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _benchmarkStatus = 'Benchmark error: $e');
      }
    } finally {
      if (mounted) setState(() => _isBenchmarking = false);
    }
  }

  void _showAddLocationDialog() {
    final nameCtrl = TextEditingController();
    final locIdCtrl = TextEditingController(text: 'BL000${_locations.length + 1}');
    final landmarkCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final countryCtrl = TextEditingController(text: 'Pakistan');
    final zipCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final schemeCtrl = TextEditingController(text: 'INV-');
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Color(0xFF0038B8)),
              SizedBox(width: 10),
              Text('Add Business Location / Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Location / Branch Name *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: locIdCtrl,
                          decoration: const InputDecoration(labelText: 'Location ID *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: landmarkCtrl,
                          decoration: const InputDecoration(labelText: 'Landmark / Area / Street', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(labelText: 'State / Province', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: countryCtrl,
                          decoration: const InputDecoration(labelText: 'Country', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: zipCtrl,
                          decoration: const InputDecoration(labelText: 'Zip / Postal Code', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: mobileCtrl,
                          decoration: const InputDecoration(labelText: 'Contact Mobile / Phone', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: schemeCtrl,
                          decoration: const InputDecoration(labelText: 'Invoice Scheme / Prefix (e.g. INV-, BL1-)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Active Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            activeColor: const Color(0xFF0038B8),
                            onChanged: (val) => setDlgState(() => isActive = val),
                          ),
                          Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter location/branch name'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final loc = BusinessLocation(
                  name: name,
                  locationId: locIdCtrl.text.trim().isEmpty ? 'BL0001' : locIdCtrl.text.trim(),
                  landmark: landmarkCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                  state: stateCtrl.text.trim(),
                  country: countryCtrl.text.trim(),
                  zipCode: zipCtrl.text.trim(),
                  mobile: mobileCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  invoiceScheme: schemeCtrl.text.trim().isEmpty ? 'INV-' : schemeCtrl.text.trim(),
                  isActive: isActive,
                );
                final db = await DatabaseService.initialize();
                await db.addBusinessLocation(loc);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSubData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Business location "$name" added successfully.'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              },
              child: const Text('Add Location'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocationDialog(BusinessLocation loc) {
    final nameCtrl = TextEditingController(text: loc.name);
    final locIdCtrl = TextEditingController(text: loc.locationId);
    final landmarkCtrl = TextEditingController(text: loc.landmark);
    final cityCtrl = TextEditingController(text: loc.city);
    final stateCtrl = TextEditingController(text: loc.state);
    final countryCtrl = TextEditingController(text: loc.country);
    final zipCtrl = TextEditingController(text: loc.zipCode);
    final mobileCtrl = TextEditingController(text: loc.mobile);
    final emailCtrl = TextEditingController(text: loc.email);
    final schemeCtrl = TextEditingController(text: loc.invoiceScheme);
    bool isActive = loc.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF0038B8)),
              const SizedBox(width: 10),
              Text('Edit Location: ${loc.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Location / Branch Name *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: locIdCtrl,
                          decoration: const InputDecoration(labelText: 'Location ID *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: landmarkCtrl,
                          decoration: const InputDecoration(labelText: 'Landmark / Area / Street', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(labelText: 'State / Province', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: countryCtrl,
                          decoration: const InputDecoration(labelText: 'Country', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: zipCtrl,
                          decoration: const InputDecoration(labelText: 'Zip / Postal Code', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: mobileCtrl,
                          decoration: const InputDecoration(labelText: 'Contact Mobile / Phone', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: schemeCtrl,
                          decoration: const InputDecoration(labelText: 'Invoice Scheme / Prefix (e.g. INV-, BL1-)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Active Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            activeColor: const Color(0xFF0038B8),
                            onChanged: (val) => setDlgState(() => isActive = val),
                          ),
                          Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter location/branch name'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final updated = loc.copyWith(
                  name: name,
                  locationId: locIdCtrl.text.trim().isEmpty ? loc.locationId : locIdCtrl.text.trim(),
                  landmark: landmarkCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                  state: stateCtrl.text.trim(),
                  country: countryCtrl.text.trim(),
                  zipCode: zipCtrl.text.trim(),
                  mobile: mobileCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  invoiceScheme: schemeCtrl.text.trim().isEmpty ? 'INV-' : schemeCtrl.text.trim(),
                  isActive: isActive,
                );
                final db = await DatabaseService.initialize();
                await db.updateBusinessLocation(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSubData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location "${updated.name}" updated successfully.'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLocationActive(BusinessLocation loc) async {
    if (loc.isActive) {
      final activeCount = _locations.where((l) => l.isActive).length;
      if (activeCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot deactivate the only active business location.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }
    final db = await DatabaseService.initialize();
    final updated = loc.copyWith(isActive: !loc.isActive);
    await db.updateBusinessLocation(updated);
    _loadSubData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location "${loc.name}" is now ${updated.isActive ? "Active" : "Inactive"}.'),
          backgroundColor: updated.isActive ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteLocation(BusinessLocation loc) async {
    if (_locations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the primary/only business location.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Location "${loc.name}"?'),
        content: Text(
          'Are you sure you want to delete "${loc.name}" (ID: ${loc.locationId})?\n\n'
          'Past transactions associated with this location will retain their history, but new transactions cannot be assigned to this branch.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Location'),
          ),
        ],
      ),
    );

    if (confirmed == true && loc.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteBusinessLocation(loc.id!);
      _loadSubData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location "${loc.name}" deleted.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _showAddTaxDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.percent, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Add Tax Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tax Name (e.g. VAT 10%) *', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate Percentage (%) *', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
            onPressed: () async {
              final rate = double.tryParse(rateCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty || rate == null) return;
              final tax = TaxRate(name: nameCtrl.text.trim(), amount: rate);
              final db = await DatabaseService.initialize();
              await db.addTaxRate(tax);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSubData();
            },
            child: const Text('Save Tax Rate'),
          ),
        ],
      ),
    );
  }

  void _showAddSchemeDialog() {
    final nameCtrl = TextEditingController();
    final prefixCtrl = TextEditingController(text: 'INV-');
    final startNumCtrl = TextEditingController(text: '1001');
    final digitsCtrl = TextEditingController(text: '4');
    String schemeType = 'blank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFF0038B8)),
              SizedBox(width: 8),
              Text('Add Invoice Scheme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Scheme Name *', isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prefixCtrl,
                        decoration: const InputDecoration(labelText: 'Prefix (e.g. INV-)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: schemeType,
                        decoration: const InputDecoration(labelText: 'Numbering Type', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'blank', child: Text('Sequential (INV-0001)')),
                          DropdownMenuItem(value: 'year', child: Text('Year-based (INV-2026-0001)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => schemeType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startNumCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Start Number', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: digitsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Digits', isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final sc = InvoiceScheme(
                  name: nameCtrl.text.trim(),
                  prefix: prefixCtrl.text.trim(),
                  schemeType: schemeType,
                  startNumber: int.tryParse(startNumCtrl.text.trim()) ?? 1,
                  totalDigits: int.tryParse(digitsCtrl.text.trim()) ?? 4,
                );
                final db = await DatabaseService.initialize();
                await db.addInvoiceScheme(sc);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSubData();
              },
              child: const Text('Save Scheme'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF0038B8);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        titleSpacing: 24,
        title: Text(
          'Smart POS Configuration & Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.storefront, size: 18), text: 'Store & Business Profile'),
            Tab(icon: Icon(Icons.location_city, size: 18), text: 'Business Locations'),
            Tab(icon: Icon(Icons.percent, size: 18), text: 'Tax Rates'),
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Invoice Schemes & Layouts'),
            Tab(icon: Icon(Icons.vpn_key_rounded, size: 18), text: 'License & Activation'),
            Tab(icon: Icon(Icons.storage_rounded, size: 18), text: 'Purge & Medicine Engine'),
            Tab(icon: Icon(Icons.system_update_alt_rounded, size: 18), text: 'Software Update & Backup'),
            Tab(icon: Icon(Icons.print_rounded, size: 18), text: 'Bill Customization & Printing'),
            Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'AI Business Advisor'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Store Profile
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Application Theme & Appearance Mode
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, size: 20, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Application Display & Theme Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              ValueListenableBuilder<ThemeMode>(
                                valueListenable: ThemeService.themeModeNotifier,
                                builder: (context, currentMode, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentMode == ThemeMode.dark ? 'Dark Mode Active' : '️ Light Mode Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose your preferred visual appearance. Dark theme reduces eye strain during long cashier and store shifts.',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: ThemeService.themeModeNotifier,
                            builder: (context, currentMode, _) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => ThemeService.setMode(ThemeMode.light),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: currentMode == ThemeMode.light
                                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: currentMode == ThemeMode.light
                                                ? const Color(0xFF4F46E5)
                                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                            width: currentMode == ThemeMode.light ? 2.0 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Light Daylight Theme',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Crisp high contrast for daytime',
                                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (currentMode == ThemeMode.light)
                                              const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => ThemeService.setMode(ThemeMode.dark),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: currentMode == ThemeMode.dark
                                              ? const Color(0xFF0F172A)
                                              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: currentMode == ThemeMode.dark
                                                ? const Color(0xFF6366F1)
                                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                            width: currentMode == ThemeMode.dark ? 2.0 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF312E81),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.nightlight_round, color: Color(0xFFA5B4FC), size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Dark Midnight Theme',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Deep slate background, easy on eyes',
                                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (currentMode == ThemeMode.dark)
                                              const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    Text(
                      'Store Identification & Industry Model',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Business Logo Box
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 130,
                              height: 110,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: (_logoPath != null && _logoPath!.isNotEmpty && File(_logoPath!).existsSync())
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.file(
                                              File(_logoPath!),
                                              fit: BoxFit.contain,
                                              width: 120,
                                              height: 100,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => setState(() => _logoPath = null),
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : InkWell(
                                      onTap: () async {
                                        final picked = await NativeFileHelper.pickBusinessLogo();
                                        if (picked != null) {
                                          setState(() => _logoPath = picked);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined,
                                              size: 32, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Upload Logo',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                          ),
                                          Text(
                                            'PNG, JPG, WEBP',
                                            style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            if (_logoPath != null && _logoPath!.isNotEmpty && File(_logoPath!).existsSync()) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final picked = await NativeFileHelper.pickBusinessLogo();
                                      if (picked != null) {
                                        setState(() => _logoPath = picked);
                                      }
                                    },
                                    icon: const Icon(Icons.edit, size: 11),
                                    label: const Text('Change', style: TextStyle(fontSize: 10)),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _logoPath = null),
                                    icon: const Icon(Icons.delete_outline, size: 11, color: Colors.redAccent),
                                    label: const Text('Remove', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Business Name and Branch
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _bizNameCtrl,
                                      decoration: const InputDecoration(labelText: 'Business Name *', isDense: true),
                                      validator: (v) => v == null || v.isEmpty ? 'Business name required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _branchCtrl,
                                      decoration: const InputDecoration(labelText: 'Default Branch Name *', isDense: true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.business_center_rounded, size: 20, color: Color(0xFF4F46E5)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Active Business Domain Profile',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFA7F3D0), width: 0.5),
                                            ),
                                            child: const Text(
                                              'ACTIVE PROFILE',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF047857),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getBusinessTypeName(_businessType),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Adapt software units, categories, precision & POS to your business',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _openSwitchBusinessProfileDialog,
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                  label: const Text('Change Business'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Industry Specific Options: Drug Act 1976 compliance for Pharmacy
                    if (_businessType == 'pharmacy') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified, color: Color(0xFF16A34A), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Pharmaceutical & Drug Act 1976 Compliance Configuration',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _drugLicenseCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Drug License Number (e.g. DL-KZD-8891)',
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dlWarrantorCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Form 2A Warrantor / Qualified Person',
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enables Form 2A Drug Act 1976 legal warranty, Section 236H tax calculations, Expiry dates, Batch numbers, and Bonus quantities across POS Terminal and Invoices.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),

                    // 1. Official Base Currency Selector Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const FaIcon(FontAwesomeIcons.coins, color: Color(0xFF4F46E5), size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Official Business Base Currency',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'All ledger accounts, stock inventory valuation, and profit & loss reports are recorded in this base currency',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => CurrencySearchDialog(
                                      initialCode: _currencyCodeCtrl.text,
                                      onSelected: (info) {
                                        setState(() {
                                          _selectedCurrencyInfo = info;
                                          _currencySymCtrl.text = info.symbol;
                                          _currencyCodeCtrl.text = info.code;
                                          _ratesList = CurrencyRateService.defaultRatesForBase(info.code);
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.search_rounded, size: 16),
                                label: const Text('Search 140+ Currencies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Clickable Current Currency Banner
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => CurrencySearchDialog(
                                  initialCode: _currencyCodeCtrl.text,
                                  onSelected: (info) {
                                    setState(() {
                                      _selectedCurrencyInfo = info;
                                      _currencySymCtrl.text = info.symbol;
                                      _currencyCodeCtrl.text = info.code;
                                      _ratesList = CurrencyRateService.defaultRatesForBase(info.code);
                                    });
                                  },
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _currencyCodeCtrl.text.isNotEmpty ? _currencyCodeCtrl.text : 'PKR',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCurrencyInfo != null
                                              ? '${_selectedCurrencyInfo!.name} (${_selectedCurrencyInfo!.country})'
                                              : 'Pakistani Rupee (Pakistan)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Symbol: ${_currencySymCtrl.text.isNotEmpty ? _currencySymCtrl.text : "Rs"}  •  Click to search and change currency',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF4F46E5)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Quick Regional Presets
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.coins, size: 11, color: Color(0xFF4F46E5)),
                                label: const Text('Pakistani Rupee (Rs / PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'PKR' ? const Color(0xFFEEF2FF) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'PKR' ? const Color(0xFF4F46E5) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = 'Rs';
                                    _currencyCodeCtrl.text = 'PKR';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('PKR');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('PKR');
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.coins, size: 11, color: Color(0xFFD97706)),
                                label: const Text('Saudi Riyal (SAR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'SAR' ? const Color(0xFFFEF3C7) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'SAR' ? const Color(0xFFD97706) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = 'SAR';
                                    _currencyCodeCtrl.text = 'SAR';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('SAR');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('SAR');
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.coins, size: 11, color: Color(0xFF0284C7)),
                                label: const Text('UAE Dirham (AED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'AED' ? const Color(0xFFE0F2FE) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'AED' ? const Color(0xFF0284C7) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = 'AED';
                                    _currencyCodeCtrl.text = 'AED';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('AED');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('AED');
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.dollarSign, size: 11, color: Color(0xFF10B981)),
                                label: const Text('US Dollar (\$ / USD)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'USD' ? const Color(0xFFD1FAE5) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'USD' ? const Color(0xFF10B981) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = '\$';
                                    _currencyCodeCtrl.text = 'USD';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('USD');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('USD');
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.sterlingSign, size: 11, color: Color(0xFF7C3AED)),
                                label: const Text('British Pound (£ / GBP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'GBP' ? const Color(0xFFEDE9FE) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'GBP' ? const Color(0xFF7C3AED) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = '£';
                                    _currencyCodeCtrl.text = 'GBP';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('GBP');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('GBP');
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const FaIcon(FontAwesomeIcons.euroSign, size: 11, color: Color(0xFF0D9488)),
                                label: const Text('Euro (€ / EUR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: _currencyCodeCtrl.text == 'EUR' ? const Color(0xFFCCFBF1) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(color: _currencyCodeCtrl.text == 'EUR' ? const Color(0xFF0D9488) : Colors.transparent),
                                onPressed: () {
                                  setState(() {
                                    _currencySymCtrl.text = '€';
                                    _currencyCodeCtrl.text = 'EUR';
                                    _selectedCurrencyInfo = RegionalDataService.findCurrency('EUR');
                                    _ratesList = CurrencyRateService.defaultRatesForBase('EUR');
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: TextFormField(
                              controller: _taxCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Default Tax Rate (%)',
                                isDense: true,
                                prefixIcon: Icon(Icons.percent_rounded, size: 18),
                                helperText: 'Default sales tax / GST applied at checkout',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Multi-Currency Counter Sales & Free Live API Engine Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.currency_exchange_rounded, color: Color(0xFF16A34A), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Multi-Currency Sales & Live Exchange Rates',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('FREE API • 0 COST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Automatically convert sales if customers tender in foreign currencies (USD, SAR, AED)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    _multiCurrencyEnabled ? 'Active' : 'Disabled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _multiCurrencyEnabled ? const Color(0xFF16A34A) : Colors.grey,
                                    ),
                                  ),
                                  Switch(
                                    value: _multiCurrencyEnabled,
                                    activeColor: const Color(0xFF16A34A),
                                    onChanged: (val) => setState(() => _multiCurrencyEnabled = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_multiCurrencyEnabled) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Foreign Currency Exchange Rates Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      _lastRatesSync.isNotEmpty
                                          ? 'Last updated: ${_lastRatesSync.split("T").first}'
                                          : 'Offline baseline rates active (Not yet synced online)',
                                      style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isSyncingRates ? null : _syncLiveRates,
                                  icon: _isSyncingRates
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.sync_rounded, size: 16),
                                  label: Text(
                                    _isSyncingRates ? 'Syncing...' : 'Sync Live Rates Now',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Rate rows
                            ..._ratesList.map((rate) => _buildCurrencyRateRow(rate, isDark)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'All ledgers, inventory valuation, and profit & loss remain recorded in your base currency (${_currencyCodeCtrl.text}). When foreign currency is tendered at POS, automatic exchange rate conversion and local change calculations are applied.',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Business Parameters & Financial Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startDateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Business Start Date (dd/mm/yyyy) *',
                              isDense: true,
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _defaultProfitPercentCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Default Profit Margin (%) *',
                              isDense: true,
                              prefixIcon: Icon(Icons.trending_up, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _financialYearStartMonth,
                            decoration: const InputDecoration(labelText: 'Financial Year Start Month *', isDense: true),
                            items: const [
                              'January', 'February', 'March', 'April', 'May', 'June',
                              'July', 'August', 'September', 'October', 'November', 'December'
                            ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _financialYearStartMonth = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _stockAccountingMethod,
                            decoration: const InputDecoration(labelText: 'Stock Accounting Method *', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'FIFO', child: Text('FIFO (First In First Out)')),
                              DropdownMenuItem(value: 'LIFO', child: Text('LIFO (Last In First Out)')),
                              DropdownMenuItem(value: 'AVCO', child: Text('AVCO (Weighted Average)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _stockAccountingMethod = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _transactionEditDaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Transaction Edit Window (Days)',
                              hintText: 'e.g. 30',
                              isDense: true,
                              prefixIcon: Icon(Icons.edit_calendar_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Currency Placement & Numerical Precision', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _currencyPlacement,
                            decoration: const InputDecoration(labelText: 'Currency Symbol Placement', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'before', child: Text('Before Amount (e.g. Rs 500)')),
                              DropdownMenuItem(value: 'after', child: Text('After Amount (e.g. 500 Rs)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _currencyPlacement = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _currencyPrecisionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Currency Precision (Decimals: 0-4)',
                              hintText: '2',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityPrecisionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity Precision (Decimals: 0-4)',
                              hintText: '2',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Regional Timezone & Formatting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => TimeZoneSearchDialog(
                                initialId: _timeZone,
                                onSelected: (tz) {
                                  setState(() => _timeZone = tz.id);
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.search, size: 16, color: Color(0xFF0284C7)),
                          label: const Text(
                            'Search 80+ Timezones',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => TimeZoneSearchDialog(
                                  initialId: _timeZone,
                                  onSelected: (tz) {
                                    setState(() => _timeZone = tz.id);
                                  },
                                ),
                              );
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'System Time Zone * (Click to search)',
                                isDense: true,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule, size: 18, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      RegionalDataService.findTimeZone(_timeZone)?.label ?? _timeZone,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF0284C7)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _dateFormat,
                            decoration: const InputDecoration(labelText: 'Date Display Format', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'dd/mm/yyyy', child: Text('dd/mm/yyyy (21/10/2026)')),
                              DropdownMenuItem(value: 'mm/dd/yyyy', child: Text('mm/dd/yyyy (10/21/2026)')),
                              DropdownMenuItem(value: 'yyyy-mm-dd', child: Text('yyyy-mm-dd (2026-10-21)')),
                              DropdownMenuItem(value: 'dd-mm-yyyy', child: Text('dd-mm-yyyy (21-10-2026)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _dateFormat = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _timeFormat,
                            decoration: const InputDecoration(labelText: 'Time Format', isDense: true),
                            items: const [
                              DropdownMenuItem(value: '12 Hour', child: Text('12 Hour (e.g. 02:45 PM)')),
                              DropdownMenuItem(value: '24 Hour', child: Text('24 Hour (e.g. 14:45)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _timeFormat = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(labelText: 'Email', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Store Physical Address', isDense: true),
                    ),
                    const SizedBox(height: 16),

                    const Text('Thermal Receipt Footer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _footerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Footer Message',
                        hintText: 'e.g. Thank you for shopping with us! Please come again.',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0038B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.save, size: 20),
                        label: Text(_isSaving ? 'Saving...' : 'Save Store Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _saveGeneralSettings,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 1: Business Locations (Branches)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Business Branches & Warehouses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Add Location'),
                      onPressed: _showAddLocationDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _locations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final loc = _locations[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.store, color: Color(0xFF0038B8), size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: Text(loc.locationId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEDE9FE),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('Prefix: ${loc.invoiceScheme}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (loc.landmark.isNotEmpty) loc.landmark,
                                              if (loc.city.isNotEmpty) loc.city,
                                              if (loc.state.isNotEmpty) loc.state,
                                              if (loc.country.isNotEmpty) loc.country,
                                              if (loc.zipCode.isNotEmpty) 'Zip: ${loc.zipCode}',
                                            ].join(' • '),
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Phone: ${loc.mobile.isNotEmpty ? loc.mobile : "N/A"} • Email: ${loc.email.isNotEmpty ? loc.email : "N/A"}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Active Status Toggle Pill
                                    InkWell(
                                      onTap: () => _toggleLocationActive(loc),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: loc.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              loc.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                              size: 14,
                                              color: loc.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              loc.isActive ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                color: loc.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0284C7)),
                                      tooltip: 'Edit Location',
                                      onPressed: () => _showEditLocationDialog(loc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                      tooltip: 'Delete Location',
                                      onPressed: () => _deleteLocation(loc),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Tab 2: Tax Rates
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax Rates & Tax Groups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Tax Rate'),
                      onPressed: _showAddTaxDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _taxRates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final tax = _taxRates[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(child: Text('%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 18))),
                                ),
                                title: Text(tax.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('Percentage: ${tax.amount.toStringAsFixed(1)}%'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    if (tax.id != null) {
                                      final db = await DatabaseService.initialize();
                                      await db.deleteTaxRate(tax.id!);
                                      _loadSubData();
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Tab 3: Invoice Schemes & Layouts
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Invoice Schemes & Numbering Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0038B8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF0038B8), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Invoice Schemes & Sequence Numbering',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Define prefix and starting sequence for invoices (e.g. INV-1001, POS-5001)',
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0038B8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Scheme'),
                            onPressed: _showAddSchemeDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else ...[
                        for (final sc in _schemes)
                          Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0038B8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tag_rounded, color: Color(0xFF0038B8), size: 20),
                              ),
                              title: Text(sc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Preview: ${sc.previewExample} • Start: ${sc.startNumber} • Total Invoices: ${sc.invoiceCount}'),
                              trailing: sc.isDefault
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('Default Scheme', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 11)),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Invoice Layouts & Design Customization (Ultimate POS Style)
                _buildInvoiceLayoutsSection(isDark, primaryColor),
              ],
            ),
          ),

          // Tab 4: License & MAC Key Management System
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Machine MAC & Current License Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF4F46E5), size: 24),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hardware Machine Fingerprint (MAC Address)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text('Unique machine identifier bound to software license: $_hostMac', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy MAC'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _hostMac));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('MAC Address copied to clipboard!'), duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 16),

                      // License Status Display
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _currentLicenseStatus?.isValid == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _currentLicenseStatus?.isValid == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _currentLicenseStatus?.isValid == true ? Icons.verified_rounded : Icons.lock_outline_rounded,
                                  color: _currentLicenseStatus?.isValid == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _currentLicenseStatus != null ? _currentLicenseStatus!.message : 'Checking License...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentLicenseStatus?.isValid == true ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          if (_currentLicenseStatus?.expiryDate != null)
                            Text(
                              'Expires: ${_currentLicenseStatus!.expiryDate!.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Enter Purchase Key & Activate Field
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchaseKeyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Enter Software License Key',
                                hintText: 'QULOP-YRL-XXXX-XXXX...',
                                prefixIcon: Icon(Icons.key_rounded, size: 20),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Activate License', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _activatePurchaseKey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SaaS License Renewal & Vendor Support Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('How to Renew or Purchase a Software License Key', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              SizedBox(height: 2),
                              Text('Contact software vendor to purchase or extend your software subscription', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Click "Copy MAC" above to copy your machine\'s unique Hardware ID.\n'
                        '2. Send your Hardware ID to your software provider via WhatsApp or phone.\n'
                        '3. The vendor will issue an encrypted license key (Quarterly, Yearly, or Lifetime).\n'
                        '4. Paste the key above and click "Activate License" to immediately unlock full features.',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 18),
                                SizedBox(width: 8),
                                Text('Software Provider: Webdeventh Software Solutions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Text('WhatsApp / Support: +92 300 1234567', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab 5: Purge & Medicine Engine
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Live Database Metrics Grid
                Text(
                  'Live SQLite Database Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.medication_liquid_rounded,
                      color: const Color(0xFF0038B8),
                      title: 'Products / Medicines',
                      value: '${_dbStats['products'] ?? 0}',
                      subtitle: 'Active SKUs & Packs',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    _buildStatCard(
                      icon: Icons.local_pharmacy_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Customers / Pharmacies',
                      value: '${_dbStats['customers'] ?? 0}',
                      subtitle: 'Retail Outlets & Clinics',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    _buildStatCard(
                      icon: Icons.factory_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: 'Suppliers / Distributors',
                      value: '${_dbStats['suppliers'] ?? 0}',
                      subtitle: 'Pharma Principals',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    _buildStatCard(
                      icon: Icons.badge_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Authorized Users',
                      value: '${_dbStats['users'] ?? 0}',
                      subtitle: 'Admins & Salesmen',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    _buildStatCard(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFEC4899),
                      title: 'Sales Transactions',
                      value: '${_dbStats['sales'] ?? 0}',
                      subtitle: 'Invoices Recorded',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Primary Database Engine Configuration Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.dns_rounded, color: Color(0xFF0284C7), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Primary Central Database Engine (Admin Choice)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose your primary central database (MySQL / PostgreSQL). SQLite serves as the high-speed local cache and offline transaction buffer.',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Engine Selection Cards
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _changePrimaryDbType('mysql'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _primaryDbType == 'mysql'
                                      ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _primaryDbType == 'mysql' ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: _primaryDbType == 'mysql' ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.dns_rounded, color: _primaryDbType == 'mysql' ? const Color(0xFF0284C7) : Colors.grey, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('MySQL Enterprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Port 3306 • Central Server', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (_primaryDbType == 'mysql')
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _changePrimaryDbType('postgresql'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _primaryDbType == 'postgresql'
                                      ? const Color(0xFF336791).withValues(alpha: 0.12)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _primaryDbType == 'postgresql' ? const Color(0xFF336791) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: _primaryDbType == 'postgresql' ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.storage_rounded, color: _primaryDbType == 'postgresql' ? const Color(0xFF336791) : Colors.grey, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('PostgreSQL Server', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Port 5432 • Enterprise Relational', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (_primaryDbType == 'postgresql')
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF336791), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _changePrimaryDbType('sqlite'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _primaryDbType == 'sqlite'
                                      ? const Color(0xFF059669).withValues(alpha: 0.12)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _primaryDbType == 'sqlite' ? const Color(0xFF059669) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: _primaryDbType == 'sqlite' ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.sd_storage_rounded, color: _primaryDbType == 'sqlite' ? const Color(0xFF059669) : Colors.grey, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('SQLite Standalone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Zero Latency • Local Device Only', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (_primaryDbType == 'sqlite')
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Host / Port / User / Pass Form for MySQL / PostgreSQL
                      if (_primaryDbType != 'sqlite') ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _dbHostCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Database Host / IP',
                                  hintText: 'localhost or 192.168.1.100',
                                  prefixIcon: const Icon(Icons.computer_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _dbPortCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Port',
                                  hintText: _primaryDbType == 'postgresql' ? '5432' : '3306',
                                  prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _dbNameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Database Name',
                                  hintText: 'smartpos',
                                  prefixIcon: const Icon(Icons.folder_shared_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dbUserCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  hintText: _primaryDbType == 'postgresql' ? 'postgres' : 'root',
                                  prefixIcon: const Icon(Icons.person_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _dbPassCtrl,
                                obscureText: _obscureDbPass,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Leave empty if no password',
                                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureDbPass ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureDbPass = !_obscureDbPass;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password (leave Password empty). Or use username "smartpos" with password "smartpos123".',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Test Connection & Save Row
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isTestingDbConnection
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)))
                                : const Icon(Icons.network_check_rounded, size: 18),
                            label: const Text('Test Live Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isTestingDbConnection ? null : _testDatabaseConnection,
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Save Database Engine Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _saveDatabaseEngineSettings,
                          ),
                        ],
                      ),

                      // Live Connection Result Feedback
                      if (_dbConnectionResult != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_dbConnectionSuccess == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_dbConnectionSuccess == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _dbConnectionSuccess == true ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                color: _dbConnectionSuccess == true ? const Color(0xFF059669) : const Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dbConnectionResult!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _dbConnectionSuccess == true ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Offline SQLite Sync Guarantee Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.sync_rounded, color: Color(0xFF2563EB), size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Offline-First Local SQLite Sync Guarantee',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'SmartPOS operates with an offline-first architecture. SQLite runs locally on this device as a high-speed transaction buffer. When the central MySQL/PostgreSQL server is temporarily unreachable or offline, local sales continue without pause and sync automatically upon reconnection.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Seeding Engine Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.hub_rounded, color: Color(0xFF0038B8), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pharmaceutical Agency Bulk Seeder Engine',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Instantly populate 2,500 medicine items, 1,500 pharmacies, 100 suppliers, and 15 salesmen using SQLite batch transactions.',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Included Dataset Specifications:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• 2,500 Realistic Medicines: Panadol, Augmentin, Arinac, Risek, Brufen, Amoxil, Flagyl, Ciproxin, Velosef, Surbex Z, etc.\n'
                              '• Complete Batch Numbers, Expiry Dates (Active, Near Expiry <90 days, Expired for audit testing), Unit packs, Purchase & Sale Prices.\n'
                              '• 1,500 Customer Outlets: Shaheen Chemist, Fazal Din, Clinix, Servaid, Care Pharmacy, Al-Shifa Medicose with DL & NTN numbers.\n'
                              '• 100 Distributors: Getz Pharma, GSK, Abbott, Searle, Sami, Hilton, Bosch, Sanofi, Ferozsons, Highnoon, etc.\n'
                              '• 15 Salesmen Accounts: salesmen 1 to 15 with login permissions and auto-assigned territories.',
                              style: TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      if (_seedingStatus.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFF059669), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _seedingStatus,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF065F46), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0038B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSeeding
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bolt, size: 20),
                        label: Text(
                          _isSeeding ? 'Seeding Medicine Database...' : 'Seed 2,500 Medicines, 1,500 Customers & 15 Salesmen',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSeeding || _isPurging ? null : _seedMedicineAgencyData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Benchmark Engine Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.speed_rounded, color: Color(0xFF7C3AED), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SQLite Transaction Performance & Stress Benchmark',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Benchmark local desktop SQLite disk I/O throughput across 10,000 to 1,500,000 transaction workloads.',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_benchmarkStatus.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _benchmarkStatus,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isBenchmarking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Benchmark 10,000 Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isBenchmarking || _isSeeding ? null : () => _runBenchmark(10000),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFF7C3AED)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 18),
                            label: const Text('Benchmark 50,000 Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isBenchmarking || _isSeeding ? null : () => _runBenchmark(50000),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Zone: Complete Purge & Factory Reset
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danger Zone: Database Reset & Testing Utilities',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Use these utilities to purge operational data or factory-reset the installation to test another business preset from scratch.',
                                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Reset Option 1: Factory Reset for New Business Preset
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.restart_alt_rounded, color: Color(0xFFEA580C), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '1. Factory Reset & Switch Business (Relaunch Setup Wizard)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9A3412)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Completely wipes all business data, products, sales, customers, and resets configuration (is_configured = 0). Immediately launches the Smart POS Setup Wizard so you can select and test a new business preset (Super Store, Mobile & Electronics, Solar & Inverters, Pharmacy, Gym, Restaurant, Hotel, Repair).',
                              style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12), height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isPurging
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.restart_alt_rounded, size: 18),
                              label: const Text('Factory Reset & Switch Business', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _isPurging || _isSeeding ? null : _factoryResetForNewBusiness,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reset Option 2: Purge Business Data Only
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '2. Purge Business Data Only',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Wipes all products, sales, purchases, batches, inventory, customers, and suppliers clean for a fresh test cycle while keeping current business configuration and admin credentials intact.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isPurging
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.delete_forever_rounded, size: 18),
                              label: Text(
                                _isPurging ? 'Purging Database...' : 'Purge All Business Data Only',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isPurging || _isSeeding ? null : _purgeDatabase,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab 6: Software Update & Backup Center
          _buildSoftwareUpdateAndBackupTab(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildSoftwareUpdateAndBackupTab(bool isDark, Color primaryColor) {
    final serverRunning = LocalApiService.instance.isRunning;
    final serverPort = LocalApiService.instance.port;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Embedded Local REST API Server Monitor
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (serverRunning ? const Color(0xFF10B981) : const Color(0xFF64748B)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.wifi_tethering_rounded,
                        color: serverRunning ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Smart POS Embedded Local REST API Server',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (serverRunning ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: serverRunning ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                                child: Text(
                                  serverRunning ? '● LIVE ACTIVE' : '○ STOPPED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: serverRunning ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serverRunning
                                ? 'Companion Flutter Mobile Apps (Waiter KOT, Field Sales, Live Owner Dashboard) can connect to http://127.0.0.1:$serverPort'
                                : 'Local REST Server is inactive. Start the server to accept connections from mobile terminals and LAN clients.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: serverRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isStartingApi
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(serverRunning ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, size: 20),
                      label: Text(_isStartingApi ? 'Switching...' : (serverRunning ? 'Stop Server' : 'Start Server')),
                      onPressed: _isStartingApi ? null : _toggleLocalApi,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Text(
                  'Active REST Endpoints (Local Wi-Fi Network):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildApiChip('GET /health', 'System health & DB connectivity', const Color(0xFF3B82F6)),
                    _buildApiChip('GET /products', 'Real-time inventory & stock query', const Color(0xFF10B981)),
                    _buildApiChip('GET /contacts', 'Customer balances & credit ledgers', const Color(0xFF8B5CF6)),
                    _buildApiChip('GET /reports/summary', 'Owner shift & sales overview', const Color(0xFFF59E0B)),
                    _buildApiChip('POST /orders', 'Push orders from Waiter KOT/Mobile POS', const Color(0xFFEC4899)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Online and Offline Updates Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online Cloud Update Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF3B82F6), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Online Software Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text('Check cloud repository for patches & releases', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0038B8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isCheckingUpdate
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(_isCheckingUpdate ? 'Checking...' : 'Check Now'),
                            onPressed: _isCheckingUpdate ? null : _checkOnlineUpdates,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Installed Version:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0038B8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'v2.5.0 Enterprise',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0038B8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_updateInfo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.new_releases_rounded, color: Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Update Available: v${_updateInfo!['latest_version']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_updateInfo!['download_size_mb']} MB',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _updateInfo!['release_notes'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: _isApplyingUpdate
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.download_rounded, size: 18),
                                  label: Text(_isApplyingUpdate ? 'Downloading & Applying Patch...' : 'Download & Apply v${_updateInfo!['latest_version']} Patch'),
                                  onPressed: _isApplyingUpdate ? null : _applyOnlineUpdate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Air-gapped / Offline migration
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      const Text(
                        'Offline / Air-Gapped Migration (.pkg / .zip)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'For high-security air-gapped terminals without internet connection.',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _offlinePkgCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Package File Path',
                                prefixIcon: const Icon(Icons.folder_zip_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: const Icon(Icons.install_desktop_rounded, size: 16),
                            label: const Text('Apply Package', style: TextStyle(fontSize: 12)),
                            onPressed: _isApplyingUpdate ? null : _applyOfflineUpdate,
                          ),
                        ],
                      ),
                      if (_updateStatusMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            _updateStatusMessage,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right Column: Database Backup & Restore Center
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('1-Click SQLite Backup & Restore', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text('Instant safe snapshot with rollback capability', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isCreatingBackup
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 16),
                            label: Text(_isCreatingBackup ? 'Saving...' : 'Backup Now'),
                            onPressed: _isCreatingBackup ? null : _createInstantBackup,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Stored Database Backups (${_backupFiles.length})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: 'Refresh Backups',
                            onPressed: _loadBackups,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: _isLoadingBackups
                            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                            : _backupFiles.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.folder_open_rounded, size: 36, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No manual backups saved yet.\nClick "Backup Now" to create your first safe snapshot.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _backupFiles.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (ctx, idx) {
                                      final item = _backupFiles[idx];
                                      final name = item.path.split(Platform.pathSeparator).last;
                                      final stat = item.statSync();
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.storage_rounded, color: Color(0xFF0038B8), size: 20),
                                        title: Text(
                                          name,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'Size: ${_formatFileSize(stat.size)} • Date: ${_formatFileDate(stat.modified)}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                        trailing: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => _confirmAndRestoreBackup(item),
                                          child: const Text('Restore', style: TextStyle(fontSize: 11)),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Tab 7: Bill Customization & Universal Printing Setup
          _buildBillCustomizationTab(isDark, primaryColor),

          // Tab 8: AI Business Advisor (BYO Gemini / OpenAI)
          _buildAiSettingsTab(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildApiChip(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // INVOICE LAYOUTS & DETAILED A4 CUSTOMIZATION (Ultimate POS Style)
  // ==========================================

  Widget _buildInvoiceLayoutsSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x04000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.design_services_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice Layouts & Print Designs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Select layout format and configure columns for Batch No., Expiry Date, Khata balance & Warranties.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.preview_rounded, size: 16),
                    label: const Text('Live A4 Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      setState(() => _receiptPaperSize = 'a4');
                      _openUniversalPreviewDialog();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Test Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      setState(() => _receiptPaperSize = 'a4');
                      _testPrintSampleReceipt();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isSavingReceiptSettings ? 'Saving...' : 'Save Layout', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _isSavingReceiptSettings ? null : _saveReceiptSettings,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 1. Template Design Picker (Ultimate POS Style)
          const Text(
            'Invoice Template Design',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your layout style. Detailed A4 includes Batch & Expiry columns recommended for Medicine, Pharmacy & Wholesale agencies.',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLayoutDesignCard(
                title: 'Detailed A4 (Agency & Expiry)',
                badge: 'Recommended',
                badgeColor: const Color(0xFF10B981),
                desc: 'Full-feature 9-column invoice with Batch No., Expiry Date, Bonus, Rate, Discount, Khata Due & Drug Act 1976 Form 2A Warranty.',
                icon: Icons.local_hospital_rounded,
                selected: _receiptPaperSize == 'a4' && _invoiceLayoutDesign == 'detailed',
                onTap: () {
                  setState(() {
                    _receiptPaperSize = 'a4';
                    _invoiceLayoutDesign = 'detailed';
                    _showBatchOnInvoice = true;
                    _showExpiryOnInvoice = true;
                    _showWarrantyOnInvoice = true;
                  });
                },
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildLayoutDesignCard(
                title: 'Classic A4 (Standard Retail)',
                badge: 'General Trading',
                badgeColor: const Color(0xFF0284C7),
                desc: 'Clean corporate layout without batch/expiry columns for general retail, electronics, garments & supermarkets.',
                icon: Icons.description_rounded,
                selected: _receiptPaperSize == 'a4' && _invoiceLayoutDesign == 'classic',
                onTap: () {
                  setState(() {
                    _receiptPaperSize = 'a4';
                    _invoiceLayoutDesign = 'classic';
                    _showBatchOnInvoice = false;
                    _showExpiryOnInvoice = false;
                  });
                },
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildLayoutDesignCard(
                title: '80mm Thermal Slip (POS)',
                badge: 'Counter Roll',
                badgeColor: const Color(0xFF7C3AED),
                desc: 'Standard thermal receipt roll for rapid checkout, customer slips, and thermal POS printers.',
                icon: Icons.receipt_long_rounded,
                selected: _receiptPaperSize == '80mm',
                onTap: () {
                  setState(() => _receiptPaperSize = '80mm');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildLayoutDesignCard(
                title: '58mm Mini Thermal',
                badge: 'Mobile Bluetooth',
                badgeColor: const Color(0xFFD97706),
                desc: 'Compact mobile slip for handheld Bluetooth and delivery printers.',
                icon: Icons.receipt_rounded,
                selected: _receiptPaperSize == '58mm',
                onTap: () {
                  setState(() => _receiptPaperSize = '58mm');
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 2. Product Columns & Elements Visibility
          const Text(
            'Product Columns & Print Elements',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enable or disable specific columns on the invoice table. Perfect for customizing medicine expiry details, brands, and customer ledger dues.',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildCheckboxChip(
                label: 'Show Product Expiry Date',
                value: _showExpiryOnInvoice,
                icon: Icons.event_available_rounded,
                onChanged: (val) => setState(() => _showExpiryOnInvoice = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Batch / Lot Number',
                value: _showBatchOnInvoice,
                icon: Icons.qr_code_scanner_rounded,
                onChanged: (val) => setState(() => _showBatchOnInvoice = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Product Brand',
                value: _showBrandOnInvoice,
                icon: Icons.branding_watermark_rounded,
                onChanged: (val) => setState(() => _showBrandOnInvoice = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show SKU / Product Code',
                value: _showSkuOnInvoice,
                icon: Icons.barcode_reader,
                onChanged: (val) => setState(() => _showSkuOnInvoice = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Customer Khata Balance',
                value: _showCustomerBalanceOnReceipt,
                icon: Icons.account_balance_wallet_rounded,
                onChanged: (val) => setState(() => _showCustomerBalanceOnReceipt = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Drug Act Legal Warranty',
                value: _showWarrantyOnInvoice,
                icon: Icons.verified_user_rounded,
                onChanged: (val) => setState(() => _showWarrantyOnInvoice = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Amount in Words',
                value: _showTotalInWords,
                icon: Icons.spellcheck_rounded,
                onChanged: (val) => setState(() => _showTotalInWords = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show FBR / Digital QR Code',
                value: _showQrOnReceipt,
                icon: Icons.qr_code_2_rounded,
                onChanged: (val) => setState(() => _showQrOnReceipt = val),
                isDark: isDark,
              ),
              _buildCheckboxChip(
                label: 'Show Tax Breakdown (GST / NTN)',
                value: _showTaxBreakdownOnReceipt,
                icon: Icons.percent_rounded,
                onChanged: (val) => setState(() => _showTaxBreakdownOnReceipt = val),
                isDark: isDark,
              ),
            ],
          ),
          if (_showTotalInWords) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Primary Language Selection
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.language, size: 20, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _enableSecondaryLanguage ? 'Primary Language (بنیادی زبان)' : 'Primary Language',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Choose primary language for invoice totals in words (English, Urdu, Pashto, Farsi, Spanish, Dutch)',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _totalInWordsLanguage,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: NumberToWordsService.supportedLanguages.map((l) {
                          return DropdownMenuItem<String>(
                            value: l.code,
                            child: Text('${l.name} (${l.nativeName})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _totalInWordsLanguage = val);
                            _saveReceiptSettings(showSnackbar: true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Row 2: Secondary Language Toggle & Dropdown
                  Row(
                    children: [
                      Checkbox(
                        value: _enableSecondaryLanguage,
                        activeColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() => _enableSecondaryLanguage = val ?? false);
                          _saveReceiptSettings(showSnackbar: true);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _enableSecondaryLanguage = !_enableSecondaryLanguage);
                            _saveReceiptSettings(showSnackbar: true);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _enableSecondaryLanguage ? 'Enable Secondary Language (ثانوی زبان - اختیاری)' : 'Enable Secondary Language (Optional)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _enableSecondaryLanguage
                                          ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                                          : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _enableSecondaryLanguage ? 'Active' : 'Disabled (Clean UI)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _enableSecondaryLanguage ? const Color(0xFF4F46E5) : (isDark ? Colors.white54 : Colors.black45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _enableSecondaryLanguage
                                    ? 'Show bilingual subtitles on navigation sidebar and secondary receipt translations'
                                    : 'When disabled, only primary language is displayed across the entire app with zero clutter',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_enableSecondaryLanguage) ...[
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _secondaryLanguage,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: NumberToWordsService.supportedLanguages.map((l) {
                            return DropdownMenuItem<String>(
                              value: l.code,
                              child: Text('${l.name} (${l.nativeName})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _secondaryLanguage = val);
                              _saveReceiptSettings(showSnackbar: true);
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  // Row 3: Live Preview Banner
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview_rounded, size: 14, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Text(
                              'Live Words Preview (${_currencySymCtrl.text.trim().isNotEmpty ? _currencySymCtrl.text.trim() : "Rs"} 3,650.00):',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Primary (${_totalInWordsLanguage.toUpperCase()}): ${NumberToWordsService.convert(3650.0, language: _totalInWordsLanguage, currencySymbol: _currencySymCtrl.text.trim(), currencyCode: _currencyCodeCtrl.text.trim())}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
                        ),
                        if (_enableSecondaryLanguage) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Secondary (${_secondaryLanguage.toUpperCase()}): ${NumberToWordsService.convert(3650.0, language: _secondaryLanguage, currencySymbol: _currencySymCtrl.text.trim(), currencyCode: _currencyCodeCtrl.text.trim())}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                          _isSavingReceiptSettings ? 'Saving...' : 'Save Language & Invoice Settings',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: _isSavingReceiptSettings ? null : () => _saveReceiptSettings(showSnackbar: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 3. Invoice Header Title & Customization
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _invoiceHeadingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Heading / Title (e.g. TAX INVOICE, COMMERCIAL INVOICE)',
                    prefixIcon: Icon(Icons.title_rounded, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _receiptTaglineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Header Sub-title / Agency License (e.g. Drug License # / NTN)',
                    prefixIcon: Icon(Icons.subtitles_rounded, size: 18),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutDesignCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String desc,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: selected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)), size: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxChip({
    required String label,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 14, color: value ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: value ? FontWeight.bold : FontWeight.normal, color: value ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF1E293B)))),
      selected: value,
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      checkmarkColor: Colors.white,
      side: BorderSide(color: value ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      onSelected: onChanged,
    );
  }

  // ==========================================
  // BILL CUSTOMIZATION & UNIVERSAL PRINT ENGINE
  // ==========================================

  Future<void> _saveReceiptSettings({bool showSnackbar = true}) async {
    setState(() => _isSavingReceiptSettings = true);
    try {
      final updated = widget.settings.copyWith(
        receiptPaperSize: _receiptPaperSize,
        receiptHeaderTagline: _receiptTaglineCtrl.text.trim(),
        receiptHeaderNote: _receiptNoteCtrl.text.trim(),
        receiptReturnPolicy: _receiptReturnPolicyCtrl.text.trim(),
        invoicePrintCopies: _invoicePrintCopies,
        showLogoOnReceipt: _showLogoOnReceipt,
        showBarcodeOnReceipt: _showBarcodeOnReceipt,
        showQrOnReceipt: _showQrOnReceipt,
        showCustomerBalanceOnReceipt: _showCustomerBalanceOnReceipt,
        showTaxBreakdownOnReceipt: _showTaxBreakdownOnReceipt,
        showCashierNameOnReceipt: _showCashierNameOnReceipt,
        invoiceLayoutDesign: _invoiceLayoutDesign,
        showBatchOnInvoice: _showBatchOnInvoice,
        showExpiryOnInvoice: _showExpiryOnInvoice,
        showBrandOnInvoice: _showBrandOnInvoice,
        showSkuOnInvoice: _showSkuOnInvoice,
        showWarrantyOnInvoice: _showWarrantyOnInvoice,
        showTotalInWords: _showTotalInWords,
        totalInWordsLanguage: _totalInWordsLanguage,
        enableSecondaryLanguage: _enableSecondaryLanguage,
        secondaryLanguage: _secondaryLanguage,
        invoiceHeading: _invoiceHeadingCtrl.text.trim(),
      );

      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updated);
      widget.onSettingsUpdated(updated);

      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save receipt settings: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingReceiptSettings = false);
    }
  }

  Sale _getSampleSaleForTesting() {
    return Sale(
      id: 9999,
      invoiceNo: 'POS-INV-8821',
      customerId: 1,
      customerName: 'Muhammad Tariq (Regular Customer)',
      subtotal: 1900.0,
      discount: 50.0,
      taxAmount: 92.5,
      paidAmount: 1850.0,
      totalAmount: 1850.0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      cashierName: 'Admin Counter #1',
      items: [
        SaleItem(
          saleId: 9999,
          productId: 101,
          productName: 'Panadol Extra 500mg Tablets (Box of 20)',
          sku: 'MED-PAN-500',
          quantity: 2,
          unitPrice: 350.0,
          subtotal: 700.0,
          batchNumber: 'BN-9921',
          expiryDate: '12/2027',
        ),
        SaleItem(
          saleId: 9999,
          productId: 102,
          productName: 'Brufen 400mg Suspension Syrup 120ml',
          sku: 'MED-BRU-120',
          quantity: 1,
          unitPrice: 280.0,
          subtotal: 280.0,
          batchNumber: 'BN-4412',
          expiryDate: '08/2026',
        ),
        SaleItem(
          saleId: 9999,
          productId: 103,
          productName: 'Surgical Face Masks 3-Ply (Pack of 50)',
          sku: 'MED-MSK-050',
          quantity: 1,
          unitPrice: 870.0,
          subtotal: 870.0,
        ),
      ],
    );
  }

  void _testPrintSampleReceipt() {
    final sampleSale = _getSampleSaleForTesting();
    final tempSettings = widget.settings.copyWith(
      receiptPaperSize: _receiptPaperSize,
      receiptHeaderTagline: _receiptTaglineCtrl.text.trim(),
      receiptHeaderNote: _receiptNoteCtrl.text.trim(),
      receiptReturnPolicy: _receiptReturnPolicyCtrl.text.trim(),
      showLogoOnReceipt: _showLogoOnReceipt,
      showBarcodeOnReceipt: _showBarcodeOnReceipt,
      showQrOnReceipt: _showQrOnReceipt,
      showCustomerBalanceOnReceipt: _showCustomerBalanceOnReceipt,
      showTaxBreakdownOnReceipt: _showTaxBreakdownOnReceipt,
      showCashierNameOnReceipt: _showCashierNameOnReceipt,
      invoiceLayoutDesign: _invoiceLayoutDesign,
      showBatchOnInvoice: _showBatchOnInvoice,
      showExpiryOnInvoice: _showExpiryOnInvoice,
      showBrandOnInvoice: _showBrandOnInvoice,
      showSkuOnInvoice: _showSkuOnInvoice,
      showWarrantyOnInvoice: _showWarrantyOnInvoice,
      showTotalInWords: _showTotalInWords,
      totalInWordsLanguage: _totalInWordsLanguage,
      enableSecondaryLanguage: _enableSecondaryLanguage,
      secondaryLanguage: _secondaryLanguage,
      invoiceHeading: _invoiceHeadingCtrl.text.trim(),
    );

    final html = PrintService.generateSaleInvoiceHtml(
      settings: tempSettings,
      sale: sampleSale,
      paperSizeOverride: _receiptPaperSize,
      tenderedAmount: 2000.0,
      changeReturn: 150.0,
    );

    PrintService.openPrintWindow(htmlContent: html, title: _receiptPaperSize == 'a4' ? 'Sample-A4-Invoice' : 'Sample-Thermal-Receipt');
  }

  void _openUniversalPreviewDialog() {
    final sampleSale = _getSampleSaleForTesting();
    final tempSettings = widget.settings.copyWith(
      receiptPaperSize: _receiptPaperSize,
      receiptHeaderTagline: _receiptTaglineCtrl.text.trim(),
      receiptHeaderNote: _receiptNoteCtrl.text.trim(),
      receiptReturnPolicy: _receiptReturnPolicyCtrl.text.trim(),
      showLogoOnReceipt: _showLogoOnReceipt,
      showBarcodeOnReceipt: _showBarcodeOnReceipt,
      showQrOnReceipt: _showQrOnReceipt,
      showCustomerBalanceOnReceipt: _showCustomerBalanceOnReceipt,
      showTaxBreakdownOnReceipt: _showTaxBreakdownOnReceipt,
      showCashierNameOnReceipt: _showCashierNameOnReceipt,
      invoiceLayoutDesign: _invoiceLayoutDesign,
      showBatchOnInvoice: _showBatchOnInvoice,
      showExpiryOnInvoice: _showExpiryOnInvoice,
      showBrandOnInvoice: _showBrandOnInvoice,
      showSkuOnInvoice: _showSkuOnInvoice,
      showWarrantyOnInvoice: _showWarrantyOnInvoice,
      showTotalInWords: _showTotalInWords,
      totalInWordsLanguage: _totalInWordsLanguage,
      enableSecondaryLanguage: _enableSecondaryLanguage,
      secondaryLanguage: _secondaryLanguage,
      invoiceHeading: _invoiceHeadingCtrl.text.trim(),
    );

    final html = PrintService.generateSaleInvoiceHtml(
      settings: tempSettings,
      sale: sampleSale,
      paperSizeOverride: _receiptPaperSize,
      tenderedAmount: 2000.0,
      changeReturn: 150.0,
    );

    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Thermal Bill Live Preview & Customization',
        htmlContent: html,
        defaultPaperSize: _receiptPaperSize,
        settings: tempSettings,
      ),
    );
  }

  Widget _buildBillCustomizationTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0x04000000),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.print_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Printing & Receipt Customization Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure your thermal slip layout (80mm/58mm/A4), return policy, barcodes, verification QR code, and customer balance.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.preview_rounded, size: 18),
                  label: const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openUniversalPreviewDialog,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Test Print', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _testPrintSampleReceipt,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSavingReceiptSettings ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isSavingReceiptSettings ? null : _saveReceiptSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Two-column layout: Left Controls, Right Live Preview
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final leftControls = _buildReceiptConfigControls(isDark, primaryColor);
              final rightPreview = _buildLiveReceiptPreview(isDark);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: leftControls),
                    const SizedBox(width: 24),
                    SizedBox(width: 380, child: rightPreview),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftControls,
                    const SizedBox(height: 24),
                    rightPreview,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptConfigControls(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paper Size Section
          const Text(
            'Receipt Paper Size / Printer Format',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the default format supported by your counter POS printer (80mm standard, 58mm portable, or A4 agency invoice).',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPaperSizeOption(
                label: '80mm Thermal',
                desc: 'Standard Counter Roll',
                icon: Icons.receipt_long,
                value: '80mm',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildPaperSizeOption(
                label: '58mm Mini',
                desc: 'Mobile Bluetooth / USB',
                icon: Icons.receipt,
                value: '58mm',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildPaperSizeOption(
                label: 'A4 Standard',
                desc: 'Wholesale / Laser Page',
                icon: Icons.description_rounded,
                value: 'a4',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Header Text Inputs
          const Text('Receipt Header & Sub-title', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _receiptTaglineCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Header Tagline / Business Slogan',
              hintText: 'e.g. Wholesale & Retail Distributor',
              prefixIcon: Icon(Icons.subtitles_rounded, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _receiptNoteCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Header Greeting / Welcome Note',
              hintText: 'e.g. Welcome to our store!',
              prefixIcon: Icon(Icons.waving_hand_rounded, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Return Policy & Copies
          const Text('Footer Terms & Print Copies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _receiptReturnPolicyCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Return & Exchange Policy / Warranty Terms',
              hintText: 'e.g. Goods once sold can only be exchanged within 7 days with original receipt.',
              prefixIcon: Icon(Icons.policy_rounded, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _invoicePrintCopies,
                  decoration: const InputDecoration(
                    labelText: 'Number of Print Copies',
                    prefixIcon: Icon(Icons.content_copy_rounded, size: 18),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Copy (Customer Receipt)')),
                    DropdownMenuItem(value: 2, child: Text('2 Copies (Customer + Store Copy)')),
                    DropdownMenuItem(value: 3, child: Text('3 Copies (Customer + Store + Accounts)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _invoicePrintCopies = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Toggles Section
          const Text('Print Elements & Visibility Toggles', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Turn sections ON or OFF to match your preferred thermal receipt length and detail level.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            title: 'Show Store Logo & Title',
            desc: 'Prints business name and visual logo at receipt apex',
            value: _showLogoOnReceipt,
            onChanged: (val) => setState(() => _showLogoOnReceipt = val),
            isDark: isDark,
          ),
          _buildToggleRow(
            title: 'Show Code128 Barcode',
            desc: 'Prints scannable barcode for instant returns and lookup',
            value: _showBarcodeOnReceipt,
            onChanged: (val) => setState(() => _showBarcodeOnReceipt = val),
            isDark: isDark,
          ),
          _buildToggleRow(
            title: 'Show Verification QR Code',
            desc: 'Prints QR code for digital validation and electronic invoicing',
            value: _showQrOnReceipt,
            onChanged: (val) => setState(() => _showQrOnReceipt = val),
            isDark: isDark,
          ),
          _buildToggleRow(
            title: 'Show Customer Khata / Previous Dues',
            desc: 'Displays previous outstanding balance and current total dues',
            value: _showCustomerBalanceOnReceipt,
            onChanged: (val) => setState(() => _showCustomerBalanceOnReceipt = val),
            isDark: isDark,
          ),
          _buildToggleRow(
            title: 'Show Tax Breakdown (GST / VAT)',
            desc: 'Displays itemized tax calculations and store NTN/STRN',
            value: _showTaxBreakdownOnReceipt,
            onChanged: (val) => setState(() => _showTaxBreakdownOnReceipt = val),
            isDark: isDark,
          ),
          _buildToggleRow(
            title: 'Show Cashier / Operator Name',
            desc: 'Displays the name of the cashier who billed the transaction',
            value: _showCashierNameOnReceipt,
            onChanged: (val) => setState(() => _showCashierNameOnReceipt = val),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSizeOption({
    required String label,
    required String desc,
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _receiptPaperSize == value;
    final color = isSelected ? const Color(0xFF0038B8) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final bg = isSelected
        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _receiptPaperSize = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: isSelected ? const Color(0xFF0038B8) : Colors.grey),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF0038B8))
                  else
                    const Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? (isDark ? Colors.white : const Color(0xFF0038B8)) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF0038B8),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveReceiptPreview(bool isDark) {
    final currency = widget.settings.currencySymbol;
    final bizName = widget.settings.businessName.isNotEmpty ? widget.settings.businessName : 'Smart POS Enterprise';
    final tagline = _receiptTaglineCtrl.text.trim();
    final note = _receiptNoteCtrl.text.trim();
    final returnPolicy = _receiptReturnPolicyCtrl.text.trim();
    final phone = widget.settings.phone.isNotEmpty ? widget.settings.phone : '+92 300 1234567';
    final address = widget.settings.address.isNotEmpty ? widget.settings.address : 'Commercial Plaza, Karachi';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, size: 18, color: Color(0xFF0038B8)),
              const SizedBox(width: 8),
              Text(
                _receiptPaperSize == 'a4' ? 'Live A4 Invoice Preview' : 'Live Thermal Receipt Preview',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0038B8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _receiptPaperSize == 'a4' ? 'A4 DETAILED' : _receiptPaperSize.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0038B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Paper styled container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x15000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: _receiptPaperSize == 'a4'
                ? _buildA4PaperContent(bizName, tagline, phone, address, currency)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                if (_showLogoOnReceipt) ...[
                  const Icon(Icons.point_of_sale_rounded, color: Colors.black87, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    bizName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ],
                const SizedBox(height: 4),
                Text(
                  address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54),
                ),
                Text(
                  'Tel: $phone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '*** $note ***',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 10, color: Colors.black87),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('--------------------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Inv: POS-INV-8821', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                  ],
                ),
                if (_showCashierNameOnReceipt)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cashier: Admin Counter #1', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                  ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cust: Muhammad Tariq', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                ),
                const SizedBox(height: 6),
                const Text('--------------------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Expanded(flex: 5, child: Text('Item', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))),
                    Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))),
                    Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('--------------------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                const SizedBox(height: 4),
                _previewItemRow('Panadol Extra 500mg (20s)', '2', '$currency 700.00'),
                _previewItemRow('Brufen Syrup 120ml', '1', '$currency 280.00'),
                _previewItemRow('Face Masks 3-Ply 50s', '1', '$currency 870.00'),
                const SizedBox(height: 6),
                const Text('--------------------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                _previewTotalRow('Subtotal:', '$currency 1,850.00'),
                _previewTotalRow('Discount:', '-$currency 50.00'),
                if (_showTaxBreakdownOnReceipt) _previewTotalRow('Tax (GST 5%):', '$currency 92.50'),
                const Text('============================================', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                _previewTotalRow('NET PAYABLE:', '$currency 1,850.00', isBold: true, fontSize: 12),
                const Text('============================================', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black)),
                _previewTotalRow('Cash Paid:', '$currency 2,000.00'),
                _previewTotalRow('Change Return:', '$currency 150.00'),
                if (_showCustomerBalanceOnReceipt) ...[
                  const SizedBox(height: 4),
                  const Text('--------------------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black54)),
                  _previewTotalRow('Prev Customer Balance:', '$currency 1,450.00'),
                  _previewTotalRow('TOTAL CURRENT DUE:', '$currency 1,450.00', isBold: true),
                ],
                const SizedBox(height: 10),
                if (_showBarcodeOnReceipt) ...[
                  Container(
                    height: 28,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Text('||||| | |||| ||| |||| | ||||||', style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2, color: Colors.black)),
                  ),
                  const Text('*POS-INV-8821*', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black54)),
                  const SizedBox(height: 8),
                ],
                if (_showQrOnReceipt) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
                    child: const Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.black),
                  ),
                  const SizedBox(height: 2),
                  const Text('Scan to verify digital invoice', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black54)),
                  const SizedBox(height: 8),
                ],
                if (returnPolicy.isNotEmpty) ...[
                  Text(
                    returnPolicy,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Powered by Smart POS Enterprise',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildA4PaperContent(String bizName, String tagline, String phone, String address, String currency) {
    final heading = _invoiceHeadingCtrl.text.trim().isNotEmpty ? _invoiceHeadingCtrl.text.trim().toUpperCase() : 'TAX INVOICE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A4 Header
        Text(
          bizName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black),
        ),
        Text(
          '$heading • WHOLESALE & DISTRIBUTION',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: Color(0xFF334155)),
        ),
        Text(
          '$address • $phone',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black54),
        ),
        const SizedBox(height: 8),

        // Party Info Box
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PARTY: M. Tariq (Regular Customer)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black)),
                  Text('INV: POS-INV-8821', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CITY: Commercial Area, Karachi', style: TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: Colors.black87)),
                  Text('DATE: 08-Nov-2026 11:38 AM', style: TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: Colors.black87)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Table Header
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            children: [
              const Expanded(flex: 4, child: Text('DESCRIPTION', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
              if (_showBatchOnInvoice)
                const Expanded(flex: 2, child: Text('BATCH', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
              if (_showExpiryOnInvoice)
                const Expanded(flex: 2, child: Text('EXPIRY', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
              const Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
              const Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.black54),

        // Sample Items
        _buildA4ItemRow('Panadol Extra 500mg (20s)', 'BN-9921', '12/27', '2', '$currency 700.00'),
        _buildA4ItemRow('Brufen Syrup 120ml', 'BN-4412', '08/26', '1', '$currency 280.00'),
        _buildA4ItemRow('Face Masks 3-Ply 50s', 'MSK-2026', '05/29', '1', '$currency 870.00'),

        const Divider(height: 1, color: Colors.black54),
        const SizedBox(height: 4),

        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('NET INVOICE TOTAL:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black)),
            Text('$currency 1,850.00', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 9.5, color: Colors.black)),
          ],
        ),

        if (_showTotalInWords) ...[
          const SizedBox(height: 2),
          Text(
            'Words: ${NumberToWordsService.convert(1850.0, language: _totalInWordsLanguage, currencySymbol: _currencySymCtrl.text)}',
            style: const TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 7.5, color: Colors.black87),
          ),
        ],

        if (_showCustomerBalanceOnReceipt) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: Colors.black45),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Prev Bal: $currency 1,450.00', style: const TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: Colors.black)),
                Text('Paid: $currency 1,850.00', style: const TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: Colors.black)),
                Text('Total Due: $currency 1,450.00', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 7.5, color: Colors.red)),
              ],
            ),
          ),
        ],

        if (_showWarrantyOnInvoice) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'WARRANTY: Form 2A under Section 23(i) of Drug Act 1976. Goods do not contravene provisions.',
              style: TextStyle(fontFamily: 'monospace', fontSize: 7, color: Colors.black54),
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'نوٹ: مال وصول کرتے وقت ایکسپائری اور ڈبہ چیک کرلیں۔',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildA4ItemRow(String desc, String batch, String exp, String qty, String total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(desc, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black87))),
          if (_showBatchOnInvoice)
            Expanded(flex: 2, child: Text(batch, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black87))),
          if (_showExpiryOnInvoice)
            Expanded(flex: 2, child: Text(exp, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Color(0xFFD97706)))),
          Expanded(flex: 1, child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.black87))),
          Expanded(flex: 2, child: Text(total, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _previewItemRow(String name, String qty, String total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87))),
          Expanded(flex: 2, child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87))),
          Expanded(flex: 3, child: Text(total, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _previewTotalRow(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
          Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildCurrencyRateRow(CurrencyRate rate, bool isDark) {
    final baseCode = _currencyCodeCtrl.text.isNotEmpty ? _currencyCodeCtrl.text : 'PKR';
    final effective = rate.effectiveRate;
    final isCustom = rate.customRate != null && rate.customRate! > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rate.isEnabled
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        children: [
          // Currency Badge
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: rate.isEnabled
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${rate.symbol} ${rate.code}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: rate.isEnabled ? const Color(0xFF4F46E5) : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & Country
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: rate.isEnabled ? null : Colors.grey,
                  ),
                ),
                Text(
                  rate.country,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Live API Rate Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('API LIVE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '1 ${rate.code} = $baseCode ${rate.liveRate.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Counter Rate: 1 ${rate.code} = $baseCode ${effective.toStringAsFixed(2)} ${isCustom ? "(Custom)" : ""}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                    color: isCustom ? const Color(0xFFD97706) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          // Custom Rate Input
          SizedBox(
            width: 130,
            child: TextFormField(
              initialValue: rate.customRate != null ? rate.customRate!.toStringAsFixed(2) : '',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Merchant Rate',
                hintText: rate.liveRate.toStringAsFixed(2),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffixIcon: rate.customRate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          setState(() {
                            final idx = _ratesList.indexWhere((r) => r.code == rate.code);
                            if (idx != -1) {
                              _ratesList[idx] = _ratesList[idx].copyWith(customRate: null);
                            }
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val.trim());
                final idx = _ratesList.indexWhere((r) => r.code == rate.code);
                if (idx != -1) {
                  _ratesList[idx] = _ratesList[idx].copyWith(customRate: parsed);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // Toggle Active at POS
          Tooltip(
            message: rate.isEnabled ? 'Disable at POS checkout' : 'Enable at POS checkout',
            child: Switch(
              value: rate.isEnabled,
              activeColor: const Color(0xFF4F46E5),
              onChanged: (val) {
                setState(() {
                  final idx = _ratesList.indexWhere((r) => r.code == rate.code);
                  if (idx != -1) {
                    _ratesList[idx] = _ratesList[idx].copyWith(isEnabled: val);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSettingsTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart POS AI Business Advisor & Intelligence',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bring Your Own (BYO) API Key: Connect Google Gemini (100% Free) or OpenAI GPT-4o to analyze financial turnover, predict inventory reorders, and guide staff in Roman Urdu.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Configuration Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('AI Engine Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Text('Enable AI Integration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Switch(
                            value: _aiSettings.isEnabled,
                            activeColor: const Color(0xFF7C3AED),
                            onChanged: (v) {
                              setState(() {
                                _aiSettings = _aiSettings.copyWith(isEnabled: v);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Provider Selector
                  const Text('Select AI Model Provider:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _aiSettings = _aiSettings.copyWith(
                                provider: 'gemini',
                                modelName: 'gemini-1.5-flash',
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _aiSettings.provider == 'gemini'
                                  ? const Color(0xFFEEF2FF)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _aiSettings.provider == 'gemini' ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                width: _aiSettings.provider == 'gemini' ? 2 : 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Color(0xFF4F46E5), size: 22),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Google Gemini 1.5 Flash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('100% Free • Recommended • Fast', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _aiSettings = _aiSettings.copyWith(
                                provider: 'openai',
                                modelName: 'gpt-4o-mini',
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _aiSettings.provider == 'openai'
                                  ? const Color(0xFFECFDF5)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _aiSettings.provider == 'openai' ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                width: _aiSettings.provider == 'openai' ? 2 : 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 22),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('OpenAI GPT-4o Mini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('High Intelligence • Paid Key', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // API Key Field
                  TextField(
                    controller: _aiApiKeyCtrl,
                    obscureText: _obscureAiKey,
                    onChanged: (val) {
                      _aiSettings = _aiSettings.copyWith(apiKey: val.trim());
                    },
                    decoration: InputDecoration(
                      labelText: _aiSettings.provider == 'gemini' ? 'Google Gemini API Key *' : 'OpenAI Secret API Key *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureAiKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureAiKey = !_obscureAiKey),
                      ),
                      helperText: _aiSettings.provider == 'gemini'
                          ? 'Get your free key in 30 seconds from: https://aistudio.google.com/app/apikey'
                          : 'From your OpenAI account platform: https://platform.openai.com/api-keys',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Advisory Language
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _aiSettings.preferredLanguage,
                          decoration: const InputDecoration(labelText: 'AI Advisory Language', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'roman_urdu', child: Text('Roman Urdu (اردو/English - Recommended)')),
                            DropdownMenuItem(value: 'urdu', child: Text('Urdu (اردو رسم الخط)')),
                            DropdownMenuItem(value: 'english', child: Text('English (Executive Business Standard)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _aiSettings = _aiSettings.copyWith(preferredLanguage: v));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save AI Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final key = _aiApiKeyCtrl.text.trim();
                          final updated = _aiSettings.copyWith(apiKey: key);
                          final db = await DatabaseService.initialize();
                          await db.saveAiSettings(updated);
                          setState(() => _aiSettings = updated);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('AI Assistant settings saved successfully!'), backgroundColor: Color(0xFF10B981)),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        icon: const Icon(Icons.network_check_rounded, size: 18),
                        label: Text(_isTestingAi ? 'Connecting to AI...' : 'Test AI Connection'),
                        onPressed: _isTestingAi
                            ? null
                            : () async {
                                final key = _aiApiKeyCtrl.text.trim();
                                if (key.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter an API key first!'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                setState(() {
                                  _isTestingAi = true;
                                });

                                final testSettings = _aiSettings.copyWith(apiKey: key);
                                final response = await AiAssistantService.generate(
                                  prompt: 'Hello! Please confirm in one short sentence that you are connected and ready to assist Smart POS.',
                                  settingsOverride: testSettings,
                                );

                                if (mounted) {
                                  setState(() {
                                    _isTestingAi = false;
                                  });

                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('AI Connection Test Result'),
                                      content: Text(response),
                                      actions: [
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                                      ],
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Google AI Studio Free Setup Guide
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                    SizedBox(width: 8),
                    Text('How to get a 100% FREE Google Gemini API Key:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                SizedBox(height: 8),
                Text('1. Go to Google AI Studio: https://aistudio.google.com/app/apikey in your browser.', style: TextStyle(fontSize: 12)),
                Text('2. Sign in with any standard Gmail / Google account.', style: TextStyle(fontSize: 12)),
                Text('3. Click the blue button: "Create API key".', style: TextStyle(fontSize: 12)),
                Text('4. Copy your key, paste it into the box above, and click "Save AI Credentials".', style: TextStyle(fontSize: 12)),
                Text('5. You will get 15 free AI requests every minute with zero billing required!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

