/// Contact Payment (Customer payment collection or Supplier payment payout)
class ContactPayment {
  final int? id;
  final int contactId;
  final String contactName;
  final String
      paymentType; // 'receive' (customer paid due), 'pay' (paid to supplier)
  final double amount;
  final String paymentMethod; // 'cash', 'card', 'bank_transfer', 'cheque'
  final String date;
  final String refNo;
  final String note;
  final String? documentPath;
  final String chequeNumber;
  final String bankName;
  final String chequeDueDate;
  final String chequeStatus;

  ContactPayment({
    this.id,
    required this.contactId,
    required this.contactName,
    required this.paymentType,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.date,
    required this.refNo,
    this.note = '',
    this.documentPath,
    this.chequeNumber = '',
    this.bankName = '',
    this.chequeDueDate = '',
    String? chequeStatus,
  }) : chequeStatus =
            chequeStatus ?? (paymentMethod == 'cheque' ? 'pending' : '');

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contact_id': contactId,
        'contact_name': contactName,
        'payment_type': paymentType,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': date,
        'ref_no': refNo,
        'note': note,
        if (documentPath != null && documentPath!.isNotEmpty) 'document_path': documentPath,
        'cheque_number': chequeNumber,
        'bank_name': bankName,
        'cheque_due_date': chequeDueDate,
        'cheque_status': chequeStatus,
      };

  factory ContactPayment.fromMap(Map<String, dynamic> map) => ContactPayment(
        id: map['id'] as int?,
        contactId: map['contact_id'] as int,
        contactName: map['contact_name'] as String,
        paymentType: map['payment_type'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        date: map['date'] as String,
        refNo: map['ref_no'] as String? ?? '',
        note: map['note'] as String? ?? '',
        documentPath: map['document_path'] as String?,
        chequeNumber: map['cheque_number'] as String? ?? '',
        bankName: map['bank_name'] as String? ?? '',
        chequeDueDate: map['cheque_due_date'] as String? ?? '',
        chequeStatus: map['cheque_status'] as String?,
      );
}
