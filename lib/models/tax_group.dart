import 'dart:convert';
import '../services/app_logger.dart';
import 'tax_rate.dart';

/// Compound / Group Tax definition combining multiple [TaxRate] components.
class TaxGroup {
  final int? id;
  final String name;
  final List<int> subTaxIds;
  final bool isCompound;
  final double effectiveRate;
  final bool isActive;
  final String? createdAt;

  const TaxGroup({
    this.id,
    required this.name,
    required this.subTaxIds,
    this.isCompound = false,
    this.effectiveRate = 0.0,
    this.isActive = true,
    this.createdAt,
  });

  /// Computes total tax rate (%) across [subTaxIds] in [availableRates].
  /// Additive: r1 + r2. Compound: ((1 + r1/100) * (1 + r2/100) - 1) * 100.
  double computeEffectiveRate(List<TaxRate> availableRates) {
    final byId = {
      for (final r in availableRates)
        if (r.id != null) r.id!: r
    };
    if (!isCompound) {
      double sum = 0.0;
      for (final tid in subTaxIds) {
        sum += byId[tid]?.amount ?? 0.0;
      }
      return sum;
    }
    double factor = 1.0;
    for (final tid in subTaxIds) {
      final rate = byId[tid]?.amount ?? 0.0;
      factor *= (1.0 + rate / 100.0);
    }
    return (factor - 1.0) * 100.0;
  }

  /// Calculates individual sub-tax monetary amounts on [taxableAmount].
  Map<String, double> calculateBreakdown(
    double taxableAmount,
    List<TaxRate> availableRates,
  ) {
    if (taxableAmount <= 0 || subTaxIds.isEmpty) return {};
    final byId = {
      for (final r in availableRates)
        if (r.id != null) r.id!: r
    };
    final result = <String, double>{};
    double runningBase = taxableAmount;

    for (final tid in subTaxIds) {
      final rate = byId[tid];
      if (rate == null) continue;
      final amt = double.parse(
          (runningBase * (rate.amount / 100.0)).toStringAsFixed(2));
      result[rate.name] = (result[rate.name] ?? 0.0) + amt;
      if (isCompound) {
        runningBase += amt;
      }
    }
    return result;
  }

  double calculateTotalTax(
    double taxableAmount,
    List<TaxRate> availableRates,
  ) {
    if (taxableAmount <= 0) return 0.0;
    if (subTaxIds.isEmpty) {
      return double.parse(
          (taxableAmount * (effectiveRate / 100.0)).toStringAsFixed(2));
    }
    final breakdown = calculateBreakdown(taxableAmount, availableRates);
    return breakdown.values.fold(0.0, (sum, v) => sum + v);
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sub_tax_ids': jsonEncode(subTaxIds),
        'is_compound': isCompound ? 1 : 0,
        'effective_rate': effectiveRate,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory TaxGroup.fromMap(Map<String, dynamic> map) {
    List<int> parsedIds = [];
    final raw = map['sub_tax_ids'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        parsedIds = decoded.map((e) => (e as num).toInt()).toList();
      } catch (e, st) {
        AppLogger.warning(
            'TaxGroup', 'Falling back to CSV parse for sub_tax_ids', e, st);
        parsedIds = raw
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();
      }
    }
    return TaxGroup(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      subTaxIds: parsedIds,
      isCompound: (map['is_compound'] as int? ?? 0) == 1,
      effectiveRate: (map['effective_rate'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }
}
