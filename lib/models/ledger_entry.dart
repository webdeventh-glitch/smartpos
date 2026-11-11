/// Modern Double-Entry Ledger Transaction Model
class LedgerEntry {
  final String date;
  final String
      transactionType; // 'sale_invoice', 'customer_payment', 'purchase_bill', 'supplier_payment', 'sale_return', 'purchase_return', 'expense', 'transfer_in', 'transfer_out', 'opening_balance'
  final String refNo;
  final String description;
  final String paymentMethod;
  final String accountName;
  final double debit; // Dr (Money in / Receivable increased / Asset debited)
  final double
      credit; // Cr (Money out / Payable increased / Liability credited)
  final double runningBalance; // Calculated progressive balance
  final int? parentId;

  LedgerEntry({
    required this.date,
    required this.transactionType,
    required this.refNo,
    required this.description,
    this.paymentMethod = 'cash',
    this.accountName = 'Main Till',
    this.debit = 0.0,
    this.credit = 0.0,
    this.runningBalance = 0.0,
    this.parentId,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'transaction_type': transactionType,
        'ref_no': refNo,
        'description': description,
        'payment_method': paymentMethod,
        'account_name': accountName,
        'debit': debit,
        'credit': credit,
        'running_balance': runningBalance,
        if (parentId != null) 'parent_id': parentId,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        date: map['date'] as String? ?? '',
        transactionType: map['transaction_type'] as String? ?? 'general',
        refNo: map['ref_no'] as String? ?? '',
        description: map['description'] as String? ?? '',
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        accountName: map['account_name'] as String? ?? '',
        debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
        credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
        runningBalance: (map['running_balance'] as num?)?.toDouble() ?? 0.0,
        parentId: map['parent_id'] as int?,
      );
}
