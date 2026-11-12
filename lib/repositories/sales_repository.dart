import 'dart:convert';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'base_repository.dart';

abstract class ISalesRepository {
  Future<Sale> createSale({required Sale sale, required List<CartItem> items, List<Map<String, dynamic>>? splitTenders});
  Future<List<Sale>> getSales({String? status, String? search});
  Future<PagedResult<Sale>> getSalesPaged({
    String? status,
    String? search,
    String conversionFilter = 'all',
    int page = 1,
    int pageSize = 25,
    int? cursorId,
    bool includeTotalCount = true,
  });
  Future<List<Sale>> getQuotations({String? search, String conversionFilter = 'all'});
  Future<Sale> convertQuotationToInvoice({required int quotationId, String paymentMethod = 'cash', double? paidAmount, String note = ''});
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
  }) async {
    final createdSale = await db.transaction((txn) async {
      // 1. Insert Sale record
      final saleId = await txn.insert('sales', sale.toMap());

      // 2. Insert items and decrement stock
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));

        if (sale.saleStatus == 'final' && item.product.id != null) {
          final baseDeduction = item.quantity * (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.product.id!,
            variationId: item.variationId,
            delta: -baseDeduction,
          );
        }
      }

      // 3. Update customer balance if partial or due (Final sales only)
      if (sale.saleStatus == 'final' && sale.customerId != null && sale.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [sale.dueAmount, sale.customerId],
        );
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
            await txn.insert('payment_transactions', {
              'transaction_type': 'sale',
              'parent_id': saleId,
              'contact_id': sale.customerId,
              'contact_name': sale.customerName,
              'payment_method': m,
              'amount': amt,
              'account_name': (m == 'cash') ? 'Cash Register' : 'Main Bank Account',
              'transaction_date': sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
              'ref_no': sale.invoiceNo,
              'note': sale.note,
              'created_by': 'Cashier',
              'created_at': nowStr,
            });
          }
        }
      } else if (sale.paidAmount > 0) {
        await txn.insert('payment_transactions', {
          'transaction_type': 'sale',
          'parent_id': saleId,
          'contact_id': sale.customerId,
          'contact_name': sale.customerName,
          'payment_method': sale.paymentMethod,
          'amount': sale.paidAmount,
          'account_name': (sale.paymentMethod == 'cash') ? 'Cash Register' : 'Main Bank Account',
          'transaction_date': sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
          'ref_no': sale.invoiceNo,
          'note': sale.note,
          'created_by': 'Cashier',
          'created_at': nowStr,
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
        note: sale.note,
        createdAt: sale.createdAt,
        userName: sale.userName,
        convertedFromQuotationId: sale.convertedFromQuotationId,
        convertedToSaleId: sale.convertedToSaleId,
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
    return createdSale;
  }

  Future<Sale> updateSale({
    required int saleId,
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
  }) async {
    final updated = await db.transaction((txn) async {
      final oldSaleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      final oldSale = oldSaleRows.isNotEmpty ? Sale.fromMap(oldSaleRows.first) : null;
      final wasFinal = oldSale?.saleStatus == 'final';
      final isNowFinal = sale.saleStatus == 'final';

      // If it was already final, restore old item stock and customer balance first
      if (wasFinal) {
        final oldItems = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final row in oldItems) {
          final item = SaleItem.fromMap(row);
          if (item.productId != null) {
            final restoreQty = item.quantity * (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
            await adjustProductAndVariationStock(
              txn,
              productId: item.productId!,
              variationId: item.variationId,
              delta: restoreQty,
            );
          }
        }
        if (oldSale?.customerId != null && (oldSale?.dueAmount ?? 0) > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance - ? WHERE id = ?',
            [oldSale!.dueAmount, oldSale.customerId],
          );
        }
      }

      // Update the sales record
      final updateMap = sale.toMap();
      updateMap.remove('id');
      await txn.update('sales', updateMap, where: 'id = ?', whereArgs: [saleId]);

      // Delete old sale_items
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // Insert new sale items and decrement stock if now final
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));

        if (isNowFinal && item.product.id != null) {
          final baseDeduction = item.quantity * (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
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

      // Update cash register if now final (and was not final before)
      if (isNowFinal && !wasFinal) {
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
          if (sale.paymentMethod.toLowerCase() == 'cash' && sale.paidAmount > 0) {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else if (sale.paymentMethod.toLowerCase() == 'card' && sale.paidAmount > 0) {
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
      final saleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRows.isEmpty) return;
      final sale = Sale.fromMap(saleRows.first);

      // If sale was final, revert stock and customer balance
      if (sale.saleStatus == 'final') {
        final itemRows = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
        for (final row in itemRows) {
          final item = SaleItem.fromMap(row);
          if (item.productId != null) {
            final qtyToRestore = item.quantity * (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
            await adjustProductAndVariationStock(
              txn,
              productId: item.productId!,
              variationId: item.variationId,
              delta: qtyToRestore,
            );
          }
        }

        // Revert customer balance if due amount was added
        if (sale.customerId != null && sale.dueAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET balance = balance - ? WHERE id = ?',
            [sale.dueAmount, sale.customerId],
          );
        }

        // Revert cash register if paid in cash
        if (sale.paymentMethod.toLowerCase() == 'cash' && sale.paidAmount > 0) {
          await txn.rawUpdate(
            'UPDATE cash_registers SET total_sales_cash = total_sales_cash - ? WHERE status = \'open\'',
            [sale.paidAmount],
          );
        }
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
      conditions.add('(converted_to_sale_id IS NULL OR converted_to_sale_id = 0)');
    } else if (conversionFilter == 'converted') {
      conditions.add('(converted_to_sale_id IS NOT NULL AND converted_to_sale_id > 0)');
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
      final quoteRows = await txn.query('sales', where: 'id = ?', whereArgs: [quotationId], limit: 1);
      if (quoteRows.isEmpty) {
        throw StateError('Quotation #$quotationId not found.');
      }
      final quotation = Sale.fromMap(quoteRows.first);
      if (quotation.saleStatus != 'quotation') {
        throw StateError('Record #${quotation.invoiceNo} is not a quotation.');
      }
      if (quotation.isConvertedQuotation) {
        throw StateError('Quotation #${quotation.invoiceNo} has already been converted.');
      }

      final itemRows = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [quotationId]);
      final items = itemRows.map((r) => SaleItem.fromMap(r)).toList();

      final maxRow = await txn.rawQuery('SELECT MAX(id) as max_id FROM sales');
      final nextId = ((maxRow.first['max_id'] as int?) ?? 1000) + 1;
      final invoiceNo = 'INV-$nextId';
      final nowStr = DateTime.now().toIso8601String();
      final resolvedPaid = (paidAmount ?? quotation.totalAmount).clamp(0.0, double.infinity);
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
          final deductQty = item.quantity * (item.unitMultiplier > 0 ? item.unitMultiplier : 1.0);
          await adjustProductAndVariationStock(
            txn,
            productId: item.productId!,
            variationId: item.variationId,
            delta: -deductQty,
          );
        }
      }

      final dueAmt = (invoiceSale.totalAmount - resolvedPaid).clamp(0.0, double.infinity);
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
          'account_name': methodKey == 'cash' ? 'Cash Register' : 'Main Bank Account',
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

    final rows =
        await db.query('sales', where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  @override
  Future<PagedResult<Sale>> getSalesPaged({
    String? status,
    String? search,
    String conversionFilter = 'all',
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
    if (conversionFilter == 'pending') {
      baseConditions.add('(converted_to_sale_id IS NULL OR converted_to_sale_id = 0)');
    } else if (conversionFilter == 'converted') {
      baseConditions.add('(converted_to_sale_id IS NOT NULL AND converted_to_sale_id > 0)');
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
      final baseWhere =
          baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : '';
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

  /// Counts final, draft, and quotation rows in one pass for SalesListScreen tabs.
  Future<Map<String, int>> getSalesTabCounts() async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN sale_status = 'final' THEN 1 ELSE 0 END), 0) AS final_count,
        COALESCE(SUM(CASE WHEN sale_status = 'draft' THEN 1 ELSE 0 END), 0) AS draft_count,
        COALESCE(SUM(CASE WHEN sale_status = 'quotation' THEN 1 ELSE 0 END), 0) AS quotation_count
      FROM sales
    ''');
    final r = rows.first;
    return {
      'final': (r['final_count'] as num?)?.toInt() ?? 0,
      'draft': (r['draft_count'] as num?)?.toInt() ?? 0,
      'quotation': (r['quotation_count'] as num?)?.toInt() ?? 0,
    };
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final rows = await db.query('sale_items',
        where: 'sale_id = ?', whereArgs: [saleId]);
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
      final saleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
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
        'ref_no': refNo.isNotEmpty ? refNo : 'REC-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty ? note : 'Ledger due recovery for ${sale.invoiceNo}',
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
    return await db.insert('parked_sales', parked.toMap());
  }

  @override
  Future<List<ParkedSale>> getParkedSales() async {
    final rows = await db.query('parked_sales', orderBy: 'id DESC');
    return rows.map((e) => ParkedSale.fromMap(e)).toList();
  }

  @override
  Future<int> deleteParkedSale(int id) async {
    return await db.delete('parked_sales', where: 'id = ?', whereArgs: [id]);
  }

  // Purchases

  // ===================== SALES RETURNS =====================
  Future<List<SaleReturn>> getSaleReturns() async {
    final rows = await db.query('sale_returns', orderBy: 'id DESC');
    final List<SaleReturn> list = [];
    for (final r in rows) {
      final retId = r['id'] as int;
      final itemRows = await db.query('sale_return_items', where: 'return_id = ?', whereArgs: [retId]);
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

  Future<int> addSaleReturn(SaleReturn sr) async {
    return await db.transaction((txn) async {
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
        'note': sr.note.isNotEmpty ? sr.note : sr.reason,
        'items_json': jsonEncode(sr.items.map((i) => i.toMap()).toList()),
      };
      final id = await txn.insert('sale_returns', map);
      for (final item in sr.items) {
        final itemMap = item.toMap();
        itemMap['return_id'] = id;
        await txn.insert('sale_return_items', itemMap);

        // Restock returned product (and specific variation if linked)
        await adjustProductAndVariationStock(
          txn,
          productId: item.productId,
          variationId: item.variationId,
          delta: item.quantity,
        );
      }

      // If customer balance adjustment
      if (sr.customerId != null && sr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [sr.refundAmount, sr.customerId],
        );
      }

      // If refund was paid out in cash, deduct from active cash register
      if (sr.paymentMethod.toLowerCase() == 'cash' && sr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash - ? WHERE status = \'open\'',
          [sr.refundAmount],
        );
      }
      return id;
    });
  }

}
