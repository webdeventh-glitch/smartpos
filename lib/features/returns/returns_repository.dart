import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../stock_store.dart';

class ReturnItem {
  final int lineId, productId, sold, returned, price, entitlement;
  final String name;
  const ReturnItem(this.lineId, this.productId, this.name, this.sold,
      this.returned, this.price, this.entitlement);
  int get remaining => sold - returned;
  int refund(int quantity) {
    if (quantity < 0 || quantity > remaining) {
      throw ArgumentError('Return quantity exceeds remaining units for $name.');
    }
    return _share(entitlement, returned + quantity, sold) -
        _share(entitlement, returned, sold);
  }
}

// BigInt prevents overflow when allocating large invoice totals proportionally.
int _share(int amount, int weight, int total) => total == 0
    ? 0
    : ((BigInt.from(amount) * BigInt.from(weight)) ~/ BigInt.from(total))
        .toInt();

class ReturnsRepository {
  final StockStore store;
  ReturnsRepository(this.store);

  static Future<void> migrate(Database db) async {
    await db.execute('''CREATE TABLE sale_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL REFERENCES documents(id),
      token TEXT NOT NULL UNIQUE, payload TEXT NOT NULL,
      reason TEXT NOT NULL, method TEXT NOT NULL,
      total INTEGER NOT NULL CHECK(total >= 0), created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE sale_return_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL REFERENCES sale_returns(id),
      sale_line_id INTEGER NOT NULL REFERENCES document_lines(id),
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      refund INTEGER NOT NULL CHECK(refund >= 0))''');
    await db.execute('CREATE INDEX returns_sale ON sale_returns(sale_id, id)');
    await db.execute(
        'CREATE INDEX returns_line ON sale_return_lines(sale_line_id)');
    for (final table in ['sale_returns', 'sale_return_lines']) {
      for (final action in ['UPDATE', 'DELETE']) {
        await db.execute('''CREATE TRIGGER ${table}_no_${action.toLowerCase()}
          BEFORE $action ON $table BEGIN
          SELECT RAISE(ABORT, 'Posted returns are immutable'); END''');
      }
    }
  }

  Future<List<ReturnItem>> items(int saleId) =>
      store.db.transaction((tx) => _items(tx, saleId));

  Future<List<ReturnItem>> _items(DatabaseExecutor tx, int saleId) async {
    final sales = await tx.query('documents',
        where: 'id = ? AND kind = ?', whereArgs: [saleId, 'sale']);
    if (sales.isEmpty) throw StateError('Sale not found.');
    final sale = sales.single;
    if (sale['operation_id'] == null) {
      throw StateError(
          'Legacy sale payment is unknown; automatic refund is unavailable.');
    }
    final lines = await tx.rawQuery('''SELECT l.*,
      COALESCE((SELECT SUM(r.quantity) FROM sale_return_lines r
        WHERE r.sale_line_id = l.id), 0) AS returned
      FROM document_lines l WHERE l.document_id = ? ORDER BY l.id''', [saleId]);
    final gross = lines.fold<int>(
        0, (sum, l) => sum + (l['price'] as int) * (l['quantity'] as int));
    var cumulative = 0;
    final result = <ReturnItem>[];
    for (final l in lines) {
      final weight = (l['price'] as int) * (l['quantity'] as int);
      final amount = _share(sale['total'] as int, cumulative + weight, gross) -
          _share(sale['total'] as int, cumulative, gross);
      cumulative += weight;
      result.add(ReturnItem(
          l['id'] as int,
          l['product_id'] as int,
          l['name'] as String,
          l['quantity'] as int,
          l['returned'] as int,
          l['price'] as int,
          amount));
    }
    return result;
  }

  Future<List<Map<String, Object?>>> history(int saleId) => store.db.rawQuery(
      '''SELECT r.*,
        (SELECT GROUP_CONCAT(l.name || ' x' || rl.quantity, ', ')
         FROM sale_return_lines rl JOIN document_lines l ON l.id = rl.sale_line_id
         WHERE rl.return_id = r.id) AS items
        FROM sale_returns r WHERE r.sale_id = ? ORDER BY r.id DESC''',
      [saleId]);

  Future<int> post(
      {required int saleId,
      required String token,
      required Map<int, int> quantities,
      required String reason,
      required String method,
      required int expectedRefund}) async {
    if (token.trim().isEmpty ||
        reason.trim().isEmpty ||
        reason.trim().length > 500 ||
        !['Cash', 'Card', 'Bank', 'Digital'].contains(method) ||
        quantities.isEmpty ||
        quantities.values.any((q) => q <= 0)) {
      throw ArgumentError(
          'Select items, a refund method and a reason (up to 500 characters).');
    }
    final ids = quantities.keys.toList()..sort();
    final payload = jsonEncode({
      'sale': saleId,
      'items': [
        for (final id in ids) [id, quantities[id]]
      ],
      'reason': reason.trim(),
      'method': method,
      'refund': expectedRefund
    });
    return store.db.transaction((tx) async {
      final previous = await tx
          .query('sale_returns', where: 'token = ?', whereArgs: [token]);
      if (previous.isNotEmpty) {
        if (previous.single['payload'] != payload) {
          throw StateError(
              'Return reference was already used with different details.');
        }
        return previous.single['id'] as int;
      }
      final available = await _items(tx, saleId);
      final selected =
          available.where((l) => quantities.containsKey(l.lineId)).toList();
      if (selected.length != quantities.length) {
        throw ArgumentError('Invalid sale item.');
      }
      var refund = 0;
      for (final item in selected) {
        refund += item.refund(quantities[item.lineId]!);
      }
      if (refund != expectedRefund) {
        throw StateError('Return balance changed. Close and reopen this sale.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final id = await tx.insert('sale_returns', {
        'sale_id': saleId,
        'token': token,
        'payload': payload,
        'reason': reason.trim(),
        'method': method,
        'total': refund,
        'created_at': now
      });
      for (final item in selected) {
        final quantity = quantities[item.lineId]!;
        final products = await tx
            .query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (products.isEmpty) {
          throw StateError(
              'Product removed: ${item.name}. Return cannot restock it.');
        }
        final product = products.single;
        final balance = (product['quantity'] as int) + quantity;
        if (balance > 100000000) {
          throw StateError('Stock limit exceeded: ${item.name}.');
        }
        await tx.update('products', {'quantity': balance},
            where: 'id = ?', whereArgs: [item.productId]);
        await tx.insert('movements', {
          'product_id': item.productId,
          'product_name': product['name'],
          'delta': quantity,
          'balance': balance,
          'note': 'Return #$id / Sale #$saleId',
          'created_at': now
        });
        await tx.insert('sale_return_lines', {
          'return_id': id,
          'sale_line_id': item.lineId,
          'quantity': quantity,
          'refund': item.refund(quantity)
        });
      }
      return id;
    });
  }
}
