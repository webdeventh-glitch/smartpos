import 'cart_item.dart';
import 'product.dart';

/// Evaluated promotional discount summary for the current POS cart.
class DiscountEvaluationResult {
  final double discountAmount;
  final List<String> appliedRuleNames;

  const DiscountEvaluationResult({
    this.discountAmount = 0.0,
    this.appliedRuleNames = const [],
  });

  bool get hasDiscount => discountAmount > 0 && appliedRuleNames.isNotEmpty;
}

/// Scheduled & conditional POS discount rule backed by SQLite `discounts` table.
class DiscountRule {
  final int? id;
  final String name;
  final String
      ruleType; // 'standard', 'buy_x_get_y', 'quantity_break', 'time_based'
  final String discountType; // 'percentage', 'fixed'
  final double discountAmount;
  final String? startsAt;
  final String? endsAt;
  final int? productId;
  final int? brandId;
  final int? categoryId;
  final int? locationId;
  final String
      daysOfWeek; // e.g. '1,2,3,4,5' (ISO weekday 1=Mon..7=Sun); empty = all days
  final String startTime; // 'HH:mm'
  final String endTime; // 'HH:mm'
  final double minQuantity;
  final double buyQuantity;
  final double freeQuantity;
  final double minOrderAmount;
  final int priority;
  final bool applicableInPos;
  final bool isActive;
  final String createdAt;

  const DiscountRule({
    this.id,
    required this.name,
    this.ruleType = 'standard',
    this.discountType = 'percentage',
    this.discountAmount = 0.0,
    this.startsAt,
    this.endsAt,
    this.productId,
    this.brandId,
    this.categoryId,
    this.locationId,
    this.daysOfWeek = '',
    this.startTime = '',
    this.endTime = '',
    this.minQuantity = 0.0,
    this.buyQuantity = 0.0,
    this.freeQuantity = 0.0,
    this.minOrderAmount = 0.0,
    this.priority = 1,
    this.applicableInPos = true,
    this.isActive = true,
    required this.createdAt,
  });

  /// Checks whether the rule is active at [now] considering date range, weekday, and time window.
  bool isScheduleMatch(DateTime now) {
    if (!isActive || !applicableInPos) return false;

    if (startsAt != null && startsAt!.trim().isNotEmpty) {
      final s = DateTime.tryParse(startsAt!.trim());
      if (s != null) {
        final startDay = DateTime(s.year, s.month, s.day);
        if (now.isBefore(startDay)) return false;
      }
    }
    if (endsAt != null && endsAt!.trim().isNotEmpty) {
      final e = DateTime.tryParse(endsAt!.trim());
      if (e != null) {
        final endDay = DateTime(e.year, e.month, e.day, 23, 59, 59);
        if (now.isAfter(endDay)) return false;
      }
    }

    if (daysOfWeek.trim().isNotEmpty) {
      final allowed = daysOfWeek
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();
      if (allowed.isNotEmpty && !allowed.contains(now.weekday)) {
        return false;
      }
    }

    if (startTime.trim().isNotEmpty && endTime.trim().isNotEmpty) {
      final startMins = _parseHhMm(startTime.trim());
      final endMins = _parseHhMm(endTime.trim());
      if (startMins != null && endMins != null) {
        final nowMins = now.hour * 60 + now.minute;
        if (endMins >= startMins) {
          if (nowMins < startMins || nowMins > endMins) return false;
        } else {
          // Overnight window (e.g., 22:00 to 02:00)
          if (nowMins < startMins && nowMins > endMins) return false;
        }
      }
    }
    return true;
  }

  static int? _parseHhMm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  bool matchesProduct(Product p) {
    if (productId != null && p.id != productId) return false;
    if (brandId != null && p.brandId != brandId) return false;
    if (categoryId != null && p.categoryId != categoryId) return false;
    return true;
  }

  /// Calculates discount granted by this rule on [items] at [now].
  double computeDiscount(List<CartItem> items, DateTime now) {
    if (items.isEmpty || !isScheduleMatch(now)) return 0.0;

    final matchingItems =
        items.where((item) => matchesProduct(item.product)).toList();
    if (matchingItems.isEmpty) return 0.0;

    final matchingSubtotal =
        matchingItems.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final totalCartSubtotal =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);

    if (matchingSubtotal <= 0 || totalCartSubtotal < minOrderAmount) {
      return 0.0;
    }

    final matchingQty =
        matchingItems.fold<double>(0.0, (sum, item) => sum + item.quantity);

