/// Information model for a supported language in Number to Words conversion
class NumberLanguageOption {
  final String code; // e.g. 'ur', 'en', 'ps', 'fa', 'es', 'nl'
  final String name; // e.g. 'Urdu'
  final String nativeName; // e.g. 'اردو'
  final bool isRtl;

  const NumberLanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isRtl = false,
  });
}

/// Abstract base interface for language-specific converters (Strategy Pattern)
abstract class NumberToWordsConverter {
  /// Converts a numeric amount to written words in this language
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  });
}

/// Urdu (اردو) Number to Words Converter
class UrduNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _urduNumbers = [
    'صفر', 'ایک', 'دو', 'تین', 'چار', 'پانچ', 'چھ', 'سات', 'آٹھ', 'نو',
    'دس', 'گیارہ', 'بارہ', 'تیرہ', 'چودہ', 'پندرہ', 'سولہ', 'سترہ', 'اٹھارہ', 'انیس',
    'بیس', 'اکیس', 'بائیس', 'تئیس', 'چوبیس', 'پچیس', 'چھبیس', 'ستائیس', 'اٹھائیس', 'انتیس',
    'تیس', 'اکتیس', 'بتیس', 'تینتیس', 'چونتیس', 'پینتیس', 'چھتیس', 'سینتیس', 'اڑتیس', 'انتالیس',
    'چالیس', 'اکتالیس', 'بیالیس', 'تینتالیس', 'چوالیس', 'پینتالیس', 'چھیالیس', 'سینتالیس', 'اڑتالیس', 'انچاس',
    'پچاس', 'اکیاون', 'باون', 'ترپن', 'چون', 'پچپن', 'چھپن', 'ستاون', 'اٹھاون', 'انسٹھ',
    'ساٹھ', 'اکسٹھ', 'باسٹھ', 'تریسٹھ', 'چوسٹھ', 'پینسٹھ', 'چھیاسٹھ', 'سڑسٹھ', 'اڑسٹھ', 'انہتر',
    'ستر', 'اکہتر', 'بہتر', 'تہتر', 'چوہتر', 'پچہتر', 'چھہتر', 'ستتر', 'اٹھتر', 'اناسی',
    'اسی', 'اکیاسی', 'بیاسی', 'تراسی', 'چوراسی', 'پچاسی', 'چھیاسی', 'ستاسی', 'اٹھاسی', 'نواسی',
    'نوے', 'اکیانوے', 'بانوے', 'ترانوے', 'چورانوے', 'پچانوے', 'چھیانوے', 'ستانوے', 'اٹھانوے', 'ننانوے'
  ];

  String _convertBelowThousand(int n) {
    if (n <= 0) return '';
    if (n < 100) return _urduNumbers[n];
    final hundreds = n ~/ 100;
    final rem = n % 100;
    final hundredText = '${_urduNumbers[hundreds]} سو';
    if (rem == 0) return hundredText;
    return '$hundredText ${_urduNumbers[rem]}';
  }

  String _convertInteger(int n) {
    if (n <= 0) return 'صفر';
    final parts = <String>[];

    // Arab (1,000,000,000)
    if (n >= 1000000000) {
      final arab = n ~/ 1000000000;
      parts.add('${_convertInteger(arab)} ارب');
      n %= 1000000000;
    }

    // Crore (10,000,000)
    if (n >= 10000000) {
      final crore = n ~/ 10000000;
      parts.add('${_convertInteger(crore)} کروڑ');
      n %= 10000000;
    }

    // Lakh (100,000)
    if (n >= 100000) {
      final lakh = n ~/ 100000;
      parts.add('${_convertInteger(lakh)} لاکھ');
      n %= 100000;
    }

    // Thousand (1,000)
    if (n >= 1000) {
      final thousand = n ~/ 1000;
      parts.add('${_convertInteger(thousand)} ہزار');
      n %= 1000;
    }

    // Below thousand (1 - 999)
    if (n > 0) {
      parts.add(_convertBelowThousand(n));
    }

    return parts.join(' ');
  }

  String _getCurrencyWord(String? symbol, String? code) {
    final s = (symbol ?? '').trim().toUpperCase();
    final c = (code ?? '').trim().toUpperCase();
    if (s.contains('\$') || c == 'USD') return 'ڈالر';
    if (s.contains('€') || c == 'EUR') return 'یورو';
    if (s.contains('£') || c == 'GBP') return 'پاؤنڈ';
    if (s.contains('﷼') || c == 'SAR') return 'ریال';
    if (c == 'AED') return 'درہم';
    if (c == 'AFN') return 'افغانی';
    return 'روپے';
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) return 'صفر';
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final intPart = absAmount.floor();
    final decimalPart = ((absAmount - intPart) * 100).round();

    final currency = _getCurrencyWord(currencySymbol, currencyCode);
    final words = _convertInteger(intPart);

    final buffer = StringBuffer();
    if (isNegative) buffer.write('منفی ');
    buffer.write(words);
    buffer.write(' $currency');

    if (includeDecimals && decimalPart > 0 && decimalPart < 100) {
      buffer.write(' اور ${_urduNumbers[decimalPart]} پیسے');
    }

    return '${buffer.toString().trim()}۔';
  }
}

