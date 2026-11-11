/// Cash register session for the cashier
class CashRegister {
  final int? id;
  final String cashierName;
  final double openingAmount;
  final double closingAmount;
  final double totalSalesCash;
  final double totalSalesCard;
  final double totalSalesOther;
  final String status; // 'open', 'closed'
  final String openedAt;
  final String? closedAt;
  final String note;

  CashRegister({
    this.id,
    this.cashierName = 'Admin Cashier',
    this.openingAmount = 250.0,
    this.closingAmount = 0.0,
    this.totalSalesCash = 0.0,
    this.totalSalesCard = 0.0,
    this.totalSalesOther = 0.0,
    this.status = 'open',
    required this.openedAt,
    this.closedAt,
    this.note = '',
  });

  double get totalCashInRegister => openingAmount + totalSalesCash;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cashier_name': cashierName,
        'opening_amount': openingAmount,
        'closing_amount': closingAmount,
        'total_sales_cash': totalSalesCash,
        'total_sales_card': totalSalesCard,
        'total_sales_other': totalSalesOther,
        'status': status,
        'opened_at': openedAt,
        'closed_at': closedAt,
        'note': note,
      };

  factory CashRegister.fromMap(Map<String, dynamic> map) => CashRegister(
        id: map['id'] as int?,
        cashierName: map['cashier_name'] as String? ?? 'Admin Cashier',
        openingAmount: (map['opening_amount'] as num?)?.toDouble() ?? 0.0,
        closingAmount: (map['closing_amount'] as num?)?.toDouble() ?? 0.0,
        totalSalesCash: (map['total_sales_cash'] as num?)?.toDouble() ?? 0.0,
        totalSalesCard: (map['total_sales_card'] as num?)?.toDouble() ?? 0.0,
        totalSalesOther: (map['total_sales_other'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] as String? ?? 'open',
        openedAt: map['opened_at'] as String,
        closedAt: map['closed_at'] as String?,
        note: map['note'] as String? ?? '',
      );
}