    switch (ruleType) {
      case 'buy_x_get_y':
        if (buyQuantity <= 0 || freeQuantity <= 0) return 0.0;
        final bundleSize = buyQuantity + freeQuantity;
        final sets = (matchingQty / bundleSize).floor();
        if (sets <= 0) return 0.0;
        final avgPrice =
            matchingQty > 0 ? (matchingSubtotal / matchingQty) : 0.0;
        final disc = sets * freeQuantity * avgPrice;
        return disc.clamp(0.0, matchingSubtotal);

      case 'quantity_break':
        if (minQuantity > 0 && matchingQty < minQuantity) return 0.0;
        return _computeStandardValue(matchingSubtotal);

      case 'time_based':
      case 'standard':
      default:
        return _computeStandardValue(matchingSubtotal);
    }
  }

  double _computeStandardValue(double targetSubtotal) {
    if (discountAmount <= 0 || targetSubtotal <= 0) return 0.0;
    if (discountType == 'percentage') {
      return (targetSubtotal * (discountAmount / 100.0))
          .clamp(0.0, targetSubtotal);
    }
    return discountAmount.clamp(0.0, targetSubtotal);
  }

  /// Evaluates sorted rules against the cart and returns the best non-overlapping total discount.
  static DiscountEvaluationResult evaluateCart({
    required List<DiscountRule> rules,
    required List<CartItem> items,
    DateTime? now,
  }) {
    if (items.isEmpty || rules.isEmpty) return const DiscountEvaluationResult();
    final checkNow = now ?? DateTime.now();
    final sorted = [...rules]..sort((a, b) => b.priority.compareTo(a.priority));

    final totalSubtotal =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    if (totalSubtotal <= 0) return const DiscountEvaluationResult();

    // Pick highest-priority / highest-saving applicable rule cleanly so promos don't stack unintentionally above 100%.
    double bestDiscount = 0.0;
    DiscountRule? bestRule;
    for (final rule in sorted) {
      final d = rule.computeDiscount(items, checkNow);
      if (d > bestDiscount) {
        bestDiscount = d;
        bestRule = rule;
      }
    }

    if (bestRule == null || bestDiscount <= 0) {
      return const DiscountEvaluationResult();
    }
    return DiscountEvaluationResult(
      discountAmount: double.parse(bestDiscount.toStringAsFixed(2)),
      appliedRuleNames: [bestRule.name],
    );
  }

  DiscountRule copyWith({
    int? id,
    String? name,
    String? ruleType,
    String? discountType,
    double? discountAmount,
    String? startsAt,
    String? endsAt,
    int? productId,
    int? brandId,
    int? categoryId,
    int? locationId,
    String? daysOfWeek,
    String? startTime,
    String? endTime,
    double? minQuantity,
    double? buyQuantity,
    double? freeQuantity,
    double? minOrderAmount,
    int? priority,
    bool? applicableInPos,
    bool? isActive,
    String? createdAt,
  }) =>
      DiscountRule(
        id: id ?? this.id,
        name: name ?? this.name,
        ruleType: ruleType ?? this.ruleType,
        discountType: discountType ?? this.discountType,
        discountAmount: discountAmount ?? this.discountAmount,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        productId: productId ?? this.productId,
        brandId: brandId ?? this.brandId,
        categoryId: categoryId ?? this.categoryId,
        locationId: locationId ?? this.locationId,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        minQuantity: minQuantity ?? this.minQuantity,
        buyQuantity: buyQuantity ?? this.buyQuantity,
        freeQuantity: freeQuantity ?? this.freeQuantity,
        minOrderAmount: minOrderAmount ?? this.minOrderAmount,
        priority: priority ?? this.priority,
        applicableInPos: applicableInPos ?? this.applicableInPos,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'rule_type': ruleType,
        'discount_type': discountType,
        'discount_amount': discountAmount,
        'starts_at': startsAt ?? '',
        'ends_at': endsAt ?? '',
        'product_id': productId,
        'brand_id': brandId,
        'category_id': categoryId,
        'location_id': locationId,
        'days_of_week': daysOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'min_quantity': minQuantity,
        'buy_quantity': buyQuantity,
        'free_quantity': freeQuantity,
        'min_order_amount': minOrderAmount,
        'priority': priority,
        'applicable_in_pos': applicableInPos ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory DiscountRule.fromMap(Map<String, dynamic> map) => DiscountRule(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        ruleType: map['rule_type'] as String? ?? 'standard',
        discountType: map['discount_type'] as String? ?? 'percentage',
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
        startsAt: map['starts_at'] as String?,
        endsAt: map['ends_at'] as String?,
        productId: map['product_id'] as int?,
        brandId: map['brand_id'] as int?,
        categoryId: map['category_id'] as int?,
        locationId: map['location_id'] as int?,
        daysOfWeek: map['days_of_week'] as String? ?? '',
        startTime: map['start_time'] as String? ?? '',
        endTime: map['end_time'] as String? ?? '',
        minQuantity: (map['min_quantity'] as num?)?.toDouble() ?? 0.0,
        buyQuantity: (map['buy_quantity'] as num?)?.toDouble() ?? 0.0,
        freeQuantity: (map['free_quantity'] as num?)?.toDouble() ?? 0.0,
        minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0.0,
        priority: map['priority'] as int? ?? 1,
        applicableInPos: (map['applicable_in_pos'] as int? ?? 1) == 1,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: map['created_at'] as String? ?? '',
      );
}
