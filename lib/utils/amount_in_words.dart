/// Converts numeric amounts into human-readable words in the active
/// (or secondary) application language.
class AmountInWords {
  AmountInWords._();

  static const List<String> _enUnits = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _enTens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static const List<String> _ur0To99 = [
    'صفر',
    'ایک',
    'دو',
    'تین',
    'چار',
    'پانچ',
    'چھ',
    'سات',
    'آٹھ',
    'نو',
    'دس',
    'گیارہ',
    'بارہ',
    'تیرہ',
    'چودہ',
    'پندرہ',
    'سولہ',
    'سترہ',
    'اٹھارہ',
    'انیس',
    'بیس',
    'اکیس',
    'بائیس',
    'تئیس',
    'چوبیس',
    'پچیس',
    'چھبیس',
    'ستائیس',
    'اٹھائیس',
    'انتیس',
    'تیس',
    'اکتیس',
    'بتیس',
    'تینتیس',
    'چونتیس',
    'پینتیس',
    'چھتیس',
    'سینتیس',
    'اڑتیس',
    'انتالیس',
    'چالیس',
    'اکتالیس',
    'بیالیس',
    'تینتالیس',
    'چوالیس',
    'پینتالیس',
    'چھیالیس',
    'سینتالیس',
    'اڑتالیس',
    'انچاس',
    'پچاس',
    'اکیاون',
    'باون',
    'ترپن',
    'چون',
    'پچپن',
    'چھپن',
    'ستاون',
    'اٹھاون',
    'انسٹھ',
    'ساٹھ',
    'اکسٹھ',
    'باسٹھ',
    'تریسٹھ',
    'چونسٹھ',
    'پینسٹھ',
    'چھیاسٹھ',
    'سڑسٹھ',
    'اڑسٹھ',
    'انہتر',
    'ستر',
    'اکہتر',
    'بہتر',
    'تہتر',
    'چوہتر',
    'پچتر',
    'چھہتر',
    'ستتر',
    'اٹھتر',
    'اناسی',
    'اسی',
    'اکیاسی',
    'بیاسی',
    'تراسی',
    'چوراسی',
    'پچاسی',
    'چھیاسی',
    'ستاسی',
    'اٹھاسی',
    'نواسی',
    'نوے',
    'اکیانوے',
    'بانوے',
    'ترانوے',
    'چورانوے',
    'پچانوے',
    'چھیانوے',
    'ستانوے',
    'اٹھانوے',
    'ننانوے',
  ];

  /// Converts [amount] (rounded to nearest whole unit) into words in [languageCode].
  static String convert(double amount, {String languageCode = 'en'}) {
    if (!amount.isFinite) return '';
    final lang = languageCode.toLowerCase().trim();
    final isNeg = amount < 0;
    final n = amount.abs().round();

    String body;
    switch (lang) {
      case 'ur':
        body = _toUrdu(n);
        break;
      case 'ar':
        body = _toArabic(n);
        break;
      case 'fa':
        body = _toPersian(n);
        break;
      case 'ps':
        body = _toPashto(n);
        break;
      case 'es':
        body = _toSpanish(n);
        break;
      case 'nl':
        body = _toDutch(n);
        break;
      default:
        body = _toEnglish(n);
        break;
    }

    if (!isNeg || n == 0) return body;
    return switch (lang) {
      'ur' => 'منفی $body',
      'ar' => 'سالب $body',
      'fa' => 'منفی $body',
      'ps' => 'منفي $body',
      'es' => 'Menos $body',
      'nl' => 'Min $body',
      _ => 'Minus $body',
    };
  }

  static String _toEnglish(int n) {
    if (n == 0) return 'Zero';
    const scales = ['', 'Thousand', 'Million', 'Billion', 'Trillion'];
    final parts = <String>[];
    var rem = n;
    var idx = 0;
    while (rem > 0) {
      final chunk = rem % 1000;
      if (chunk > 0) {
        final chunkWords = _enBelow1000(chunk);
        final scale = idx < scales.length ? scales[idx] : '';
        parts.insert(0, scale.isEmpty ? chunkWords : '$chunkWords $scale');
      }
      rem ~/= 1000;
      idx++;
    }
    return parts.join(' ');
  }

  static String _enBelow1000(int n) {
    final parts = <String>[];
    if (n >= 100) {
      parts.add('${_enUnits[n ~/ 100]} Hundred');
      n %= 100;
    }
    if (n >= 20) {
      final t = _enTens[n ~/ 10];
      final u = n % 10;
      parts.add(u > 0 ? '$t-${_enUnits[u]}' : t);
    } else if (n > 0) {
      parts.add(_enUnits[n]);
    }
    return parts.join(' ');
  }

