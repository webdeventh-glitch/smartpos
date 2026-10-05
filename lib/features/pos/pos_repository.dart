import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/money.dart';
import '../../stock_store.dart';

class CheckoutTotals {
  final int subtotal, discount, tax, total;
  const CheckoutTotals(this.subtotal, this.discount, this.tax, this.total);
  factory CheckoutTotals.calculate(
      List<OrderLine> lines, int discount, int rate,
      {bool taxInclusive = false}) {
    if (lines.isEmpty || discount < 0 || rate < 0 || rate > 10000) {
      throw ArgumentError('Add items and enter valid discount and tax.');
    }
    var subtotal = 0;
    final ids = <int>{};
    for (final line in lines) {
      if (!ids.add(line.productId)) throw ArgumentError('Duplicate item.');
      subtotal =
          Money.add(subtotal, Money.lineTotal(line.price, line.quantity));
    }
    if (discount > subtotal) throw ArgumentError('Discount exceeds subtotal.');
    final taxable = subtotal - discount;
    // Divide before multiplying to keep intermediate arithmetic bounded.
    final divisor = taxInclusive ? 10000 + rate : 10000;
    final tax = (taxable ~/ divisor) * rate +
        ((taxable % divisor) * rate + divisor ~/ 2) ~/ divisor;
    return CheckoutTotals(subtotal, discount, tax,
        taxInclusive ? taxable : Money.add(taxable, tax));
  }
}

/// Cash may exceed the remaining balance; electronic tenders may not.
class PaymentSettlement {
  final Map<String, int> allocations;
  final int cashReceived, change;
  PaymentSettlement._(this.allocations, this.cashReceived, this.change);

  factory PaymentSettlement.calculate(int total, Map<String, int> tender) {
    if (total < 0 || total > Money.maxTotal) {
      throw ArgumentError('Invalid amount due.');
    }
    var electronic = 0;
    for (final entry in tender.entries) {
      if (!['Cash', 'Card', 'Bank', 'Digital'].contains(entry.key) ||
          entry.value < 0 ||
          entry.value > Money.maxTotal) {
        throw ArgumentError('Invalid payment amount.');
      }
      if (entry.key != 'Cash') electronic = Money.add(electronic, entry.value);
    }
    if (electronic > total) {
      throw ArgumentError('Non-cash payments exceed the amount due.');
    }
    final cashDue = total - electronic;
    final received = tender['Cash'] ?? 0;
    if (received < cashDue) {
      throw ArgumentError('Remaining: ${Money.format(cashDue - received)}');
    }
    if (cashDue == 0 && received > 0) {
      throw ArgumentError('No cash is due. Set cash received to zero.');
    }
    return PaymentSettlement._({
      for (final entry in tender.entries)
        if (entry.key != 'Cash' && entry.value > 0) entry.key: entry.value,
      if (cashDue > 0) 'Cash': cashDue,
    }, received, received - cashDue);
  }
}

class PosRepository {
  final StockStore store;
  PosRepository(this.store);
  static Future<void> migrate(Database db) async {
    await db.execute('ALTER TABLE documents ADD COLUMN operation_id TEXT');
    await db.execute('ALTER TABLE documents ADD COLUMN request_payload TEXT');
    await db.execute('ALTER TABLE documents ADD COLUMN subtotal INTEGER');
    await db.execute('ALTER TABLE documents ADD COLUMN discount INTEGER');
    await db.execute('ALTER TABLE documents ADD COLUMN tax INTEGER');
    await db.execute(
        'CREATE UNIQUE INDEX document_operation ON documents(operation_id)');
    await db.execute('''CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL,
      method TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount > 0))''');
    await db.execute('CREATE INDEX payments_document ON payments(document_id)');
    await db.execute('''CREATE TABLE parked_bills (
      token TEXT PRIMARY KEY, label TEXT NOT NULL, payload TEXT NOT NULL,
      created_at TEXT NOT NULL)''');
    for (final table in ['documents', 'document_lines', 'payments']) {
      for (final action in ['UPDATE', 'DELETE']) {
        await db.execute('''CREATE TRIGGER ${table}_no_${action.toLowerCase()}
          BEFORE $action ON $table BEGIN
          SELECT RAISE(ABORT, 'Posted financial records are immutable'); END''');
      }
    }
  }

