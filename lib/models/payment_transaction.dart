/// Multi-tender & Split Payment Transaction Ledger Record
class PaymentTransaction {
  final int? id;
  final String
      transactionType; // 'sale', 'purchase', 'sale_due_collection', 'purchase_due_payment', 'customer_advance', 'supplier_advance'
  final int? parentId; // sale_id or purchase_id
  final int? contactId;
  final String contactName;
  final String
      paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque', 'custom'
  final double amount;
  final int? accountId;
  final String accountName;
  final String transactionDate;
  final String refNo;
  final String note;
  final String createdBy;
  final String createdAt;

  PaymentTransaction({
    this.id,
    required this.transactionType,
    this.parentId,
    this.contactId,
    required this.contactName,
    this.paymentMethod = 'cash',
    required this.amount,
    this.accountId,
    this.accountName = 'Cash Till',
    required this.transactionDate,
    this.refNo = '',
    this.note = '',
    this.createdBy = 'Cashier',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'transaction_type': transactionType,
        'parent_id': parentId,
        'contact_id': contactId,
        'contact_name': contactName,
        'payment_method': paymentMethod,
        'amount': amount,
        'account_id': accountId,
        'account_name': accountName,
        'transaction_date': transactionDate,
        'ref_no': refNo,
        'note': note,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) =>
      PaymentTransaction(
        id: map['id'] as int?,
        transactionType: map['transaction_type'] as String? ?? 'sale',
        parentId: map['parent_id'] as int?,
        contactId: map['contact_id'] as int?,
        contactName: map['contact_name'] as String? ?? 'Walk-in Customer',
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: map['account_id'] as int?,
        accountName: map['account_name'] as String? ?? 'Cash Till',
        transactionDate: map['transaction_date'] as String? ?? '',
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? 'System',
        createdAt: map['created_at'] as String? ?? '',
      );
}
