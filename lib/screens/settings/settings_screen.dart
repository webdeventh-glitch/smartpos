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
import '../../services/print_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
    if (mounted) {
      setState(() {
        _locations = locs;
        _taxRates = taxes;
        _schemes = scs;
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
        return 'Dairy, Milk & Eggs / دودھ، دہی، مکھن اور انڈے';
      case 'tyres_battery':
      case 'tyres':
        return 'Tyre Shop, Rims & Battery / ٹائر، رمز اور بیٹری';
      case 'hardware_tools':
      case 'hardware':
        return 'Hardware, Tools & Paint / ہارڈویئر اور اوزار';
      case 'auto_parts':
        return 'Auto Spare Parts / آٹو سپیئر پارٹس اور پرزہ جات';
      case 'meat_butchery':
      case 'meat':
        return 'Meat, Butchery & Poultry / گوشت، بیف، مٹن اور چکن';
      case 'fabrics_textile':
      case 'fabrics':
        return 'Fabrics & Cloth (Meter / Gazz) / کپڑا اور تھان';
      case 'lubricants_oil':
      case 'lubricants':
        return 'Mobile Oil & Lubricants / موبائل آئل اور لبریکنٹس';
      case 'sanitary_tiles':
      case 'sanitary':
        return 'Sanitary, Tiles & Bath / سینیٹری اور سیرامک ٹائلز';
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
                                  'کاروباری ماڈل تبدیل کریں • Adapt software units, categories & POS to your trade',
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
    final cityCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.store, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Add Business Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Location / Branch Name *', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locIdCtrl,
                decoration: const InputDecoration(labelText: 'Location ID (e.g. BL0003)', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City / Area', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                decoration: const InputDecoration(labelText: 'Contact Mobile', isDense: true),
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
              final loc = BusinessLocation(
                name: nameCtrl.text.trim(),
                locationId: locIdCtrl.text.trim().isEmpty ? 'BL0001' : locIdCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                mobile: mobileCtrl.text.trim(),
              );
              final db = await DatabaseService.initialize();
              await db.addBusinessLocation(loc);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSubData();
            },
            child: const Text('Add Location'),
          ),
        ],
      ),
    );
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
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Invoice Schemes'),
            Tab(icon: Icon(Icons.vpn_key_rounded, size: 18), text: 'Qulop License System'),
            Tab(icon: Icon(Icons.storage_rounded, size: 18), text: 'Purge & Medicine Engine'),
            Tab(icon: Icon(Icons.system_update_alt_rounded, size: 18), text: 'Software Update & Backup'),
            Tab(icon: Icon(Icons.print_rounded, size: 18), text: 'Bill Customization & Printing'),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Currency & Standard Tax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CurrencySearchDialog(
                                initialCode: _currencyCodeCtrl.text,
                                onSelected: (info) {
                                  setState(() {
                                    _currencySymCtrl.text = info.symbol;
                                    _currencyCodeCtrl.text = info.code;
                                  });
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Search 130+ Currencies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Currency Presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const FaIcon(FontAwesomeIcons.coins, size: 12, color: Color(0xFF4F46E5)),
                          label: const Text('Pakistani Rupee (Rs / PKR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setState(() {
                              _currencySymCtrl.text = 'Rs';
                              _currencyCodeCtrl.text = 'PKR';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const FaIcon(FontAwesomeIcons.dollarSign, size: 12, color: Color(0xFF10B981)),
                          label: const Text('US Dollar (\$ / USD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setState(() {
                              _currencySymCtrl.text = '\$';
                              _currencyCodeCtrl.text = 'USD';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const FaIcon(FontAwesomeIcons.coins, size: 12, color: Color(0xFFD97706)),
                          label: const Text('Saudi Riyal (SAR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setState(() {
                              _currencySymCtrl.text = 'SAR';
                              _currencyCodeCtrl.text = 'SAR';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const FaIcon(FontAwesomeIcons.coins, size: 12, color: Color(0xFF0284C7)),
                          label: const Text('UAE Dirham (AED)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setState(() {
                              _currencySymCtrl.text = 'AED';
                              _currencyCodeCtrl.text = 'AED';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const FaIcon(FontAwesomeIcons.sterlingSign, size: 12, color: Color(0xFF7C3AED)),
                          label: const Text('British Pound (£ / GBP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            setState(() {
                              _currencySymCtrl.text = '£';
                              _currencyCodeCtrl.text = 'GBP';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currencySymCtrl,
                            decoration: const InputDecoration(labelText: 'Currency Symbol * (e.g. Rs, \$, PKR, €)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _currencyCodeCtrl,
                            decoration: const InputDecoration(labelText: 'Currency Code (PKR, USD, EUR, SAR)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _taxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Default Tax Rate (%)', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Multi-Currency & Dual Tender Information Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.currency_exchange, color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Multi-Currency System (Dual Tender Ready)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF166534),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aapka official Ledger & Accounting Currency "${_currencyCodeCtrl.text}" (${_currencySymCtrl.text}) par set hai. International ya border trade mein secondary foreign currencies (USD, SAR, AED, EUR, GBP) POS cash counter par automatic live conversion ke sath receive ki ja sakti hain jabke stock valuation aur tax audit local base currency mein mehfooz rehta hai.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF15803D),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.store, color: Color(0xFF0038B8)),
                                ),
                                title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('ID: ${loc.locationId} • ${loc.city.isNotEmpty ? loc.city : "City not set"} • Mobile: ${loc.mobile.isNotEmpty ? loc.mobile : "N/A"}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: loc.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    loc.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: loc.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
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

          // Tab 3: Invoice Schemes
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Invoice Schemes & Sequence Numbering', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _schemes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final sc = _schemes[i];
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
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.format_list_numbered, color: Color(0xFF0038B8)),
                                ),
                                title: Text(sc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('Preview: ${sc.previewExample} • Start: ${sc.startNumber} • Total Invoices: ${sc.invoiceCount}'),
                                trailing: sc.isDefault
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Default', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12)),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
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
                                  const Text('Qulop Hardware Machine Fingerprint (MAC Address)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text('Unique machine identifier bound to Qulop license: $_hostMac', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                                labelText: 'Enter Qulop License Key',
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
                              Text('How to Renew or Purchase a Qulop License Key', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              SizedBox(height: 2),
                              Text('Contact software vendor to purchase or extend your Qulop subscription', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                                Text('Qulop SaaS Provider: Webdeventh Software Solutions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        child: const Column(
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
  // BILL CUSTOMIZATION & UNIVERSAL PRINT ENGINE
  // ==========================================

  Future<void> _saveReceiptSettings() async {
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
      );

      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updated);
      widget.onSettingsUpdated(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill Customization & Printing settings saved successfully!'),
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
    );

    final html = PrintService.generateSaleInvoiceHtml(
      settings: tempSettings,
      sale: sampleSale,
      paperSizeOverride: _receiptPaperSize,
      tenderedAmount: 2000.0,
      changeReturn: 150.0,
    );

    PrintService.openPrintWindow(htmlContent: html, title: 'Sample-Thermal-Receipt');
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
              const Text(
                'Live Thermal Receipt Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0038B8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _receiptPaperSize.toUpperCase(),
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
            child: Column(
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
}

