import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'core_providers.dart';

/// Filter parameters for querying the unified Activity Log / Audit Trail.
class ActivityLogFilter {
  final String? entityType;
  final String? action;
  final String? search;
  final int limit;

  const ActivityLogFilter({
    this.entityType,
    this.action,
    this.search,
    this.limit = 200,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityLogFilter &&
          entityType == other.entityType &&
          action == other.action &&
          search == other.search &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(entityType, action, search, limit);
}

final taxRatesProvider = FutureProvider.autoDispose<List<TaxRate>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getTaxRates();
});

final taxGroupsProvider =
    FutureProvider.autoDispose<List<TaxGroup>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getTaxGroups();
});

final customerGroupsProvider =
    FutureProvider.autoDispose<List<CustomerGroup>>((ref) async {
  return ref.watch(contactsRepositoryProvider).getCustomerGroups();
});

final rolesProvider = FutureProvider.autoDispose<List<AppRole>>((ref) async {
  return ref.watch(authRepositoryProvider).getRoles();
});

final activityLogsProvider = FutureProvider.autoDispose
    .family<List<ActivityLogEntry>, ActivityLogFilter>((ref, filter) async {
  return ref.watch(authRepositoryProvider).getActivityLogs(
        limit: filter.limit,
        entityType: filter.entityType,
        action: filter.action,
        search: filter.search,
      );
});
