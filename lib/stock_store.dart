import 'dart:io';
import 'features/returns/returns_repository.dart';
import 'features/pos/pos_repository.dart';
import 'core/money.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class StockStore {
  final Database db;
  StockStore(this.db);

  static Future<StockStore> open({String? path}) async {
    sqfliteFfiInit();
    if (path == null) {
      final base = Platform.environment['LOCALAPPDATA'];
      if (base == null) {
        throw StateError('Local application data folder unavailable.');
      }
      final folder = Directory(p.join(base, 'SimpleStock'));
      await folder.create(recursive: true);
      path = p.join(folder.path, 'stock.db');
    }
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 6,
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) await _createDocuments(db);
              if (oldVersion < 3) await _upgradeInventory(db);
              if (oldVersion < 4) await PosRepository.migrate(db);
              if (oldVersion < 5) await PosRepository.migrateV5(db);
              if (oldVersion < 6) await ReturnsRepository.migrate(db);
            },
            onCreate: (db, version) async {
              await db.execute('''CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, sku TEXT NOT NULL COLLATE NOCASE UNIQUE,
        price INTEGER NOT NULL CHECK(price >= 0),
        quantity INTEGER NOT NULL CHECK(quantity >= 0),
        minimum INTEGER NOT NULL CHECK(minimum >= 0))''');
              await db.execute('''CREATE TABLE movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
        delta INTEGER NOT NULL, balance INTEGER NOT NULL,
        note TEXT NOT NULL, created_at TEXT NOT NULL)''');
              await _createDocuments(db);
              await _upgradeInventory(db);
              await PosRepository.migrate(db);
              await PosRepository.migrateV5(db);
              await ReturnsRepository.migrate(db);
            }));
    return StockStore(db);
  }

  Future<List<Map<String, Object?>>> products() =>
      db.query('products', orderBy: 'name COLLATE NOCASE');
  Future<List<Map<String, Object?>>> history() =>
      db.query('movements', orderBy: 'id DESC', limit: 200);

  static Future<void> _upgradeInventory(Database db) async {
    await db
        .execute('ALTER TABLE products ADD COLUMN barcode TEXT COLLATE NOCASE');
    await db.execute(
        "ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT ''");
    await db.execute(
        'ALTER TABLE products ADD COLUMN cost INTEGER CHECK(cost IS NULL OR (cost >= 0 AND cost <= 9999999999))');
    await db.execute(
        'CREATE UNIQUE INDEX products_barcode ON products(barcode) WHERE barcode IS NOT NULL');
    await db
        .execute('CREATE INDEX products_name ON products(name COLLATE NOCASE)');
    await db.execute(
        'CREATE INDEX products_category ON products(category COLLATE NOCASE)');
    // Some early v1 databases contain products only.
    await db.execute('''CREATE TABLE IF NOT EXISTS movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL, delta INTEGER NOT NULL, balance INTEGER NOT NULL,
      note TEXT NOT NULL, created_at TEXT NOT NULL)''');
    await db
        .execute('CREATE INDEX movements_product ON movements(product_id, id)');
    await db.execute('CREATE INDEX documents_kind ON documents(kind, id)');
    for (final action in ['UPDATE', 'DELETE']) {
      await db.execute('''CREATE TRIGGER movements_no_${action.toLowerCase()}
        BEFORE $action ON movements BEGIN
        SELECT RAISE(ABORT, 'Stock movements are immutable'); END''');
    }
  }

  /// Bounded prefix lookup for future POS catalogs; wildcard input is literal.
  Future<List<Map<String, Object?>>> searchProducts(String query,
      {int limit = 50, int offset = 0}) {
    if (limit < 1 || limit > 200 || offset < 0) {
      throw ArgumentError('Invalid catalog page.');
    }
    final prefix = query
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    return db.query('products',
        where:
            "name LIKE ? ESCAPE '\\' OR sku LIKE ? ESCAPE '\\' OR barcode LIKE ? ESCAPE '\\'",
        whereArgs: ['$prefix%', '$prefix%', '$prefix%'],
        orderBy: 'name COLLATE NOCASE, id',
        limit: limit,
        offset: offset);
  }

  Future<Map<String, Object?>?> findBarcode(String barcode) async {
    final rows = await db.query('products',
        where: 'barcode = ?', whereArgs: [barcode.trim()], limit: 1);
    return rows.isEmpty ? null : rows.single;
  }

  static Future<void> _createDocuments(Database db) async {
    await db.execute('''CREATE TABLE documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT NOT NULL CHECK(kind IN ('sale', 'purchase')),
      party TEXT NOT NULL, note TEXT NOT NULL,
      total INTEGER NOT NULL CHECK(total >= 0), created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE document_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL, name TEXT NOT NULL, sku TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      price INTEGER NOT NULL CHECK(price >= 0))''');
    await db.execute(
        'CREATE INDEX document_lines_parent ON document_lines(document_id)');
  }

  Future<List<Map<String, Object?>>> documents(String kind) =>
      db.query('documents',
          where: 'kind = ?', whereArgs: [kind], orderBy: 'id DESC');
  Future<List<Map<String, Object?>>> documentLines(int id) =>
      db.query('document_lines',
          where: 'document_id = ?', whereArgs: [id], orderBy: 'id');

  Future<int> postDocument(
      String kind, String party, String note, List<OrderLine> lines) async {
    if (!['sale', 'purchase'].contains(kind) || lines.isEmpty) {
      throw ArgumentError('Add at least one product.');
    }
    final ids = <int>{};
    var total = 0;
    for (final line in lines) {
      if (!ids.add(line.productId) ||
          line.quantity <= 0 ||
          line.quantity > 100000000 ||
          line.price < 0 ||
          line.price > 9999999999) {
        throw ArgumentError('Invalid or duplicate product line.');
      }
      total = Money.add(total, Money.lineTotal(line.price, line.quantity));
    }
    return db.transaction((tx) async {
      final id = await tx.insert('documents', {
        'kind': kind,
        'party': party.trim(),
        'note': note.trim(),
        'total': total,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      for (final line in lines) {
        final products = await tx
            .query('products', where: 'id = ?', whereArgs: [line.productId]);
        if (products.isEmpty) {
          throw StateError('A selected product no longer exists.');
        }
        final product = products.single;
        final delta = kind == 'sale' ? -line.quantity : line.quantity;
        final balance = (product['quantity'] as int) + delta;
        if (balance < 0) {
          throw StateError('Not enough stock for ${product['name']}.');
        }
        if (balance > 100000000) throw StateError('Stock limit exceeded.');
        await tx.insert('document_lines', {
          'document_id': id,
          'product_id': line.productId,
          'name': product['name'],
          'sku': product['sku'],
          'quantity': line.quantity,
          'price': line.price
        });
        await tx.update('products', {'quantity': balance},
            where: 'id = ?', whereArgs: [line.productId]);
        await _record(tx, line.productId, product['name'] as String, delta,
            balance, '${kind == 'sale' ? 'Sale' : 'Purchase'} #$id');
      }
      return id;
    });
  }

  Future<void> save(
      {int? id,
      required String name,
      required String sku,
      required int price,
      required int minimum,
      String? barcode,
      String? category,
      int? cost,
      bool clearCost = false,
      int quantity = 0}) async {
    if (name.trim().isEmpty ||
        sku.trim().isEmpty ||
        price < 0 ||
        minimum < 0 ||
        quantity < 0 ||
        quantity > 100000000 ||
        minimum > 100000000 ||
        price > Money.maxUnitPrice ||
        name.trim().length > 100 ||
        sku.trim().length > 40 ||
        (barcode?.trim().length ?? 0) > 80 ||
        (category?.trim().length ?? 0) > 80 ||
        (cost != null && (cost < 0 || cost > Money.maxUnitPrice))) {
      throw ArgumentError('Please enter valid product details.');
    }
    await db.transaction((tx) async {
      final values = <String, Object?>{
        'name': name.trim(),
        'sku': sku.trim(),
        'price': price,
        'minimum': minimum
      };
      if (barcode != null) {
        values['barcode'] = barcode.trim().isEmpty ? null : barcode.trim();
      }
      if (category != null) values['category'] = category.trim();
      if (cost != null || clearCost) values['cost'] = cost;
      if (id == null) {
        values['quantity'] = quantity;
        final newId = await tx.insert('products', values);
        await _record(
            tx, newId, name.trim(), quantity, quantity, 'Opening stock');
      } else {
        if (await tx
                .update('products', values, where: 'id = ?', whereArgs: [id]) !=
            1) {
          throw StateError('Product no longer exists.');
        }
      }
    });
  }

  Future<void> adjust(int id, int delta, String note) async {
    if (delta == 0 || delta < -100000000 || delta > 100000000) {
      throw ArgumentError('Enter a quantity from 1 to 100,000,000.');
    }
    await db.transaction((tx) async {
      final rows = await tx.query('products', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Product no longer exists.');
      final row = rows.single;
      final balance = (row['quantity'] as int) + delta;
      if (balance < 0) throw StateError('Not enough stock available.');
      if (balance > 100000000) throw StateError('Stock limit exceeded.');
      await tx.update('products', {'quantity': balance},
          where: 'id = ?', whereArgs: [id]);
      await _record(
          tx,
          id,
          row['name'] as String,
          delta,
          balance,
          note.trim().isEmpty
              ? (delta > 0 ? 'Stock in' : 'Stock out')
              : note.trim());
    });
  }

  Future<void> delete(int id) async {
    await db.transaction((tx) async {
      final rows = await tx.query('products', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final row = rows.single;
      await _record(tx, id, row['name'] as String, -(row['quantity'] as int), 0,
          'Product deleted');
      await tx.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _record(Transaction tx, int id, String name, int delta,
      int balance, String note) async {
    await tx.insert('movements', {
      'product_id': id,
      'product_name': name,
      'delta': delta,
      'balance': balance,
      'note': note,
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
  }
}

class OrderLine {
  final int productId, quantity, price;
  const OrderLine(this.productId, this.quantity, this.price);
}
