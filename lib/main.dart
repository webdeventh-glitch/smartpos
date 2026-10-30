import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/qulop_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/local_api_service.dart';
import 'services/mysql_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/qulop_lockout_screen.dart';
import 'screens/setup/setup_wizard_screen.dart';
import 'screens/main_shell.dart';
import 'pos_workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartPosApp());
}

/// Backward compatibility wrapper for existing tests
class DesktopStarterApp extends StatelessWidget {
  final dynamic store;
  const DesktopStarterApp({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    if (store != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeService.lightTheme,
        darkTheme: ThemeService.darkTheme,
        home: PosWorkspace(store: store),
      );
    }
    return const SmartPosApp();
  }
}

class SmartPosApp extends StatelessWidget {
  const SmartPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Smart POS System - Advanced ERP & Retail Terminal',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          scrollBehavior: ThemeService.scrollBehavior,
          home: const _DatabaseInitializer(),
        );
      },
    );
  }
}

class _DatabaseInitializer extends StatefulWidget {
  const _DatabaseInitializer();

  @override
  State<_DatabaseInitializer> createState() => _DatabaseInitializerState();
}

class _DatabaseInitializerState extends State<_DatabaseInitializer> {
  late Future<BusinessSettings> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  Future<BusinessSettings> _bootstrap() async {
    final dbService = await DatabaseService.initialize();
    var settings = await dbService.getBusinessSettings();

    // Primary Database Sync:
    // If configured and MySQL is selected, connect and sync seamlessly without ever wiping local business data
    if (settings.isConfigured && settings.isMySql) {
      try {
        final isConfiguredInMySql = await MySqlService.isMySqlDatabaseConfigured(settings);
        if (isConfiguredInMySql) {
          await MySqlService.pullDataFromMySql(settings: settings, localDb: dbService);
          await MySqlService.connectAndSync(settings: settings, localDb: dbService);
        } else if (MySqlService.isMySqlOnline.value) {
          debugPrint('[SmartPOS] MySQL is online but uninitialized. Syncing local configuration to MySQL...');
          try {
            await MySqlService.initializeDatabaseAndTables(
              host: settings.dbHost,
              port: settings.dbPort > 0 ? settings.dbPort : 3306,
              user: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
              password: settings.dbPassword,
              databaseName: settings.dbName,
              initialSettings: settings,
            );
            await MySqlService.syncAllLocalCatalogToMySql(settings: settings, localDb: dbService);
            await MySqlService.connectAndSync(settings: settings, localDb: dbService);
          } catch (e) {
            debugPrint('[SmartPOS] Failed to auto-provision MySQL: $e. Operating in resilient local SQLite mode.');
          }
        } else {
          debugPrint('[SmartPOS] MySQL database not yet configured or offline. Operating in resilient local SQLite mode.');
        }
      } catch (e) {
        debugPrint('[SmartPOS] MySQL sync notice: $e. Operating in local SQLite mode.');
      }
    }
    await QulopService.checkCurrentQulop(settings);
    await CloudSyncService.initialize(settings);
    try {
      if (settings.isPrimaryServer && !LocalApiService.instance.isRunning) {
        await LocalApiService.instance.startServer(port: settings.serverPort);
      }
    } catch (_) {}
    return settings;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BusinessSettings>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0038B8), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0x660038B8), blurRadius: 20, offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFF0038B8), strokeWidth: 3),
                  const SizedBox(height: 20),
                  const Text(
                    'SMART POS SYSTEM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connecting to Primary Database Engine & initializing terminal environment...',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to Initialize Database',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
                      onPressed: () => setState(() => _initFuture = _bootstrap()),
                      child: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final settings = snapshot.data ?? BusinessSettings();

        // First-Time Setup Wizard Check
        if (!settings.isConfigured) {
          return SetupWizardScreen(
            settings: settings,
            onSetupComplete: (configuredSettings) {
              setState(() => _initFuture = _bootstrap());
            },
          );
        }

        // Qulop SaaS Engine Gate (Enforces 30-day Trial & Paid Subscription)
        return ValueListenableBuilder<QulopStatus?>(
          valueListenable: QulopService.qulopNotifier,
          builder: (context, qulopStatus, _) {
            if (qulopStatus != null && !qulopStatus.isValid) {
              return QulopLockoutScreen(
                settings: settings,
                onLicenseActivated: (updatedSettings) {
                  setState(() => _initFuture = _bootstrap());
                },
              );
            }

            // Executive Authentication Session Gate
            return ValueListenableBuilder<User?>(
              valueListenable: AuthService.currentUserNotifier,
              builder: (context, currentUser, _) {
                if (currentUser == null) {
                  return LoginScreen(
                    settings: settings,
                    onLoginSuccess: () {
                      // AuthService updates currentUserNotifier automatically
                    },
                    onReconfigureDatabase: () {
                      setState(() => _initFuture = _bootstrap());
                    },
                  );
                }
                return MainShell(initialSettings: settings);
              },
            );
          },
        );
      },
    );
  }
}
