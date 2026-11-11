/// Payment Account (Bank account, Cash drawer, Merchant POS)
class PaymentAccount {
  final int? id;
  final String name;
  final String accountNumber;
  final String accountType; // 'cash', 'bank', 'pos_terminal'
  final double openingBalance;
  final double currentBalance;
  final String note;

  PaymentAccount({
    this.id,
    required this.name,
    this.accountNumber = '',
    this.accountType = 'bank',
    this.openingBalance = 0.0,
    required this.currentBalance,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'account_number': accountNumber,
        'account_type': accountType,
        'opening_balance': openingBalance,
        'current_balance': currentBalance,
        'note': note,
      };

  factory PaymentAccount.fromMap(Map<String, dynamic> map) => PaymentAccount(
        id: map['id'] as int?,
        name: map['name'] as String,
        accountNumber: map['account_number'] as String? ?? '',
        accountType: map['account_type'] as String? ?? 'bank',
        openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
        note: map['note'] as String? ?? '',
      );
}

/// Fund Transfer between Payment Accounts
class AccountTransfer {
  final int? id;
  final int fromAccountId;
  final String fromAccountName;
  final int toAccountId;
  final String toAccountName;
  final double amount;
  final String date;
  final String refNo;
  final String note;

  AccountTransfer({
    this.id,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.date,
    required this.refNo,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'from_account_id': fromAccountId,
        'from_account_name': fromAccountName,
        'to_account_id': toAccountId,
        'to_account_name': toAccountName,
        'amount': amount,
        'date': date,
        'ref_no': refNo,
        'note': note,
      };

  factory AccountTransfer.fromMap(Map<String, dynamic> map) => AccountTransfer(
        id: map['id'] as int?,
        fromAccountId: map['from_account_id'] as int,
        fromAccountName: map['from_account_name'] as String,
        toAccountId: map['to_account_id'] as int,
        toAccountName: map['to_account_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: map['date'] as String,
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );
}