/// Pashto (پښتو) Number to Words Converter
class PashtoNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _units = [
    'صفر', 'یو', 'دوه', 'درې', 'څلور', 'پنځه', 'شپږ', 'اووه', 'اته', 'نهه',
    'لس', 'یوولس', 'دوولس', 'دیارلس', 'څوارلس', 'پنځلس', 'شپاړس', 'اوولس', 'اتلس', 'نولس'
  ];

  static const List<String> _tens = [
    '', '', 'شل', 'دېرش', 'څلوېښت', 'پنځوس', 'شپېته', 'اویا', 'اتیا', 'نوي'
  ];

  String _underHundred(int n) {
    if (n < 20) return _units[n];
    final t = n ~/ 10;
    final u = n % 10;
    if (u == 0) return _tens[t];
    // Special Pashto 20s
    if (t == 2) {
      const twenties = ['', 'یوویشت', 'دوه ویشت', 'درویشت', 'څلیرویشت', 'پنځه ویشت', 'شپږویشت', 'اووه ویشت', 'اتویشت', 'نهه ویشت'];
      return twenties[u];
    }
    return '${_units[u]} ${_tens[t]}';
  }

  String _convertBelowThousand(int n) {
    if (n <= 0) return '';
    if (n < 100) return _underHundred(n);
    final hundreds = n ~/ 100;
    final rem = n % 100;
    final hText = hundreds == 1 ? 'سل' : '${_units[hundreds]} سوه';
    if (rem == 0) return hText;
    return '$hText ${_underHundred(rem)}';
  }

  String _convertInteger(int n) {
    if (n <= 0) return 'صفر';
    final parts = <String>[];

    if (n >= 10000000) {
      final crore = n ~/ 10000000;
      parts.add('${_convertInteger(crore)} کروړ');
      n %= 10000000;
    }
    if (n >= 100000) {
      final lakh = n ~/ 100000;
      parts.add('${_convertInteger(lakh)} لک');
      n %= 100000;
    }
    if (n >= 1000) {
      final thousand = n ~/ 1000;
      final tText = thousand == 1 ? 'زر' : '${_convertInteger(thousand)} زره';
      parts.add(tText);
      n %= 1000;
    }
    if (n > 0) {
      parts.add(_convertBelowThousand(n));
    }
    return parts.join(' ');
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) return 'صفر';
    final absAmount = amount.abs();
    final intPart = absAmount.floor();
    final words = _convertInteger(intPart);

    final c = (currencyCode ?? '').toUpperCase();
    final currency = c == 'AFN' ? 'افغانۍ' : 'روپۍ';

    return '$words $currency'.trim();
  }
}

