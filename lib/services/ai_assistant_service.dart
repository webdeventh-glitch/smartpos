import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';

class AiAssistantService {
  /// Calls Google Gemini API or OpenAI API based on the admin's configured credentials
  static Future<String> generate({
    required String prompt,
    AiSettings? settingsOverride,
    String? systemInstruction,
  }) async {
    final db = await DatabaseService.initialize();
    final aiSettings = settingsOverride ?? await db.getAiSettings();

    if (!aiSettings.hasValidKey) {
      return _generateOfflineFallback(prompt);
    }

    try {
      if (aiSettings.provider == 'openai') {
        return await _callOpenAi(aiSettings, prompt, systemInstruction);
      } else {
        return await _callGemini(aiSettings, prompt, systemInstruction);
      }
    } catch (e) {
      return 'AI Connection Error: ${e.toString()}\n\n'
          'Fallback Analysis:\n${_generateOfflineFallback(prompt)}';
    }
  }

  /// Calls Google Gemini API (gemini-1.5-flash or gemini-1.5-pro)
  static Future<String> _callGemini(
    AiSettings settings,
    String prompt,
    String? systemInstruction,
  ) async {
    final model = settings.modelName.isNotEmpty ? settings.modelName : 'gemini-1.5-flash';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${settings.apiKey.trim()}',
    );

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      }
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String? ?? 'No response generated.';
        }
      }
      return 'Empty response from Gemini API.';
    } else {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Calls OpenAI API (gpt-4o-mini or gpt-4o)
  static Future<String> _callOpenAi(
    AiSettings settings,
    String prompt,
    String? systemInstruction,
  ) async {
    final model = settings.modelName.isNotEmpty ? settings.modelName : 'gpt-4o-mini';
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final messages = [
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        {'role': 'system', 'content': systemInstruction},
      {'role': 'user', 'content': prompt},
    ];

    final payload = {
      'model': model,
      'messages': messages,
      'temperature': 0.4,
      'max_tokens': 1024,
    };

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey.trim()}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final msg = choices[0]['message'] as Map<String, dynamic>?;
        return msg?['content'] as String? ?? 'No response generated.';
      }
      return 'Empty response from OpenAI.';
    } else {
      throw Exception('OpenAI HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Executive AI financial and operational explainer for store reports
  static Future<String> explainBusinessReports({
    required Map<String, dynamic> report,
    required List<Map<String, dynamic>> expiries,
    required List<Product> lowStock,
    required BusinessSettings settings,
    AiSettings? aiSettings,
  }) async {
    final cur = settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs';
    final totalSales = (report['totalSales'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (report['netProfit'] as num?)?.toDouble() ?? 0.0;
    final marginPercent = totalSales > 0 ? ((netProfit / totalSales) * 100).toStringAsFixed(1) : '0.0';
    final totalPurchases = (report['totalPurchases'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (report['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final totalDues = (report['totalCustomerDues'] as num?)?.toDouble() ?? 0.0;

    final expiredCount = expiries.where((e) => e['risk_category'] == 'expired').length;
    final critical30Count = expiries.where((e) => e['risk_category'] == '30_days').length;
    double costAtRisk = 0.0;
    for (final e in expiries) {
      if (e['risk_category'] == 'expired' || e['risk_category'] == '30_days') {
        costAtRisk += (e['cost_value_at_risk'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final prompt = '''
Store Name: ${settings.businessName} (${settings.branchName})
Currency: $cur
Total Sales: $cur ${totalSales.toStringAsFixed(2)}
Total Purchases: $cur ${totalPurchases.toStringAsFixed(2)}
Total Expenses: $cur ${totalExpenses.toStringAsFixed(2)}
Net Profit: $cur ${netProfit.toStringAsFixed(2)} (Net Margin: $marginPercent%)
Pending Customer Khata Dues: $cur ${totalDues.toStringAsFixed(2)}
Inventory Alert: ${lowStock.length} items low or out of stock.
Stock Expiry Alert: $expiredCount batches already expired, $critical30Count batches expiring within 30 days. Total Cost at Risk: $cur ${costAtRisk.toStringAsFixed(2)}.

Task:
Please provide an executive summary and business advisory for the store owner in natural, professional Roman Urdu (with clear headings and bullet points):
1. Financial Health & Profitability (Sales aur Net Profit ka tajziya)
2. Inventory & Expiry Risks (Kahan nuqsan ya phansa hua paisa hai)
3. 3 Actionable Recommendations (Shop owner ko agle hafte kya karna chahiye: promotions, recovery, reordering).
''';

    const systemInstruction = 'You are Smart POS Enterprise AI Business Advisor. '
        'Provide concise, empowering, data-driven financial advice in Roman Urdu. Use bullet points and clean structure.';

    return await generate(
      prompt: prompt,
      settingsOverride: aiSettings,
      systemInstruction: systemInstruction,
    );
  }

  /// Interactive POS Help Chatbot (Answers how to use software & shortcut keys)
  static Future<String> chatWithPosHelper({
    required String question,
    required BusinessSettings settings,
    AiSettings? aiSettings,
  }) async {
    final prompt = '''
User Question: "$question"

Software Context:
- App: Smart POS Retail & Systems v1.0
- Business: ${settings.businessName}
- Shortcuts:
  * F1: Open POS Terminal / Barcode Scanner Focus
  * F2: Instant Cash Checkout (Fast Bill)
  * F3: Search / Switch Customer
  * F4: Suspend / Hold Order
  * F7: Split / Multiple Payment Methods
  * F8: Reset POS Order
  * F9: Recent Transactions & Drafts Resume
  * F10: Cash Register Till & Shift Reconciliation
  * F12: Switch Retail / Wholesale Mode

Answer the user directly and helpfully in natural Roman Urdu. If they ask about software operations, give exact steps and shortcut keys.
''';

    const systemInstruction = 'You are the official Smart POS AI Support Assistant. Help the cashier or store manager operate the desktop POS smoothly.';

    return await generate(
      prompt: prompt,
      settingsOverride: aiSettings,
      systemInstruction: systemInstruction,
    );
  }

  /// Rule-based fallback summary when no AI key is configured or offline
  static String _generateOfflineFallback(String prompt) {
    return 'Smart POS Automated Analytics Engine (Offline Mode)\n\n'
        '1. Financial Performance: Store metrics have been calculated from local database transactions.\n'
        '2. Inventory Safety: Keep buffer stock for high-velocity items and review impending batch expirations in Advanced Reports.\n'
        '3. Cash Flow: Monitor customer credit ledgers (Khata) and schedule recovery reminders via SMS & WhatsApp.\n\n'
        'Note: To unlock live Generative AI summaries powered by Google Gemini or OpenAI, '
        'open Settings > AI Assistant and enter your free API key from Google AI Studio.';
  }
}

