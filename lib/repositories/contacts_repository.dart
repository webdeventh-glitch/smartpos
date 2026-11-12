import '../models/models.dart';
import '../services/app_logger.dart';
import 'base_repository.dart';

abstract class IContactsRepository {
  Future<List<Contact>> getContacts({String? type, String? search});
  Future<PagedResult<Contact>> getContactsPaged({
    String? type,
    String? search,
    String balanceFilter = 'all',
    int page = 1,
    int pageSize = 25,
    String? cursorName,
    int? cursorId,
    bool includeTotalCount = true,
  });
  Future<Contact?> getContactById(int id);
  Future<int> addContact(Contact contact);
  Future<int> updateContact(Contact contact);
  Future<int> deleteContact(int id);
  Future<void> updateContactBalance(int contactId, double delta);
  Future<bool> isWalkInCustomer(int? contactId);
  Future<int> addContactPayment(ContactPayment payment);
  Future<List<ContactPayment>> getContactPayments(int contactId);
  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(int contactId);
  Future<List<CustomerGroup>> getCustomerGroups();
  Future<CustomerGroup?> getCustomerGroupById(int id);
  Future<int> addCustomerGroup(CustomerGroup group);
  Future<int> updateCustomerGroup(CustomerGroup group);
  Future<int> deleteCustomerGroup(int id);
  Future<void> assignCustomerToGroup(int contactId, int? groupId);
}

/// Manages customers, suppliers, customer groups, khata balances, loyalty points, contact payments, and split payment transactions.
class ContactsRepository extends BaseRepository implements IContactsRepository {
  const ContactsRepository([super.dbService]);