/// Farsi / Persian (فارسی) Number to Words Converter
class FarsiNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _units = [
    'صفر', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه',
    'ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'
  ];

  static const List<String> _tens = [
    '', '', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'
  ];

  static const List<String> _hundreds = [
    '', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'
  ];

  String _convertBelowThousand(int n) {
    if (n <= 0) return '';
    final parts = <String>[];
    if (n >= 100) {
      parts.add(_hundreds[n ~/ 100]);
      n %= 100;
    }
    if (n >= 20) {
      parts.add(_tens[n ~/ 10]);
      n %= 10;
    }
    if (n > 0 && n < 20) {
      parts.add(_units[n]);
    }
    return parts.join(' و ');
  }

  String _convertInteger(int n) {
    if (n <= 0) return 'صفر';
    final parts = <String>[];

    if (n >= 1000000000) {
      final b = n ~/ 1000000000;
      parts.add('${_convertInteger(b)} میلیارد');
      n %= 1000000000;
    }
    if (n >= 1000000) {
      final m = n ~/ 1000000;
      parts.add('${_convertInteger(m)} میلیون');
      n %= 1000000;
    }
    if (n >= 1000) {
      final t = n ~/ 1000;
      parts.add('${_convertInteger(t)} هزار');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(_convertBelowThousand(n));
    }
    return parts.join(' و ');
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) return 'صفر';
    final absAmount = amount.abs();
    final intPart = absAmount.floor();
    final words = _convertInteger(intPart);

    final c = (currencyCode ?? '').toUpperCase();
    final currency = c == 'IRR' ? 'ریال' : (c == 'AFN' ? 'افغانی' : 'تومان');
    return '$words $currency'.trim();
  }
}

/// Spanish (Español) Number to Words Converter
class SpanishNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _units = [
    'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve',
    'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
    'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve'
  ];

  static const List<String> _tens = [
    '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'
  ];

  static const List<String> _hundreds = [
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'
  ];

  String _convertBelowThousand(int n) {
    if (n <= 0) return '';
    if (n == 100) return 'cien';
    final parts = <String>[];
    if (n >= 100) {
      parts.add(_hundreds[n ~/ 100]);
      n %= 100;
    }
    if (n < 30 && n > 0) {
      parts.add(_units[n]);
    } else if (n >= 30) {
      final t = n ~/ 10;
      final u = n % 10;
      parts.add(u == 0 ? _tens[t] : '${_tens[t]} y ${_units[u]}');
    }
    return parts.join(' ');
  }

  String _convertInteger(int n) {
    if (n <= 0) return 'cero';
    final parts = <String>[];

    if (n >= 1000000) {
      final m = n ~/ 1000000;
      parts.add(m == 1 ? 'un millón' : '${_convertInteger(m)} millones');
      n %= 1000000;
    }
    if (n >= 1000) {
      final t = n ~/ 1000;
      parts.add(t == 1 ? 'mil' : '${_convertInteger(t)} mil');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(_convertBelowThousand(n));
    }
    return parts.join(' ');
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) return 'cero';
    final absAmount = amount.abs();
    final intPart = absAmount.floor();
    final words = _convertInteger(intPart);
    final c = (currencyCode ?? '').toUpperCase();
    final currency = c == 'EUR' ? 'euros' : (c == 'USD' ? 'dólares' : 'pesos');
    return '$words $currency'.trim();
  }
}

/// Dutch (Nederlands) Number to Words Converter
class DutchNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _units = [
    'nul', 'één', 'twee', 'drie', 'vier', 'vijf', 'zes', 'zeven', 'acht', 'negen',
    'tien', 'elf', 'twaalf', 'dertien', 'veertien', 'vijftien', 'zestien', 'zeventien', 'achttien', 'negentien'
  ];

  static const List<String> _tens = [
    '', '', 'twintig', 'dertig', 'veertig', 'vijftig', 'zestig', 'zeventig', 'tachtig', 'negentig'
  ];

  String _convertBelowHundred(int n) {
    if (n < 20) return _units[n];
    final t = n ~/ 10;
    final u = n % 10;
    if (u == 0) return _tens[t];
    return '${_units[u]}en${_tens[t]}';
  }

  String _convertBelowThousand(int n) {
    if (n <= 0) return '';
    final h = n ~/ 100;
    final rem = n % 100;
    var hText = '';
    if (h == 1) {
      hText = 'honderd';
    } else if (h > 1) {
      hText = '${_units[h]}honderd';
    }
    if (rem == 0) return hText;
    return '$hText${_convertBelowHundred(rem)}';
  }

  String _convertInteger(int n) {
    if (n <= 0) return 'nul';
    final parts = <String>[];

    if (n >= 1000000) {
      final m = n ~/ 1000000;
      parts.add(m == 1 ? 'één miljoen' : '${_convertInteger(m)} miljoen');
      n %= 1000000;
    }
    if (n >= 1000) {
      final t = n ~/ 1000;
      parts.add(t == 1 ? 'duizend' : '${_convertInteger(t)} duizend');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(_convertBelowThousand(n));
    }
    return parts.join(' ');
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite) return 'nul';
    final absAmount = amount.abs();
    final intPart = absAmount.floor();
    final words = _convertInteger(intPart);
    final c = (currencyCode ?? '').toUpperCase();
    final currency = c == 'EUR' ? 'euro' : (c == 'USD' ? 'dollar' : 'roepie');
    return '$words $currency'.trim();
  }
}

