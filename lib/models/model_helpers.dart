import '../services/app_logger.dart';

int modelAsInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed != null) return parsed.toInt();
  }
  return fallback;
}

double modelAsDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed != null) return parsed.toDouble();
  }
  return fallback;
}

bool modelAsBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return fallback;
}

String modelAsString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

/// Robust pharmaceutical & retail expiry date parser
/// Handles:
/// - MM-YYYY (e.g. "01-2028")
/// - YYYY-MM (e.g. "2028-01")
/// - MM/YYYY (e.g. "01/2028")
/// - MM-YY / MM/YY (e.g. "01-28")
/// - DD-MM-YYYY / YYYY-MM-DD
DateTime? parseExpiryDate(String? expiryDate) {
  if (expiryDate == null || expiryDate.trim().isEmpty) return null;
  try {
    final trimmed = expiryDate.trim();

    // Check for textual month formats like "15 Dec 2026" or "Dec 2026" or "15-Dec-2026"
    final monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12
    };

    final tokens = trimmed
        .replaceAll('-', ' ')
        .replaceAll('/', ' ')
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'));
    if (tokens.any((t) => monthMap.containsKey(t.toLowerCase()))) {
      int? day;
      int? month;
      int? year;
      for (final t in tokens) {
        final lower = t.toLowerCase();
        if (monthMap.containsKey(lower)) {
          month = monthMap[lower];
        } else {
          final num = int.tryParse(t);
          if (num != null) {
            if (num > 31) {
              year = num < 100 ? num + 2000 : num;
            } else if (day == null) {
              day ??= num;
            } else {
              year ??= num < 100 ? num + 2000 : num;
            }
          }
        }
      }
      if (year != null && month != null) {
        if (day != null) {
          return DateTime(year, month, day, 23, 59, 59);
        } else {
          return DateTime(year, month + 1, 0, 23, 59, 59);
        }
      }
    }

    final separator =
        trimmed.contains('-') ? '-' : (trimmed.contains('/') ? '/' : null);
    if (separator != null) {
      final rawParts =
          trimmed.split(separator).map((s) => int.tryParse(s.trim())).toList();
      if (rawParts.length == 2 && rawParts[0] != null && rawParts[1] != null) {
        int y = rawParts[0]!;
        int m = rawParts[1]!;
        if (y <= 12 && m > 12) {
          final temp = y;
          y = m;
          m = temp;
        }
        if (y < 100) y += 2000;
        if (m < 1) m = 1;
        if (m > 12) m = 12;
        return DateTime(y, m + 1, 0, 23, 59, 59);
      } else if (rawParts.length == 3 &&
          rawParts[0] != null &&
          rawParts[1] != null &&
          rawParts[2] != null) {
        int y = rawParts[0]!;
        int m = rawParts[1]!;
        int d = rawParts[2]!;
        if (d >= 1000 && y <= 31) {
          final temp = y;
          y = d;
          d = temp;
        }
        if (y < 100) y += 2000;
        if (m < 1) m = 1;
        if (m > 12) m = 12;
        if (d < 1) d = 1;
        if (d > 31) d = 31;
        return DateTime(y, m, d, 23, 59, 59);
      }
    }
    return DateTime.tryParse(trimmed);
  } catch (e, st) {
    AppLogger.warning(
        'Models', 'Failed parsing expiry date "$expiryDate"', e, st);
    return null;
  }
}

int? calculateDaysUntilExpiry(String? expiryDate) {
  final exp = parseExpiryDate(expiryDate);
  if (exp == null) return null;
  final now = DateTime.now();
  return exp.difference(DateTime(now.year, now.month, now.day)).inDays;
}
