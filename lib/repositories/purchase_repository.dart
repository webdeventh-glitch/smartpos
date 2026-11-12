import 'dart:convert';
import '../models/models.dart';
import 'base_repository.dart';

abstract class IPurchaseRepository {
  Future<int> createPurchase(
      {required Purchase purchase, required List<Map<String, dynamic>> items});
  Future<List<Purchase>> getPurchases();
  Future<PagedResult<Purchase>> getPurchasesPaged({
    String? status,
    String? paymentStatus,
    String? search,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  });
  Future<void> settlePurchasePayment({
    required int purchaseId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  });
}

/// Manages supplier purchases, GRN status transitions, payable settlements, and purchase returns.
class PurchaseRepository extends BaseRepository implements IPurchaseRepository {
  const PurchaseRepository([super.dbService]);

  /// Settle purchase balance due to supplier and update supplier balance ledger
  @override
  Future<void> settlePurchasePayment({
    required int purchaseId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query('purchases',
          where: 'id = ?', whereArgs: [purchaseId], limit: 1);
      if (rows.isEmpty) throw Exception('Purchase #$purchaseId not found');
      final purchase = Purchase.fromMap(rows.first);

      final newPaidAmount = purchase.paidAmount + amountPaid;
      final newStatus =
          newPaidAmount >= purchase.totalAmount ? 'paid' : 'partial';

      await txn.update(
        'purchases',
        {
          'paid_amount': newPaidAmount,
          'payment_status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      // Deduct paid installment from supplier's payable ledger
      if (purchase.supplierId != null) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [amountPaid, purchase.supplierId],
        );
      }

      // Record in payment_transactions table
      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': 'purchase',
        'parent_id': purchaseId,
        'contact_id': purchase.supplierId,
        'contact_name': purchase.supplierName,
        'payment_method': paymentMethod,
        'amount': amountPaid,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': refNo.isNotEmpty
            ? refNo
            : 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty
            ? note
            : 'Supplier installment payment for ${purchase.referenceNo}',
        'created_by': createdBy,
        'created_at': nowStr,
      });
    });
  }

  Future<String> generateNextPurchaseRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM purchases');
    final maxId = (rows.first['max_id'] as int?) ?? 100;
    return 'PO-2026-${maxId + 1}';
  }

  @override
  Future<int> createPurchase({
    required Purchase purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    final purchaseId = await db.transaction((txn) async {
      final purchaseMap = purchase.toMap();
      if (purchase.itemsJson.isEmpty || purchase.itemsJson == '[]') {
        purchaseMap['items_json'] = jsonEncode(items);
      }
      final purchaseId = await txn.insert('purchases', purchaseMap);

      final isReceived = purchase.status == 'received';

      for (var item in items) {
        final productId = item['product_id'] as int?;
        final variationId = item['variation_id'] as int?;
        final qty = (item['quantity'] as num).toDouble();
        final unitCost = (item['purchase_price'] as num?)?.toDouble() ??
            (item['unit_cost'] as num?)?.toDouble();
        final sellingPrice = (item['selling_price'] as num?)?.toDouble();
        final batchNo =
            (item['batch_number'] ?? item['lot_number'])?.toString().trim();
        final mfgDate = item['manufacturing_date']?.toString().trim();
        final expDate =
            (item['expiry_date'] ?? item['exp_date'])?.toString().trim();

        if (productId != null) {
          if (isReceived) {
            if (variationId != null) {
              if (unitCost != null && sellingPrice != null && sellingPrice > 0) {
                await txn.rawUpdate(
                  'UPDATE variations SET purchase_price = ?, selling_price = ? WHERE id = ?',
                  [unitCost, sellingPrice, variationId],
                );
              } else if (unitCost != null) {
                await txn.rawUpdate(
                  'UPDATE variations SET purchase_price = ? WHERE id = ?',
                  [unitCost, variationId],
                );
              }
            } else {
              if (unitCost != null && sellingPrice != null && sellingPrice > 0) {
                await txn.rawUpdate(
                  'UPDATE products SET purchase_price = ?, selling_price = ? WHERE id = ?',
                  [unitCost, sellingPrice, productId],
                );
              } else if (unitCost != null) {
                await txn.rawUpdate(
                  'UPDATE products SET purchase_price = ? WHERE id = ?',
                  [unitCost, productId],
                );
              }
            }
            await adjustProductAndVariationStock(
              txn,
              productId: productId,
              variationId: variationId,
              delta: qty,
            );

            // If expiry date or batch is provided, update product metadata
            if (expDate != null && expDate.isNotEmpty) {
              await txn.rawUpdate(
                'UPDATE products SET expiry_date = ?, batch_number = COALESCE(NULLIF(batch_number, \'\'), ?) WHERE id = ?',
                [expDate, batchNo ?? '', productId],
              );
            } else if (batchNo != null && batchNo.isNotEmpty) {
              await txn.rawUpdate(
                'UPDATE products SET batch_number = ? WHERE id = ?',
                [batchNo, productId],
              );
            }
          }

          // Automatically record into product_serials_batches table for stock tracking & expiry alerts
          if (batchNo != null && batchNo.isNotEmpty) {
            final prodRow = await txn.query('products',
                where: 'id = ?', whereArgs: [productId], limit: 1);
            final prodName = prodRow.isNotEmpty
                ? (prodRow.first['name'] as String? ?? 'Product')
                : (item['product_name'] ?? 'Product');
            final prodSku = prodRow.isNotEmpty
                ? (prodRow.first['sku'] as String? ?? '')
                : (item['sku'] ?? '');

            await txn.insert('product_serials_batches', {
              'product_id': productId,
              'product_name': prodName,
              'sku': prodSku,
              'batch_number': batchNo,
              'manufacturing_date': mfgDate ?? '',
              'expiry_date': expDate ?? '',
              'warranty_months': 0,
              'status': isReceived ? 'in_stock' : purchase.status,
              'purchase_id': purchaseId,
              'location_id': purchase.locationId,
              'purchase_price': unitCost ?? 0.0,
              'selling_price': sellingPrice ?? 0.0,
              'notes': 'Recorded via Purchase ${purchase.refNo}',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      // Update supplier khata balance if goods are received and due amount remains
      if (isReceived && purchase.supplierId != null && purchase.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [purchase.dueAmount, purchase.supplierId],
        );
      }

      // If supplier was paid, debit the payment account or cash register
      if (purchase.paidAmount > 0) {
        if (purchase.paymentAccountId != null) {
          await txn.rawUpdate(
            'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
            [purchase.paidAmount, purchase.paymentAccountId],
          );
        } else if (purchase.paymentMethod.toLowerCase() == 'cash') {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_cash = total_sales_cash - ? WHERE status = \'open\'',
            [purchase.paidAmount],
          );
        }
      }

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'purchase',
        'entity_id': purchaseId.toString(),
        'action': 'create',
        'payload_json': jsonEncode({
          'purchase': purchase.toMap()..['id'] = purchaseId,
          'items': items,
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return purchaseId;
    });
    dbService.triggerAsyncMySqlSync();
    await recordActivity(
      action: 'created',
      entityType: 'purchase',
      entityId: purchaseId,
      newValues: {
        'ref_no': purchase.refNo,
        'supplier_name': purchase.supplierName,
        'total_amount': purchase.totalAmount,
        'status': purchase.status,
      },
    );
    return purchaseId;
  }

  /// Update purchase status (e.g. 'ordered' -> 'received', 'pending' -> 'received', or revert)
  Future<bool> updatePurchaseStatus(int purchaseId, String newStatus) async {
    return await db.transaction((txn) async {
      final rows = await txn.query('purchases',
          where: 'id = ?', whereArgs: [purchaseId], limit: 1);
      if (rows.isEmpty) return false;
      final purchase = Purchase.fromMap(rows.first);
      final oldStatus = purchase.status;
      if (oldStatus == newStatus) return true;

      final items = purchase.getItems();

      // 1. Transitioning TO received from non-received:
      if (oldStatus != 'received' && newStatus == 'received') {
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final variationId = item['variation_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final unitCost = (item['purchase_price'] as num?)?.toDouble() ??
              (item['unit_cost'] as num?)?.toDouble();
          final sellingPrice = (item['selling_price'] as num?)?.toDouble();
          final batchNo =
              (item['batch_number'] ?? item['lot_number'])?.toString().trim();
          final expDate =
              (item['expiry_date'] ?? item['exp_date'])?.toString().trim();

          if (productId != null) {
            if (variationId != null) {
              if (unitCost != null && sellingPrice != null && sellingPrice > 0) {
                await txn.rawUpdate(
                  'UPDATE variations SET purchase_price = ?, selling_price = ? WHERE id = ?',
                  [unitCost, sellingPrice, variationId],
                );
              } else if (unitCost != null) {
                await txn.rawUpdate(
                  'UPDATE variations SET purchase_price = ? WHERE id = ?',
                  [unitCost, variationId],
                );
              }
            } else {
              if (unitCost != null && sellingPrice != null && sellingPrice > 0) {
                await txn.rawUpdate(
                  'UPDATE products SET purchase_price = ?, selling_price = ? WHERE id = ?',
                  [unitCost, sellingPrice, productId],
                );
              } else if (unitCost != null) {
                await txn.rawUpdate(
                  'UPDATE products SET purchase_price = ? WHERE id = ?',
                  [unitCost, productId],
                );
              }
            }
            await adjustProductAndVariationStock(
              txn,
              productId: productId,
              variationId: variationId,
              delta: qty,
            );

            if (expDate != null && expDate.isNotEmpty) {
              await txn.rawUpdate(
                'UPDATE products SET expiry_date = ?, batch_number = COALESCE(NULLIF(batch_number, \'\'), ?) WHERE id = ?',
                [expDate, batchNo ?? '', productId],
              );
            }
          }
        }

        // Activate serial/batch entries
        await txn.rawUpdate(
          'UPDATE product_serials_batches SET status = \'in_stock\' WHERE purchase_id = ?',
          [purchaseId],
        );

        // Add due amount to supplier balance
        if (purchase.supplierId != null && purchase.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance + ? WHERE id = ?',
            [purchase.dueAmount, purchase.supplierId],
          );
        }
      }
      // 2. Transitioning FROM received to non-received:
      else if (oldStatus == 'received' && newStatus != 'received') {
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final variationId = item['variation_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          if (productId != null) {
            await adjustProductAndVariationStock(
              txn,
              productId: productId,
              variationId: variationId,
              delta: -qty,
              clampAtZero: true,
            );
          }
        }

        // Deactivate serial/batch entries
        await txn.rawUpdate(
          'UPDATE product_serials_batches SET status = ? WHERE purchase_id = ?',
          [newStatus, purchaseId],
        );

        // Revert supplier balance
        if (purchase.supplierId != null && purchase.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = MAX(0, balance - ?) WHERE id = ?',
            [purchase.dueAmount, purchase.supplierId],
          );
        }
      }

      // Update purchases table
      await txn.update(
        'purchases',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'purchase',
        'entity_id': purchaseId.toString(),
        'action': 'update_status',
        'payload_json': jsonEncode({'id': purchaseId, 'status': newStatus}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    }).then((ok) async {
      if (ok) {
        await recordActivity(
          action: 'updated',
          entityType: 'purchase',
          entityId: purchaseId,
          newValues: {'status': newStatus},
        );
      }
      return ok;
    });
  }

  Future<bool> deletePurchase(int purchaseId) async {
    return await db.transaction((txn) async {
      final rows = await txn.query('purchases',
          where: 'id = ?', whereArgs: [purchaseId], limit: 1);
      if (rows.isEmpty) return false;
      final purchase = Purchase.fromMap(rows.first);
      final wasReceived = purchase.status == 'received';

      // 1. Reverse stock only if goods were actually received into inventory
      if (wasReceived) {
        for (final item in purchase.getItems()) {
          final productId = item['product_id'] as int?;
          final variationId = item['variation_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          if (productId != null) {
            await adjustProductAndVariationStock(
              txn,
              productId: productId,
              variationId: variationId,
              delta: -qty,
              clampAtZero: true,
            );
          }
        }
      }

      // 2. Reverse batch entries
      await txn.delete('product_serials_batches',
          where: 'purchase_id = ?', whereArgs: [purchaseId]);

      // 3. Reverse supplier balance only if was received
      if (wasReceived &&
          purchase.supplierId != null &&
          purchase.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = MAX(0, balance - ?) WHERE id = ?',
          [purchase.dueAmount, purchase.supplierId],
        );
      }

      // 4. Restore payment account balance if paid
      if (purchase.paidAmount > 0 && purchase.paymentAccountId != null) {
        await txn.rawUpdate(
          'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE id = ?',
          [purchase.paidAmount, purchase.paymentAccountId],
        );
      }

      // 5. Delete contact_payment associated with this purchase ref
      await txn.delete('contact_payments',
          where: 'ref_no = ? AND payment_type = ?',
          whereArgs: [purchase.refNo, 'pay']);

      // 6. Delete purchase
      await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);

      // 7. Sync queue
      await txn.insert('sync_queue', {
        'entity_type': 'purchase',
        'entity_id': purchaseId.toString(),
        'action': 'delete',
        'payload_json':
            jsonEncode({'id': purchaseId, 'ref_no': purchase.refNo}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      await recordActivity(
        action: 'deleted',
        entityType: 'purchase',
        entityId: purchaseId,
        oldValues: {
          'ref_no': purchase.refNo,
          'supplier_name': purchase.supplierName,
          'total_amount': purchase.totalAmount,
        },
        txn: txn,
      );

      return true;
    });
  }

  @override
  Future<List<Purchase>> getPurchases() async {
    final rows = await db.query('purchases', orderBy: 'id DESC');
    return rows.map((e) => Purchase.fromMap(e)).toList();
  }

  @override
  Future<PagedResult<Purchase>> getPurchasesPaged({
    String? status,
    String? paymentStatus,
    String? search,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 25 : pageSize;
    final baseConditions = <String>[];
    final baseArgs = <dynamic>[];

    if (status != null && status.isNotEmpty && status != 'all') {
      baseConditions.add('status = ?');
      baseArgs.add(status);
    }
    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all') {
      baseConditions.add('payment_status = ?');
      baseArgs.add(paymentStatus);
    }
    final cleanSearch = search?.trim() ?? '';
    if (cleanSearch.isNotEmpty) {
      final q = '%$cleanSearch%';
      baseConditions.add('(ref_no LIKE ? OR supplier_name LIKE ?)');
      baseArgs.addAll([q, q]);
    }

    final queryConditions = List<String>.from(baseConditions);
    final queryArgs = List<dynamic>.from(baseArgs);
    if (cursorId != null) {
      queryConditions.add('id < ?');
      queryArgs.add(cursorId);
    }

    final rows = await db.query(
      'purchases',
      where: queryConditions.isNotEmpty ? queryConditions.join(' AND ') : null,
      whereArgs: queryArgs.isNotEmpty ? queryArgs : null,
      orderBy: 'id DESC',
      limit: safePageSize + 1,
      offset: cursorId != null ? null : (safePage - 1) * safePageSize,
    );

    final hasMore = rows.length > safePageSize;
    final items = rows.take(safePageSize).map(Purchase.fromMap).toList();

    int totalCount = 0;
    if (includeTotalCount) {
      final baseWhere =
          baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : '';
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM purchases $baseWhere',
        baseArgs,
      );
      totalCount = (countRows.first['total'] as int?) ?? 0;
    }

    return PagedResult<Purchase>(
      items: items,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: safePageSize,
      nextCursorId: items.isNotEmpty ? items.last.id : cursorId,
      hasMore: hasMore,
    );
  }

  /// Computes purchase summary metrics and tab counts in a single SQL query.
  Future<Map<String, num>> getPurchaseSummaryStats() async {
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_count,
        COALESCE(SUM(total_amount), 0.0) AS total_amount,
        COALESCE(SUM(CASE WHEN total_amount - paid_amount > 0 THEN total_amount - paid_amount ELSE 0 END), 0.0) AS total_due,
        COALESCE(SUM(CASE WHEN status = 'received' THEN 1 ELSE 0 END), 0) AS received_count,
        COALESCE(SUM(CASE WHEN status = 'ordered' THEN 1 ELSE 0 END), 0) AS ordered_count,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END), 0) AS pending_count
      FROM purchases
    ''');
    final r = rows.first;
    return {
      'totalCount': (r['total_count'] as num?)?.toInt() ?? 0,
      'totalAmount': (r['total_amount'] as num?)?.toDouble() ?? 0.0,
      'totalDue': (r['total_due'] as num?)?.toDouble() ?? 0.0,
      'receivedCount': (r['received_count'] as num?)?.toInt() ?? 0,
      'orderedCount': (r['ordered_count'] as num?)?.toInt() ?? 0,
      'pendingCount': (r['pending_count'] as num?)?.toInt() ?? 0,
    };
  }

  // Stock Transfers

  // ===================== PURCHASE RETURNS =====================
  Future<List<PurchaseReturn>> getPurchaseReturns() async {
    final rows = await db.query('purchase_returns', orderBy: 'id DESC');
    final List<PurchaseReturn> list = [];
    for (final r in rows) {
      final retId = r['id'] as int;
      final itemRows = await db.query('purchase_return_items',
          where: 'return_id = ?', whereArgs: [retId]);
      final items =
          itemRows.map((ir) => PurchaseReturnItem.fromMap(ir)).toList();
      list.add(PurchaseReturn.fromMap(r, items: items));
    }
    return list;
  }

  Future<String> generateNextPurchaseReturnRef() async {
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM purchase_returns');
    final count = ((res.first['c'] as int?) ?? 0) + 1;
    return 'PR-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  Future<int> addPurchaseReturn(PurchaseReturn pr) async {
    return await db.transaction((txn) async {
      final map = {
        if (pr.id != null) 'id': pr.id,
        'ref_no': pr.returnNo,
        'purchase_id': pr.purchaseId ?? 0,
        'purchase_ref': pr.purchaseRef,
        'supplier_id': pr.supplierId,
        'supplier_name': pr.supplierName,
        'total_amount': pr.totalAmount,
        'refund_amount': pr.refundAmount,
        'refund_method': 'cash',
        'status': pr.status,
        'date': pr.date,
        'note': pr.note.isNotEmpty ? pr.note : pr.reason,
        'items_json': jsonEncode(pr.items.map((i) => i.toMap()).toList()),
      };
      final id = await txn.insert('purchase_returns', map);
      for (final item in pr.items) {
        final itemMap = item.toMap();
        itemMap['return_id'] = id;
        await txn.insert('purchase_return_items', itemMap);

        // Deduct returned quantity from stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = MAX(0, stock_quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // Deduct payable to supplier
      if (pr.supplierId != null && pr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [pr.refundAmount, pr.supplierId],
        );
      }
      return id;
    });
  }
}
