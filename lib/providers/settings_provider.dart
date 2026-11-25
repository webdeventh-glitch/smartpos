import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_settings.dart';
import '../services/localization_service.dart';
import 'core_providers.dart';

/// Reactive [BusinessSettings] state loaded from [SettingsRepository].
class SettingsNotifier extends AsyncNotifier<BusinessSettings> {
  @override
  Future<BusinessSettings> build() async {
    final settings =
        await ref.watch(settingsRepositoryProvider).getBusinessSettings();
    PosLocalization.setActiveSettings(settings);
    return settings;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        final s =
            await ref.read(settingsRepositoryProvider).getBusinessSettings();
        PosLocalization.setActiveSettings(s);
        return s;
      },
    );
  }

  void setSettings(BusinessSettings settings) {
    PosLocalization.setActiveSettings(settings);
    state = AsyncValue.data(settings);
  }

  Future<void> updateSettings(BusinessSettings settings) async {
    await ref.read(settingsRepositoryProvider).updateBusinessSettings(settings);
    PosLocalization.setActiveSettings(settings);
    state = AsyncValue.data(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, BusinessSettings>(
  SettingsNotifier.new,
);
