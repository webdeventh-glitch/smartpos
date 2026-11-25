import 'i18n_ur.dart';
import 'i18n_ar.dart';
import 'i18n_fa.dart';
import 'i18n_ps.dart';
import 'i18n_es.dart';
import 'i18n_nl.dart';

/// Modular extended translation dictionaries across all supported languages.
/// Loaded and merged by [PosLocalization].
class I18nExtra {
  I18nExtra._();

  static final Map<String, Map<String, String>> dictionaries = {
    'ur': i18nExtraUr,
    'ar': i18nExtraAr,
    'fa': i18nExtraFa,
    'ps': i18nExtraPs,
    'es': i18nExtraEs,
    'nl': i18nExtraNl,
  };

  static final Map<String, Map<String, String>> _lowerCache = {};

  static Map<String, String> _lowerMapFor(String lang) {
    return _lowerCache.putIfAbsent(lang, () {
      final dict = dictionaries[lang];
      if (dict == null) return const {};
      return {for (final e in dict.entries) e.key.toLowerCase(): e.value};
    });
  }

  static String? lookup(String lang, String key) {
    final dict = dictionaries[lang];
    if (dict == null) return null;
    if (dict.containsKey(key)) return dict[key];

    final cleanStar = key.replaceAll('*', '').trim();
    if (dict.containsKey(cleanStar)) {
      final res = dict[cleanStar]!;
      return key.contains('*') ? '$res *' : res;
    }

    final cleanColon = cleanStar.endsWith(':')
        ? cleanStar.substring(0, cleanStar.length - 1).trim()
        : cleanStar;
    if (dict.containsKey(cleanColon)) {
      var res = dict[cleanColon]!;
      if (cleanStar.endsWith(':')) res = '$res:';
      if (key.contains('*')) res = '$res *';
      return res;
    }

    final lower = _lowerMapFor(lang);
    final lk = cleanColon.toLowerCase();
    if (lower.containsKey(lk)) {
      var res = lower[lk]!;
      if (cleanStar.endsWith(':')) res = '$res:';
      if (key.contains('*')) res = '$res *';
      return res;
    }
    return null;
  }
}