  /// South Asian scale (ہزار, لاکھ, کروڑ, ارب) matching natural Urdu usage.
  static String _toUrdu(int n) {
    if (n == 0) return _ur0To99[0];
    final parts = <String>[];

    final arab = n ~/ 1000000000;
    if (arab > 0) {
      parts.add('${_toUrdu(arab)} ارب');
      n %= 1000000000;
    }
    final crore = n ~/ 10000000;
    if (crore > 0) {
      parts.add('${_urBelow1000(crore)} کروڑ');
      n %= 10000000;
    }
    final lakh = n ~/ 100000;
    if (lakh > 0) {
      parts.add('${_ur0To99[lakh]} لاکھ');
      n %= 100000;
    }
    final thousand = n ~/ 1000;
    if (thousand > 0) {
      parts.add('${_ur0To99[thousand]} ہزار');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(_urBelow1000(n));
    }
    return parts.join(' ');
  }

  static String _urBelow1000(int n) {
    final parts = <String>[];
    if (n >= 100) {
      parts.add('${_ur0To99[n ~/ 100]} سو');
      n %= 100;
    }
    if (n > 0) {
      parts.add(_ur0To99[n]);
    }
    return parts.join(' ');
  }

  static String _toArabic(int n) {
    if (n == 0) return 'صفر';
    const ones = [
      '',
      'واحد',
      'اثنان',
      'ثلاثة',
      'أربعة',
      'خمسة',
      'ستة',
      'سبعة',
      'ثمانية',
      'تسعة',
      'عشرة',
      'أحد عشر',
      'اثنا عشر',
      'ثلاثة عشر',
      'أربعة عشر',
      'خمسة عشر',
      'ستة عشر',
      'سبعة عشر',
      'ثمانية عشر',
      'تسعة عشر',
    ];
    const tens = [
      '',
      '',
      'عشرون',
      'ثلاثون',
      'أربعون',
      'خمسون',
      'ستون',
      'سبعون',
      'ثمانون',
      'تسعون',
    ];
    const hundreds = [
      '',
      'مائة',
      'مائتان',
      'ثلاثمائة',
      'أربعمائة',
      'خمسمائة',
      'ستمائة',
      'سبعمائة',
      'ثمانمائة',
      'تسعمائة',
    ];

    String below1000(int v) {
      final p = <String>[];
      if (v >= 100) {
        p.add(hundreds[v ~/ 100]);
        v %= 100;
      }
      if (v >= 20) {
        final u = v % 10;
        final t = tens[v ~/ 10];
        p.add(u > 0 ? '${ones[u]} و$t' : t);
      } else if (v > 0) {
        p.add(ones[v]);
      }
      return p.join(' و');
    }

    final p = <String>[];
    final billions = n ~/ 1000000000;
    if (billions > 0) {
      p.add(billions == 1 ? 'مليار' : '${below1000(billions)} مليار');
      n %= 1000000000;
    }
    final millions = n ~/ 1000000;
    if (millions > 0) {
      p.add(millions == 1
          ? 'مليون'
          : (millions == 2 ? 'مليونان' : '${below1000(millions)} مليون'));
      n %= 1000000;
    }
    final thousands = n ~/ 1000;
    if (thousands > 0) {
      p.add(thousands == 1
          ? 'ألف'
          : (thousands == 2 ? 'ألفان' : '${below1000(thousands)} ألف'));
      n %= 1000;
    }
    if (n > 0) p.add(below1000(n));
    return p.join(' و');
  }

  static String _toPersian(int n) {
    if (n == 0) return 'صفر';
    const ones = [
      '',
      'یک',
      'دو',
      'سه',
      'چهار',
      'پنج',
      'شش',
      'هفت',
      'هشت',
      'نه',
      'ده',
      'یازده',
      'دوازده',
      'سیزده',
      'چهارده',
      'پانزده',
      'شانزده',
      'هفده',
      'هجده',
      'نوزده',
    ];
    const tens = [
      '',
      '',
      'بیست',
      'سی',
      'چهل',
      'پنجاه',
      'شصت',
      'هفتاد',
      'هشتاد',
      'نود',
    ];
    const hundreds = [
      '',
      'صد',
      'دویست',
      'سیصد',
      'چهارصد',
      'پانصد',
      'ششصد',
      'هفتصد',
      'هشتصد',
      'نهصد',
    ];
    String below1000(int v) {
      final p = <String>[];
      if (v >= 100) {
        p.add(hundreds[v ~/ 100]);
        v %= 100;
      }
      if (v >= 20) {
        final t = tens[v ~/ 10];
        final u = v % 10;
        p.add(u > 0 ? '$t و ${ones[u]}' : t);
      } else if (v > 0) {
        p.add(ones[v]);
      }
      return p.join(' و ');
    }

    const scales = ['', 'هزار', 'میلیون', 'میلیارد'];
    final p = <String>[];
    var rem = n;
    var i = 0;
    while (rem > 0) {
      final chunk = rem % 1000;
      if (chunk > 0) {
        final w = below1000(chunk);
        p.insert(0, i == 0 ? w : '$w ${scales[i]}');
      }
      rem ~/= 1000;
      i++;
    }
    return p.join(' و ');
  }

