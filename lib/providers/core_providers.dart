import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repositories.dart';
import '../services/database_service.dart';

/// Exposes the initialized local [DatabaseService] coordinator.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => ref.watch(databaseServiceProvider).settingsRepo,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(databaseServiceProvider).authRepo,
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ref.watch(databaseServiceProvider).productRepo,
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ref.watch(databaseServiceProvider).contactsRepo,
);

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => ref.watch(databaseServiceProvider).salesRepo,
);

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => ref.watch(databaseServiceProvider).purchaseRepo,
);

final accountingRepositoryProvider = Provider<AccountingRepository>(
  (ref) => ref.watch(databaseServiceProvider).accountingRepo,
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => ref.watch(databaseServiceProvider).inventoryRepo,
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ref.watch(databaseServiceProvider).expenseRepo,
);

final registerRepositoryProvider = Provider<RegisterRepository>(
  (ref) => ref.watch(databaseServiceProvider).registerRepo,
);

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ref.watch(databaseServiceProvider).reportRepo,
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => ref.watch(databaseServiceProvider).syncRepo,
);

final industryModulesRepositoryProvider = Provider<IndustryModulesRepository>(
  (ref) => ref.watch(databaseServiceProvider).industryModulesRepo,
);

final seederRepositoryProvider = Provider<SeederRepository>(
  (ref) => ref.watch(databaseServiceProvider).seederRepo,
);
