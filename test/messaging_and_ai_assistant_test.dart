import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/messaging_service.dart';
import 'package:desktop_starter/services/ai_assistant_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Messaging (SMS / WhatsApp) & AI Assistant Integration Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('messaging_ai_test_');
      dbPath = path.join(tempDir.path, 'pos_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Pakistani Phone Number Formatting: Converts 03xx to international 923xx', () {
      expect(MessagingService.formatPhoneNumber('03001234567'), '923001234567');
      expect(MessagingService.formatPhoneNumber('3001234567'), '923001234567');
      expect(MessagingService.formatPhoneNumber('+92 321-9876543'), '923219876543');
      expect(MessagingService.formatPhoneNumber('00923331122334'), '923331122334');
      expect(MessagingService.formatPhoneNumber('03001234567', international: false), '03001234567');
    });

    test('2. SMS Gateways Full CRUD & Message Logging', () async {
      // 1. Check default seeded gateways
      final initialGateways = await dbService.getSmsGateways();
      expect(initialGateways, isNotEmpty);

      // 2. Add custom Pakistani Branded SMS Gateway
      final newGateway = SmsGateway(
        name: 'Ufone Corporate Messaging',
        provider: 'ufone',
        apiUrl: 'https://ufone.api.domain/sms?to={to}&msg={message}&mask={mask}&key={key}',
        apiKey: 'ufone_test_key_123',
        senderId: 'MYBRAND',
        httpMethod: 'GET',
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      final gwId = await dbService.addSmsGateway(newGateway);
      expect(gwId, greaterThan(0));

      final allGws = await dbService.getSmsGateways();
      final savedGw = allGws.firstWhere((g) => g.id == gwId);
      expect(savedGw.name, 'Ufone Corporate Messaging');
      expect(savedGw.senderId, 'MYBRAND');

      // 3. Update gateway
      final updatedGw = savedGw.copyWith(senderId: 'SUPERPOS', httpMethod: 'POST');
      await dbService.updateSmsGateway(updatedGw);

      final refetched = (await dbService.getSmsGateways()).firstWhere((g) => g.id == gwId);
      expect(refetched.senderId, 'SUPERPOS');
      expect(refetched.httpMethod, 'POST');

      // 4. Record and retrieve outgoing message logs
      final logId = await dbService.addMessageLog(MessageLog(
        recipientName: 'Muhammad Ali',
        phoneNumber: '923001234567',
        channel: 'sms',
        messageBody: 'Your bill #INV-1001 for Rs 4,500 has been generated. Thank you!',
        status: 'sent',
        gatewayName: 'Ufone Corporate Messaging',
        createdAt: DateTime.now().toIso8601String(),
      ));
      expect(logId, greaterThan(0));

      final logs = await dbService.getMessageLogs(limit: 10);
      expect(logs, isNotEmpty);
      expect(logs.first.recipientName, 'Muhammad Ali');
      expect(logs.first.status, 'sent');
    });

    test('3. WhatsApp & SMS Bill Message Template Formatter', () async {
      final initialSettings = await dbService.getBusinessSettings();
      final settings = initialSettings.copyWith(
        businessName: 'Al-Madina Pharmacy & Superstore',
        currencySymbol: 'Rs',
        phone: '+92 300 1234567',
      );

      final sale = Sale(
        invoiceNo: 'INV-2026-0042',
        customerName: 'Tariq Mehmood',
        subtotal: 1200.0,
        discount: 100.0,
        totalAmount: 1100.0,
        paidAmount: 1000.0,
        paymentMethod: 'cash',
        paymentStatus: 'partial',
        createdAt: '2026-11-10 11:30',
      );

      final receiptText = MessagingService.formatSaleReceiptMessage(
        sale: sale,
        settings: settings,
      );

      expect(receiptText.contains('Al-Madina Pharmacy & Superstore'), isTrue);
      expect(receiptText.contains('INV-2026-0042'), isTrue);
      expect(receiptText.contains('Tariq Mehmood'), isTrue);
      expect(receiptText.contains('Total Amount: Rs 1100.00'), isTrue);
      expect(receiptText.contains('Pending Due: Rs 100.00'), isTrue);

      final reminderText = MessagingService.formatDuePaymentReminder(
        customerName: 'Tariq Mehmood',
        dueAmount: 5000.0,
        settings: settings,
        invoiceNo: 'INV-2026-0042',
      );

      expect(reminderText.contains('Tariq Mehmood'), isTrue);
      expect(reminderText.contains('Rs 5000.00'), isTrue);
      expect(reminderText.contains('Al-Madina Pharmacy'), isTrue);
    });

    test('4. AI Assistant Settings & Business Analytics Engine', () async {
      // 1. Default AI settings
      final aiSettings = await dbService.getAiSettings();
      expect(aiSettings.provider, 'gemini');
      expect(aiSettings.modelName, 'gemini-1.5-flash');

      // 2. Save Custom API key
      final updatedAi = aiSettings.copyWith(
        apiKey: 'AIzaSyFakeKeyTest123456789',
        preferredLanguage: 'roman_urdu',
        isEnabled: true,
      );
      await dbService.saveAiSettings(updatedAi);

      final savedAi = await dbService.getAiSettings();
      expect(savedAi.apiKey, 'AIzaSyFakeKeyTest123456789');
      expect(savedAi.hasValidKey, isTrue);

      // 3. Fallback / Rule-based Analytics Engine Verification
      final baseSettings = await dbService.getBusinessSettings();
      final settings = baseSettings.copyWith(
        businessName: 'Royal Electronics & Solar Solutions',
      );

      final explanation = await AiAssistantService.explainBusinessReports(
        report: {
          'totalSales': 450000.0,
          'netProfit': 85000.0,
          'totalPurchases': 320000.0,
          'totalExpenses': 25000.0,
          'totalCustomerDues': 60000.0,
        },
        expiries: [
          {'risk_category': '30_days', 'cost_value_at_risk': 15000.0},
        ],
        lowStock: [],
        settings: settings,
      );

      expect(explanation, isNotEmpty);

      // 4. POS Helper Query
      final helperResponse = await AiAssistantService.chatWithPosHelper(
        question: 'What is F1 and F2 shortcut for?',
        settings: settings,
      );
      expect(helperResponse, isNotEmpty);
    });
  });
}

