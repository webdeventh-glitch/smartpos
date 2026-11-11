/// Expense record in Smart POS
class Expense {
  final int? id;
  final String category;
  final double amount;
  final String refNo;
  final String note;
  final String date;
  final String paymentMethod;

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.refNo,
    this.note = '',
    required this.date,
    this.paymentMethod = 'cash',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'amount': amount,
        'ref_no': refNo,
        'note': note,
        'date': date,
        'payment_method': paymentMethod,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
        date: map['date'] as String,
        paymentMethod: map['payment_method'] as String? ?? 'cash',
      );
}
