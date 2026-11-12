import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import 'base_repository.dart';

class _ReportCacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  const _ReportCacheEntry(this.data, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Manages dashboard KPIs, P&L, stock valuation, expiry traceability, register shifts, and trend analytics.
class ReportRepository extends BaseRepository {
  const ReportRepository([super.dbService]);

  static final Map<String, _ReportCacheEntry> _queryCache = {};
  static const Duration _cacheTtl = Duration(seconds: 30);

  static void clearCache() => _queryCache.clear();

  static T? _getCached<T>(String key) {
    final entry = _queryCache[key];
    if (entry != null && entry.isValid && entry.data is T) {
      return entry.data as T;
    }
    return null;
  }

  static void _putCached(String key, dynamic data) {
    _queryCache[key] = _ReportCacheEntry(data, DateTime.now().add(_cacheTtl));
  }

  /// Ultimate POS Register & Cashier Shift Report
  Future<List<Map<String, dynamic>>> getRegisterReport({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? cashierName,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (status != null && status != 'all' && status.isNotEmpty) {
      conditions.add('status = ?');
      args.add(status);
    }

    if (cashierName != null && cashierName.trim().isNotEmpty) {
      conditions.add('cashier_name LIKE ?');
      args.add('%${cashierName.trim()}%');
    }

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd 00:00:00').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd 23:59:59').format(endDate);
      conditions.add('opened_at >= ? AND opened_at <= ?');
      args.addAll([startStr, endStr]);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery(
      'SELECT * FROM cash_registers $whereClause ORDER BY id DESC',
      args,
    );

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final opening = (map['opening_amount'] as num?)?.toDouble() ?? 0.0;
      final cashSales = (map['total_sales_cash'] as num?)?.toDouble() ?? 0.0;
      final cardSales = (map['total_sales_card'] as num?)?.toDouble() ?? 0.0;
      final otherSales = (map['total_sales_other'] as num?)?.toDouble() ?? 0.0;
      final closing = (map['closing_amount'] as num?)?.toDouble() ?? 0.0;
      final st = (map['status'] as String?) ?? 'closed';

      final totalSales = cashSales + cardSales + otherSales;
      final expectedCash = opening + cashSales;
      final diff = st == 'closed' ? (closing - expectedCash) : 0.0;

      map['total_sales'] = totalSales;
      map['expected_cash'] = expectedCash;
      map['difference'] = diff;
      return map;
    }).toList();
  }

  /// Ultimate POS Stock Expiry & Batch Traceability Report
  Future<List<Map<String, dynamic>>> getStockExpiryReport({
    String? filter,
    String? searchQuery,
  }) async {
    final rows = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.name as product_name,
        p.sku,
        p.barcode,
        p.batch_number,
        p.expiry_date,
        p.stock_quantity,
        p.purchase_price,
        p.selling_price,
        c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.expiry_date IS NOT NULL 
        AND TRIM(p.expiry_date) != '' 
        AND p.stock_quantity > 0
      ORDER BY p.name ASC
    ''');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = <Map<String, dynamic>>[];

    for (final r in rows) {
      final pName = (r['product_name'] as String?) ?? 'Product';
      final sku = (r['sku'] as String?) ?? '';
      final batch = (r['batch_number'] as String?) ?? '-';
      final expStr = (r['expiry_date'] as String?) ?? '';
      final stockQty = (r['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (r['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final price = (r['selling_price'] as num?)?.toDouble() ?? 0.0;

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final match = pName.toLowerCase().contains(q) ||
            sku.toLowerCase().contains(q) ||
            batch.toLowerCase().contains(q);
        if (!match) continue;
      }

      final expDate = parseExpiryDate(expStr);
      int? daysRemaining;
      String statusCategory = 'valid';

      if (expDate != null) {
        final expDay = DateTime(expDate.year, expDate.month, expDate.day);
        daysRemaining = expDay.difference(today).inDays;
        if (daysRemaining < 0) {
          statusCategory = 'expired';
        } else if (daysRemaining <= 30) {
          statusCategory = '30_days';
        } else if (daysRemaining <= 60) {
          statusCategory = '60_days';
        } else if (daysRemaining <= 90) {
          statusCategory = '90_days';
        } else {
          statusCategory = 'valid';
        }
      }

      if (filter != null && filter != 'all') {
        if (filter == 'expired' && statusCategory != 'expired') continue;
        if (filter == '30_days' && statusCategory != '30_days' && statusCategory != 'expired') continue;
        if (filter == '60_days' && statusCategory != '30_days' && statusCategory != '60_days' && statusCategory != 'expired') continue;
        if (filter == '90_days' && statusCategory != '30_days' && statusCategory != '60_days' && statusCategory != '90_days' && statusCategory != 'expired') continue;
      }

      final costRisk = stockQty * cost;
      final retailRisk = stockQty * price;

      results.add({
        'product_id': r['product_id'],
        'product_name': pName,
        'sku': sku,
        'barcode': r['barcode'] ?? '',
        'batch_number': batch,
        'expiry_date': expStr,
        'parsed_expiry': expDate?.toIso8601String(),
        'days_remaining': daysRemaining,
        'status_category': statusCategory,
        'stock_quantity': stockQty,
        'purchase_price': cost,
        'selling_price': price,
        'stock_value_cost': costRisk,
        'stock_value_retail': retailRisk,
        'category_name': r['category_name'] ?? 'General',
      });
    }

    results.sort((a, b) {
      final daysA = a['days_remaining'] as int? ?? 999999;
      final daysB = b['days_remaining'] as int? ?? 999999;
      return daysA.compareTo(daysB);
    });

    return results;
  }

  // Dashboard Aggregates (Step 7.1: Date Range Aware + Step 7.5 Cache)
  Future<Map<String, dynamic>> getDashboardMetrics({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    final dfDay = DateFormat('yyyy-MM-dd');
    final startStr = startDate != null ? dfDay.format(startDate) : null;
    final endExclusiveStr = endDate != null
        ? dfDay.format(endDate.add(const Duration(days: 1)))
        : null;
    final expStartStr = startStr;
    final expEndStr = endDate != null ? dfDay.format(endDate) : null;

    final cacheKey = 'dash_${dbService.dbFilePath ?? "mem"}_${startStr ?? "all"}_${expEndStr ?? "all"}';
    if (!forceRefresh) {
      final cached = _getCached<Map<String, dynamic>>(cacheKey);
      if (cached != null) return Map<String, dynamic>.from(cached);
    }

    final salesArgs = <dynamic>[];
    String salesDateClause = '';
    if (startStr != null && endExclusiveStr != null) {
      salesDateClause = ' AND created_at >= ? AND created_at < ?';
      salesArgs.addAll([startStr, endExclusiveStr]);
    }

    final purchaseArgs = <dynamic>[];
    String purchaseDateClause = '';
    if (startStr != null && endExclusiveStr != null) {
      purchaseDateClause = ' WHERE created_at >= ? AND created_at < ?';
      purchaseArgs.addAll([startStr, endExclusiveStr]);
    }

    final expArgs = <dynamic>[];
    String expDateClause = '';
    if (expStartStr != null && expEndStr != null) {
      expDateClause = ' WHERE date >= ? AND date <= ?';
      expArgs.addAll([expStartStr, expEndStr]);
    }

    // Total Sales & Invoice Due
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_invoices,
        SUM(total_amount) as total_sales,
        SUM(total_amount - paid_amount) as total_invoice_due
      FROM sales WHERE sale_status = 'final'$salesDateClause
    ''', salesArgs);

    // Total Purchases & Purchase Due
    final purchaseResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_purchases_count,
        SUM(total_amount) as total_purchases,
        SUM(total_amount - paid_amount) as total_purchase_due
      FROM purchases$purchaseDateClause
    ''', purchaseArgs);

    // Total Expenses
    final expenseResult = await db.rawQuery('''
      SELECT SUM(amount) as total_expenses FROM expenses$expDateClause
    ''', expArgs);

    // Product Count & Low Stock Count
    final productResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN stock_quantity <= alert_quantity THEN 1 ELSE 0 END) as low_stock_count
      FROM products
    ''');

    // Customer & Supplier count
    final contactResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'customer' THEN 1 ELSE 0 END) as customer_count,
        SUM(CASE WHEN type = 'supplier' THEN 1 ELSE 0 END) as supplier_count
      FROM contacts
    ''');

    final totalSales = (salesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final invoiceDue = (salesResult.first['total_invoice_due'] as num?)?.toDouble() ?? 0.0;
    final totalPurchases = (purchaseResult.first['total_purchases'] as num?)?.toDouble() ?? 0.0;
    final purchaseDue = (purchaseResult.first['total_purchase_due'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (expenseResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final totalProducts = (productResult.first['total_products'] as int?) ?? 0;
    final lowStockCount = (productResult.first['low_stock_count'] as int?) ?? 0;
    final customerCount = (contactResult.first['customer_count'] as int?) ?? 0;
    final supplierCount = (contactResult.first['supplier_count'] as int?) ?? 0;

    double totalSellReturn = 0.0;
    try {
      final sRetRes = await db.rawQuery(
        expStartStr != null && expEndStr != null
            ? 'SELECT SUM(total_amount) as total FROM sale_returns WHERE date >= ? AND date <= ?'
            : 'SELECT SUM(total_amount) as total FROM sale_returns',
        expStartStr != null && expEndStr != null ? [expStartStr, expEndStr] : const [],
      );
      totalSellReturn = (sRetRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'Failed loading sale_returns sum', e, st);
    }

    double totalPurchaseReturn = 0.0;
    try {
      final pRetRes = await db.rawQuery(
        expStartStr != null && expEndStr != null
            ? 'SELECT SUM(total_amount) as total FROM purchase_returns WHERE date >= ? AND date <= ?'
            : 'SELECT SUM(total_amount) as total FROM purchase_returns',
        expStartStr != null && expEndStr != null ? [expStartStr, expEndStr] : const [],
      );
      totalPurchaseReturn = (pRetRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'Failed loading purchase_returns sum', e, st);
    }

    final result = {
      'totalSales': totalSales,
      'invoiceDue': invoiceDue,
      'totalPurchases': totalPurchases,
      'purchaseDue': purchaseDue,
      'totalExpenses': totalExpenses,
      'totalSellReturn': totalSellReturn,
      'totalPurchaseReturn': totalPurchaseReturn,
      'netProfit': totalSales - (totalPurchases * 0.7) - totalExpenses,
      'totalProducts': totalProducts,
      'lowStockCount': lowStockCount,
      'customerCount': customerCount,
      'supplierCount': supplierCount,
    };
    _putCached(cacheKey, result);
    return result;
  }

  // Phase 7: Profit & Loss and Stock Valuation Reports
  Future<Map<String, dynamic>> getProfitAndLossReport() async {
    final salesRes = await db.rawQuery("SELECT SUM(total_amount) as total_sales FROM sales WHERE sale_status = 'final'");
    final cogsRes = await db.rawQuery(
      "SELECT SUM(si.quantity * p.purchase_price) as cogs "
      "FROM sale_items si "
      "JOIN sales s ON si.sale_id = s.id "
      "JOIN products p ON si.product_id = p.id "
      "WHERE s.sale_status = 'final'",
    );
    final expRes = await db.rawQuery("SELECT SUM(amount) as total_expenses FROM expenses");
    final adjRecoveryRes = await db.rawQuery("SELECT SUM(recovered_amount) as total_recovered FROM stock_adjustments");

    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final cogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? (totalSales * 0.6);
    final totalExpenses = (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final recoveredAmount = (adjRecoveryRes.first['total_recovered'] as num?)?.toDouble() ?? 0.0;

    final grossProfit = totalSales - cogs;
    final netProfit = grossProfit - totalExpenses + recoveredAmount;

    return {
      'totalSales': totalSales,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'totalExpenses': totalExpenses,
      'recoveredAmount': recoveredAmount,
      'netProfit': netProfit,
    };
  }

  Future<Map<String, dynamic>> getStockValuationReport() async {
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        SUM(stock_quantity) as total_quantity,
        SUM(stock_quantity * purchase_price) as stock_value_cost,
        SUM(stock_quantity * selling_price) as stock_value_retail
      FROM products
    ''');

    final totalItems = (res.first['total_items'] as int?) ?? 0;
    final totalQuantity = (res.first['total_quantity'] as num?)?.toDouble() ?? 0.0;
    final stockValueCost = (res.first['stock_value_cost'] as num?)?.toDouble() ?? 0.0;
    final stockValueRetail = (res.first['stock_value_retail'] as num?)?.toDouble() ?? 0.0;
    final potentialProfit = stockValueRetail - stockValueCost;

    return {
      'totalItems': totalItems,
      'totalQuantity': totalQuantity,
      'stockValueCost': stockValueCost,
      'stockValueRetail': stockValueRetail,
      'potentialProfit': potentialProfit,
    };
  }

  /// Generates a comprehensive multi-dimensional enterprise business report
  Future<Map<String, dynamic>> getComprehensiveBusinessReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String salesDateClause = '';
    String purchasesDateClause = '';
    String expensesDateClause = '';
    final List<dynamic> salesArgs = [];
    final List<dynamic> purchasesArgs = [];
    final List<dynamic> expensesArgs = [];

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDate);
      final expStartStr = DateFormat('yyyy-MM-dd').format(startDate);
      final expEndStr = DateFormat('yyyy-MM-dd').format(endDate);

      salesDateClause = ' AND s.created_at >= ? AND s.created_at <= ?';
      purchasesDateClause = ' AND p.created_at >= ? AND p.created_at <= ?';
      expensesDateClause = ' WHERE date >= ? AND date <= ?';

      salesArgs.addAll([startStr, endStr]);
      purchasesArgs.addAll([startStr, endStr]);
      expensesArgs.addAll([expStartStr, expEndStr]);
    }

    // 1. Sales Summary
    final salesRes = await db.rawQuery(
      "SELECT COUNT(*) as invoice_count, SUM(total_amount) as total_sales, SUM(paid_amount) as total_paid, SUM(due_amount) as total_due, SUM(tax_amount) as output_tax FROM sales s WHERE s.sale_status = 'final'$salesDateClause",
      salesArgs,
    );
    final invoiceCount = (salesRes.first['invoice_count'] as int?) ?? 0;
    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalPaidSales = (salesRes.first['total_paid'] as num?)?.toDouble() ?? 0.0;
    final totalDueSales = (salesRes.first['total_due'] as num?)?.toDouble() ?? 0.0;
    final outputTax = (salesRes.first['output_tax'] as num?)?.toDouble() ?? 0.0;

    // 2. COGS (Cost of goods sold)
    final cogsRes = await db.rawQuery(
      "SELECT SUM(si.quantity * p.purchase_price) as cogs FROM sale_items si JOIN sales s ON si.sale_id = s.id JOIN products p ON si.product_id = p.id WHERE s.sale_status = 'final'$salesDateClause",
      salesArgs,
    );
    final cogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? (totalSales * 0.65);
    final grossProfit = totalSales - cogs;

    // 3. Purchases Summary
    final purchasesRes = await db.rawQuery(
      "SELECT COUNT(*) as po_count, SUM(total_amount) as total_purchases, SUM(paid_amount) as total_paid, SUM(total_amount - paid_amount) as total_due FROM purchases p WHERE p.status = 'received'$purchasesDateClause",
      purchasesArgs,
    );
    final poCount = (purchasesRes.first['po_count'] as int?) ?? 0;
    final totalPurchases = (purchasesRes.first['total_purchases'] as num?)?.toDouble() ?? 0.0;
    final totalPaidPurchases = (purchasesRes.first['total_paid'] as num?)?.toDouble() ?? 0.0;
    final totalDuePurchases = (purchasesRes.first['total_due'] as num?)?.toDouble() ?? 0.0;
    const inputTax = 0.0; // Input tax credit when applicable

    // 4. Expenses Summary & Breakdown
    final expRes = await db.rawQuery(
      "SELECT SUM(amount) as total_expenses FROM expenses$expensesDateClause",
      expensesArgs,
    );
    final totalExpenses = (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    final expCatRows = await db.rawQuery(
      "SELECT category, SUM(amount) as cat_total, COUNT(*) as cat_count FROM expenses$expensesDateClause GROUP BY category ORDER BY cat_total DESC",
      expensesArgs,
    );
    final expenseCategories = expCatRows.map((r) => {
      'category': r['category'] as String? ?? 'General Expense',
      'amount': (r['cat_total'] as num?)?.toDouble() ?? 0.0,
      'count': (r['cat_count'] as int?) ?? 0,
    }).toList();

    // 5. Stock Adjustments Recovery
    final adjRecoveryRes = await db.rawQuery("SELECT SUM(recovered_amount) as total_recovered FROM stock_adjustments");
    final recoveredAmount = (adjRecoveryRes.first['total_recovered'] as num?)?.toDouble() ?? 0.0;

    final netProfit = grossProfit - totalExpenses + recoveredAmount;
    final netTaxPayable = outputTax - inputTax;

    // 6. Top 10 Best-Selling / Trending Products
    final topProductsRes = await db.rawQuery(
      "SELECT si.product_name, p.sku, SUM(si.quantity) as total_qty, SUM(si.subtotal) as total_rev FROM sale_items si JOIN sales s ON si.sale_id = s.id LEFT JOIN products p ON si.product_id = p.id WHERE s.sale_status = 'final'$salesDateClause GROUP BY si.product_name, p.sku ORDER BY total_qty DESC LIMIT 10",
      salesArgs,
    );
    final topSellingProducts = topProductsRes.map((r) => {
      'name': r['product_name'] as String? ?? 'Product',
      'sku': r['sku'] as String? ?? '-',
      'quantity': (r['total_qty'] as num?)?.toDouble() ?? 0.0,
      'revenue': (r['total_rev'] as num?)?.toDouble() ?? 0.0,
    }).toList();

    // 7. Customer Receivables & Top Debtors
    final custDuesRes = await db.rawQuery("SELECT SUM(balance) as total_ar FROM contacts WHERE type = 'customer' AND balance > 0");
    final totalCustomerDue = (custDuesRes.first['total_ar'] as num?)?.toDouble() ?? 0.0;

    final topDebtorsRes = await db.rawQuery("SELECT name, phone, balance FROM contacts WHERE type = 'customer' AND balance > 0 ORDER BY balance DESC LIMIT 5");
    final topDebtors = topDebtorsRes.map((r) => {
      'name': r['name'] as String? ?? 'Customer',
      'phone': r['phone'] as String? ?? '-',
      'balance': (r['balance'] as num?)?.toDouble() ?? 0.0,
    }).toList();

    // 8. Supplier Payables & Top Creditors
    final suppDuesRes = await db.rawQuery("SELECT SUM(balance) as total_ap FROM contacts WHERE type = 'supplier' AND balance > 0");
    final totalSupplierPayable = (suppDuesRes.first['total_ap'] as num?)?.toDouble() ?? 0.0;

    final topCreditorsRes = await db.rawQuery("SELECT name, phone, balance FROM contacts WHERE type = 'supplier' AND balance > 0 ORDER BY balance DESC LIMIT 5");
    final topCreditors = topCreditorsRes.map((r) => {
      'name': r['name'] as String? ?? 'Supplier',
      'phone': r['phone'] as String? ?? '-',
      'balance': (r['balance'] as num?)?.toDouble() ?? 0.0,
    }).toList();

    // 9. Stock Valuation
    final stockValuation = await getStockValuationReport();

    return {
      'invoiceCount': invoiceCount,
      'totalSales': totalSales,
      'totalPaidSales': totalPaidSales,
      'totalDueSales': totalDueSales,
      'outputTax': outputTax,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'poCount': poCount,
      'totalPurchases': totalPurchases,
      'totalPaidPurchases': totalPaidPurchases,
      'totalDuePurchases': totalDuePurchases,
      'inputTax': inputTax,
      'netTaxPayable': netTaxPayable,
      'totalExpenses': totalExpenses,
      'recoveredAmount': recoveredAmount,
      'netProfit': netProfit,
      'expenseCategories': expenseCategories,
      'topSellingProducts': topSellingProducts,
      'totalCustomerDue': totalCustomerDue,
      'topDebtors': topDebtors,
      'totalSupplierPayable': totalSupplierPayable,
      'topCreditors': topCreditors,
      'stockValuation': stockValuation,
    };
  }

  // Dead Stock & Expiring Products
  Future<List<Product>> getDeadStockProducts({int daysThreshold = 30}) async {
    final query = '''
      SELECT p.* FROM products p
      WHERE p.stock_quantity > 0
      AND p.id NOT IN (
        SELECT DISTINCT si.product_id FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE datetime(s.created_at) >= datetime('now', '-$daysThreshold days')
      )
      ORDER BY p.stock_quantity DESC
    ''';
    final rows = await db.rawQuery(query);
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> getExpiringProducts({int monthsAhead = 6}) async {
    final all = await dbService.productRepo.getProducts();
    final now = DateTime.now();
    final targetLimit = DateTime(now.year, now.month + monthsAhead, now.day);

    final expiring = <Product>[];
    for (final p in all) {
      if (p.expiryDate != null && p.expiryDate!.trim().isNotEmpty) {
        final expDate = parseExpiryDate(p.expiryDate);
        if (expDate != null && expDate.isBefore(targetLimit)) {
          expiring.add(p);
        }
      }
    }
    return expiring;
  }


  Future<List<Map<String, dynamic>>> getDailySalesTrend({
    int days = 7,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final anchorEnd = endDate ?? DateTime.now();
    final effectiveDays = (startDate != null && endDate != null)
        ? (endDate.difference(startDate).inDays + 1).clamp(1, 365)
        : days;
    final List<Map<String, dynamic>> results = [];

    final rows = await db.rawQuery('''
      SELECT 
        substr(created_at, 1, 10) as date_str,
        COUNT(*) as order_count,
        SUM(total_amount) as total_revenue
      FROM sales
      WHERE sale_status = 'final'
      GROUP BY substr(created_at, 1, 10)
    ''');

    final Map<String, Map<String, dynamic>> byDate = {};
    for (final r in rows) {
      final d = r['date_str'] as String?;
      if (d != null) byDate[d] = r;
    }

    final df = DateFormat('yyyy-MM-dd');
    for (int i = effectiveDays - 1; i >= 0; i--) {
      final day = anchorEnd.subtract(Duration(days: i));
      final key = df.format(day);
      if (byDate.containsKey(key)) {
        results.add({
          'date': key,
          'dayLabel': DateFormat('E d').format(day),
          'orderCount': (byDate[key]!['order_count'] as int?) ?? 0,
          'revenue': (byDate[key]!['total_revenue'] as num?)?.toDouble() ?? 0.0,
        });
      } else {
        results.add({
          'date': key,
          'dayLabel': DateFormat('E d').format(day),
          'orderCount': 0,
          'revenue': 0.0,
        });
      }
    }

    return results;
  }

  Future<Map<String, double>> getPaymentMethodBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final args = <dynamic>[];
    String dateClause = '';
    if (startDate != null && endDate != null) {
      final dfDay = DateFormat('yyyy-MM-dd');
      dateClause = ' AND created_at >= ? AND created_at < ?';
      args.addAll([
        dfDay.format(startDate),
        dfDay.format(endDate.add(const Duration(days: 1))),
      ]);
    }
    final rows = await db.rawQuery('''
      SELECT 
        payment_method,
        SUM(total_amount) as total_amount
      FROM sales
      WHERE sale_status = 'final'$dateClause
      GROUP BY payment_method
    ''', args);

    final Map<String, double> result = {};
    for (final r in rows) {
      final rawMethod = (r['payment_method'] as String?)?.trim();
      final method = (rawMethod != null && rawMethod.isNotEmpty) ? rawMethod.toUpperCase() : 'CASH';
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      result[method] = (result[method] ?? 0.0) + total;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final args = <dynamic>[];
    String dateClause = '';
    if (startDate != null && endDate != null) {
      final dfDay = DateFormat('yyyy-MM-dd');
      dateClause = ' AND s.created_at >= ? AND s.created_at < ?';
      args.addAll([
        dfDay.format(startDate),
        dfDay.format(endDate.add(const Duration(days: 1))),
      ]);
    }
    args.add(limit);

    final rows = await db.rawQuery('''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_qty,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.sale_status = 'final'$dateClause
      GROUP BY si.product_id, si.product_name
      ORDER BY total_qty DESC
      LIMIT ?
    ''', args);

    return rows.map((r) => {
      'name': (r['product_name'] as String?) ?? 'Unknown Item',
      'qty': (r['total_qty'] as num?)?.toDouble() ?? 0.0,
      'revenue': (r['total_revenue'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }

  Future<Map<String, dynamic>> getTodaySalesMetrics() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as today_orders,
        SUM(total_amount) as today_sales,
        SUM(paid_amount) as today_cash
      FROM sales
      WHERE sale_status = 'final' AND substr(created_at, 1, 10) = ?
    ''', [todayStr]);

    final orders = (res.first['today_orders'] as int?) ?? 0;
    final sales = (res.first['today_sales'] as num?)?.toDouble() ?? 0.0;
    final cash = (res.first['today_cash'] as num?)?.toDouble() ?? 0.0;

    return {
      'todayOrders': orders,
      'todaySales': sales,
      'todayCash': cash,
    };
  }

  /// Tracks quotation conversion funnel metrics (Step 3.4).
  Future<Map<String, dynamic>> getQuotationConversionStats() async {
    final rows = await db.query(
      'sales',
      columns: ['id', 'total_amount', 'converted_to_sale_id'],
      where: "sale_status = 'quotation'",
    );
    int convertedCount = 0;
    double quotedTotal = 0.0;
    double convertedTotal = 0.0;
    for (final r in rows) {
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      quotedTotal += total;
      final linkedSaleId = (r['converted_to_sale_id'] as num?)?.toInt();
      if (linkedSaleId != null && linkedSaleId > 0) {
        convertedCount++;
        convertedTotal += total;
      }
    }
    final totalQuotations = rows.length;
    final pendingQuotations = totalQuotations - convertedCount;
    final conversionRate =
        totalQuotations > 0 ? (convertedCount / totalQuotations) * 100.0 : 0.0;
    return {
      'totalQuotations': totalQuotations,
      'convertedQuotations': convertedCount,
      'pendingQuotations': pendingQuotations,
      'conversionRate': conversionRate,
      'quotedTotal': quotedTotal,
      'convertedTotal': convertedTotal,
    };
  }
}
