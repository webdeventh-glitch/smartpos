import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/business_settings.dart';
import 'package:desktop_starter/services/localization_service.dart';

void main() {
  tearDown(() => PosLocalization.setActiveSettings(null));

  test(
      'PosLocalization strictly follows selected primary and secondary language',
      () {
    final enOnly = BusinessSettings(
      primaryLanguage: 'en',
      enableSecondaryLanguage: false,
      secondaryLanguage: 'ur',
    );
    expect(
      PosLocalization.tr('Specialized Industry Modules', settings: enOnly),
      equals('Specialized Industry Modules'),
    );
    expect(
      PosLocalization.trSecondary('Specialized Industry Modules',
          settings: enOnly),
      isNull,
    );

    final enWithUr = BusinessSettings(
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );
    expect(
      PosLocalization.tr('Specialized Industry Modules', settings: enWithUr),
      contains('('),
    );
    expect(
      PosLocalization.trSecondary('Specialized Industry Modules',
          settings: enWithUr),
      isNotEmpty,
    );

    final urOnly = BusinessSettings(
      primaryLanguage: 'ur',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ar',
    );
    final urText =
        PosLocalization.tr('Specialized Industry Modules', settings: urOnly);
    expect(urText, isNot(contains('Specialized Industry Modules')));
    expect(
      PosLocalization.trSecondary('Specialized Industry Modules',
          settings: urOnly),
      isNull,
    );

    for (final lang in ['ar', 'fa', 'ps', 'es', 'nl']) {
      final s = BusinessSettings(primaryLanguage: lang);
      expect(
        PosLocalization.tr('Dashboard', settings: s),
        isNotEmpty,
      );
      expect(
        PosLocalization.tr('Default Product Barcode Type', settings: s),
        isNotEmpty,
      );
    }
  });

  test(
      'PosLocalization.setActiveSettings works without explicit settings parameter',
      () {
    final esSettings = BusinessSettings(primaryLanguage: 'es');
    PosLocalization.setActiveSettings(esSettings);
    expect(PosLocalization.tr('Dashboard'), isNot(equals('Dashboard')));
    expect(
      PosLocalization.trParams(
        'Reset to {business} Defaults',
        {'business': 'Pharmacy'},
      ),
      contains('Pharmacy'),
    );
  });
}
