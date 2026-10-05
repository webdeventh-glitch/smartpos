import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/database_service.dart';
import 'screens/main_shell.dart';
import 'pos_workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UltimatePosApp());
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
        theme: ThemeData(useMaterial3: true),
        home: PosWorkspace(store: store),
      );
    }
    return const UltimatePosApp();
  }
}

class UltimatePosApp extends StatelessWidget {
  const UltimatePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultimate POS - Enterprise ERP & Point of Sale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004EEB),
          primary: const Color(0xFF004EEB),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF004EEB), width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const _DatabaseInitializer(),
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
    return await dbService.getBusinessSettings();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BusinessSettings>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF004EEB)),
                  SizedBox(height: 20),
                  Text(
                    'ULTIMATE POS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Loading local database & initializing store environment...',
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
                      onPressed: () => setState(() => _initFuture = _bootstrap()),
                      child: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MainShell(initialSettings: snapshot.data ?? BusinessSettings());
      },
    );
  }
}
