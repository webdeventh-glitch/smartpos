import '../models/models.dart';
import 'base_repository.dart';

/// Repository for Phase 6 business workflows:
/// Cheque Management, Commission Agents & Reports, and Discount Schedules.
class AdvancedFeaturesRepository extends BaseRepository {
  const AdvancedFeaturesRepository([super.dbService]);

  // ==================== STEP 6.3: CHEQUE MANAGEMENT ====================

  Future<List<PaymentTransaction>> getCheques({
    String? status,
    String? transactionType,
    String? search,
  }) async {
    final where = <String>["LOWER(payment_method) = 'cheque'"];
    final args = <dynamic>[];

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'overdue') {
        where.add(
          "COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' "
          "AND cheque_due_date IS NOT NULL AND TRIM(cheque_due_date) != '' "
          "AND SUBSTR(cheque_due_date, 1, 10) < ?",
        );
        args.add(todayStr);
      } else {
        where.add("COALESCE(NULLIF(cheque_status, ''), 'pending') = ?");
        args.add(status);
      }
    }

    if (transactionType != null &&
        transactionType.isNotEmpty &&
        transactionType != 'all') {
      where.add('transaction_type = ?');
      args.add(transactionType);
    }

    final q = (search ?? '').trim().toLowerCase();
    if (q.isNotEmpty) {
      where.add(
        '(LOWER(contact_name) LIKE ? OR LOWER(COALESCE(cheque_number, "")) LIKE ? '
        'OR LOWER(COALESCE(bank_name, "")) LIKE ? OR LOWER(COALESCE(ref_no, "")) LIKE ?)',
      );
      final pattern = '%$q%';
      args.addAll([pattern, pattern, pattern, pattern]);
    }

    final rows = await db.query(
      'payment_transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: "CASE WHEN COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' THEN 0 ELSE 1 END, "
          'cheque_due_date ASC, id DESC',
    );
    return rows.map((e) => PaymentTransaction.fromMap(e)).toList();
  }

  Future<Map<String, num>> getChequeSummary() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_count,
        COALESCE(SUM(CASE WHEN COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE WHEN COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' THEN amount ELSE 0 END), 0.0) AS pending_amount,
        COALESCE(SUM(CASE WHEN COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' AND cheque_due_date != '' AND SUBSTR(cheque_due_date, 1, 10) < ? THEN 1 ELSE 0 END), 0) AS overdue_count,
        COALESCE(SUM(CASE WHEN COALESCE(NULLIF(cheque_status, ''), 'pending') = 'pending' AND cheque_due_date != '' AND SUBSTR(cheque_due_date, 1, 10) < ? THEN amount ELSE 0 END), 0.0) AS overdue_amount,
        COALESCE(SUM(CASE WHEN cheque_status = 'cleared' THEN 1 ELSE 0 END), 0) AS cleared_count,
        COALESCE(SUM(CASE WHEN cheque_status = 'cleared' THEN amount ELSE 0 END), 0.0) AS cleared_amount,
        COALESCE(SUM(CASE WHEN cheque_status = 'bounced' THEN 1 ELSE 0 END), 0) AS bounced_count,
        COALESCE(SUM(CASE WHEN cheque_status = 'bounced' THEN amount ELSE 0 END), 0.0) AS bounced_amount
      FROM payment_transactions
      WHERE LOWER(payment_method) = 'cheque'
    ''', [todayStr, todayStr]);

    final r = rows.first;
    return {
      'totalCount': (r['total_count'] as num?)?.toInt() ?? 0,
      'pendingCount': (r['pending_count'] as num?)?.toInt() ?? 0,
      'pendingAmount': (r['pending_amount'] as num?)?.toDouble() ?? 0.0,
      'overdueCount': (r['overdue_count'] as num?)?.toInt() ?? 0,
      'overdueAmount': (r['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      'clearedCount': (r['cleared_count'] as num?)?.toInt() ?? 0,
      'clearedAmount': (r['cleared_amount'] as num?)?.toDouble() ?? 0.0,
      'bouncedCount': (r['bounced_count'] as num?)?.toInt() ?? 0,
      'bouncedAmount': (r['bounced_amount'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<void> updateChequeStatus({
    required int transactionId,
    required String newStatus,
    String? clearedDate,
    String? note,
  }) async {
    final normalized = newStatus.trim().toLowerCase();
    const allowed = {'pending', 'cleared', 'bounced', 'cancelled'};
    if (!allowed.contains(normalized)) {
      throw ArgumentError('Unsupported cheque status: $newStatus');
    }

    final existing = await db.query(
      'payment_transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw Exception('Cheque transaction #$transactionId not found');
    }

    final nowIso = clearedDate ?? DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'cheque_status': normalized,
      'cheque_cleared_at': normalized == 'cleared' ? nowIso : '',
    };
    if (note != null && note.trim().isNotEmpty) {
      updates['note'] = note.trim();
    }

    await db.update(
      'payment_transactions',
      updates,
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    await recordActivity(
      action: 'updated',
      entityType: 'cheque',
      entityId: transactionId,
      oldValues: {'cheque_status': existing.first['cheque_status']},
      newValues: {'cheque_status': normalized, 'cleared_at': updates['cheque_cleared_at']},
    );
  }

  // ==================== STEP 6.4: COMMISSION AGENTS ====================

  Future<List<CommissionAgent>> getCommissionAgents({bool activeOnly = false}) async {
    final rows = await db.query(
      'commission_agents',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((e) => CommissionAgent.fromMap(e)).toList();
  }

  Future<int> addCommissionAgent(CommissionAgent agent) async {
    final id = await db.insert('commission_agents', agent.toMap());
    await recordActivity(
      action: 'created',
      entityType: 'commission_agent',
      entityId: id,
      newValues: {
        'name': agent.name,
        'commission_percent': agent.commissionPercent,
      },
    );
    return id;
  }

  Future<int> updateCommissionAgent(CommissionAgent agent) async {
    if (agent.id == null) return 0;
    return await db.update(
      'commission_agents',
      agent.toMap(),
      where: 'id = ?',
      whereArgs: [agent.id],
    );
  }

  Future<int> deleteCommissionAgent(int id) async {
    return await db.delete('commission_agents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCommissionReport({
    DateTime? startDate,
    DateTime? endDate,
    int? agentId,
  }) async {
    final joinCond = <String>["s.sale_status = 'final'"];
    final args = <dynamic>[];

    if (startDate != null) {
      joinCond.add('s.created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      joinCond.add('s.created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    String where = '';
    if (agentId != null) {
      where = 'WHERE ca.id = ?';
      args.add(agentId);
    }

    final rows = await db.rawQuery('''
      SELECT
        ca.id AS agent_id,
        ca.name AS agent_name,
        ca.phone AS phone,
        ca.commission_percent AS commission_percent,
        ca.is_active AS is_active,
        COUNT(s.id) AS sale_count,
        COALESCE(SUM(s.total_amount), 0.0) AS total_sales,
        COALESCE(SUM(s.commission_amount), 0.0) AS total_commission
      FROM commission_agents ca
      LEFT JOIN sales s
        ON s.commission_agent_id = ca.id AND ${joinCond.join(' AND ')}
      $where
      GROUP BY ca.id, ca.name, ca.phone, ca.commission_percent, ca.is_active
      ORDER BY total_commission DESC, ca.name COLLATE NOCASE ASC
    ''', args);

    return rows
        .map((r) => {
              'agentId': (r['agent_id'] as num?)?.toInt() ?? 0,
              'agentName': r['agent_name'] as String? ?? '',
              'phone': r['phone'] as String? ?? '',
              'commissionPercent':
                  (r['commission_percent'] as num?)?.toDouble() ?? 0.0,
              'isActive': (r['is_active'] as num?)?.toInt() == 1,
              'saleCount': (r['sale_count'] as num?)?.toInt() ?? 0,
              'totalSales': (r['total_sales'] as num?)?.toDouble() ?? 0.0,
              'totalCommission':
                  (r['total_commission'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
  }

  Future<List<Sale>> getSalesByCommissionAgent(
    int agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final where = <String>["sale_status = 'final'", 'commission_agent_id = ?'];
    final args = <dynamic>[agentId];
    if (startDate != null) {
      where.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }
    final rows = await db.query(
      'sales',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
    );
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  // ==================== STEP 6.5: DISCOUNT SCHEDULES ====================

  Future<List<DiscountRule>> getDiscountRules({bool activeOnly = false}) async {
    final rows = await db.query(
      'discounts',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'priority DESC, id DESC',
    );
    return rows.map((e) => DiscountRule.fromMap(e)).toList();
  }

  Future<int> addDiscountRule(DiscountRule rule) async {
    final id = await db.insert('discounts', rule.toMap());
    await recordActivity(
      action: 'created',
      entityType: 'discount_rule',
      entityId: id,
      newValues: {
        'name': rule.name,
        'rule_type': rule.ruleType,
        'discount_amount': rule.discountAmount,
      },
    );
    return id;
  }

  Future<int> updateDiscountRule(DiscountRule rule) async {
    if (rule.id == null) return 0;
    return await db.update(
      'discounts',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> deleteDiscountRule(int id) async {
    return await db.delete('discounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<DiscountEvaluationResult> evaluateCartDiscounts(
    List<CartItem> items, {
    DateTime? now,
  }) async {
    if (items.isEmpty) return const DiscountEvaluationResult();
    final activeRules = await getDiscountRules(activeOnly: true);
    return DiscountRule.evaluateCart(
      rules: activeRules,
      items: items,
      now: now,
    );
  }
}