  static Future<void> migrateV5(Database db) async {
    await db.execute('ALTER TABLE documents ADD COLUMN tax_inclusive INTEGER');
    await db.execute('ALTER TABLE documents ADD COLUMN cash_received INTEGER');
    await db.execute('ALTER TABLE documents ADD COLUMN cash_change INTEGER');
  }

  Future<int> checkout(
      {required String token,
      required List<OrderLine> lines,
      required Map<String, int> payments,
      String customer = '',
      int discount = 0,
      int taxRate = 0,
      bool taxInclusive = false,
      int? cashReceived}) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('Missing checkout reference.');
    }
    final totals = CheckoutTotals.calculate(lines, discount, taxRate,
        taxInclusive: taxInclusive);
    var paid = 0;
    for (final entry in payments.entries) {
      if (!['Cash', 'Card', 'Bank', 'Digital'].contains(entry.key) ||
          entry.value <= 0) {
        throw ArgumentError('Invalid payment allocation.');
      }
      paid = Money.add(paid, entry.value);
    }
    if (paid != totals.total) {
      throw ArgumentError('Payments must equal the amount due.');
    }
    final cash = payments['Cash'] ?? 0;
    final received = cashReceived ?? cash;
    if (received < cash ||
        received > Money.maxTotal ||
        (cash == 0 && received != 0)) {
      throw ArgumentError('Cash received must cover the cash allocation.');
    }
    final sortedLines = [...lines]
      ..sort((a, b) => a.productId.compareTo(b.productId));
    final methods = payments.keys.toList()..sort();
    final payload = jsonEncode({
      'lines':
          sortedLines.map((l) => [l.productId, l.quantity, l.price]).toList(),
      'customer': customer.trim(),
      'discount': discount,
      'taxRate': taxRate,
      if (taxInclusive) 'taxInclusive': true,
      if (received != cash) 'cashReceived': received,
      'payments': {for (final method in methods) method: payments[method]},
    });
    return store.db.transaction((tx) async {
      final existing = await tx
          .query('documents', where: 'operation_id = ?', whereArgs: [token]);
      if (existing.isNotEmpty) {
        if (existing.single['request_payload'] != payload) {
          throw StateError(
              'This bill was already posted with different details.');
        }
        return existing.single['id'] as int;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final id = await tx.insert('documents', {
        'kind': 'sale',
        'party': customer.trim(),
        'note': '',
        'total': totals.total,
        'subtotal': totals.subtotal,
        'discount': discount,
        'tax': totals.tax,
        'tax_inclusive': taxInclusive ? 1 : 0,
        'cash_received': received,
        'cash_change': received - cash,
        'operation_id': token,
        'request_payload': payload,
        'created_at': now,
      });
      for (final line in lines) {
        final rows = await tx
            .query('products', where: 'id = ?', whereArgs: [line.productId]);
        if (rows.isEmpty) {
          throw StateError('A product was removed. Review this bill.');
        }
        final product = rows.single;
        final balance = (product['quantity'] as int) - line.quantity;
        if (balance < 0) {
          throw StateError('Insufficient stock: ${product['name']}');
        }
        await tx.insert('document_lines', {
          'document_id': id,
          'product_id': line.productId,
          'name': product['name'],
          'sku': product['sku'],
          'quantity': line.quantity,
          'price': line.price,
        });
        await tx.update('products', {'quantity': balance},
            where: 'id = ?', whereArgs: [line.productId]);
        await tx.insert('movements', {
          'product_id': line.productId,
          'product_name': product['name'],
          'delta': -line.quantity,
          'balance': balance,
          'note': 'Sale #$id',
          'created_at': now,
        });
      }
      for (final payment in payments.entries) {
        await tx.insert('payments', {
          'document_id': id,
          'method': payment.key,
          'amount': payment.value
        });
      }
      await tx.delete('parked_bills', where: 'token = ?', whereArgs: [token]);
      return id;
    });
  }

  Future<void> park(
      String token, String label, Map<String, dynamic> payload) async {
    await store.db.insert(
        'parked_bills',
        {
          'token': token,
          'label': label,
          'payload': jsonEncode(payload),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> parked() =>
      store.db.query('parked_bills', orderBy: 'created_at');
}