  // Contacts
  @override
  Future<List<Contact>> getContacts({String? type, String? search}) async {
    final List<String> conditions = [];
    final List<dynamic> whereArgs = [];

    if (type != null) {
      conditions.add('c.type = ?');
      whereArgs.add(type);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(c.name LIKE ? OR c.phone LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%']);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT c.*, cg.name AS customer_group_name
      FROM contacts c
      LEFT JOIN customer_groups cg ON cg.id = c.customer_group_id
      $whereClause
      ORDER BY c.name ASC
    ''', whereArgs);
    return rows.map((e) => Contact.fromMap(e)).toList();
  }

  @override
  Future<PagedResult<Contact>> getContactsPaged({
    String? type,
    String? search,
    String balanceFilter = 'all',
    int page = 1,
    int pageSize = 25,
    String? cursorName,
    int? cursorId,
    bool includeTotalCount = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 25 : pageSize;
    final baseConditions = <String>[];
    final baseArgs = <dynamic>[];

    if (type != null && type.isNotEmpty) {
      baseConditions.add('c.type = ?');
      baseArgs.add(type);
    }
    if (balanceFilter == 'defaulters') {
      baseConditions.add('c.balance > 0');
    } else if (balanceFilter == 'over_limit') {
      baseConditions.add('(c.credit_limit > 0 AND c.balance > c.credit_limit)');
    } else if (balanceFilter == 'clear') {
      baseConditions.add('c.balance <= 0');
    }
    final cleanSearch = search?.trim() ?? '';
    if (cleanSearch.isNotEmpty) {
      final q = '%$cleanSearch%';
      baseConditions.add('(c.name LIKE ? OR c.phone LIKE ?)');
      baseArgs.addAll([q, q]);
    }

    final queryConditions = List<String>.from(baseConditions);
    final queryArgs = List<dynamic>.from(baseArgs);
    final useCursor = cursorName != null && cursorId != null;
    if (useCursor) {
      queryConditions.add(
        '(c.name COLLATE NOCASE > ? COLLATE NOCASE OR (c.name COLLATE NOCASE = ? COLLATE NOCASE AND c.id > ?))',
      );
      queryArgs.addAll([cursorName, cursorName, cursorId]);
    }

    final whereClause =
        queryConditions.isNotEmpty ? 'WHERE ${queryConditions.join(' AND ')}' : '';
    final limitOffset = useCursor
        ? 'LIMIT ${safePageSize + 1}'
        : 'LIMIT ${safePageSize + 1} OFFSET ${(safePage - 1) * safePageSize}';

    final rows = await db.rawQuery('''
      SELECT c.*, cg.name AS customer_group_name
      FROM contacts c
      LEFT JOIN customer_groups cg ON cg.id = c.customer_group_id
      $whereClause
      ORDER BY c.name COLLATE NOCASE ASC, c.id ASC
      $limitOffset
    ''', queryArgs);

    final hasMore = rows.length > safePageSize;
    final items = rows.take(safePageSize).map(Contact.fromMap).toList();

    int totalCount = 0;
    if (includeTotalCount) {
      final baseWhere =
          baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : '';
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM contacts c $baseWhere',
        baseArgs,
      );
      totalCount = (countRows.first['total'] as int?) ?? 0;
    }

    return PagedResult<Contact>(
      items: items,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: safePageSize,
      nextCursorId: items.isNotEmpty ? items.last.id : cursorId,
      nextCursorSortValue: items.isNotEmpty ? items.last.name : cursorName,
      hasMore: hasMore,
    );
  }

  /// Computes contact summary totals for a contact type (`customer` or `supplier`).
  Future<Map<String, num>> getContactSummaryStats({required String type}) async {
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_count,
        COALESCE(SUM(CASE WHEN balance > 0 THEN balance ELSE 0 END), 0.0) AS total_receivable,
        COALESCE(SUM(CASE WHEN balance > 0 THEN 1 ELSE 0 END), 0) AS active_dues_count,
        COALESCE(SUM(CASE WHEN credit_limit > 0 AND balance > credit_limit THEN 1 ELSE 0 END), 0) AS over_limit_count,
        COALESCE(SUM(CASE WHEN balance <= 0 THEN 1 ELSE 0 END), 0) AS clear_count
      FROM contacts
      WHERE type = ?
    ''', [type]);
    final r = rows.first;
    return {
      'totalCount': (r['total_count'] as num?)?.toInt() ?? 0,
      'totalReceivable': (r['total_receivable'] as num?)?.toDouble() ?? 0.0,
      'activeDuesCount': (r['active_dues_count'] as num?)?.toInt() ?? 0,
      'overLimitCount': (r['over_limit_count'] as num?)?.toInt() ?? 0,
      'clearCount': (r['clear_count'] as num?)?.toInt() ?? 0,
    };
  }

  @override
  Future<int> deleteContact(int id) async {
    final existing = await getContactById(id);
    final count = await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    if (count > 0) {
      await recordActivity(
        action: 'deleted',
        entityType: 'contact',
        entityId: id,
        oldValues: existing == null
            ? null
            : {
                'name': existing.name,
                'type': existing.type,
                'phone': existing.phone,
              },
      );
    }
    return count;
  }

  @override
  Future<int> addContact(Contact contact) async {
    final id = await db.insert('contacts', contact.toMap());
    final cMap = contact.toMap()..['id'] = id;
    await dbService.queueSyncItem(
      entityType: 'contact',
      entityId: id.toString(),
      action: 'create',
      payload: cMap,
    );
    await recordActivity(
      action: 'created',
      entityType: 'contact',
      entityId: id,
      newValues: {
        'name': contact.name,
        'type': contact.type,
        'phone': contact.phone,
        if (contact.customerGroupId != null)
          'customer_group_id': contact.customerGroupId,
      },
    );
    dbService.triggerAsyncMySqlSync();
    return id;
  }

  @override
  Future<int> updateContact(Contact contact) async {
    final existing = contact.id != null ? await getContactById(contact.id!) : null;
    final res = await db.update('contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
    await dbService.queueSyncItem(
      entityType: 'contact',
      entityId: (contact.id ?? 0).toString(),
      action: 'update',
      payload: contact.toMap(),
    );
    await recordActivity(
      action: 'updated',
      entityType: 'contact',
      entityId: contact.id,
      oldValues: existing == null
          ? null
          : {
              'name': existing.name,
              'type': existing.type,
              'phone': existing.phone,
              'customer_group_id': existing.customerGroupId,
            },
      newValues: {
        'name': contact.name,
        'type': contact.type,
        'phone': contact.phone,
        'customer_group_id': contact.customerGroupId,
      },
    );
    dbService.triggerAsyncMySqlSync();
    return res;
  }

  @override
  Future<Contact?> getContactById(int id) async {
    final rows = await db.rawQuery('''
      SELECT c.*, cg.name AS customer_group_name
      FROM contacts c
      LEFT JOIN customer_groups cg ON cg.id = c.customer_group_id
      WHERE c.id = ?
      LIMIT 1
    ''', [id]);
    if (rows.isNotEmpty) return Contact.fromMap(rows.first);
    return null;
  }


  /// Direct customer or supplier ledger payment recording
  Future<void> recordContactPayment({
    required int contactId,
    required double amount,
    required String paymentMethod,
    String transactionType = 'customer_payment',
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
    String chequeNumber = '',
    String bankName = '',
    String chequeDueDate = '',
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query('contacts', where: 'id = ?', whereArgs: [contactId], limit: 1);
      if (rows.isEmpty) throw Exception('Contact #$contactId not found');
      final contact = Contact.fromMap(rows.first);

      // Reduce contact balance
      await txn.rawUpdate(
        'UPDATE contacts SET balance = balance - ? WHERE id = ?',
        [amount, contactId],
      );

      final nowStr = DateTime.now().toIso8601String();
      final actualRef = refNo.isNotEmpty ? refNo : 'REC-${DateTime.now().millisecondsSinceEpoch}';
      final actualNote = note.isNotEmpty ? note : 'Direct ledger settlement for ${contact.name}';
      final isCheque = paymentMethod.toLowerCase() == 'cheque';

      final paymentId = await txn.insert('contact_payments', {
        'contact_id': contactId,
        'contact_name': contact.name,
        'payment_type': transactionType == 'customer_payment' ? 'receive' : 'pay',
        'amount': amount,
        'payment_method': paymentMethod,
        'date': nowStr,
        'ref_no': actualRef,
        'note': actualNote,
        'cheque_number': chequeNumber,
        'bank_name': bankName,
        'cheque_due_date': chequeDueDate,
        'cheque_status': isCheque ? 'pending' : '',
      });

      await txn.insert('payment_transactions', {
        'transaction_type': transactionType,
        'parent_id': paymentId,
        'contact_id': contactId,
        'contact_name': contact.name,
        'payment_method': paymentMethod,
        'amount': amount,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': actualRef,
        'note': actualNote,
        'created_by': createdBy,
        'created_at': nowStr,
        'cheque_number': chequeNumber,
        'bank_name': bankName,
        'cheque_due_date': chequeDueDate,
        'cheque_status': isCheque ? 'pending' : '',
      });
    });
  }


  // Contact Payments & Due Collections
  Future<String> generateNextPaymentRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM contact_payments');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'PAY-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  @override
  Future<int> addContactPayment(ContactPayment payment) async {
    return await db.transaction((txn) async {
      final paymentId = await txn.insert('contact_payments', payment.toMap());

      // Deduct paid amount from contact's outstanding due balance
      await txn.rawUpdate(
        'UPDATE contacts SET balance = balance - ? WHERE id = ?',
        [payment.amount, payment.contactId],
      );

      // If customer paid due in cash, update active register total cash
      if (payment.paymentType == 'receive' && payment.paymentMethod == 'cash') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
          [payment.amount],
        );
      }

      // Record in payment_transactions table for unified ledger history
      final nowStr = DateTime.now().toIso8601String();
      final isCheque = payment.paymentMethod.toLowerCase() == 'cheque';
      await txn.insert('payment_transactions', {
        'transaction_type': payment.paymentType == 'receive' ? 'customer_payment' : 'supplier_payment',
        'parent_id': paymentId,
        'contact_id': payment.contactId,
        'contact_name': payment.contactName,
        'payment_method': payment.paymentMethod,
        'amount': payment.amount,
        'account_name': (payment.paymentMethod == 'cash') ? 'Cash Register' : 'Main Bank Account',
        'transaction_date': payment.date.isNotEmpty ? payment.date : nowStr,
        'ref_no': payment.refNo,
        'note': payment.note,
        'created_by': 'Cashier',
        'created_at': nowStr,
        'cheque_number': payment.chequeNumber,
        'bank_name': payment.bankName,
        'cheque_due_date': payment.chequeDueDate,
        'cheque_status': isCheque
            ? (payment.chequeStatus.isNotEmpty ? payment.chequeStatus : 'pending')
            : '',
      });

      return paymentId;
    });
  }

  @override
  Future<List<ContactPayment>> getContactPayments(int contactId) async {
    final rows = await db.query(
      'contact_payments',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'id DESC',
    );
    return rows.map((e) => ContactPayment.fromMap(e)).toList();
  }

  // Expenses

  // Customer & Supplier shortcuts
  Future<List<Contact>> getCustomers() async => getContacts(type: 'customer');
  Future<List<Contact>> getSuppliers() async => getContacts(type: 'supplier');


  // ===================== PAYMENT TRANSACTIONS (SPLIT & DUE RECOVERIES) =====================

  Future<int> addPaymentTransaction(PaymentTransaction transaction) async {
    final id = await db.insert('payment_transactions', transaction.toMap());
    try {
      await dbService.queueSyncItem(
        entityType: 'payment_transaction',
        entityId: id.toString(),
        action: 'create',
        payload: transaction.toMap(),
      );
    } catch (e, st) {
      AppLogger.warning('DatabaseService', 'Failed queuing payment_transaction sync item', e, st);
    }
    return id;
  }

  Future<List<PaymentTransaction>> getPaymentTransactionsForSale(int saleId) async {
    final res = await db.query(
      'payment_transactions',
      where: "transaction_type = 'sale' AND parent_id = ?",
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<List<PaymentTransaction>> getPaymentTransactionsForPurchase(int purchaseId) async {
    final res = await db.query(
      'payment_transactions',
      where: "transaction_type = 'purchase' AND parent_id = ?",
      whereArgs: [purchaseId],
      orderBy: 'id ASC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(int contactId) async {
    final res = await db.query(
      'payment_transactions',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'id DESC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<List<PaymentTransaction>> getAllPaymentTransactions({int limit = 100}) async {
    final res = await db.query(
      'payment_transactions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<int> deletePaymentTransaction(int id) async {
    return await db.delete('payment_transactions', where: 'id = ?', whereArgs: [id]);
  }


  // ===================== CONTACT LEDGER & WALK-IN HELPERS =====================

  @override
  Future<void> updateContactBalance(int contactId, double deltaAmount) async {
    await db.rawUpdate('''
      UPDATE contacts 
      SET balance = balance + ? 
      WHERE id = ?
    ''', [deltaAmount, contactId]);
  }

  Future<void> updateContactLoyaltyPoints(int contactId, double deltaPoints) async {
    await db.rawUpdate('''
      UPDATE contacts 
      SET loyalty_points = MAX(0.0, COALESCE(loyalty_points, 0.0) + ?) 
      WHERE id = ?
    ''', [deltaPoints, contactId]);
  }

  @override
  Future<bool> isWalkInCustomer(int? customerId) async {
    if (customerId == null) return true;
    final res = await db.query('contacts', where: 'id = ?', whereArgs: [customerId], limit: 1);
    if (res.isEmpty) return true;
    final name = (res.first['name'] as String? ?? '').toLowerCase();
    final isWalkIn = (res.first['is_default_walk_in'] as int? ?? 0) == 1;
    return isWalkIn || name.contains('walk-in') || name.contains('walk in');
  }

  // ===================== CUSTOMER GROUPS (TIERED PRICING) =====================

  @override
  Future<List<CustomerGroup>> getCustomerGroups() async {
    final rows = await db.query('customer_groups', orderBy: 'id ASC');
    return rows.map((e) => CustomerGroup.fromMap(e)).toList();
  }

  @override
  Future<CustomerGroup?> getCustomerGroupById(int id) async {
    final rows = await db.query(
      'customer_groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomerGroup.fromMap(rows.first);
  }

  @override
  Future<int> addCustomerGroup(CustomerGroup group) async {
    final map = Map<String, dynamic>.from(group.toMap())..remove('id');
    final id = await db.insert('customer_groups', map);
    await recordActivity(
      action: 'created',
      entityType: 'customer_group',
      entityId: id,
      newValues: {
        'name': group.name,
        'amount': group.amount,
        'price_calculation_type': group.priceCalculationType,
      },
    );
    return id;
  }

  @override
  Future<int> updateCustomerGroup(CustomerGroup group) async {
    if (group.id == null) return 0;
    final existing = await getCustomerGroupById(group.id!);
    final map = Map<String, dynamic>.from(group.toMap())..remove('id');
    final count = await db.update(
      'customer_groups',
      map,
      where: 'id = ?',
      whereArgs: [group.id],
    );
    await recordActivity(
      action: 'updated',
      entityType: 'customer_group',
      entityId: group.id,
      oldValues: existing == null
          ? null
          : {
              'name': existing.name,
              'amount': existing.amount,
              'price_calculation_type': existing.priceCalculationType,
            },
      newValues: {
        'name': group.name,
        'amount': group.amount,
        'price_calculation_type': group.priceCalculationType,
      },
    );
    return count;
  }

  @override
  Future<int> deleteCustomerGroup(int id) async {
    final existing = await getCustomerGroupById(id);
    final count = await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE contacts SET customer_group_id = NULL WHERE customer_group_id = ?',
        [id],
      );
      return await txn.delete(
        'customer_groups',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    if (count > 0) {
      await recordActivity(
        action: 'deleted',
        entityType: 'customer_group',
        entityId: id,
        oldValues: existing == null ? null : {'name': existing.name, 'amount': existing.amount},
      );
    }
    return count;
  }

  @override
  Future<void> assignCustomerToGroup(int contactId, int? groupId) async {
    final existing = await getContactById(contactId);
    await db.update(
      'contacts',
      {'customer_group_id': groupId},
      where: 'id = ?',
      whereArgs: [contactId],
    );
    await recordActivity(
      action: 'updated',
      entityType: 'contact',
      entityId: contactId,
      oldValues: {'customer_group_id': existing?.customerGroupId},
      newValues: {'customer_group_id': groupId},
    );
  }

}
