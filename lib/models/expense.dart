/// Expense record in Smart POS (UltimatePOS-compatible).
class Expense {
  final int? id;
  final int locationId;
  final String title;
  final String paymentTo;
  final String category;
  final String subCategory;
  final double amount;
  final double paidAmount;
  final String paymentStatus; // 'paid', 'partial', 'due'
  final String refNo;
  final String note;
  final String date;
  final String paymentMethod;
  final String expenseForUser;
  final int? contactId;
  final String contactName;
  final double taxRate;
  final String taxName;
  final String documentPath;
  final bool isRefund;
  final bool isRecurring;
  final int recurringInterval;
  final String recurringUnit; // 'Days', 'Months', 'Years'
  final int? recurringRepetitions;

  Expense({
    this.id,
    this.locationId = 1,
    this.title = '',
    this.paymentTo = '',
    required this.category,
    this.subCategory = '',
    required this.amount,
    double? paidAmount,
    String? paymentStatus,
    required this.refNo,
    this.note = '',
    required this.date,
    this.paymentMethod = 'cash',
    this.expenseForUser = '',
    this.contactId,
    this.contactName = '',
    this.taxRate = 0.0,
    this.taxName = '',
    this.documentPath = '',
    this.isRefund = false,
    this.isRecurring = false,
    this.recurringInterval = 0,
    this.recurringUnit = 'Days',
    this.recurringRepetitions,
  })  : paidAmount = paidAmount ?? amount,
        paymentStatus = paymentStatus ??
            _computePaymentStatus(amount, paidAmount ?? amount);

  static String _computePaymentStatus(double total, double paid) {
    if (total <= 0 || paid >= total - 0.009) return 'paid';
    if (paid > 0.009) return 'partial';
    return 'due';
  }

  double get dueAmount {
    final due = amount - paidAmount;
    return due > 0.009 ? due : 0.0;
  }

  Expense copyWith({
    int? id,
    int? locationId,
    String? title,
    String? paymentTo,
    String? category,
    String? subCategory,
    double? amount,
    double? paidAmount,
    String? paymentStatus,
    String? refNo,
    String? note,
    String? date,
    String? paymentMethod,
    String? expenseForUser,
    int? contactId,
    bool clearContactId = false,
    String? contactName,
    double? taxRate,
    String? taxName,
    String? documentPath,
    bool? isRefund,
    bool? isRecurring,
    int? recurringInterval,
    String? recurringUnit,
    int? recurringRepetitions,
    bool clearRecurringRepetitions = false,
  }) {
    final nextAmount = amount ?? this.amount;
    final nextPaid = paidAmount ?? this.paidAmount;
    return Expense(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      title: title ?? this.title,
      paymentTo: paymentTo ?? this.paymentTo,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      amount: nextAmount,
      paidAmount: nextPaid,
      paymentStatus:
          paymentStatus ?? _computePaymentStatus(nextAmount, nextPaid),
      refNo: refNo ?? this.refNo,
      note: note ?? this.note,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      expenseForUser: expenseForUser ?? this.expenseForUser,
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: contactName ?? this.contactName,
      taxRate: taxRate ?? this.taxRate,
      taxName: taxName ?? this.taxName,
      documentPath: documentPath ?? this.documentPath,
      isRefund: isRefund ?? this.isRefund,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringUnit: recurringUnit ?? this.recurringUnit,
      recurringRepetitions: clearRecurringRepetitions
          ? null
          : (recurringRepetitions ?? this.recurringRepetitions),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'location_id': locationId,
        'title': title,
        'payment_to': paymentTo,
        'category': category,
        'sub_category': subCategory,
        'amount': amount,
        'paid_amount': paidAmount,
        'payment_status': paymentStatus,
        'ref_no': refNo,
        'note': note,
        'date': date,
        'payment_method': paymentMethod,
        'expense_for_user': expenseForUser,
        'contact_id': contactId,
        'contact_name': contactName,
        'tax_rate': taxRate,
        'tax_name': taxName,
        'document_path': documentPath,
        'is_refund': isRefund ? 1 : 0,
        'is_recurring': isRecurring ? 1 : 0,
        'recurring_interval': recurringInterval,
        'recurring_unit': recurringUnit,
        'recurring_repetitions': recurringRepetitions,
      };

  factory Expense.fromMap(Map<String, dynamic> map) {
    final total = (map['amount'] as num).toDouble();
    final rawPaid = map['paid_amount'];
    final paid = rawPaid != null ? (rawPaid as num).toDouble() : total;
    final status = (map['payment_status'] as String?)?.trim();
    return Expense(
      id: map['id'] as int?,
      locationId: (map['location_id'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? '',
      paymentTo: map['payment_to'] as String? ?? '',
      category: map['category'] as String,
      subCategory: map['sub_category'] as String? ?? '',
      amount: total,
      paidAmount: paid,
      paymentStatus: (status != null && status.isNotEmpty)
          ? status
          : _computePaymentStatus(total, paid),
      refNo: map['ref_no'] as String? ?? '',
      note: map['note'] as String? ?? '',
      date: map['date'] as String,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      expenseForUser: map['expense_for_user'] as String? ?? '',
      contactId: (map['contact_id'] as num?)?.toInt(),
      contactName: map['contact_name'] as String? ?? '',
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxName: map['tax_name'] as String? ?? '',
      documentPath: map['document_path'] as String? ?? '',
      isRefund:
          (map['is_refund'] as num?)?.toInt() == 1 || map['is_refund'] == true,
      isRecurring: (map['is_recurring'] as num?)?.toInt() == 1 ||
          map['is_recurring'] == true,
      recurringInterval: (map['recurring_interval'] as num?)?.toInt() ?? 0,
      recurringUnit: map['recurring_unit'] as String? ?? 'Days',
      recurringRepetitions: (map['recurring_repetitions'] as num?)?.toInt(),
    );
  }
}