  static String _toPashto(int n) {
    if (n == 0) return 'صفر';
    const ones = [
      '',
      'یو',
      'دوه',
      'درې',
      'څلور',
      'پنځه',
      'شپږ',
      'اووه',
      'اته',
      'نهه',
      'لس',
      'يوولس',
      'دولس',
      'دیارلس',
      'څوارلس',
      'پنځلس',
      'شپاړس',
      'اوولس',
      'اتلس',
      'نولس',
    ];
    const tens = [
      '',
      '',
      'شل',
      'دېرش',
      'څلوېښت',
      'پنځوس',
      'شپېته',
      'اویا',
      'اتیا',
      'نوي',
    ];
    String below1000(int v) {
      final p = <String>[];
      if (v >= 100) {
        final h = v ~/ 100;
        p.add(h == 1 ? 'سل' : '${ones[h]} سوه');
        v %= 100;
      }
      if (v >= 20) {
        final u = v % 10;
        final t = tens[v ~/ 10];
        p.add(u > 0 ? '${ones[u]} $t' : t);
      } else if (v > 0) {
        p.add(ones[v]);
      }
      return p.join(' او ');
    }

    const scales = ['', 'زره', 'میلیون', 'میلیارد'];
    final p = <String>[];
    var rem = n;
    var i = 0;
    while (rem > 0) {
      final chunk = rem % 1000;
      if (chunk > 0) {
        final w = below1000(chunk);
        p.insert(0, i == 0 ? w : '$w ${scales[i]}');
      }
      rem ~/= 1000;
      i++;
    }
    return p.join(' او ');
  }

  static String _toSpanish(int n) {
    if (n == 0) return 'Cero';
    const ones = [
      '',
      'Uno',
      'Dos',
      'Tres',
      'Cuatro',
      'Cinco',
      'Seis',
      'Siete',
      'Ocho',
      'Nueve',
      'Diez',
      'Once',
      'Doce',
      'Trece',
      'Catorce',
      'Quince',
      'Dieciséis',
      'Diecisiete',
      'Dieciocho',
      'Diecinueve',
    ];
    const tens = [
      '',
      '',
      'Veinte',
      'Treinta',
      'Cuarenta',
      'Cincuenta',
      'Sesenta',
      'Setenta',
      'Ochenta',
      'Noventa',
    ];
    const hundreds = [
      '',
      'Ciento',
      'Doscientos',
      'Trescientos',
      'Cuatrocientos',
      'Quinientos',
      'Seiscientos',
      'Setecientos',
      'Ochocientos',
      'Novecientos',
    ];
    String below1000(int v) {
      if (v == 100) return 'Cien';
      final p = <String>[];
      if (v >= 100) {
        p.add(hundreds[v ~/ 100]);
        v %= 100;
      }
      if (v >= 20) {
        final t = tens[v ~/ 10];
        final u = v % 10;
        p.add(u > 0 ? '$t y ${ones[u]}' : t);
      } else if (v > 0) {
        p.add(ones[v]);
      }
      return p.join(' ');
    }

    final p = <String>[];
    final millions = n ~/ 1000000;
    if (millions > 0) {
      p.add(millions == 1 ? 'Un Millón' : '${below1000(millions)} Millones');
      n %= 1000000;
    }
    final thousands = n ~/ 1000;
    if (thousands > 0) {
      p.add(thousands == 1 ? 'Mil' : '${below1000(thousands)} Mil');
      n %= 1000;
    }
    if (n > 0) p.add(below1000(n));
    return p.join(' ');
  }

  static String _toDutch(int n) {
    if (n == 0) return 'Nul';
    const ones = [
      '',
      'Een',
      'Twee',
      'Drie',
      'Vier',
      'Vijf',
      'Zes',
      'Zeven',
      'Acht',
      'Negen',
      'Tien',
      'Elf',
      'Twaalf',
      'Dertien',
      'Veertien',
      'Vijftien',
      'Zestien',
      'Zeventien',
      'Achttien',
      'Negentien',
    ];
    const tens = [
      '',
      '',
      'Twintig',
      'Dertig',
      'Veertig',
      'Vijftig',
      'Zestig',
      'Zeventig',
      'Tachtig',
      'Negentig',
    ];
    String below1000(int v) {
      final p = <String>[];
      if (v >= 100) {
        final h = v ~/ 100;
        p.add(h == 1 ? 'Honderd' : '${ones[h]}honderd');
        v %= 100;
      }
      if (v >= 20) {
        final u = v % 10;
        final t = tens[v ~/ 10];
        p.add(u > 0 ? '${ones[u]}en$t'.toLowerCase() : t);
      } else if (v > 0) {
        p.add(ones[v]);
      }
      return p.join(' ');
    }

    final p = <String>[];
    final millions = n ~/ 1000000;
    if (millions > 0) {
      p.add('${below1000(millions)} Miljoen');
      n %= 1000000;
    }
    final thousands = n ~/ 1000;
    if (thousands > 0) {
      p.add(thousands == 1 ? 'Duizend' : '${below1000(thousands)} Duizend');
      n %= 1000;
    }
    if (n > 0) p.add(below1000(n));
    return p.join(' ');
  }
}
