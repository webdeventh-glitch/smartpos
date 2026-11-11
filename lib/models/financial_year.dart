/// Financial Year End Closing Model
class FinancialYear {
  final int? id;
  final String yearTitle;
  final String startDate;
  final String endDate;
  final String closingDate;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double netProfit;
  final double stockValuation;
  final double receivables;
  final double payables;
  final String closedBy;
  final String status;
  final String notes;

  FinancialYear({
    this.id,
    required this.yearTitle,
    required this.startDate,
    required this.endDate,
    required this.closingDate,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.netProfit,
    required this.stockValuation,
    required this.receivables,
    required this.payables,
    required this.closedBy,
    this.status = 'closed',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'year_title': yearTitle,
        'start_date': startDate,
        'end_date': endDate,
        'closing_date': closingDate,
        'total_sales': totalSales,
        'total_purchases': totalPurchases,
        'total_expenses': totalExpenses,
        'net_profit': netProfit,
        'stock_valuation': stockValuation,
        'receivables': receivables,
        'payables': payables,
        'closed_by': closedBy,
        'status': status,
        'notes': notes,
      };

  factory FinancialYear.fromMap(Map<String, dynamic> map) => FinancialYear(
        id: map['id'] as int?,
        yearTitle: map['year_title'] as String? ?? '',
        startDate: map['start_date'] as String? ?? '',
        endDate: map['end_date'] as String? ?? '',
        closingDate: map['closing_date'] as String? ?? '',
        totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0.0,
        totalPurchases: (map['total_purchases'] as num?)?.toDouble() ?? 0.0,
        totalExpenses: (map['total_expenses'] as num?)?.toDouble() ?? 0.0,
        netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
        stockValuation: (map['stock_valuation'] as num?)?.toDouble() ?? 0.0,
        receivables: (map['receivables'] as num?)?.toDouble() ?? 0.0,
        payables: (map['payables'] as num?)?.toDouble() ?? 0.0,
        closedBy: map['closed_by'] as String? ?? 'SuperAdmin',
        status: map['status'] as String? ?? 'closed',
        notes: map['notes'] as String? ?? '',
      );
}
