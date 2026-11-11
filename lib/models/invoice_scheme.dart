/// Invoice Scheme configuration in Smart POS
class InvoiceScheme {
  final int? id;
  final String name;
  final String schemeType; // 'blank', 'year'
  final String prefix;
  final int startNumber;
  final int invoiceCount;
  final int totalDigits;
  final bool isDefault;

  InvoiceScheme({
    this.id,
    required this.name,
    this.schemeType = 'blank',
    this.prefix = 'INV-',
    this.startNumber = 1,
    this.invoiceCount = 0,
    this.totalDigits = 4,
    this.isDefault = false,
  });

  String get previewExample {
    final nextNum =
        (startNumber + invoiceCount).toString().padLeft(totalDigits, '0');
    if (schemeType == 'year') {
      final year = DateTime.now().year;
      return '$prefix$year-$nextNum';
    }
    return '$prefix$nextNum';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'scheme_type': schemeType,
        'prefix': prefix,
        'start_number': startNumber,
        'invoice_count': invoiceCount,
        'total_digits': totalDigits,
        'is_default': isDefault ? 1 : 0,
      };

  factory InvoiceScheme.fromMap(Map<String, dynamic> map) => InvoiceScheme(
        id: map['id'] as int?,
        name: map['name'] as String,
        schemeType: map['scheme_type'] as String? ?? 'blank',
        prefix: map['prefix'] as String? ?? 'INV-',
        startNumber: map['start_number'] as int? ?? 1,
        invoiceCount: map['invoice_count'] as int? ?? 0,
        totalDigits: map['total_digits'] as int? ?? 4,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
      );
}
