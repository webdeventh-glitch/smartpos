import 'dart:convert';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'base_repository.dart';

abstract class ISalesRepository {
  Future<Sale> createSale({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
    int pointsRedeemed = 0,
    int pointsEarned = 0,
    bool enforceStock = false,
  });
  Future<List<Sale>> getSales({String? status, String? search});
  Future<PagedResult<Sale>> getSalesPaged({
    String? status,
    String? search,
    String conversionFilter = 'all',
    int? locationId,
    int? customerId,
    String? paymentStatus,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  });
  Future<List<Sale>> getQuotations(
      {String? search, String conversionFilter = 'all'});
  Future<Sale> convertQuotationToInvoice(
      {required int quotationId,
      String paymentMethod = 'cash',
      double? paidAmount,
      String note = ''});
  Future<List<SaleItem>> getSaleItems(int saleId);
  Future<void> settleSalePayment({
    required int saleId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  });
  Future<int> parkSale(ParkedSale parked);
  Future<List<ParkedSale>> getParkedSales();
  Future<int> deleteParkedSale(int id);
}

/// Manages POS sales, invoice numbering, parked carts, due settlements, and sales returns.
class SalesRepository extends BaseRepository implements ISalesRepository {
  const SalesRepository([super.dbService]);

  // POS & Sales
  Future<String> generateNextInvoiceNo() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM sales');
    final maxId = (rows.first['max_id'] as int?) ?? 1000;
    return 'INV-${maxId + 1}';
  }

  @override
  Future<Sale> createSale({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
    int pointsRedeemed = 0,
    int pointsEarned = 0,
    bool enforceStock = false,
  }) async {
    final createdSale = await db.transaction((txn) async {
      int? activeRegisterId = sale.cashRegisterId;
      if (activeRegisterId == null && sale.saleStatus == 'final') {
        final regRows = await txn.query(
          'cash_registers',
          columns: ['id'],
          where: "status = 'open'",
          orderBy: 'id DESC',
          limit: 1,
        );
        if (regRows.isNotEmpty) {
          activeRegisterId = regRows.first['id'] as int?;
        }
      }

      if (enforceStock && sale.saleStatus == 'final') {
        for (final item in items) {
          if (item.product.id == null) continue;
          final baseReq = item.quantity *
              (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          final prodRows = await txn.query(
            'products',
            columns: ['name', 'stock_quantity'],
            where: 'id = ?',
            whereArgs: [item.product.id],
            limit: 1,
          );
          if (prodRows.isNotEmpty) {
            final avail =
                (prodRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            if (baseReq > avail + 0.0001) {
              throw StateError(
                'Insufficient stock for "${prodRows.first['name']}": available ${avail.toStringAsFixed(2)}, requested ${baseReq.toStringAsFixed(2)}.',
              );
            }
          }
        }
      }

      // 1. Insert Sale record
      final saleMap = sale.toMap();
      if (activeRegisterId != null) {
        saleMap['cash_register_id'] = activeRegisterId;
      }
      final saleId = await txn.insert('sales', saleMap);

      // 2. Insert items, decrement stock & location stock, and FEFO batches
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));

        if (sale.saleStatus == 'final' && item.product.id != null) {
          final baseDeduction = item.quantity *
              (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.product.id!,
            variationId: item.variationId,
            delta: -baseDeduction,
          );
          await txn.rawUpdate(
            'UPDATE product_locations SET qty_available = qty_available - ?, updated_at = ? WHERE product_id = ? AND location_id = ?',
            [
              baseDeduction,
              DateTime.now().toIso8601String(),
              item.product.id!,
              sale.locationId,
            ],
          );

          // Automate FEFO batch / serial deduction when batches are tracked
          final batchRows = await txn.query(
            'product_serials_batches',
            where: "product_id = ? AND status = 'in_stock'",
            whereArgs: [item.product.id!],
            orderBy:
                "CASE WHEN COALESCE(expiry_date, '') = '' THEN '9999-12-31' ELSE expiry_date END ASC, id ASC",
          );
          if (batchRows.isNotEmpty) {
            int remainingUnits = baseDeduction.ceil();
            for (final b in batchRows) {
              if (remainingUnits <= 0) break;
              await txn.update(
                'product_serials_batches',
                {'status': 'sold', 'sale_id': saleId},
                where: 'id = ?',
                whereArgs: [b['id']],
              );
              remainingUnits--;
            }
          }
        }
      }

      // 3. Update customer balance if partial or due + atomic loyalty points (Final sales only)
      if (sale.saleStatus == 'final' && sale.customerId != null) {
        if (sale.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance + ? WHERE id = ?',
            [sale.dueAmount, sale.customerId],
          );
        }
        final netPointsDelta = pointsEarned - pointsRedeemed;
        if (netPointsDelta != 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET loyalty_points = MAX(0, loyalty_points + ?) WHERE id = ?',
            [netPointsDelta.toDouble(), sale.customerId],
          );
        }
      }

      // 4. Update Cash register sales if final
      if (sale.saleStatus == 'final') {
        if (splitTenders != null && splitTenders.isNotEmpty) {
          for (final st in splitTenders) {
            final amt = (st['amount'] as num?)?.toDouble() ?? 0.0;
            final m = (st['method'] as String?)?.toLowerCase() ?? 'cash';
            if (amt > 0) {
              if (m == 'cash') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
                  [amt],
                );
              } else if (m == 'card') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
                  [amt],
                );
              } else {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
                  [amt],
                );
              }
            }
          }
        } else {
          if (sale.paymentMethod == 'cash') {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else if (sale.paymentMethod == 'card') {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          }
        }
      }

      // 5. Record Payment Transactions Ledger
      final nowStr = DateTime.now().toIso8601String();
      if (splitTenders != null && splitTenders.isNotEmpty) {
        for (final st in splitTenders) {
          final amt = (st['amount'] as num?)?.toDouble() ?? 0.0;
          if (amt > 0) {
            final m = st['method'] as String? ?? 'cash';
            final isCheque = m.toLowerCase() == 'cheque';
            final chNo = (st['chequeNumber'] as String?) ?? chequeNumber;
            final chBank = (st['bankName'] as String?) ?? bankName;
            final chDue = (st['chequeDueDate'] as String?) ?? chequeDueDate;
            await txn.insert('payment_transactions', {
              'transaction_type': 'sale',
              'parent_id': saleId,
              'contact_id': sale.customerId,
              'contact_name': sale.customerName,
              'payment_method': m,
              'amount': amt,
              'account_name':
                  (m == 'cash') ? 'Cash Register' : 'Main Bank Account',
              'transaction_date':
                  sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
              'ref_no': sale.invoiceNo,
              'note': sale.note,
              'created_by': 'Cashier',
              'created_at': nowStr,
              'cheque_number': isCheque ? chNo : '',
              'bank_name': isCheque ? chBank : '',
              'cheque_due_date': isCheque ? chDue : '',
              'cheque_status': isCheque ? 'pending' : '',
            });
          }
        }
      } else if (sale.paidAmount > 0 && sale.saleStatus == 'final') {
        final isCheque = sale.paymentMethod.toLowerCase() == 'cheque';
        await txn.insert('payment_transactions', {
          'transaction_type': 'sale',
          'parent_id': saleId,
          'contact_id': sale.customerId,
          'contact_name': sale.customerName,
          'payment_method': sale.paymentMethod,
          'amount': sale.paidAmount,
          'account_name': (sale.paymentMethod == 'cash')
              ? 'Cash Register'
              : 'Main Bank Account',
          'transaction_date':
              sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
          'ref_no': sale.invoiceNo,
          'note': sale.note,
          'created_by': 'Cashier',
          'created_at': nowStr,
          'cheque_number': isCheque ? chequeNumber : '',
          'bank_name': isCheque ? bankName : '',
          'cheque_due_date': isCheque ? chequeDueDate : '',
          'cheque_status': isCheque ? 'pending' : '',
        });
      }

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'sale',
        'entity_id': saleId.toString(),
        'action': 'create',
        'payload_json': jsonEncode({
          'sale': sale.toMap()..['id'] = saleId,
          'items': items.map((i) => i.toMap(saleId)).toList(),
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': nowStr,
      });

      return Sale(
        id: saleId,
        invoiceNo: sale.invoiceNo,
        customerId: sale.customerId,
        customerName: sale.customerName,
        subtotal: sale.subtotal,
        discount: sale.discount,
        taxAmount: sale.taxAmount,
        taxRate: sale.taxRate,
        shipping: sale.shipping,
        totalAmount: sale.totalAmount,
        paidAmount: sale.paidAmount,
        paymentMethod: sale.paymentMethod,
        paymentStatus: sale.paymentStatus,
        saleStatus: sale.saleStatus,
        orderStatus: sale.orderStatus,
        note: sale.note,
        createdAt: sale.createdAt,
        userName: sale.userName,
        convertedFromQuotationId: sale.convertedFromQuotationId,
        convertedToSaleId: sale.convertedToSaleId,
        convertedFromOrderId: sale.convertedFromOrderId,
        commissionAgentId: sale.commissionAgentId,
        commissionAgentName: sale.commissionAgentName,
        commissionPercent: sale.commissionPercent,
        commissionAmount: sale.commissionAmount,
        taxGroupId: sale.taxGroupId,
        taxBreakdownJson: sale.taxBreakdownJson,
        items: items
            .map((e) => SaleItem(
                  saleId: saleId,
                  productId: e.product.id,
                  variationId: e.variationId,
                  variationName: e.variationName,
                  productName: e.product.name,
                  sku: e.product.sku,
                  unitPrice: e.unitPrice,
                  quantity: e.quantity,
                  discount: e.calculatedDiscount,
                  discountType: e.discountType,
                  discountValue: e.discountValue,
                  packDiscount: e.packDiscount,
                  taxAmount: e.taxAmount,
                  taxName: e.taxName,
                  unitName: e.selectedUnitName,
                  unitMultiplier: e.unitMultiplier,
                  subtotal: e.subtotal,
                ))
            .toList(),
      );
    });
    dbService.triggerAsyncMySqlSync();
    await recordActivity(
      action: 'created',
      entityType: sale.saleStatus == 'quotation' ? 'quotation' : 'sale',
      entityId: createdSale.id,
      newValues: {
        'invoice_no': createdSale.invoiceNo,
        'customer_name': createdSale.customerName,
        'total_amount': createdSale.totalAmount,
        'sale_status': createdSale.saleStatus,
      },
    );
    if (createdSale.saleStatus == 'final') {
      DatabaseService.onRealtimeEvent?.call('stock_changed', {
        'invoice_no': createdSale.invoiceNo,
        'location_id': sale.locationId,
        'product_ids': items.map((i) => i.product.id).whereType<int>().toList(),
      });
    }
    return createdSale;
  }

  Future<void> _assertWithinTransactionEditWindow(
    dynamic txn,
    Sale existing,
  ) async {
    if (existing.saleStatus != 'final') return;
    final bsRows = await txn.query(
      'business_settings',
      columns: ['transaction_edit_days'],
      orderBy: 'id DESC',
      limit: 1,
    );
    final editDays = bsRows.isNotEmpty
        ? ((bsRows.first['transaction_edit_days'] as num?)?.toInt() ?? 0)
        : 0;
    if (editDays <= 0) return;
    final created =
        DateTime.tryParse(existing.createdAt.replaceFirst(' ', 'T'));
    if (created == null) return;
    final ageDays = DateTime.now().difference(created).inDays;
    if (ageDays > editDays) {
      throw StateError(
        'Transaction edit window ($editDays days) has expired for ${existing.invoiceNo}.',
      );
    }
  }

  Future<void> _revertRegisterTendersForSale(dynamic txn, Sale sale) async {
    if (sale.id == null || sale.saleStatus != 'final') return;
    final txns = await txn.query(
      'payment_transactions',
      where: "transaction_type = 'sale' AND parent_id = ?",
      whereArgs: [sale.id],
    );
    if (txns.isNotEmpty) {
      for (final row in txns) {
        final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final m = (row['payment_method'] as String? ?? 'cash').toLowerCase();
        if (amt <= 0) continue;
        final col = m == 'cash'
            ? 'total_sales_cash'
            : (m == 'card' ? 'total_sales_card' : 'total_sales_other');
        await txn.rawUpdate(
          'UPDATE cash_registers SET $col = $col - ? WHERE status = \'open\'',
          [amt],
        );
      }
    } else if (sale.paidAmount > 0) {
      final m = sale.paymentMethod.toLowerCase();
      final col = m == 'cash'
          ? 'total_sales_cash'
          : (m == 'card' ? 'total_sales_card' : 'total_sales_other');
      await txn.rawUpdate(
        'UPDATE cash_registers SET $col = $col - ? WHERE status = \'open\'',
        [sale.paidAmount],
      );
    }
  }

  Future<Sale> updateSale({
    required int saleId,
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
  }) async {
    final updated = await db.transaction((txn) async {
      final oldSaleRows = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      final oldSale =
          oldSaleRows.isNotEmpty ? Sale.fromMap(oldSaleRows.first) : null;
      if (oldSale != null) {
        await _assertWithinTransactionEditWindow(txn, oldSale);
      }
      final wasFinal = oldSale?.saleStatus == 'final';
      final isNowFinal = sale.saleStatus == 'final';

      // If it was already final, restore old item stock, register buckets, and customer balance first
      if (wasFinal && oldSale != null) {
        final oldItems = await txn
            .query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final row in oldItems) {
          final item = SaleItem.fromMap(row);
          if (item.productId != null) {
            final restoreQty = item.quantity *
                (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
            await adjustProductAndVariationStock(
              txn,
              productId: item.productId!,
              variationId: item.variationId,
              delta: restoreQty,
            );
          }
        }
        if (oldSale.customerId != null && oldSale.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance - ? WHERE id = ?',
            [oldSale.dueAmount, oldSale.customerId],
          );
        }
        await _revertRegisterTendersForSale(txn, oldSale);
        await txn.delete(
          'payment_transactions',
          where: "transaction_type = 'sale' AND parent_id = ?",
          whereArgs: [saleId],
        );
      }

      // Update the sales record
      final updateMap = sale.toMap();
      updateMap.remove('id');
      await txn
          .update('sales', updateMap, where: 'id = ?', whereArgs: [saleId]);

      // Delete old sale_items
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // Insert new sale items and decrement stock if now final
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));

        if (isNowFinal && item.product.id != null) {
          final baseDeduction = item.quantity *
              (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.product.id!,
            variationId: item.variationId,
            delta: -baseDeduction,
          );
        }
      }

      // Update customer balance if now final and due
      if (isNowFinal && sale.customerId != null && sale.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [sale.dueAmount, sale.customerId],
        );
      }

      // Update cash register whenever updated sale is final (old tender buckets were reverted above)
      if (isNowFinal) {
        if (splitTenders != null && splitTenders.isNotEmpty) {
          for (final st in splitTenders) {
            final amt = (st['amount'] as num?)?.toDouble() ?? 0.0;
            final m = (st['method'] as String?)?.toLowerCase() ?? 'cash';
            if (amt > 0) {
              if (m == 'cash') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
                  [amt],
                );
              } else if (m == 'card') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
                  [amt],
                );
              } else {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
                  [amt],
                );
              }
            }
          }
        } else {
          if (sale.paymentMethod.toLowerCase() == 'cash' &&
              sale.paidAmount > 0) {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else if (sale.paymentMethod.toLowerCase() == 'card' &&
              sale.paidAmount > 0) {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else if (sale.paidAmount > 0) {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          }
        }
      }

      await recordActivity(
        action: 'updated',
        entityType: sale.saleStatus == 'quotation' ? 'quotation' : 'sale',
        entityId: saleId,
        oldValues: oldSale == null
            ? null
            : {
                'invoice_no': oldSale.invoiceNo,
                'total_amount': oldSale.totalAmount,
                'sale_status': oldSale.saleStatus,
              },
        newValues: {
          'invoice_no': sale.invoiceNo,
          'total_amount': sale.totalAmount,
          'sale_status': sale.saleStatus,
        },
        txn: txn,
      );

      return Sale.fromMap(updateMap..['id'] = saleId);
    });
    dbService.triggerAsyncMySqlSync();
    return updated;
  }

  Future<void> deleteSale(int saleId) async {
    await db.transaction((txn) async {
      final saleRows = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRows.isEmpty) return;
      final sale = Sale.fromMap(saleRows.first);
      await _assertWithinTransactionEditWindow(txn, sale);

      // If sale was final, revert stock, FEFO batches, cash register tenders & customer balance
      if (sale.saleStatus == 'final') {
        final itemRows = await txn
            .query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final row in itemRows) {
          final item = SaleItem.fromMap(row);
          if (item.productId != null) {
            final qtyToRestore = item.quantity *
                (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
            await adjustProductAndVariationStock(
              txn,
              productId: item.productId!,
              variationId: item.variationId,
              delta: qtyToRestore,
            );
            await txn.rawUpdate(
              'UPDATE product_locations SET qty_available = qty_available + ?, updated_at = ? WHERE product_id = ? AND location_id = ?',
              [
                qtyToRestore,
                DateTime.now().toIso8601String(),
                item.productId!,
                sale.locationId
              ],
            );
          }
        }

        await txn.update(
          'product_serials_batches',
          {'status': 'in_stock', 'sale_id': null},
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        // Revert customer balance if due amount was added
        if (sale.customerId != null && sale.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance - ? WHERE id = ?',
            [sale.dueAmount, sale.customerId],
          );
        }

        // Revert cash register across all payment methods (cash, card, other, split)
        await _revertRegisterTendersForSale(txn, sale);
        await txn.delete(
          'payment_transactions',
          where: "transaction_type = 'sale' AND parent_id = ?",
          whereArgs: [saleId],
        );
      }

      // Delete items & sale record
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);

      await recordActivity(
        action: 'deleted',
        entityType: sale.saleStatus == 'quotation' ? 'quotation' : 'sale',
        entityId: saleId,
        oldValues: {
          'invoice_no': sale.invoiceNo,
          'total_amount': sale.totalAmount,
          'customer_name': sale.customerName,
        },
        txn: txn,
      );
    });
    dbService.triggerAsyncMySqlSync();
  }

  /// Queries quotations filtered optionally by conversion state (`all`, `pending`, `converted`).
  @override
  Future<List<Sale>> getQuotations({
    String? search,
    String conversionFilter = 'all',
  }) async {
    final conditions = <String>["sale_status = 'quotation'"];
    final args = <dynamic>[];
    if (conversionFilter == 'pending') {
      conditions
          .add('(converted_to_sale_id IS NULL OR converted_to_sale_id = 0)');
    } else if (conversionFilter == 'converted') {
      conditions.add(
          '(converted_to_sale_id IS NOT NULL AND converted_to_sale_id > 0)');
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      conditions.add('(invoice_no LIKE ? OR customer_name LIKE ?)');
      args.addAll([q, q]);
    }
    final rows = await db.query(
      'sales',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  /// Atomically converts a saved quotation into a finalized sales invoice,
  /// updating stock, customer khata, cash register, and conversion traceability links.
  @override
  Future<Sale> convertQuotationToInvoice({
    required int quotationId,
    String paymentMethod = 'cash',
    double? paidAmount,
    String note = '',
  }) async {
    final createdInvoice = await db.transaction((txn) async {
      final quoteRows = await txn.query('sales',
          where: 'id = ?', whereArgs: [quotationId], limit: 1);
      if (quoteRows.isEmpty) {
        throw StateError('Quotation #$quotationId not found.');
      }
      final quotation = Sale.fromMap(quoteRows.first);
      if (quotation.saleStatus != 'quotation') {
        throw StateError('Record #${quotation.invoiceNo} is not a quotation.');
      }
      if (quotation.isConvertedQuotation) {
        throw StateError(
            'Quotation #${quotation.invoiceNo} has already been converted.');
      }

      final itemRows = await txn
          .query('sale_items', where: 'sale_id = ?', whereArgs: [quotationId]);
      final items = itemRows.map((r) => SaleItem.fromMap(r)).toList();

      final maxRow = await txn.rawQuery('SELECT MAX(id) as max_id FROM sales');
      final nextId = ((maxRow.first['max_id'] as int?) ?? 1000) + 1;
      final invoiceNo = 'INV-$nextId';
      final nowStr = DateTime.now().toIso8601String();
      final resolvedPaid =
          (paidAmount ?? quotation.totalAmount).clamp(0.0, double.infinity);
      final payStatus = resolvedPaid >= quotation.totalAmount
          ? 'paid'
          : (resolvedPaid > 0 ? 'partial' : 'due');

      final invoiceSale = Sale(
        invoiceNo: invoiceNo,
        customerId: quotation.customerId,
        customerName: quotation.customerName,
        subtotal: quotation.subtotal,
        discount: quotation.discount,
        taxAmount: quotation.taxAmount,
        taxRate: quotation.taxRate,
        shipping: quotation.shipping,
        totalAmount: quotation.totalAmount,
        paidAmount: resolvedPaid,
        paymentMethod: paymentMethod,
        paymentStatus: payStatus,
        saleStatus: 'final',
        note: note.isNotEmpty
            ? note
            : 'Converted from Quotation #${quotation.invoiceNo}',
        createdAt: nowStr,
        userName: AuthService.currentUser?.name ?? quotation.userName,
        convertedFromQuotationId: quotationId,
        taxGroupId: quotation.taxGroupId,
        taxBreakdownJson: quotation.taxBreakdownJson,
      );

      final saleId = await txn.insert('sales', invoiceSale.toMap());
      final savedItems = <SaleItem>[];

      for (final item in items) {
        final newItem = SaleItem(
          saleId: saleId,
          productId: item.productId,
          variationId: item.variationId,
          variationName: item.variationName,
          productName: item.productName,
          sku: item.sku,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          discount: item.discount,
          subtotal: item.subtotal,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
          bonusQuantity: item.bonusQuantity,
          packDiscount: item.packDiscount,
          unitName: item.unitName,
          unitMultiplier: item.unitMultiplier,
          discountType: item.discountType,
          discountValue: item.discountValue,
          taxAmount: item.taxAmount,
          taxName: item.taxName,
        );
        await txn.insert('sale_items', newItem.toMap());
        savedItems.add(newItem);

        if (item.productId != null) {
          final deductQty = item.quantity *
              (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.productId!,
            variationId: item.variationId,
            delta: -deductQty,
          );
        }
      }

      final dueAmt =
          (invoiceSale.totalAmount - resolvedPaid).clamp(0.0, double.infinity);
      if (quotation.customerId != null && dueAmt > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [dueAmt, quotation.customerId],
        );
      }

      if (resolvedPaid > 0) {
        final methodKey = paymentMethod.toLowerCase();
        if (methodKey == 'cash') {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        } else if (methodKey == 'card') {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        }

        await txn.insert('payment_transactions', {
          'transaction_type': 'sale',
          'parent_id': saleId,
          'contact_id': quotation.customerId,
          'contact_name': quotation.customerName,
          'payment_method': paymentMethod,
          'amount': resolvedPaid,
          'account_name':
              methodKey == 'cash' ? 'Cash Register' : 'Main Bank Account',
          'transaction_date': nowStr,
          'ref_no': invoiceNo,
          'note': 'Payment from converted quotation ${quotation.invoiceNo}',
          'created_by': AuthService.currentUser?.name ?? 'Cashier',
          'created_at': nowStr,
        });
      }

      await txn.update(
        'sales',
        {'converted_to_sale_id': saleId},
        where: 'id = ?',
        whereArgs: [quotationId],
      );

      await recordActivity(
        action: 'created',
        entityType: 'sale',
        entityId: saleId,
        newValues: {
          'invoice_no': invoiceNo,
          'converted_from_quotation_id': quotationId,
          'quotation_no': quotation.invoiceNo,
          'total_amount': invoiceSale.totalAmount,
        },
        txn: txn,
      );

      return Sale(
        id: saleId,
        invoiceNo: invoiceSale.invoiceNo,
        customerId: invoiceSale.customerId,
        customerName: invoiceSale.customerName,
        subtotal: invoiceSale.subtotal,
        discount: invoiceSale.discount,
        taxAmount: invoiceSale.taxAmount,
        taxRate: invoiceSale.taxRate,
        shipping: invoiceSale.shipping,
        totalAmount: invoiceSale.totalAmount,
        paidAmount: invoiceSale.paidAmount,
        paymentMethod: invoiceSale.paymentMethod,
        paymentStatus: invoiceSale.paymentStatus,
        saleStatus: invoiceSale.saleStatus,
        note: invoiceSale.note,
        createdAt: invoiceSale.createdAt,
        userName: invoiceSale.userName,
        convertedFromQuotationId: quotationId,
        taxGroupId: invoiceSale.taxGroupId,
        taxBreakdownJson: invoiceSale.taxBreakdownJson,
        items: savedItems,
      );
    });

    dbService.triggerAsyncMySqlSync();
    return createdInvoice;
  }

  @override
  Future<List<Sale>> getSales({String? status, String? search}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (status != null && status != 'all') {
      where = 'sale_status = ?';
      whereArgs = [status];
    }

    if (search != null && search.isNotEmpty) {
      const searchCond = '(invoice_no LIKE ? OR customer_name LIKE ?)';
      final searchParams = ['%$search%', '%$search%'];
      if (where != null) {
        where = '$where AND $searchCond';
        whereArgs!.addAll(searchParams);
      } else {
        where = searchCond;
        whereArgs = searchParams;
      }
    }

    final rows = await db.query('sales',
        where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  @override
  Future<PagedResult<Sale>> getSalesPaged({
    String? status,
    String? search,
    String conversionFilter = 'all',
    int? locationId,
    int? customerId,
    String? paymentStatus,
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 25 : pageSize;
    final baseConditions = <String>[];
    final baseArgs = <dynamic>[];

    if (status != null && status.isNotEmpty) {
      baseConditions.add('sale_status = ?');
      baseArgs.add(status);
    }
    if (locationId != null) {
      baseConditions.add('COALESCE(location_id, 1) = ?');
      baseArgs.add(locationId);
    }
    if (customerId != null) {
      baseConditions.add('customer_id = ?');
      baseArgs.add(customerId);
    }
    if (paymentStatus != null &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'All') {
      baseConditions.add('LOWER(payment_status) = ?');
      baseArgs.add(paymentStatus.toLowerCase());
    }
    if (conversionFilter == 'pending') {
      baseConditions
          .add('(converted_to_sale_id IS NULL OR converted_to_sale_id = 0)');
    } else if (conversionFilter == 'converted') {
      baseConditions.add(
          '(converted_to_sale_id IS NOT NULL AND converted_to_sale_id > 0)');
    }
    final cleanSearch = search?.trim() ?? '';
    if (cleanSearch.isNotEmpty) {
      final q = '%$cleanSearch%';
      baseConditions.add('(invoice_no LIKE ? OR customer_name LIKE ?)');
      baseArgs.addAll([q, q]);
    }

    final queryConditions = List<String>.from(baseConditions);
    final queryArgs = List<dynamic>.from(baseArgs);
    if (cursorId != null) {
      queryConditions.add('id < ?');
      queryArgs.add(cursorId);
    }

    final rows = await db.query(
      'sales',
      where: queryConditions.isNotEmpty ? queryConditions.join(' AND ') : null,
      whereArgs: queryArgs.isNotEmpty ? queryArgs : null,
      orderBy: 'id DESC',
      limit: safePageSize + 1,
      offset: cursorId != null ? null : (safePage - 1) * safePageSize,
    );

    final hasMore = rows.length > safePageSize;
    final items = rows.take(safePageSize).map(Sale.fromMap).toList();

    int totalCount = 0;
    if (includeTotalCount) {
      final baseWhere = baseConditions.isNotEmpty
          ? 'WHERE ${baseConditions.join(' AND ')}'
          : '';
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM sales $baseWhere',
        baseArgs,
      );
      totalCount = (countRows.first['total'] as int?) ?? 0;
    }

    return PagedResult<Sale>(
      items: items,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: safePageSize,
      nextCursorId: items.isNotEmpty ? items.last.id : cursorId,
      hasMore: hasMore,
    );
  }

  /// Counts final, draft, quotation, and sales_order rows in one pass.
  Future<Map<String, int>> getSalesTabCounts() async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN sale_status = 'final' THEN 1 ELSE 0 END), 0) AS final_count,
        COALESCE(SUM(CASE WHEN sale_status = 'draft' THEN 1 ELSE 0 END), 0) AS draft_count,
        COALESCE(SUM(CASE WHEN sale_status = 'quotation' THEN 1 ELSE 0 END), 0) AS quotation_count,
        COALESCE(SUM(CASE WHEN sale_status = 'sales_order' THEN 1 ELSE 0 END), 0) AS sales_order_count
      FROM sales
    ''');
    final r = rows.first;
    return {
      'final': (r['final_count'] as num?)?.toInt() ?? 0,
      'draft': (r['draft_count'] as num?)?.toInt() ?? 0,
      'quotation': (r['quotation_count'] as num?)?.toInt() ?? 0,
      'sales_order': (r['sales_order_count'] as num?)?.toInt() ?? 0,
    };
  }

  // ==================== STEP 6.1: SALES ORDERS WORKFLOW ====================

  Future<String> generateNextSalesOrderNo() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM sales');
    final maxId = (rows.first['max_id'] as int?) ?? 1000;
    return 'SO-${maxId + 1}';
  }

  Future<Map<String, dynamic>> getPendingSalesOrdersSummary(
      {int limit = 5}) async {
    final rows = await db.query(
      'sales',
      where:
          "sale_status = 'sales_order' AND COALESCE(NULLIF(order_status, ''), 'ordered') != 'completed'",
      orderBy: 'id DESC',
    );
    final orders = rows.map((e) => Sale.fromMap(e)).toList();
    final totalAmt = orders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    return {
      'count': orders.length,
      'totalAmount': totalAmt,
      'orders': orders.take(limit).toList(),
    };
  }

  /// Converts a Sales Order (partial or full line quantities) into a final Sale invoice,
  /// deducts stock cleanly, records payment/cheque ledger, and transitions order_status
  /// across `ordered` -> `partial` -> `completed`.
  Future<Sale> convertSalesOrderToInvoice({
    required int orderId,
    Map<int, double>? fulfillQuantitiesByItemId,
    String paymentMethod = 'cash',
    double? paidAmount,
    String note = '',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) async {
    final createdInvoice = await db.transaction((txn) async {
      final orderRows = await txn.query(
        'sales',
        where: "id = ? AND sale_status = 'sales_order'",
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw Exception('Sales Order #$orderId not found.');
      }
      final order = Sale.fromMap(orderRows.first);
      if (order.orderStatus == 'completed') {
        throw Exception('Sales Order ${order.invoiceNo} is already completed.');
      }

      final itemRows = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [orderId],
        orderBy: 'id ASC',
      );
      final orderItems = itemRows.map((e) => SaleItem.fromMap(e)).toList();
      if (orderItems.isEmpty) {
        throw Exception('Sales Order ${order.invoiceNo} has no line items.');
      }

      final itemsToInvoice = <Map<String, dynamic>>[];
      double invoiceSubtotal = 0.0;
      double invoiceTax = 0.0;

      for (final item in orderItems) {
        final itemId = item.id!;
        final remaining = item.remainingQuantity;
        if (remaining <= 0) continue;

        final requested = fulfillQuantitiesByItemId != null
            ? (fulfillQuantitiesByItemId[itemId] ?? 0.0)
            : remaining;
        final fulfillQty = requested.clamp(0.0, remaining).toDouble();
        if (fulfillQty <= 0) continue;

        final ratio = item.quantity > 0 ? (fulfillQty / item.quantity) : 0.0;
        final lineSub =
            double.parse((item.unitPrice * fulfillQty).toStringAsFixed(2));
        final lineDisc =
            double.parse((item.discount * ratio).toStringAsFixed(2));
        final lineTax =
            double.parse((item.taxAmount * ratio).toStringAsFixed(2));

        invoiceSubtotal += lineSub;
        invoiceTax += lineTax;

        itemsToInvoice.add({
          'sourceItem': item,
          'fulfillQty': fulfillQty,
          'lineSubtotal': (lineSub - lineDisc).clamp(0.0, double.infinity),
          'lineDisc': lineDisc,
          'lineTax': lineTax,
        });
      }

      if (itemsToInvoice.isEmpty) {
        throw Exception('No remaining item quantity selected to convert.');
      }

      final orderSubtotal =
          order.subtotal > 0 ? order.subtotal : invoiceSubtotal;
      final orderScale = orderSubtotal > 0
          ? (invoiceSubtotal / orderSubtotal).clamp(0.0, 1.0)
          : 1.0;
      final invoiceOrderDiscount =
          double.parse((order.discount * orderScale).toStringAsFixed(2));
      final invoiceShipping =
          order.orderStatus == 'ordered' ? order.shipping : 0.0;
      final finalTotal = double.parse(
        (invoiceSubtotal - invoiceOrderDiscount + invoiceTax + invoiceShipping)
            .clamp(0.0, double.infinity)
            .toStringAsFixed(2),
      );
      final resolvedPaid = (paidAmount ?? finalTotal).clamp(0.0, finalTotal);
      final paymentStatus = resolvedPaid >= finalTotal
          ? 'paid'
          : (resolvedPaid > 0 ? 'partial' : 'due');
      final commAmt = order.commissionPercent > 0
          ? double.parse(((finalTotal * order.commissionPercent) / 100.0)
              .toStringAsFixed(2))
          : 0.0;

      final maxRows = await txn.rawQuery('SELECT MAX(id) as max_id FROM sales');
      final maxId = (maxRows.first['max_id'] as int?) ?? 1000;
      final invoiceNo = 'INV-${maxId + 1}';
      final nowStr = DateTime.now().toIso8601String();

      final invoiceSale = Sale(
        invoiceNo: invoiceNo,
        customerId: order.customerId,
        customerName: order.customerName,
        subtotal: invoiceSubtotal,
        discount: invoiceOrderDiscount,
        taxAmount: invoiceTax,
        taxRate: order.taxRate,
        shipping: invoiceShipping,
        totalAmount: finalTotal,
        paidAmount: resolvedPaid,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        saleStatus: 'final',
        orderStatus: '',
        note: note.trim().isNotEmpty
            ? note.trim()
            : 'Converted from Sales Order #${order.invoiceNo}',
        createdAt: nowStr,
        userName: AuthService.currentUser?.name ?? order.userName,
        convertedFromOrderId: orderId,
        commissionAgentId: order.commissionAgentId,
        commissionAgentName: order.commissionAgentName,
        commissionPercent: order.commissionPercent,
        commissionAmount: commAmt,
        taxGroupId: order.taxGroupId,
        taxBreakdownJson: order.taxBreakdownJson,
      );

      final saleId = await txn.insert('sales', invoiceSale.toMap());
      final savedItems = <SaleItem>[];

      for (final entry in itemsToInvoice) {
        final item = entry['sourceItem'] as SaleItem;
        final fulfillQty = entry['fulfillQty'] as double;
        final lineDisc = entry['lineDisc'] as double;
        final lineTax = entry['lineTax'] as double;
        final lineSub = entry['lineSubtotal'] as double;

        final newItem = SaleItem(
          saleId: saleId,
          productId: item.productId,
          variationId: item.variationId,
          variationName: item.variationName,
          productName: item.productName,
          sku: item.sku,
          unitPrice: item.unitPrice,
          quantity: fulfillQty,
          fulfilledQuantity: fulfillQty,
          discount: lineDisc,
          subtotal: lineSub,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
          bonusQuantity: item.bonusQuantity,
          packDiscount: item.packDiscount,
          unitName: item.unitName,
          unitMultiplier: item.unitMultiplier,
          discountType: item.discountType,
          discountValue: item.discountValue,
          taxAmount: lineTax,
          taxName: item.taxName,
        );
        await txn.insert('sale_items', newItem.toMap());
        savedItems.add(newItem);

        // Update fulfilled_quantity on source Sales Order line item
        await txn.rawUpdate(
          'UPDATE sale_items SET fulfilled_quantity = fulfilled_quantity + ? WHERE id = ?',
          [fulfillQty, item.id],
        );

        // Deduct live stock
        if (item.productId != null) {
          final deductQty = fulfillQty *
              (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.productId!,
            variationId: item.variationId,
            delta: -deductQty,
          );
        }
      }

      // Check whether all Sales Order items are now completely fulfilled
      final refreshedItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [orderId],
      );
      final allCompleted = refreshedItems.every((r) {
        final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
        final fulfilled = (r['fulfilled_quantity'] as num?)?.toDouble() ?? 0.0;
        return fulfilled >= qty - 0.0001;
      });
      await txn.update(
        'sales',
        {
          'order_status': allCompleted ? 'completed' : 'partial',
          if (allCompleted) 'converted_to_sale_id': saleId,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final dueAmt = (finalTotal - resolvedPaid).clamp(0.0, double.infinity);
      if (order.customerId != null && dueAmt > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [dueAmt, order.customerId],
        );
      }

      if (resolvedPaid > 0) {
        final methodKey = paymentMethod.toLowerCase();
        if (methodKey == 'cash') {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        } else if (methodKey == 'card') {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
            [resolvedPaid],
          );
        }

        final isCheque = methodKey == 'cheque';
        await txn.insert('payment_transactions', {
          'transaction_type': 'sale',
          'parent_id': saleId,
          'contact_id': order.customerId,
          'contact_name': order.customerName,
          'payment_method': paymentMethod,
          'amount': resolvedPaid,
          'account_name':
              methodKey == 'cash' ? 'Cash Register' : 'Main Bank Account',
          'transaction_date': nowStr,
          'ref_no': invoiceNo,
          'note': 'Invoice from Sales Order ${order.invoiceNo}',
          'created_by': AuthService.currentUser?.name ?? 'Cashier',
          'created_at': nowStr,
          'cheque_number': isCheque ? chequeNumber : '',
          'bank_name': isCheque ? bankName : '',
          'cheque_due_date': isCheque ? chequeDueDate : '',
          'cheque_status': isCheque ? 'pending' : '',
        });
      }

      await recordActivity(
        action: 'converted',
        entityType: 'sales_order',
        entityId: orderId,
        newValues: {
          'invoice_no': invoiceNo,
          'invoice_id': saleId,
          'order_status': allCompleted ? 'completed' : 'partial',
          'total_amount': finalTotal,
        },
        txn: txn,
      );

      return Sale(
        id: saleId,
        invoiceNo: invoiceSale.invoiceNo,
        customerId: invoiceSale.customerId,
        customerName: invoiceSale.customerName,
        subtotal: invoiceSale.subtotal,
        discount: invoiceSale.discount,
        taxAmount: invoiceSale.taxAmount,
        taxRate: invoiceSale.taxRate,
        shipping: invoiceSale.shipping,
        totalAmount: invoiceSale.totalAmount,
        paidAmount: invoiceSale.paidAmount,
        paymentMethod: invoiceSale.paymentMethod,
        paymentStatus: invoiceSale.paymentStatus,
        saleStatus: 'final',
        note: invoiceSale.note,
        createdAt: invoiceSale.createdAt,
        userName: invoiceSale.userName,
        convertedFromOrderId: orderId,
        commissionAgentId: invoiceSale.commissionAgentId,
        commissionAgentName: invoiceSale.commissionAgentName,
        commissionPercent: invoiceSale.commissionPercent,
        commissionAmount: invoiceSale.commissionAmount,
        items: savedItems,
      );
    });

    dbService.triggerAsyncMySqlSync();
    return createdInvoice;
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final rows =
        await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map((e) => SaleItem.fromMap(e)).toList();
  }

  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) async {
    final clean = invoiceNo.trim();
    if (clean.isEmpty) return null;
    final rows = await db.query(
      'sales',
      where: 'invoice_no = ? OR invoice_no = ? OR invoice_no LIKE ?',
      whereArgs: [clean, 'INV-$clean', '%$clean%'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final sale = Sale.fromMap(rows.first);
    final items = await getSaleItems(sale.id!);
    return Sale.fromMap(sale.toMap(), items: items);
  }

  /// Settle partial / due sales payment and update customer balance ledger
  @override
  Future<void> settleSalePayment({
    required int saleId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) async {
    await db.transaction((txn) async {
      final saleRows = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRows.isEmpty) throw Exception('Sale #$saleId not found');
      final sale = Sale.fromMap(saleRows.first);

      final newPaidAmount = sale.paidAmount + amountPaid;
      final newStatus = newPaidAmount >= sale.totalAmount ? 'paid' : 'partial';

      await txn.update(
        'sales',
        {
          'paid_amount': newPaidAmount,
          'payment_status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // Deduct recovered payment from customer's due ledger
      if (sale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [amountPaid, sale.customerId],
        );
      }

      // Record in payment_transactions table
      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': 'sale',
        'parent_id': saleId,
        'contact_id': sale.customerId,
        'contact_name': sale.customerName,
        'payment_method': paymentMethod,
        'amount': amountPaid,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': refNo.isNotEmpty
            ? refNo
            : 'REC-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty
            ? note
            : 'Ledger due recovery for ${sale.invoiceNo}',
        'created_by': createdBy,
        'created_at': nowStr,
      });

      // Update cash register if cash
      if (paymentMethod == 'cash') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
          [amountPaid],
        );
      } else if (paymentMethod == 'card') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
          [amountPaid],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
          [amountPaid],
        );
      }
    });
  }

  @override
  Future<int> parkSale(ParkedSale parked) async {
    final id = await db.insert('parked_sales', parked.toMap());
    DatabaseService.onRealtimeEvent?.call('drafts_updated', {
      'action': 'created',
      'id': id,
      'note': parked.note,
      'customer_name': parked.customerName,
      'total': parked.total,
    });
    return id;
  }

  @override
  Future<List<ParkedSale>> getParkedSales() async {
    final rows = await db.query('parked_sales', orderBy: 'id DESC');
    return rows.map((e) => ParkedSale.fromMap(e)).toList();
  }

  @override
  Future<int> deleteParkedSale(int id) async {
    final count =
        await db.delete('parked_sales', where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      DatabaseService.onRealtimeEvent?.call('drafts_updated', {
        'action': 'deleted',
        'id': id,
      });
    }
    return count;
  }

  // Purchases

  // ===================== SALES RETURNS =====================
  Future<List<SaleReturn>> getSaleReturns() async {
    final rows = await db.query('sale_returns', orderBy: 'id DESC');
    final List<SaleReturn> list = [];
    for (final r in rows) {
      final retId = r['id'] as int;
      final itemRows = await db.query('sale_return_items',
          where: 'return_id = ?', whereArgs: [retId]);
      final items = itemRows.map((ir) => SaleReturnItem.fromMap(ir)).toList();
      list.add(SaleReturn.fromMap(r, items: items));
    }
    return list;
  }

  Future<String> generateNextSaleReturnRef() async {
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM sale_returns');
    final count = ((res.first['c'] as int?) ?? 0) + 1;
    return 'SR-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  /// Returns total already-returned quantities grouped by `product_id` for [saleId].
  Future<Map<int, double>> getReturnedQuantitiesForSale(int saleId) async {
    final rows = await db.rawQuery('''
      SELECT sri.product_id, SUM(sri.quantity) as returned_qty
      FROM sale_return_items sri
      JOIN sale_returns sr ON sr.id = sri.return_id
      WHERE sr.sale_id = ?
      GROUP BY sri.product_id
    ''', [saleId]);
    return {
      for (final r in rows)
        if (r['product_id'] != null)
          (r['product_id'] as int):
              (r['returned_qty'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<int> addSaleReturn(SaleReturn sr, {int locationId = 1}) async {
    final returnId = await db.transaction((txn) async {
      final map = {
        if (sr.id != null) 'id': sr.id,
        'ref_no': sr.returnNo,
        'sale_id': sr.saleId ?? 0,
        'invoice_no': sr.invoiceNo,
        'customer_id': sr.customerId,
        'customer_name': sr.customerName,
        'total_amount': sr.totalAmount,
        'refund_amount': sr.refundAmount,
        'refund_method': sr.paymentMethod,
        'status': sr.refundStatus,
        'date': sr.date,
        'reason': sr.reason,
        'note': sr.note.isNotEmpty ? sr.note : sr.reason,
        'created_by': sr.createdBy,
        'items_json': jsonEncode(sr.items.map((i) => i.toMap()).toList()),
      };
      final id = await txn.insert('sale_returns', map);
      int targetLocId = locationId;
      if (targetLocId <= 1 && sr.saleId != null && sr.saleId! > 0) {
        final origSale = await txn.query(
          'sales',
          columns: ['location_id'],
          where: 'id = ?',
          whereArgs: [sr.saleId],
          limit: 1,
        );
        if (origSale.isNotEmpty) {
          targetLocId = (origSale.first['location_id'] as int?) ?? 1;
        }
      }
      for (final item in sr.items) {
        final itemMap = item.toMap();
        itemMap['return_id'] = id;
        await txn.insert('sale_return_items', itemMap);

        final mult = item.unitMultiplier > 0 ? item.unitMultiplier : 1.0;
        final restockQty = item.quantity * mult;
        // Restock returned product (and specific variation if linked)
        await adjustProductAndVariationStock(
          txn,
          productId: item.productId,
          variationId: item.variationId,
          delta: restockQty,
        );
        final updatedLoc = await txn.rawUpdate(
          'UPDATE product_locations SET qty_available = qty_available + ?, updated_at = ? WHERE product_id = ? AND location_id = ?',
          [
            restockQty,
            DateTime.now().toIso8601String(),
            item.productId,
            targetLocId,
          ],
        );
        if (updatedLoc == 0) {
          await txn.insert('product_locations', {
            'product_id': item.productId,
            'location_id': targetLocId,
            'qty_available': restockQty,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Reduce customer balance ONLY when refund is issued as credit note / receivable offset
      // (avoid double-crediting when cash or bank refund is paid out immediately)
      final method = sr.paymentMethod.toLowerCase();
      if (sr.customerId != null &&
          sr.refundAmount > 0 &&
          (method == 'credit_note' || method == 'balance_adjustment')) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [sr.refundAmount, sr.customerId],
        );
      }

      // If refund was paid out in cash, deduct from active cash register
      if (method == 'cash' && sr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash - ? WHERE status = \'open\'',
          [sr.refundAmount],
        );
      }
      return id;
    });
    DatabaseService.onRealtimeEvent?.call('stock_changed', {
      'action': 'sale_return',
      'location_id': locationId,
      'product_ids': sr.items.map((i) => i.productId).toList(),
    });
    return returnId;
  }
}