/// English Number to Words Converter (Pakistani & International scale)
class EnglishNumberToWordsConverter implements NumberToWordsConverter {
  static const List<String> _units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  String _convertBelowThousand(int n) {
    if (n == 0) return '';
    if (n < 20) return _units[n];
    if (n < 100) return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_units[n % 10]}' : ''}';
    return '${_units[n ~/ 100]} Hundred${n % 100 != 0 ? ' and ${_convertBelowThousand(n % 100)}' : ''}';
  }

  @override
  String convert(
    double amount, {
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) return 'Zero Rupees Only';
    int intPart = amount.floor();

    final parts = <String>[];
    if (intPart >= 10000000) {
      parts.add('${_convertBelowThousand(intPart ~/ 10000000)} Crore');
      intPart %= 10000000;
    }
    if (intPart >= 100000) {
      parts.add('${_convertBelowThousand(intPart ~/ 100000)} Lakh');
      intPart %= 100000;
    }
    if (intPart >= 1000) {
      parts.add('${_convertBelowThousand(intPart ~/ 1000)} Thousand');
      intPart %= 1000;
    }
    if (intPart > 0) {
      parts.add(_convertBelowThousand(intPart));
    }

    final currency = (currencySymbol ?? '').trim().isNotEmpty ? (currencySymbol == 'Rs' ? 'Rupees' : currencySymbol!) : 'Rupees';
    return '${parts.join(' ')} $currency Only'.trim();
  }
}

/// Central facade service for multi-language number to words conversion
class NumberToWordsService {
  /// Registered language converters
  static final Map<String, NumberToWordsConverter> _converters = {
    'ur': UrduNumberToWordsConverter(),
    'ps': PashtoNumberToWordsConverter(),
    'fa': FarsiNumberToWordsConverter(),
    'en': EnglishNumberToWordsConverter(),
    'es': SpanishNumberToWordsConverter(),
    'nl': DutchNumberToWordsConverter(),
  };

  /// Supported languages catalog for UI dropdowns
  static const List<NumberLanguageOption> supportedLanguages = [
    NumberLanguageOption(code: 'ur', name: 'Urdu', nativeName: 'اردو', isRtl: true),
    NumberLanguageOption(code: 'ps', name: 'Pashto', nativeName: 'پښتو', isRtl: true),
    NumberLanguageOption(code: 'fa', name: 'Farsi', nativeName: 'فارسی', isRtl: true),
    NumberLanguageOption(code: 'en', name: 'English', nativeName: 'English', isRtl: false),
    NumberLanguageOption(code: 'es', name: 'Spanish', nativeName: 'Español', isRtl: false),
    NumberLanguageOption(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', isRtl: false),
  ];

  /// Checks if a language is Right-to-Left (e.g. Urdu, Pashto, Farsi, Arabic)
  static bool isRtl(String? languageCode) {
    final code = (languageCode ?? 'ur').toLowerCase().trim();
    return code == 'ur' || code == 'ps' || code == 'fa' || code == 'ar';
  }

  /// Registers or overrides a converter for a language code (for future expansion)
  static void registerConverter(String languageCode, NumberToWordsConverter converter) {
    _converters[languageCode.toLowerCase().trim()] = converter;
  }

  /// Converts a numeric amount into words in the requested language
  static String convert(
    double amount, {
    String language = 'ur',
    String? currencySymbol,
    String? currencyCode,
    bool includeDecimals = true,
  }) {
    final code = language.toLowerCase().trim();
    final converter = _converters[code] ?? _converters['ur']!;
    return converter.convert(
      amount,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      includeDecimals: includeDecimals,
    );
  }
}

