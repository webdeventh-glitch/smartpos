import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cash_register.dart';
import 'core_providers.dart';

/// Tracks the currently open [CashRegister] till session and refreshes on open/close.
class ActiveRegisterNotifier extends AsyncNotifier<CashRegister?> {
  @override
  Future<CashRegister?> build() async {
    return ref.watch(registerRepositoryProvider).getActiveRegister();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(registerRepositoryProvider).getActiveRegister(),
    );
  }

  Future<void> openRegister(String cashierName, double openingAmount) async {
    final repo = ref.read(registerRepositoryProvider);
    await repo.openRegister(cashierName, openingAmount);
    state = AsyncValue.data(await repo.getActiveRegister());
  }

  Future<void> closeRegister(int id, double closingAmount, String note) async {
    final repo = ref.read(registerRepositoryProvider);
    await repo.closeRegister(id, closingAmount, note);
    state = AsyncValue.data(await repo.getActiveRegister());
  }
}

final activeRegisterProvider =
    AsyncNotifierProvider<ActiveRegisterNotifier, CashRegister?>(
  ActiveRegisterNotifier.new,
);
