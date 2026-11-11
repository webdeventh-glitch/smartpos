import '../models/models.dart';
import 'base_repository.dart';

abstract class IInventoryRepository {
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search});
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByCode(String code);
  Future<int> addProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<List<Category>> getCategories();
  Future<List<Brand>> getBrands();
  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId);
  Future<ProductSerialBatch?> getProductSerialByImei(String imei);
  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId);
  Future<List<ProductBundleItem>> getBundleItems(int parentProductId);
}

/// Manages stock transfers, stock adjustments, IMEI/serial batches, and product BOM bundles,
/// while exposing catalog queries through [ProductRepository].
class InventoryRepository extends BaseRepository implements IInventoryRepository {
  const InventoryRepository([super.dbService]);

  @override
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search}) =>
      dbService.productRepo.getProducts(categoryId: categoryId, brandId: brandId, search: search);

  @override
  Future<Product?> getProductById(int id) => dbService.productRepo.getProductById(id);

  @override
  Future<Product?> getProductByCode(String code) => dbService.productRepo.getProductByCode(code);

  @override
  Future<int> addProduct(Product product) => dbService.productRepo.addProduct(product);

  @override
  Future<int> updateProduct(Product product) => dbService.productRepo.updateProduct(product);

  @override
  Future<int> deleteProduct(int id) => dbService.productRepo.deleteProduct(id);

  @override
  Future<List<Category>> getCategories() => dbService.productRepo.getCategories();

  @override
  Future<List<Brand>> getBrands() => dbService.productRepo.getBrands();

  Future<String> generateNextTransferRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM stock_transfers');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'ST-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<StockTransfer>> getStockTransfers() async {
    final rows = await db.query('stock_transfers', orderBy: 'id DESC');
    return rows.map((e) => StockTransfer.fromMap(e)).toList();
  }

  Future<int> createStockTransfer(StockTransfer transfer) async {
    final transferId = await db.transaction((txn) async {
      final id = await txn.insert('stock_transfers', transfer.toMap());
      // In Ultimate POS, stock is deducted from source when dispatched ('in_transit' or 'completed')
      if (transfer.status == 'completed' || transfer.status == 'in_transit') {
        for (final item in transfer.getItems()) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }
      return id;
    });
    await recordActivity(
      action: 'created',
      entityType: 'stock_transfer',
      entityId: transferId,
      newValues: {
        'ref_no': transfer.refNo,
        'status': transfer.status,
        'final_total': transfer.finalTotal,
      },
    );
    return transferId;
  }

  /// Update stock transfer status (e.g. 'pending' -> 'in_transit', 'in_transit' -> 'completed', or revert)
  Future<bool> updateStockTransferStatus(int transferId, String newStatus) async {
    final ok = await db.transaction((txn) async {
      final rows = await txn.query('stock_transfers', where: 'id = ?', whereArgs: [transferId], limit: 1);
      if (rows.isEmpty) return false;
      final transfer = StockTransfer.fromMap(rows.first);
      final oldStatus = transfer.status;
      if (oldStatus == newStatus) return true;

      final items = transfer.getItems();

      // 1. Moving from pending to in_transit or completed -> Deduct stock from source
      if (oldStatus == 'pending' && (newStatus == 'in_transit' || newStatus == 'completed')) {
        for (final item in items) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }
      // 2. Moving from in_transit or completed back to pending -> Restore stock to source
      else if ((oldStatus == 'in_transit' || oldStatus == 'completed') && newStatus == 'pending') {
        for (final item in items) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      // Update transfer record status
      await txn.update(
        'stock_transfers',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [transferId],
      );

      return true;
    });
    if (ok) {
      await recordActivity(
        action: 'updated',
        entityType: 'stock_transfer',
        entityId: transferId,
        newValues: {'status': newStatus},
      );
    }
    return ok;
  }

  Future<int> deleteStockTransfer(int id) async {
    final deleted = await db.transaction((txn) async {
      final rows = await txn.query('stock_transfers', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isNotEmpty) {
        final transfer = StockTransfer.fromMap(rows.first);
        // If transfer had deducted stock (in_transit or completed), restore back to source
        if (transfer.status == 'completed' || transfer.status == 'in_transit') {
          for (final item in transfer.getItems()) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [item.quantity, item.productId],
            );
          }
        }
      }
      return await txn.delete('stock_transfers', where: 'id = ?', whereArgs: [id]);
    });
    if (deleted > 0) {
      await recordActivity(
        action: 'deleted',
        entityType: 'stock_transfer',
        entityId: id,
      );
    }
    return deleted;
  }

  // Stock Adjustments
  Future<String> generateNextAdjustmentRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM stock_adjustments');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'ADJ-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<StockAdjustment>> getStockAdjustments() async {
    final rows = await db.query('stock_adjustments', orderBy: 'id DESC');
    return rows.map((e) => StockAdjustment.fromMap(e)).toList();
  }

  Future<int> createStockAdjustment(StockAdjustment adjustment) async {
    final adjId = await db.transaction((txn) async {
      final id = await txn.insert('stock_adjustments', adjustment.toMap());
      for (final item in adjustment.getItems()) {
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return id;
    });
    await recordActivity(
      action: 'created',
      entityType: 'stock_adjustment',
      entityId: adjId,
      newValues: {
        'ref_no': adjustment.refNo,
        'adjustment_type': adjustment.adjustmentType,
        'total_amount': adjustment.totalAmount,
        'recovered_amount': adjustment.recoveredAmount,
      },
    );
    return adjId;
  }

  Future<int> deleteStockAdjustment(int id) async {
    final deleted = await db.delete('stock_adjustments', where: 'id = ?', whereArgs: [id]);
    if (deleted > 0) {
      await recordActivity(
        action: 'deleted',
        entityType: 'stock_adjustment',
        entityId: id,
      );
    }
    return deleted;
  }


  // ===================== SERIAL NUMBERS & BATCHES (IMEI / EXPIRY FIFO) =====================

  Future<int> addProductSerialBatch(ProductSerialBatch item) async {
    return await db.insert('product_serials_batches', item.toMap());
  }

  @override
  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId, {String? status}) async {
    final where = (status != null && status != 'All')
        ? 'product_id = ? AND status = ?'
        : 'product_id = ?';
    final whereArgs = (status != null && status != 'All')
        ? [productId, status]
        : [productId];

    final res = await db.query(
      'product_serials_batches',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id ASC',
    );
    return res.map((m) => ProductSerialBatch.fromMap(m)).toList();
  }

  @override
  Future<ProductSerialBatch?> getProductSerialByImei(String imei) async {
    final clean = imei.trim();
    if (clean.isEmpty) return null;
    final res = await db.query(
      'product_serials_batches',
      where: 'serial_number_1 = ? OR serial_number_2 = ?',
      whereArgs: [clean, clean],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return ProductSerialBatch.fromMap(res.first);
  }

  @override
  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId) async {
    final res = await db.query(
      'product_serials_batches',
      where: "product_id = ? AND status = 'in_stock'",
      whereArgs: [productId],
      orderBy: 'expiry_date ASC, id ASC',
    );
    return res.map((m) => ProductSerialBatch.fromMap(m)).toList();
  }

  Future<void> updateProductSerialStatus(int id, String status, {int? saleId, int? purchaseId}) async {
    final updates = <String, dynamic>{'status': status};
    if (saleId != null) updates['sale_id'] = saleId;
    if (purchaseId != null) updates['purchase_id'] = purchaseId;
    await db.update('product_serials_batches', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProductSerialBatch(int id) async {
    return await db.delete('product_serials_batches', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== PRODUCT BUNDLES & SYSTEM PACKAGES (SOLAR BOM) =====================

  Future<int> addProductBundleItem(ProductBundleItem item) async {
    return await db.insert('product_bundles', item.toMap());
  }

  @override
  Future<List<ProductBundleItem>> getBundleItems(int parentProductId) async {
    final res = await db.query(
      'product_bundles',
      where: 'parent_product_id = ?',
      whereArgs: [parentProductId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return res.map((m) => ProductBundleItem.fromMap(m)).toList();
  }

  Future<void> saveBundleItems(int parentProductId, List<ProductBundleItem> items) async {
    await db.transaction((txn) async {
      await txn.delete('product_bundles', where: 'parent_product_id = ?', whereArgs: [parentProductId]);
      for (final itm in items) {
        await txn.insert('product_bundles', itm.toMap());
      }
    });
  }

  Future<int> deleteBundleItem(int id) async {
    return await db.delete('product_bundles', where: 'id = ?', whereArgs: [id]);
  }

}
