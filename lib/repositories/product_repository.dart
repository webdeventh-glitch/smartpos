import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import '../services/product_image_service.dart';
import 'base_repository.dart';

/// Manages products, variations, units & conversions, selling price groups, warranties, categories, and brands.
class ProductRepository extends BaseRepository {
  const ProductRepository([super.dbService]);

  // Units
  Future<List<Unit>> getUnits() async {
    final rows = await db.query('units', orderBy: 'actual_name ASC');
    return rows.map((r) => Unit.fromMap(r)).toList();
  }

  Future<int> addUnit(Unit unit) async {
    return await db.insert('units', unit.toMap());
  }

  Future<int> updateUnit(Unit unit) async {
    if (unit.id == null) return 0;
    return await db.update('units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
  }

  Future<void> deleteUnit(int id) async {
    await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns all available selling units and sub-units for a product (Base unit + Sub-units)
  Future<List<Unit>> getConversionUnitsForProduct(Product product) async {
    final allUnits = await getUnits();
    final rawUnit = product.unit.toLowerCase().trim();

    // 1. Find matching base unit in DB if exists
    Unit? matchedBase;
    for (final u in allUnits) {
      if (u.actualName.toLowerCase().trim() == rawUnit ||
          u.shortName.toLowerCase().trim() == rawUnit ||
          rawUnit.contains(u.actualName.toLowerCase().trim()) ||
          rawUnit.contains(u.shortName.toLowerCase().trim())) {
        matchedBase = u;
        break;
      }
    }

    final results = <Unit>[];

    // Always add primary/base unit (multiplier = 1.0)
    final baseName = product.unit.isNotEmpty ? product.unit : 'Pieces (Pc)';
    final baseShort = matchedBase?.shortName ?? (product.unit.contains('(') ? product.unit.split('(').last.replaceAll(')', '').trim() : 'Pc');
    results.add(Unit(
      id: matchedBase?.id,
      actualName: baseName,
      shortName: baseShort,
      allowDecimal: matchedBase?.allowDecimal ?? true,
      baseUnitMultiplier: 1.0,
    ));

    // 2. Add units that reference this base unit in DB
    if (matchedBase != null && matchedBase.id != null) {
      for (final u in allUnits) {
        if (u.baseUnitId == matchedBase.id && !results.any((r) => r.actualName.toLowerCase() == u.actualName.toLowerCase())) {
          results.add(u);
        }
      }
    }

    // 3. Smart Commercial Fallback Presets if no custom sub-units exist in DB
    // (e.g. Pharmacy strips/boxes, Grocery Pao/Dhari/Mann, Textile meters/suits)
    if (results.length == 1) {
      if (rawUnit.contains('tab') || rawUnit.contains('cap') || rawUnit.contains('pill')) {
        results.add(Unit(actualName: 'Strip (10 Tabs)', shortName: 'Strip', allowDecimal: false, baseUnitMultiplier: 10.0));
        results.add(Unit(actualName: 'Box (100 Tabs)', shortName: 'Box', allowDecimal: false, baseUnitMultiplier: 100.0));
        results.add(Unit(actualName: 'Master Carton (2000)', shortName: 'Ctn', allowDecimal: false, baseUnitMultiplier: 2000.0));
      } else if (rawUnit.contains('strip')) {
        results.add(Unit(actualName: 'Box (10 Strips)', shortName: 'Box', allowDecimal: false, baseUnitMultiplier: 10.0));
        results.add(Unit(actualName: 'Master Carton (100 Strips)', shortName: 'Ctn', allowDecimal: false, baseUnitMultiplier: 100.0));
      } else if (rawUnit.contains('box') || rawUnit.contains('pack')) {
        final packMult = product.packSize > 1 ? product.packSize : 12.0;
        results.add(Unit(actualName: 'Carton (${packMult.toInt() * 10} Units)', shortName: 'Ctn', allowDecimal: false, baseUnitMultiplier: 10.0));
      } else if (rawUnit.contains('gm') || rawUnit.contains('gram') || rawUnit == 'g') {
        results.add(Unit(actualName: 'Pao (250 Grams)', shortName: 'Pao', allowDecimal: true, baseUnitMultiplier: 250.0));
        results.add(Unit(actualName: 'Aadha Kg (500 Grams)', shortName: '0.5Kg', allowDecimal: true, baseUnitMultiplier: 500.0));
        results.add(Unit(actualName: 'Kilogram (1,000 Grams)', shortName: 'Kg', allowDecimal: true, baseUnitMultiplier: 1000.0));
        results.add(Unit(actualName: 'Dhari (5 Kg)', shortName: 'Dhari', allowDecimal: true, baseUnitMultiplier: 5000.0));
        results.add(Unit(actualName: 'Mann (40 Kg)', shortName: 'Mann', allowDecimal: true, baseUnitMultiplier: 40000.0));
      } else if (rawUnit.contains('kg') || rawUnit.contains('kilo')) {
        results.add(Unit(actualName: 'Pao (0.25 Kg)', shortName: 'Pao', allowDecimal: true, baseUnitMultiplier: 0.25));
        results.add(Unit(actualName: 'Aadha Kg (0.5 Kg)', shortName: '0.5Kg', allowDecimal: true, baseUnitMultiplier: 0.5));
        results.add(Unit(actualName: '3 Pao (0.75 Kg)', shortName: '3 Pao', allowDecimal: true, baseUnitMultiplier: 0.75));
        results.add(Unit(actualName: 'Dhari (5 Kg)', shortName: 'Dhari', allowDecimal: true, baseUnitMultiplier: 5.0));
        results.add(Unit(actualName: 'Mann (40 Kg)', shortName: 'Mann', allowDecimal: true, baseUnitMultiplier: 40.0));
        results.add(Unit(actualName: 'Bori (50 Kg)', shortName: 'Bori', allowDecimal: true, baseUnitMultiplier: 50.0));
      } else if (rawUnit.contains('ml') || rawUnit.contains('milli')) {
        results.add(Unit(actualName: 'Bottle (60 ML)', shortName: '60ml', allowDecimal: false, baseUnitMultiplier: 60.0));
        results.add(Unit(actualName: 'Bottle (120 ML)', shortName: '120ml', allowDecimal: false, baseUnitMultiplier: 120.0));
        results.add(Unit(actualName: 'Liter (1,000 ML)', shortName: 'Ltr', allowDecimal: true, baseUnitMultiplier: 1000.0));
      } else if (rawUnit.contains('liter') || rawUnit.contains('litre') || rawUnit.contains('ltr')) {
        results.add(Unit(actualName: 'Bottle (500 ML)', shortName: '0.5L', allowDecimal: true, baseUnitMultiplier: 0.5));
        results.add(Unit(actualName: 'Can (5 Liters)', shortName: '5L Can', allowDecimal: true, baseUnitMultiplier: 5.0));
        results.add(Unit(actualName: 'Carton (16 Liters)', shortName: '16L Tin', allowDecimal: true, baseUnitMultiplier: 16.0));
      } else if (rawUnit.contains('meter') || rawUnit.contains('mtr') || rawUnit == 'm') {
        results.add(Unit(actualName: 'Shalwar Piece (2.25 Mtr)', shortName: '2.25m', allowDecimal: true, baseUnitMultiplier: 2.25));
        results.add(Unit(actualName: 'Suit Piece (2.5 Mtr)', shortName: '2.5m', allowDecimal: true, baseUnitMultiplier: 2.5));
        results.add(Unit(actualName: 'Full Suit (4 Mtr)', shortName: '4m', allowDecimal: true, baseUnitMultiplier: 4.0));
        results.add(Unit(actualName: 'Thaan (20 Mtr)', shortName: 'Thaan', allowDecimal: true, baseUnitMultiplier: 20.0));
        results.add(Unit(actualName: 'Roll (100 Mtr)', shortName: 'Roll', allowDecimal: true, baseUnitMultiplier: 100.0));
      } else if (rawUnit.contains('pc') || rawUnit.contains('piece') || rawUnit.contains('each') || rawUnit.contains('item')) {
        results.add(Unit(actualName: 'Half Dozen (6 Pcs)', shortName: 'Half Doz', allowDecimal: false, baseUnitMultiplier: 6.0));
        results.add(Unit(actualName: 'Dozen (12 Pcs)', shortName: 'Dozen', allowDecimal: false, baseUnitMultiplier: 12.0));
        results.add(Unit(actualName: 'Box (24 Pcs)', shortName: 'Box', allowDecimal: false, baseUnitMultiplier: 24.0));
        results.add(Unit(actualName: 'Crate (30 Pcs)', shortName: 'Crate', allowDecimal: false, baseUnitMultiplier: 30.0));
        results.add(Unit(actualName: 'Carton (72 Pcs)', shortName: 'Ctn', allowDecimal: false, baseUnitMultiplier: 72.0));
      }
    }

    return results;
  }

  // Selling Price Groups
  Future<List<SellingPriceGroup>> getSellingPriceGroups() async {
    final rows = await db.query('selling_price_groups', orderBy: 'id ASC');
    return rows.map((r) => SellingPriceGroup.fromMap(r)).toList();
  }

  Future<int> addSellingPriceGroup(SellingPriceGroup group) async {
    return await db.insert('selling_price_groups', group.toMap());
  }

  Future<int> updateSellingPriceGroup(SellingPriceGroup group) async {
    if (group.id == null) return 0;
    return await db.update('selling_price_groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<void> deleteSellingPriceGroup(int id) async {
    await db.delete('selling_price_groups', where: 'id = ?', whereArgs: [id]);
  }

  // Warranties
  Future<List<Warranty>> getWarranties() async {
    final rows = await db.query('warranties', orderBy: 'duration ASC');
    return rows.map((r) => Warranty.fromMap(r)).toList();
  }

  Future<int> addWarranty(Warranty warranty) async {
    return await db.insert('warranties', warranty.toMap());
  }

  Future<int> updateWarranty(Warranty warranty) async {
    if (warranty.id == null) return 0;
    return await db.update('warranties', warranty.toMap(), where: 'id = ?', whereArgs: [warranty.id]);
  }

  Future<void> deleteWarranty(int id) async {
    await db.delete('warranties', where: 'id = ?', whereArgs: [id]);
  }

  // Variation Templates
  Future<List<VariationTemplate>> getVariationTemplates() async {
    final rows = await db.query('variation_templates', orderBy: 'name ASC');
    return rows.map((r) => VariationTemplate.fromMap(r)).toList();
  }

  Future<int> addVariationTemplate(VariationTemplate template) async {
    return await db.insert('variation_templates', template.toMap());
  }

  Future<int> updateVariationTemplate(VariationTemplate template) async {
    if (template.id == null) return 0;
    return await db.update('variation_templates', template.toMap(), where: 'id = ?', whereArgs: [template.id]);
  }

  Future<void> deleteVariationTemplate(int id) async {
    await db.delete('variation_templates', where: 'id = ?', whereArgs: [id]);
  }

  // Product Variations
  Future<List<ProductVariation>> getProductVariations(int productId) async {
    final rows = await db.query('variations', where: 'product_id = ?', whereArgs: [productId]);
    return rows.map((r) => ProductVariation.fromMap(r)).toList();
  }

  Future<int> addProductWithVariations(Product product, List<ProductVariation> variations) async {
    return await db.transaction((txn) async {
      String uniqueSku = product.sku.trim();
      if (uniqueSku.isEmpty) {
        uniqueSku = 'PRD-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      }
      final existingSku = await txn.query('products', where: 'sku = ? COLLATE NOCASE', whereArgs: [uniqueSku], limit: 1);
      if (existingSku.isNotEmpty) {
        uniqueSku = '$uniqueSku-${Random().nextInt(900) + 100}';
      }

      String uniqueBarcode = product.barcode.trim();
      if (uniqueBarcode.isEmpty) {
        uniqueBarcode = uniqueSku;
      }
      final existingBarcode = await txn.query('products', where: 'barcode = ? COLLATE NOCASE', whereArgs: [uniqueBarcode], limit: 1);
      if (existingBarcode.isNotEmpty) {
        uniqueBarcode = '$uniqueBarcode-${Random().nextInt(900) + 100}';
      }

      final pToSave = product.copyWith(sku: uniqueSku, barcode: uniqueBarcode);
      final prodId = await txn.insert('products', pToSave.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (var v in variations) {
        await txn.insert('variations', v.toMap(prodId), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return prodId;
    });
  }

  Future<void> updateProductWithVariations(Product product, List<ProductVariation> variations) async {
    await db.transaction((txn) async {
      await txn.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id], conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('variations', where: 'product_id = ?', whereArgs: [product.id]);
      for (var v in variations) {
        await txn.insert('variations', v.toMap(product.id!), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // Products
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search}) async {
    final List<String> conditions = [];
    final List<dynamic> whereArgs = [];

    if (categoryId != null) {
      conditions.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    if (brandId != null) {
      conditions.add('brand_id = ?');
      whereArgs.add(brandId);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query('products',
        where: where, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: 'name ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  /// Builds shared SQLite filter predicates for product list & cursor queries.
  ({List<String> conditions, List<dynamic> args}) _buildProductFilterPredicates({
    int? categoryId,
    int? brandId,
    String? search,
    String stockFilter = 'all',
    String productType = 'all',
  }) {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (brandId != null) {
      conditions.add('brand_id = ?');
      args.add(brandId);
    }
    if (productType != 'all' && productType.isNotEmpty) {
      conditions.add('type = ?');
      args.add(productType);
    }
    if (stockFilter == 'in_stock') {
      conditions.add('stock_quantity > 0');
    } else if (stockFilter == 'low' || stockFilter == 'low_stock') {
      conditions.add('(stock_quantity > 0 AND stock_quantity <= alert_quantity)');
    } else if (stockFilter == 'out' || stockFilter == 'out_of_stock') {
      conditions.add('stock_quantity <= 0');
    }
    final cleanSearch = search?.trim() ?? '';
    if (cleanSearch.isNotEmpty) {
      final q = '%$cleanSearch%';
      conditions.add(
        '(name LIKE ? OR sku LIKE ? OR barcode LIKE ? OR EXISTS (SELECT 1 FROM variations v WHERE v.product_id = products.id AND v.sub_sku LIKE ?))',
      );
      args.addAll([q, q, q, q]);
    }
    return (conditions: conditions, args: args);
  }

  /// Fetches a page of products using either keyset cursor ([cursorName] + [cursorId])
  /// for fast infinite scrolling or SQL OFFSET pagination for page bars.
  Future<PagedResult<Product>> getProductsPaged({
    int? categoryId,
    int? brandId,
    String? search,
    String stockFilter = 'all',
    String productType = 'all',
    int page = 1,
    int pageSize = 25,
    String? cursorName,
    int? cursorId,
    bool includeTotalCount = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 25 : pageSize;
    final baseFilter = _buildProductFilterPredicates(
      categoryId: categoryId,
      brandId: brandId,
      search: search,
      stockFilter: stockFilter,
      productType: productType,
    );

    final queryConditions = List<String>.from(baseFilter.conditions);
    final queryArgs = List<dynamic>.from(baseFilter.args);
    final useCursor = cursorName != null && cursorId != null;

    if (useCursor) {
      queryConditions.add(
        '(name COLLATE NOCASE > ? COLLATE NOCASE OR (name COLLATE NOCASE = ? COLLATE NOCASE AND id > ?))',
      );
      queryArgs.addAll([cursorName, cursorName, cursorId]);
    }

    final whereClause =
        queryConditions.isNotEmpty ? queryConditions.join(' AND ') : null;
    final rows = await db.query(
      'products',
      where: whereClause,
      whereArgs: queryArgs.isNotEmpty ? queryArgs : null,
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
      limit: safePageSize + 1,
      offset: useCursor ? null : (safePage - 1) * safePageSize,
    );

    final hasMore = rows.length > safePageSize;
    final items = rows
        .take(safePageSize)
        .map((e) => Product.fromMap(e))
        .toList();

    int totalCount = 0;
    if (includeTotalCount) {
      final baseWhere = baseFilter.conditions.isNotEmpty
          ? 'WHERE ${baseFilter.conditions.join(' AND ')}'
          : '';
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM products $baseWhere',
        baseFilter.args,
      );
      totalCount = (countRows.first['total'] as int?) ?? 0;
    }

    return PagedResult<Product>(
      items: items,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: safePageSize,
      nextCursorId: items.isNotEmpty ? items.last.id : cursorId,
      nextCursorSortValue: items.isNotEmpty ? items.last.name : cursorName,
      hasMore: hasMore,
    );
  }

  /// Fast single-pass aggregate metrics for the Products screen header cards.
  Future<Map<String, num>> getProductCatalogStats() async {
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_count,
        COALESCE(SUM(CASE WHEN stock_quantity > 0 AND stock_quantity <= alert_quantity THEN 1 ELSE 0 END), 0) AS low_stock_count,
        COALESCE(SUM(CASE WHEN stock_quantity <= 0 THEN 1 ELSE 0 END), 0) AS out_of_stock_count,
        COALESCE(SUM(stock_quantity * purchase_price), 0.0) AS stock_value,
        COALESCE(SUM(stock_quantity), 0.0) AS total_units,
        COALESCE(SUM(stock_quantity * selling_price), 0.0) AS selling_value
      FROM products
    ''');
    final row = rows.first;
    return {
      'totalCount': (row['total_count'] as num?)?.toInt() ?? 0,
      'lowStockCount': (row['low_stock_count'] as num?)?.toInt() ?? 0,
      'outOfStockCount': (row['out_of_stock_count'] as num?)?.toInt() ?? 0,
      'stockValue': (row['stock_value'] as num?)?.toDouble() ?? 0.0,
      'totalUnits': (row['total_units'] as num?)?.toDouble() ?? 0.0,
      'sellingValue': (row['selling_value'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Resolves a map of `productId -> imagePath` only for the requested product IDs.
  Future<Map<int, String>> getProductImagePathsByIds(
    Iterable<int> productIds,
  ) async {
    final ids = productIds.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, image_path, image_color FROM products WHERE id IN ($placeholders)',
      ids,
    );
    final result = <int, String>{};
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      final resolved = ProductImageService.resolveImagePath(
        imagePath: row['image_path'] as String?,
        imageColor: row['image_color'] as String?,
      );
      if (resolved != null) {
        result[id] = resolved;
      }
    }
    return result;
  }

  /// Looks up a product by SKU, barcode, or variation `sub_sku`, returning both
  /// the parent [Product] and the matched [ProductVariation] when scanned by sub-SKU.
  Future<(Product, ProductVariation?)?> getProductWithMatchedVariationByCode(
    String code,
  ) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;

    final rows = await db.query(
      'products',
      where: 'sku = ? COLLATE NOCASE OR barcode = ? COLLATE NOCASE',
      whereArgs: [clean, clean],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return (Product.fromMap(rows.first), null);
    }

    final varRows = await db.query(
      'variations',
      where: 'sub_sku = ? COLLATE NOCASE',
      whereArgs: [clean],
      limit: 1,
    );
    if (varRows.isNotEmpty) {
      final v = ProductVariation.fromMap(varRows.first);
      final prodRows = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [v.productId],
        limit: 1,
      );
      if (prodRows.isNotEmpty) {
        return (Product.fromMap(prodRows.first), v);
      }
    }
    return null;
  }

  Future<Product?> getProductByCode(String code) async {
    final clean = code.trim();
    final rows = await db.query('products',
        where: 'sku = ? COLLATE NOCASE OR barcode = ? COLLATE NOCASE',
        whereArgs: [clean, clean],
        limit: 1);
    if (rows.isNotEmpty) return Product.fromMap(rows.first);

    // Variation Sub-SKU Lookup
    final varRows = await db.query('variations',
        where: 'sub_sku = ? COLLATE NOCASE',
        whereArgs: [clean],
        limit: 1);
    if (varRows.isNotEmpty) {
      final v = ProductVariation.fromMap(varRows.first);
      final prodRows = await db.query('products', where: 'id = ?', whereArgs: [v.productId], limit: 1);
      if (prodRows.isNotEmpty) {
        final p = Product.fromMap(prodRows.first);
        return p.copyWith(
          name: '${p.name} (${v.name})',
          sku: v.subSku,
          barcode: v.subSku,
          purchasePrice: v.purchasePrice,
          sellingPrice: v.sellingPrice,
          stockQuantity: v.stockQuantity,
        );
      }
    }
    return null;
  }

  Future<int> addProduct(Product product) async {
    String uniqueSku = product.sku.trim();
    if (uniqueSku.isEmpty) {
      uniqueSku = 'PRD-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    }
    final existingSku = await db.query('products', where: 'sku = ? COLLATE NOCASE', whereArgs: [uniqueSku], limit: 1);
    if (existingSku.isNotEmpty) {
      uniqueSku = '$uniqueSku-${Random().nextInt(900) + 100}';
    }

    String uniqueBarcode = product.barcode.trim();
    if (uniqueBarcode.isEmpty) {
      uniqueBarcode = uniqueSku;
    }
    final existingBarcode = await db.query('products', where: 'barcode = ? COLLATE NOCASE', whereArgs: [uniqueBarcode], limit: 1);
    if (existingBarcode.isNotEmpty) {
      uniqueBarcode = '$uniqueBarcode-${Random().nextInt(900) + 100}';
    }

    final pToSave = product.copyWith(sku: uniqueSku, barcode: uniqueBarcode);
    final id = await db.insert('products', pToSave.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final pMap = pToSave.toMap()..['id'] = id;
    try {
      await dbService.queueSyncItem(
        entityType: 'product',
        entityId: id.toString(),
        action: 'create',
        payload: pMap,
      );
      dbService.triggerAsyncMySqlSync();
    } catch (e, st) {
      AppLogger.warning('ProductRepository', 'Sync queue non-fatal notice (addProduct)', e, st);
    }
    await recordActivity(
      action: 'created',
      entityType: 'product',
      entityId: id,
      newValues: {
        'name': pToSave.name,
        'sku': pToSave.sku,
        'selling_price': pToSave.sellingPrice,
        'stock_quantity': pToSave.stockQuantity,
      },
    );
    return id;
  }

  Future<int> insertProduct(Product product) => addProduct(product);

  Future<Product?> getProduct(int id) => getProductById(id);

  Future<Product?> getProductById(int id) async {
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final vars = await getProductVariations(id);
    return Product.fromMap(rows.first, variations: vars);
  }

  Future<int> updateProduct(Product product) async {
    final oldRows = product.id != null
        ? await db.query('products', where: 'id = ?', whereArgs: [product.id], limit: 1)
        : const <Map<String, dynamic>>[];
    final res = await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id], conflictAlgorithm: ConflictAlgorithm.replace);
    try {
      await dbService.queueSyncItem(
        entityType: 'product',
        entityId: (product.id ?? 0).toString(),
        action: 'update',
        payload: product.toMap(),
      );
      dbService.triggerAsyncMySqlSync();
    } catch (e, st) {
      AppLogger.warning('ProductRepository', 'Sync queue non-fatal notice (updateProduct)', e, st);
    }
    await recordActivity(
      action: 'updated',
      entityType: 'product',
      entityId: product.id,
      oldValues: oldRows.isNotEmpty
          ? {
              'name': oldRows.first['name'],
              'selling_price': oldRows.first['selling_price'],
              'stock_quantity': oldRows.first['stock_quantity'],
            }
          : null,
      newValues: {
        'name': product.name,
        'selling_price': product.sellingPrice,
        'stock_quantity': product.stockQuantity,
      },
    );
    return res;
  }

  Future<int> deleteProduct(int id) async {
    final oldRows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    final res = await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'product',
      entityId: id,
      oldValues: oldRows.isNotEmpty
          ? {'name': oldRows.first['name'], 'sku': oldRows.first['sku']}
          : null,
    );
    return res;
  }

  Future<List<Product>> getLowStockProducts() async {
    final rows = await db.query('products',
        where: 'stock_quantity <= alert_quantity',
        orderBy: 'stock_quantity ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  // Categories & Brands
  Future<List<Category>> getCategories() async {
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> addCategory(Category cat) async {
    return await db.insert('categories', cat.toMap());
  }

  Future<int> insertCategory(Category cat) => addCategory(cat);

  Future<int> updateCategory(Category cat) async {
    if (cat.id == null) return 0;
    return await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<int> deleteCategory(int id) async {
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Brand>> getBrands() async {
    final rows = await db.query('brands', orderBy: 'name ASC');
    return rows.map((e) => Brand.fromMap(e)).toList();
  }

  Future<int> addBrand(Brand brand) async {
    return await db.insert('brands', brand.toMap());
  }

  Future<int> insertBrand(Brand brand) => addBrand(brand);

  Future<int> updateBrand(Brand brand) async {
    if (brand.id == null) return 0;
    return await db.update('brands', brand.toMap(), where: 'id = ?', whereArgs: [brand.id]);
  }

  Future<int> deleteBrand(int id) async {
    return await db.delete('brands', where: 'id = ?', whereArgs: [id]);
  }

}
