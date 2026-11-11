import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_settings.dart';
import 'core_providers.dart';

/// Reactive [BusinessSettings] state loaded from [SettingsRepository].
class SettingsNotifier extends AsyncNotifier<BusinessSettings> {
  @override
  Future<BusinessSettings> build() async {
    return ref.watch(settingsRepositoryProvider).getBusinessSettings();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(settingsRepositoryProvider).getBusinessSettings(),
    );
  }

  void setSettings(BusinessSettings settings) {
    state = AsyncValue.data(settings);
  }

  Future<void> updateSettings(BusinessSettings settings) async {
    await ref.read(settingsRepositoryProvider).updateBusinessSettings(settings);
    state = AsyncValue.data(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, BusinessSettings>(
  SettingsNotifier.new,
);

