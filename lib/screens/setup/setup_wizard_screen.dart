import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/qulop_service.dart';
import '../../services/mysql_service.dart';
import '../../services/regional_data_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SetupWizardScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings) onSetupComplete;

  const SetupWizardScreen({
    super.key,
    required this.settings,
    required this.onSetupComplete,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isSeeding = false;
  String _seedStatus = '';

  // Step 1: Hardware-Bound Licensing Controllers & State
  late TextEditingController _licenseKeyCtrl;
  String _hardwareId = 'Detecting Hardware ID...';
  String _macAddress = '';
  bool _isVerifyingLicense = false;
  QulopStatus? _licenseStatus;
  String? _licenseError;

  // Step 2: Business Profile & Industry Presets Controllers
  late TextEditingController _bizNameCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _taxNumberCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _receiptFooterCtrl;
  late TextEditingController _currencySymCtrl;
  late TextEditingController _currencyCodeCtrl;
  String? _logoPath;
  String _timeZone = 'Asia/Karachi';
  CurrencyInfo? _selectedCurrency;

  // Selected Industry Preset (Strict Single Business Mode - ایک وقت میں صرف ایک کاروبار)
  String _selectedPreset = BusinessSettings.presetPharmacy;
  Set<String> get _selectedPresets => {_selectedPreset};

  bool _seedSampleData = true;
  bool _isInstallationComplete = false;
  BusinessSettings? _finalizedSettings;

  // Step 3: Network Topology & Hybrid Database Engine Controllers
  String _deploymentMode = 'offline_server'; // 'offline_server', 'lan_secondary', 'cloud_hybrid'
  String _primaryDbType = 'mysql'; // 'mysql', 'postgresql', 'sqlite'
  late TextEditingController _serverPortCtrl;
  late TextEditingController _lanHostCtrl;
  late TextEditingController _lanPortCtrl;
  late TextEditingController _lanDbNameCtrl;
  late TextEditingController _lanDbUserCtrl;
  late TextEditingController _lanDbPassCtrl;
  late TextEditingController _cloudUrlCtrl;
  late TextEditingController _cloudApiKeyCtrl;
  late TextEditingController _cloudBranchIdCtrl;

  bool _isTestingConnection = false;
  String? _connectionTestResult;
  bool? _connectionSuccess;

  // Step 4: Super Admin Account Controllers
  late TextEditingController _adminNameCtrl;
  late TextEditingController _adminUserCtrl;
  late TextEditingController _adminEmailCtrl;
  late TextEditingController _adminPhoneCtrl;
  late TextEditingController _adminPassCtrl;
  late TextEditingController _adminConfirmPassCtrl;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _obscureLanDbPass = true;

  @override
  void initState() {
    super.initState();

    // Step 1 controllers
    _licenseKeyCtrl = TextEditingController(text: widget.settings.purchaseKey);

    // Step 2 controllers
    _bizNameCtrl = TextEditingController(
      text: widget.settings.businessName.isNotEmpty && widget.settings.businessName != 'Smart POS System'
          ? widget.settings.businessName
          : 'Smart POS Retail & Systems',
    );
    _branchCtrl = TextEditingController(
      text: widget.settings.branchName.isNotEmpty ? widget.settings.branchName : 'Main Branch HQ',
    );
    _taxNumberCtrl = TextEditingController(text: widget.settings.taxNumber.isNotEmpty ? widget.settings.taxNumber : 'NTN-829104-5');
    _phoneCtrl = TextEditingController(text: widget.settings.phone.isNotEmpty ? widget.settings.phone : '+92 300 1234567');
    _emailCtrl = TextEditingController(text: widget.settings.email.isNotEmpty ? widget.settings.email : 'contact@smartpos.com');
    _addressCtrl = TextEditingController(
      text: widget.settings.address.isNotEmpty ? widget.settings.address : 'Commercial Plaza, Main Boulevard, Lahore',
    );
    _receiptFooterCtrl = TextEditingController(
      text: widget.settings.receiptFooter.isNotEmpty
          ? widget.settings.receiptFooter
          : 'Thank you for choosing Smart POS! Software Warranty & Hardware Guaranteed.',
    );
    _currencySymCtrl = TextEditingController(text: widget.settings.currencySymbol.isNotEmpty ? widget.settings.currencySymbol : 'Rs');
    _currencyCodeCtrl = TextEditingController(text: widget.settings.currencyCode.isNotEmpty ? widget.settings.currencyCode : 'PKR');
    _logoPath = widget.settings.logoPath;
    _timeZone = widget.settings.timeZone.isNotEmpty ? widget.settings.timeZone : 'Asia/Karachi';
    _selectedCurrency = RegionalDataService.findCurrency(_currencyCodeCtrl.text) ??
        RegionalDataService.findCurrency('PKR');

    // Parse business industry preset (Single exclusive selection from 16 models)
    final bType = widget.settings.businessType.toLowerCase();
    if (bType.isNotEmpty && allSupportedIndustries.any((i) => i.key == bType)) {
      _selectedPreset = bType;
    } else if (widget.settings.industryPresets.isNotEmpty) {
      final p = widget.settings.industryPresets.split(',').first.trim().toLowerCase();
      _selectedPreset = allSupportedIndustries.any((i) => i.key == p) ? p : 'universal';
    } else {
      _selectedPreset = 'universal';
    }

    // Step 3 controllers
    _deploymentMode = widget.settings.deploymentMode.isNotEmpty ? widget.settings.deploymentMode : 'offline_server';
    _primaryDbType = widget.settings.primaryDbType.isNotEmpty ? widget.settings.primaryDbType : 'mysql';
    _serverPortCtrl = TextEditingController(text: widget.settings.serverPort.toString());
    _lanHostCtrl = TextEditingController(text: widget.settings.dbHost.isNotEmpty ? widget.settings.dbHost : 'localhost');
    final defaultDbPort = _primaryDbType == 'postgresql' ? 5432 : 3306;
    _lanPortCtrl = TextEditingController(text: (widget.settings.dbPort > 0 ? widget.settings.dbPort : defaultDbPort).toString());
    _lanDbNameCtrl = TextEditingController(text: widget.settings.dbName.isNotEmpty ? widget.settings.dbName : 'smartpos');
    _lanDbUserCtrl = TextEditingController(
      text: widget.settings.dbUser.isNotEmpty ? widget.settings.dbUser : (_primaryDbType == 'postgresql' ? 'postgres' : 'root'),
    );
    _lanDbPassCtrl = TextEditingController(text: widget.settings.dbPassword);
    _cloudUrlCtrl = TextEditingController(
      text: widget.settings.syncServerUrl.isNotEmpty ? widget.settings.syncServerUrl : 'http://localhost:8000/api',
    );
    _cloudApiKeyCtrl = TextEditingController(text: widget.settings.syncApiKey);
    _cloudBranchIdCtrl = TextEditingController(text: widget.settings.syncBranchId.toString());

    // Step 4 controllers
    _adminNameCtrl = TextEditingController(text: 'Irfan Khan');
    _adminUserCtrl = TextEditingController(text: 'webdeventh');
    _adminEmailCtrl = TextEditingController(text: 'admin@smartpos.com');
    _adminPhoneCtrl = TextEditingController(text: '+92 300 1234567');
    _adminPassCtrl = TextEditingController(text: 'password');
    _adminConfirmPassCtrl = TextEditingController(text: 'password');

    _loadHardwareInfo();
  }

  @override
  void dispose() {
    _licenseKeyCtrl.dispose();
    _bizNameCtrl.dispose();
    _branchCtrl.dispose();
    _taxNumberCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _currencySymCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _serverPortCtrl.dispose();
    _lanHostCtrl.dispose();
    _lanPortCtrl.dispose();
    _lanDbNameCtrl.dispose();
    _lanDbUserCtrl.dispose();
    _lanDbPassCtrl.dispose();
    _cloudUrlCtrl.dispose();
    _cloudApiKeyCtrl.dispose();
    _cloudBranchIdCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminConfirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHardwareInfo() async {
    try {
      final hwid = await QulopService.getHardwareId();
      final mac = await QulopService.getDeviceMacAddress();
      if (mounted) {
        setState(() {
          _hardwareId = hwid;
          _macAddress = mac;
        });

        // If license key already exists, verify it right away
        if (_licenseKeyCtrl.text.trim().isNotEmpty) {
          _verifyLicenseKey(_licenseKeyCtrl.text.trim());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hardwareId = 'HWID-LOCAL-POS-DEV';
          _macAddress = 'C8-3A-35-1C-4B-40';
        });
      }
    }
  }

  Future<void> _verifyLicenseKey(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      setState(() {
        _licenseError = 'Please enter a valid Smart POS License Key.';
        _licenseStatus = null;
      });
      return;
    }

    setState(() {
      _isVerifyingLicense = true;
      _licenseError = null;
    });

    try {
      final status = await QulopService.verifyQulopKey(key);
      if (mounted) {
        setState(() {
          _isVerifyingLicense = false;
          _licenseStatus = status;
          if (!status.isValid) {
            _licenseError = status.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingLicense = false;
          _licenseError = 'Verification failed: $e';
        });
      }
    }
  }

  Future<void> _activateTrialKey() async {
    setState(() => _isVerifyingLicense = true);
    try {
      final trialKey = QulopService.generateHardwareBoundKey(
        clientName: _bizNameCtrl.text.trim().isNotEmpty ? _bizNameCtrl.text.trim() : 'Smart POS Evaluation',
        hardwareId: _hardwareId,
        tierCode: 'TRL',
      );
      _licenseKeyCtrl.text = trialKey;
      await _verifyLicenseKey(trialKey);
    } finally {
      if (mounted) setState(() => _isVerifyingLicense = false);
    }
  }

  void _copyHardwareId() {
    Clipboard.setData(ClipboardData(text: _hardwareId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Hardware ID copied: $_hardwareId'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changePrimaryDbType(String type) {
    setState(() {
      _primaryDbType = type;
      if (type == 'postgresql') {
        _lanPortCtrl.text = '5432';
        if (_lanDbUserCtrl.text == 'root' || _lanDbUserCtrl.text.isEmpty) {
          _lanDbUserCtrl.text = 'postgres';
        }
      } else if (type == 'mysql') {
        _lanPortCtrl.text = '3306';
        if (_lanDbUserCtrl.text == 'postgres' || _lanDbUserCtrl.text.isEmpty) {
          _lanDbUserCtrl.text = 'root';
        }
      }
    });
  }

  Future<void> _testNetworkConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionSuccess = null;
    });

    try {
      if (_primaryDbType == 'sqlite') {
        await Future.delayed(const Duration(milliseconds: 250));
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = true;
          _connectionTestResult = 'Local SQLite standalone active! Instant zero-latency offline POS ready.';
        });
        return;
      }

      final host = _lanHostCtrl.text.trim().isNotEmpty ? _lanHostCtrl.text.trim() : '127.0.0.1';
      final port = int.tryParse(_lanPortCtrl.text.trim()) ?? (_primaryDbType == 'postgresql' ? 5432 : 3306);
      final user = _lanDbUserCtrl.text.trim().isNotEmpty ? _lanDbUserCtrl.text.trim() : (_primaryDbType == 'postgresql' ? 'postgres' : 'root');
      final pass = _lanDbPassCtrl.text;
      final dbName = _lanDbNameCtrl.text.trim().isNotEmpty ? _lanDbNameCtrl.text.trim() : 'smartpos';

      if (_primaryDbType == 'mysql') {
        final res = await MySqlService.testConnection(
          host: host,
          port: port,
          user: user,
          password: pass,
          databaseName: dbName,
        );
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = res['success'] == true;
          _connectionTestResult = res['message'] as String;
        });
        return;
      }

      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
        socket.destroy();
        sw.stop();
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = true;
          _connectionTestResult = 'Connected to PostgreSQL Server at $host:$port (${sw.elapsedMilliseconds}ms)! Local SQLite offline sync buffer linked.';
        });
      } catch (_) {
        sw.stop();
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = false;
          _connectionTestResult = 'Notice: PostgreSQL at $host:$port is currently offline. SQLite will capture sales locally and sync queued records automatically when online.';
        });
      }
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionSuccess = false;
        _connectionTestResult = 'Database connection check: $e';
      });
    }
  }

  void _selectPreset(String presetKey) {
    setState(() {
      _selectedPreset = presetKey;
    });
  }

  String _determinePrimaryBusinessType() {
    switch (_selectedPreset) {
      case 'pharmacy':
        return 'pharmacy';
      case BusinessSettings.presetMobileElectronics:
      case 'mobile':
      case 'electronics':
        return 'mobile';
      case BusinessSettings.presetSolarHardware:
      case 'solar':
        return 'solar';
      case BusinessSettings.presetRestaurantCafe:
      case 'restaurant':
      case 'cafe':
        return 'restaurant';
      case 'universal':
        return 'universal';
      case 'custom_other':
      case 'other':
      case 'custom':
        return 'custom_other';
      case BusinessSettings.presetRetailSuperStore:
      case 'supermarket':
        return 'supermarket';
      case 'general_store':
      case 'kiryana':
        return 'general_store';
      case 'clothing':
      case 'garments':
        return 'clothing';
      case 'wholesale':
        return 'wholesale';
      case 'repair':
      case 'service':
        return 'repair';
      case 'hotel':
        return 'hotel';
      case 'gym':
        return 'gym';
      case 'manufacturing':
        return 'manufacturing';
      case 'fruit_wholesale':
      case 'fruit_mandi':
        return 'fruit_wholesale';
      case 'poultry':
        return 'poultry';
      case 'accounting_crm':
        return 'accounting_crm';
      case 'woocommerce':
        return 'woocommerce';
      case 'dairy_milk':
      case 'dairy':
        return 'dairy_milk';
      case 'tyres_battery':
      case 'tyres':
        return 'tyres_battery';
      case 'hardware_tools':
      case 'hardware':
        return 'hardware_tools';
      case 'auto_parts':
        return 'auto_parts';
      case 'meat_butchery':
      case 'meat':
        return 'meat_butchery';
      case 'fabrics_textile':
      case 'fabrics':
        return 'fabrics_textile';
      case 'lubricants_oil':
      case 'lubricants':
        return 'lubricants_oil';
      case 'sanitary_tiles':
      case 'sanitary':
        return 'sanitary_tiles';
      default:
        return _selectedPreset.isNotEmpty ? _selectedPreset : 'supermarket';
    }
  }

  List<String> _calculateEnabledModules() {
    final type = _determinePrimaryBusinessType();
    return BusinessSettings.defaultModulesForBusinessType(type);
  }

  Future<void> _completeInstallation() async {
    // Validate Step 4 password
    final pass = _adminPassCtrl.text.trim();
    final confirm = _adminConfirmPassCtrl.text.trim();
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password cannot be empty.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match. Please re-enter.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isSeeding = true;
      _seedStatus = 'Securing environment & initializing Smart POS enterprise database...';
    });

    try {
      final primaryType = _determinePrimaryBusinessType();
      final enabledModsList = _calculateEnabledModules();

      // Normalize dbHost if localhost or empty on Windows
      final rawHost = _lanHostCtrl.text.trim();
      final effectiveDbHost = MySqlService.normalizeHost(rawHost);

      final updated = BusinessSettings(
        id: widget.settings.id,
        businessName: _bizNameCtrl.text.trim().isNotEmpty ? _bizNameCtrl.text.trim() : 'Smart POS Enterprise',
        branchName: _branchCtrl.text.trim().isNotEmpty ? _branchCtrl.text.trim() : 'Main Branch HQ',
        currencySymbol: _currencySymCtrl.text.trim().isNotEmpty ? _currencySymCtrl.text.trim() : 'Rs',
        currencyCode: _currencyCodeCtrl.text.trim().isNotEmpty ? _currencyCodeCtrl.text.trim() : 'PKR',
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        taxNumber: _taxNumberCtrl.text.trim(),
        receiptFooter: _receiptFooterCtrl.text.trim(),
        purchaseKey: _licenseKeyCtrl.text.trim(),
        hardwareId: _hardwareId,
        businessType: primaryType,
        industryPresets: _selectedPresets.join(','),
        enabledModules: enabledModsList.join(','),
        deploymentMode: _deploymentMode,
        serverHost: _deploymentMode == 'lan_secondary' ? effectiveDbHost : '127.0.0.1',
        serverPort: int.tryParse(_deploymentMode == 'lan_secondary' ? _lanPortCtrl.text.trim() : _serverPortCtrl.text.trim()) ?? 8080,
        primaryDbType: _primaryDbType,
        dbHost: effectiveDbHost,
        dbPort: int.tryParse(_lanPortCtrl.text.trim()) ?? (_primaryDbType == 'postgresql' ? 5432 : 3306),
        dbName: _lanDbNameCtrl.text.trim().isNotEmpty ? _lanDbNameCtrl.text.trim() : 'smartpos',
        dbUser: _lanDbUserCtrl.text.trim().isNotEmpty ? _lanDbUserCtrl.text.trim() : (_primaryDbType == 'postgresql' ? 'postgres' : 'root'),
        dbPassword: _lanDbPassCtrl.text,
        syncMode: _deploymentMode == 'cloud_hybrid' ? 'hybrid' : 'offline',
        syncServerUrl: _cloudUrlCtrl.text.trim(),
        syncApiKey: _cloudApiKeyCtrl.text.trim(),
        syncBranchId: int.tryParse(_cloudBranchIdCtrl.text.trim()) ?? 1,
        timeZone: _timeZone,
        logoPath: _logoPath ?? '',
        isConfigured: true,
      );

      setState(() => _seedStatus = 'Writing system configuration and hardware profile...');
      final db = await DatabaseService.initialize();
      await db.updateBusinessSettings(updated);

      // Save superadmin user with salted SHA-256 password hashing
      final hashedPassword = AuthService.hashPassword(pass);
      final adminUser = User(
        name: _adminNameCtrl.text.trim().isNotEmpty ? _adminNameCtrl.text.trim() : 'Super Administrator',
        username: _adminUserCtrl.text.trim().isNotEmpty ? _adminUserCtrl.text.trim() : 'superadmin',
        password: hashedPassword,
        email: _adminEmailCtrl.text.trim(),
        phone: _adminPhoneCtrl.text.trim(),
        role: 'superadmin',
        status: 'active',
        branchId: 1,
        branchName: updated.branchName,
      );
      final savedUserId = await db.addUser(adminUser);
      final activeUser = adminUser.copyWith(id: savedUserId);

      // Audit initial setup event
      try {
        await db.logAuditAction(
          action: 'system_initialized',
          entityType: 'settings',
          entityId: '1',
          userName: adminUser.username,
          details: 'Smart POS initial installation wizard completed. Presets: ${_selectedPresets.join(", ")}.',
        );
      } catch (e) {
        debugPrint('Audit logging notice: $e');
      }

      BusinessSettings finalized = updated.copyWith(isConfigured: true);

      // 1. Seed initial data into local SQLite first if sample catalog requested
      if (_seedSampleData) {
        setState(() => _seedStatus = 'Seeding starter commercial catalog for "$primaryType" into local database...');
        await db.seedInitialDataForBusinessType(businessType: primaryType);
      }

      // 2. Provision MySQL enterprise schema and mirror catalog if MySQL is selected
      if (_primaryDbType == 'mysql') {
        setState(() => _seedStatus = 'Provisioning MySQL database "${updated.dbName}" on ${updated.dbHost}:${updated.dbPort}...');
        final mySqlRes = await MySqlService.initializeDatabaseAndTables(
          host: updated.dbHost,
          port: updated.dbPort,
          user: updated.dbUser,
          password: updated.dbPassword,
          databaseName: updated.dbName,
          initialSettings: updated,
          initialAdminUser: activeUser,
        );

        if (mySqlRes['success'] != true) {
          if (!mounted) throw Exception(mySqlRes['message'] ?? 'Failed to initialize MySQL schema.');
          
          final useSqliteFallback = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 10),
                  Text('MySQL Connection Notice'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mySqlRes['message']?.toString() ?? 'Unable to connect to MySQL database server.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?',
                      style: TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.4),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Back to Settings'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                  label: const Text('Switch to SQLite & Launch POS'),
                ),
              ],
            ),
          );

          if (useSqliteFallback == true) {
            _primaryDbType = 'sqlite';
            finalized = updated.copyWith(primaryDbType: 'sqlite', isConfigured: true);
            await db.updateBusinessSettings(finalized);
          } else {
            throw Exception(mySqlRes['message'] ?? 'Failed to initialize MySQL schema.');
          }
        } else {
          // MySQL provisioned successfully!
          // Push starter catalog (products, categories, brands, units, contacts) to MySQL
          if (_seedSampleData) {
            setState(() => _seedStatus = 'Synchronizing starter commercial catalog into MySQL tables...');
            await MySqlService.syncAllLocalCatalogToMySql(
              settings: updated,
              localDb: db,
            );
          }
        }
      }

      await db.updateBusinessSettings(finalized);

      // Explicitly ensure user is NOT auto-logged in, ensuring direct landing on Login Screen
      AuthService.currentUserNotifier.value = null;

      if (mounted) {
        setState(() {
          _isSeeding = false;
          _isInstallationComplete = true;
          _finalizedSettings = finalized;
        });
      }
    } catch (e, stack) {
      debugPrint('Setup wizard error: $e\n$stack');
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation Failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Installation Error'),
                    content: SingleChildScrollView(child: Text('$e\n\n$stack')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Step 1: Validate license
      if (_licenseStatus == null || !_licenseStatus!.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A verified License Key or Active Free Trial is required to proceed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Step 2: Validate business name
      if (_bizNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter Business / Store Name.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_selectedPresets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one Business Industry Preset.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else if (_currentStep == 2) {
      // Step 3: Validate network inputs
      if (_deploymentMode == 'lan_secondary' && _lanHostCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide Primary Server IP for LAN terminal mode.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            final isMobile = constraints.maxWidth < 500;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24,
                  vertical: isMobile ? 12 : 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 880),
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 16 : (isNarrow ? 22 : 32)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 28, offset: Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header Branding
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 8 : 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.point_of_sale_rounded, color: Colors.white, size: isMobile ? 22 : 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Smart POS',
                                      style: TextStyle(
                                        fontSize: isMobile ? 18 : 22,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'ENTERPRISE v2026',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Multi-Industry Commercial POS Ecosystem — Guided System Installation',
                                  style: TextStyle(fontSize: isMobile ? 11 : 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Responsive Step Progress Indicators
                      if (isNarrow)
                        Column(
                          children: [
                            Row(
                              children: [
                                _stepPill(0, '1. License Lock', Icons.verified_user_rounded, isDark),
                                const SizedBox(width: 8),
                                _stepPill(1, '2. Business & Presets', Icons.storefront_rounded, isDark),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _stepPill(2, '3. Topology & DB', Icons.hub_rounded, isDark),
                                const SizedBox(width: 8),
                                _stepPill(3, '4. Master Admin', Icons.admin_panel_settings_rounded, isDark),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            _stepPill(0, '1. License Lock', Icons.verified_user_rounded, isDark),
                            const SizedBox(width: 8),
                            _stepPill(1, '2. Business & Presets', Icons.storefront_rounded, isDark),
                            const SizedBox(width: 8),
                            _stepPill(2, '3. Topology & DB', Icons.hub_rounded, isDark),
                            const SizedBox(width: 8),
                            _stepPill(3, '4. Master Admin', Icons.admin_panel_settings_rounded, isDark),
                          ],
                        ),
                      const Divider(height: 32),

                // Step Content Body
                if (_isSeeding) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 4),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _seedStatus,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _primaryDbType == 'mysql'
                                ? 'Please wait, enterprise MySQL configuration & table provisioning in progress...'
                                : 'Please wait, high-speed database transaction in progress...',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_isInstallationComplete) ...[
                  _buildInstallationCompleteScreen(isDark),
                ] else if (_currentStep == 0) ...[
                  _buildStep1License(isDark),
                ] else if (_currentStep == 1) ...[
                  _buildStep2BusinessProfile(isDark),
                ] else if (_currentStep == 2) ...[
                  _buildStep3Topology(isDark),
                ] else ...[
                  _buildStep4Admin(isDark),
                ],

                // Bottom Action Buttons
                if (!_isSeeding && !_isInstallationComplete) ...[
                  const Divider(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: _prevStep,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton.icon(
                        onPressed: _currentStep == 3 ? _completeInstallation : _nextStep,
                        icon: Icon(_currentStep == 3 ? Icons.rocket_launch_rounded : Icons.arrow_forward, size: 18),
                        label: Text(_currentStep == 3 ? 'Complete Installation & Launch' : 'Continue to Next Step'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  ),
),
);
  }

  // ================= STEP 1: Hardware-Bound License Activation =================
  Widget _buildStep1License(bool isDark) {
    final isValid = _licenseStatus != null && _licenseStatus!.isValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text(
              'Step 1: Machine Hardware-Bound License Activation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine\'s Motherboard / MAC ID.',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        // Machine Hardware ID Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detected Host Machine Hardware ID (HWID):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _hardwareId,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'monospace'),
                    ),
                    if (_macAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Physical MAC: $_macAddress', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyHardwareId,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy HWID'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // License Key Input
        _fieldLabel('Smart POS Activation Key *', isDark),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _licenseKeyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. QULOP-LFT-XXXX-XXXX or SPOS-YRL-...',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) {
                  if (_licenseError != null) setState(() => _licenseError = null);
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isVerifyingLicense ? null : () => _verifyLicenseKey(_licenseKeyCtrl.text),
              icon: _isVerifyingLicense
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Verify & Activate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // One-Click Free Trial Alternative Button
        Row(
          children: [
            TextButton.icon(
              onPressed: _isVerifyingLicense ? null : _activateTrialKey,
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 18),
              label: const Text('Activate Instant 30-Day Free Trial (Hardware Bound)'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const Spacer(),
            Text('No internet required for activation', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 16),

        // License Status / Verification Result Banner
        if (_licenseError != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _licenseError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isValid && _licenseStatus != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _licenseStatus!.tierLabel,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('HARDWARE BOUND', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Licensed to: ${_licenseStatus!.clientName ?? "Registered Customer"} • ${_licenseStatus!.remainingDays} days remaining',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                      if (_licenseStatus!.expiryDate != null)
                        Text(
                          'Valid until: ${_licenseStatus!.expiryDate!.toIso8601String().split("T").first}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ================= STEP 2: Business Profile & Industry Presets =================
  Widget _buildStep2BusinessProfile(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text(
              'Step 2: Business Profile & Industry Workflows',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        // Business Profile Form with Logo Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Picker Card
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Business Logo', isDark),
                Container(
                  width: 140,
                  height: 125,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: (_logoPath != null && _logoPath!.isNotEmpty && File(_logoPath!).existsSync())
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_logoPath!),
                                  fit: BoxFit.contain,
                                  width: 128,
                                  height: 110,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => setState(() => _logoPath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload Logo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              Text(
                                'PNG, JPG, WEBP',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (_logoPath != null && _logoPath!.isNotEmpty && File(_logoPath!).existsSync()) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await NativeFileHelper.pickBusinessLogo();
                      if (picked != null) {
                        setState(() => _logoPath = picked);
                      }
                    },
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text('Change', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 16),

            // Store Name, Branch, NTN, and Phone
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Business / Store Name *', isDark),
                            TextFormField(
                              controller: _bizNameCtrl,
                              decoration: const InputDecoration(hintText: 'e.g. Al-Madina Super Store & Electronics', isDense: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Branch / Outlet', isDark),
                            TextFormField(
                              controller: _branchCtrl,
                              decoration: const InputDecoration(hintText: 'e.g. Main Branch HQ', isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('NTN / Tax ID', isDark),
                            TextFormField(
                              controller: _taxNumberCtrl,
                              decoration: const InputDecoration(hintText: 'e.g. NTN: 948102-1', isDense: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Contact Phone', isDark),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(hintText: '+92 300 1234567', isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Searchable Currency and Searchable Time Zone
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Searchable Currency Box
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('Official Currency *', isDark),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => CurrencySearchDialog(
                              initialCode: _currencyCodeCtrl.text,
                              onSelected: (info) {
                                setState(() {
                                  _selectedCurrency = info;
                                  _currencySymCtrl.text = info.symbol;
                                  _currencyCodeCtrl.text = info.code;
                                });
                              },
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Color(0xFF4F46E5)),
                            SizedBox(width: 4),
                            Text(
                              'Search 130+ Currencies',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => CurrencySearchDialog(
                          initialCode: _currencyCodeCtrl.text,
                          onSelected: (info) {
                            setState(() {
                              _selectedCurrency = info;
                              _currencySymCtrl.text = info.symbol;
                              _currencyCodeCtrl.text = info.code;
                            });
                          },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.coins,
                              color: Color(0xFF4F46E5),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _currencyCodeCtrl.text,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Symbol: ${_currencySymCtrl.text}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedCurrency?.name ?? 'Pakistani Rupee (Pakistan)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF4F46E5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Searchable Timezone Box
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('Regional Time Zone *', isDark),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => TimeZoneSearchDialog(
                              initialId: _timeZone,
                              onSelected: (tz) {
                                setState(() {
                                  _timeZone = tz.id;
                                });
                              },
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text(
                              'Search 80+ Timezones',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => TimeZoneSearchDialog(
                          initialId: _timeZone,
                          onSelected: (tz) {
                            setState(() {
                              _timeZone = tz.id;
                            });
                          },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.schedule, size: 18, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _timeZone,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        RegionalDataService.findTimeZone(_timeZone)?.offset ?? 'GMT+5',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  RegionalDataService.findTimeZone(_timeZone)?.city ?? _timeZone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF0284C7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Contact Email and Address
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Contact Email', isDark),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(hintText: 'admin@smartpos.com', isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Physical Address', isDark),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(hintText: 'Commercial Plaza, Sector 4, Main Boulevard', isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _fieldLabel('Receipt Footer Note', isDark),
        TextFormField(
          controller: _receiptFooterCtrl,
          decoration: const InputDecoration(hintText: 'Thank you for your business! Please visit again.', isDense: true),
        ),
        const SizedBox(height: 24),

        // Industry Presets Dropdown Selector (Single Exclusive Selection from all 16 supported models)
        Row(
          children: [
            const Icon(Icons.business_center_rounded, color: Color(0xFF4F46E5), size: 18),
            const SizedBox(width: 8),
            Text(
              'Select Business Industry Model (16 Supported Industries):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Text(
                '1 Business Model At A Time',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Dropdown Form Field for All 16 Business Models
        DropdownButtonFormField<String>(
          initialValue: allSupportedIndustries.any((i) => i.key == _selectedPreset) ? _selectedPreset : 'universal',
          decoration: InputDecoration(
            labelText: 'Business Industry / Domain Preset *',
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.category_rounded, color: Color(0xFF4F46E5)),
          ),
          isExpanded: true,
          items: allSupportedIndustries.map((ind) {
            return DropdownMenuItem<String>(
              value: ind.key,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ind.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FaIcon(ind.icon, size: 13, color: ind.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ind.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: ind.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ind.category,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ind.color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _selectPreset(val);
            }
          },
        ),
        const SizedBox(height: 12),

        // Selected Business Features Banner
        _buildSelectedIndustryPreviewCard(isDark),
        const SizedBox(height: 16),

        // Sample Data Seed Option
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _seedSampleData
                ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _seedSampleData
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: _seedSampleData ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _seedSampleData,
                onChanged: (val) => setState(() => _seedSampleData = val ?? false),
                activeColor: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Pre-load Starter Products, Categories & Suppliers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing. (تجرباتی اشیاء، کیٹیگریز اور سپلائرز شامل کریں تاکہ سسٹم فوراً تیار ہو)',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedIndustryPreviewCard(bool isDark) {
    final ind = allSupportedIndustries.firstWhere(
      (i) => i.key == _selectedPreset,
      orElse: () => allSupportedIndustries.first,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ind.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ind.color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(ind.icon, color: ind.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ind.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ind.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTIVE EXCLUSIVE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: ind.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ind.features,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 3: Network Topology & Hybrid Database Engine =================
  Widget _buildStep3Topology(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.hub_rounded, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text(
              'Step 3: Network Topology & Hybrid Database Engine',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        // 3 Topology Mode Cards
        Row(
          children: [
            Expanded(
              child: _topologyModeCard(
                mode: 'offline_server',
                title: 'Mode 1: Offline Primary Server',
                badge: 'Default / Recommended',
                desc: 'Runs locally on this PC using high-speed MySQL/SQLite. Hosts embedded REST/WebSocket API server for LAN terminals and Mobile Apps.',
                icon: Icons.dns_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _topologyModeCard(
                mode: 'lan_secondary',
                title: 'Mode 2: Offline LAN Secondary',
                badge: 'Client Terminal',
                desc: 'Connects over local Wi-Fi / Ethernet to Primary Server PC. Instant shared stock & billing with zero internet required.',
                icon: Icons.computer_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _topologyModeCard(
                mode: 'cloud_hybrid',
                title: 'Mode 3: Online Cloud-Synced',
                badge: 'Multi-Branch Cloud',
                desc: 'Syncs with remote Laravel/MySQL cloud server. Works offline with SQLite queue and auto-syncs when internet restores.',
                icon: Icons.cloud_sync_rounded,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Mode-Specific Details
        if (_deploymentMode == 'offline_server') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text('Primary Server & Mobile REST API Server Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Local Embedded API Server Port', isDark),
                          TextFormField(
                            controller: _serverPortCtrl,
                            decoration: const InputDecoration(hintText: '8080', isDense: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC\'s local IP and port.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (_deploymentMode == 'lan_secondary') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connect to Primary Server Machine:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Primary Server Local IP *', isDark),
                          TextFormField(
                            controller: _lanHostCtrl,
                            decoration: const InputDecoration(hintText: '192.168.1.100', isDense: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('API Port', isDark),
                          TextFormField(
                            controller: _lanPortCtrl,
                            decoration: const InputDecoration(hintText: '8080', isDense: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cloud Sync Server Configuration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Remote Cloud API URL *', isDark),
                          TextFormField(
                            controller: _cloudUrlCtrl,
                            decoration: const InputDecoration(hintText: 'https://api.smartpos.com/api', isDense: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Branch ID', isDark),
                          TextFormField(
                            controller: _cloudBranchIdCtrl,
                            decoration: const InputDecoration(hintText: '1', isDense: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _fieldLabel('Cloud API Secret Key', isDark),
                TextFormField(
                  controller: _cloudApiKeyCtrl,
                  decoration: const InputDecoration(hintText: 'Bearer token or API Secret Key', isDense: true),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Primary Central Database Selection (Admin Choice)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storage_rounded, color: Color(0xFF4F46E5), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Primary Central Database Engine (Admin Choice)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // 3 Engine Selector Cards (Responsive)
              LayoutBuilder(
                builder: (context, dbConstraints) {
                  final isDbStack = dbConstraints.maxWidth < 620;

                  final mysqlCard = _dbEngineSelectorCard(
                    type: 'mysql',
                    title: 'MySQL / MariaDB',
                    badge: 'Recommended',
                    port: '3306',
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  );
                  final postgresCard = _dbEngineSelectorCard(
                    type: 'postgresql',
                    title: 'PostgreSQL',
                    badge: 'Enterprise',
                    port: '5432',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  );
                  final sqliteCard = _dbEngineSelectorCard(
                    type: 'sqlite',
                    title: 'SQLite Standalone',
                    badge: 'Local Embedded',
                    port: 'Embedded',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  );

                  if (isDbStack) {
                    return Column(
                      children: [
                        mysqlCard,
                        const SizedBox(height: 10),
                        postgresCard,
                        const SizedBox(height: 10),
                        sqliteCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: mysqlCard),
                      const SizedBox(width: 12),
                      Expanded(child: postgresCard),
                      const SizedBox(width: 12),
                      Expanded(child: sqliteCard),
                    ],
                  );
                },
              ),

              if (_primaryDbType != 'sqlite') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Primary Database Host / IP', isDark),
                          TextFormField(
                            controller: _lanHostCtrl,
                            decoration: const InputDecoration(hintText: 'localhost or 192.168.1.100', isDense: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Port', isDark),
                          TextFormField(
                            controller: _lanPortCtrl,
                            decoration: InputDecoration(
                              hintText: _primaryDbType == 'postgresql' ? '5432' : '3306',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Database Name', isDark),
                          TextFormField(
                            controller: _lanDbNameCtrl,
                            decoration: const InputDecoration(hintText: 'smartpos', isDense: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('DB Username', isDark),
                          TextFormField(
                            controller: _lanDbUserCtrl,
                            decoration: InputDecoration(
                              hintText: _primaryDbType == 'postgresql' ? 'postgres' : 'root',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('DB Password', isDark),
                          TextFormField(
                            controller: _lanDbPassCtrl,
                            obscureText: _obscureLanDbPass,
                            decoration: InputDecoration(
                              hintText: 'Leave empty if no password',
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureLanDbPass ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureLanDbPass = !_obscureLanDbPass;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password (leave DB Password completely empty). Or use username "smartpos" with password "smartpos123".',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Architecture Resilience Callout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline-First Local SQLite Sync Guarantee',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All point-of-sale transactions write to SQLite locally first. Even if your central ${_primaryDbType.toUpperCase()} server or network is temporarily down, cashiers can continue billing without interruption. Queued sales sync automatically once the central database reconnects.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
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

        const SizedBox(height: 16),

        // Test Connection Action
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testNetworkConnection,
              icon: _isTestingConnection
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.network_check_rounded, size: 18),
              label: Text(_primaryDbType == 'sqlite' ? 'Check Local Engine' : 'Test $_primaryDbType Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 16),
            if (_connectionTestResult != null)
              Expanded(
                child: Text(
                  _connectionTestResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (_connectionSuccess == true) ? const Color(0xFF10B981) : Colors.orangeAccent,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dbEngineSelectorCard({
    required String type,
    required String title,
    required String badge,
    required String port,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _primaryDbType == type;
    return InkWell(
      onTap: () => _changePrimaryDbType(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? color : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Port: $port',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topologyModeCard({
    required String mode,
    required String title,
    required String badge,
    required String desc,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _deploymentMode == mode;

    return InkWell(
      onTap: () => setState(() {
        _deploymentMode = mode;
        _connectionTestResult = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 170,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.6) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? const Color(0xFF4F46E5) : Colors.grey, size: 22),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                desc,
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= STEP 4: Super Admin Account Creation =================
  Widget _buildStep4Admin(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text(
              'Step 4: Super Admin Master Credentials',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Create the master owner/superadmin account. Passwords are encrypted using strong salted SHA-256 before saving to database.',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Admin Full Name *', isDark),
                  TextFormField(
                    controller: _adminNameCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Irfan Khan', prefixIcon: Icon(Icons.person, size: 18), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Master Username *', isDark),
                  TextFormField(
                    controller: _adminUserCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. webdeventh / admin', prefixIcon: Icon(Icons.alternate_email, size: 18), isDense: true),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Email Address', isDark),
                  TextFormField(
                    controller: _adminEmailCtrl,
                    decoration: const InputDecoration(hintText: 'admin@smartpos.com', prefixIcon: Icon(Icons.email, size: 18), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Mobile Number', isDark),
                  TextFormField(
                    controller: _adminPhoneCtrl,
                    decoration: const InputDecoration(hintText: '+92 300 1234567', prefixIcon: Icon(Icons.phone, size: 18), isDense: true),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Master Password *', isDark),
                  TextFormField(
                    controller: _adminPassCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      hintText: 'Enter strong password',
                      prefixIcon: const Icon(Icons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Confirm Master Password *', isDark),
                  TextFormField(
                    controller: _adminConfirmPassCtrl,
                    obscureText: _obscureConfirmPass,
                    decoration: InputDecoration(
                      hintText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Security Shield Active: Passwords are encrypted using SHA-256 with cryptographic salt before being stored in local SQLite.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= UI Helper Widgets =================
  Widget _stepPill(int step, String label, IconData icon, bool isDark) {
    final isActive = !_isInstallationComplete && _currentStep == step;
    final isDone = _isInstallationComplete || _currentStep > step;

    return Expanded(
      child: InkWell(
        onTap: () {
          // Allow jumping back to earlier steps only before completion
          if (!_isInstallationComplete && step < _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4F46E5)
                : isDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF4F46E5)
                  : isDone
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : isDone
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? Colors.white
                        : isDone
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallationCompleteScreen(bool isDark) {
    final primaryType = _selectedPreset.replaceAll('preset_', '').replaceAll('_', ' ').toUpperCase();
    final dbModeStr = _primaryDbType == 'mysql'
        ? 'Enterprise Primary Server (MySQL: ${_lanDbNameCtrl.text.trim()} @ ${_lanHostCtrl.text.trim()}:${_lanPortCtrl.text.trim()})'
        : 'High-Speed Embedded SQLite Database Engine';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Success Icon Badge
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF10B981), width: 3),
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 46),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Installation & Setup Completed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'سسٹم کی تنصیب اور ڈیٹا بیس کنفیگریشن کامیابی سے مکمل ہو چکی ہے',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Summary details card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.storefront_rounded,
                  label: 'Store / Business Name',
                  value: _bizNameCtrl.text.trim().isNotEmpty ? _bizNameCtrl.text.trim() : 'Smart POS Retail',
                  isDark: isDark,
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  icon: Icons.category_rounded,
                  label: 'Industry Profile',
                  value: '$primaryType Presets & Modules',
                  isDark: isDark,
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  icon: Icons.dns_rounded,
                  label: 'Database Engine',
                  value: dbModeStr,
                  isDark: isDark,
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  icon: Icons.inventory_2_rounded,
                  label: 'Commercial Catalog',
                  value: _seedSampleData
                      ? 'Starter products, categories & suppliers pre-loaded'
                      : 'Clean blank database initialized',
                  isDark: isDark,
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Master Admin Username',
                  value: _adminUserCtrl.text.trim().isNotEmpty ? _adminUserCtrl.text.trim() : 'superadmin',
                  isDark: isDark,
                  isHighlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Security Login Instructions Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF4F46E5), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Login Bypassed for Security',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials ("${_adminUserCtrl.text.trim().isNotEmpty ? _adminUserCtrl.text.trim() : "superadmin"}").',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Proceed to Login Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                AuthService.currentUserNotifier.value = null;
                if (_finalizedSettings != null) {
                  widget.onSetupComplete(_finalizedSettings!);
                }
              },
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text(
                'Proceed to Login Screen (لاگ ان اسکرین پر جائیں)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isHighlight ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }
}
