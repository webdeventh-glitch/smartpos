import 'package:flutter/material.dart';
import '../models/business_settings.dart';
import 'i18n/i18n_extra.dart';

/// Language descriptor for UI selection
class LanguageOption {
  final String code; // 'en', 'ur', 'fa', 'ar', 'ps', 'es', 'nl'
  final String name; // 'English', 'Urdu', etc.
  final String nativeName; // 'English', 'اردو', 'فارسی', 'العربية'
  final bool isRtl;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isRtl = false,
  });
}

/// Central Localization Service for SmartPOS Enterprise.
/// Strict Language Hierarchy Rules:
/// 1. If Primary Language is NOT English ('en'):
///    - Secondary Language is disabled / not needed.
///    - 100% of the UI, receipts, alerts, menus, and numbers-in-words render in the chosen primary language alone.
/// 2. If Primary Language IS English ('en'):
///    - Secondary Language becomes active and is optional.
///    - English is removed from secondary language choices (only non-English languages are available).
///    - If enabled, bilingual labels and secondary translations are displayed.
///    - If unchecked/disabled, clean English only is displayed.
class PosLocalization {
  PosLocalization._();

  /// Active app settings synced on bootstrap and whenever settings change,
  /// allowing any widget or helper dialog to resolve selected translations even
  /// when a [BusinessSettings] instance is not explicitly passed.
  static BusinessSettings? currentSettings;
  static final ValueNotifier<BusinessSettings?> settingsNotifier =
      ValueNotifier<BusinessSettings?>(null);

  static void setActiveSettings(BusinessSettings? settings) {
    currentSettings = settings;
    settingsNotifier.value = settings;
  }

  /// All supported primary languages
  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
        code: 'en', name: 'English', nativeName: 'English', isRtl: false),
    LanguageOption(code: 'ur', name: 'Urdu', nativeName: 'اردو', isRtl: true),
    LanguageOption(code: 'fa', name: 'Farsi', nativeName: 'فارسی', isRtl: true),
    LanguageOption(
        code: 'ar', name: 'Arabic', nativeName: 'العربية', isRtl: true),
    LanguageOption(code: 'ps', name: 'Pashto', nativeName: 'پښتو', isRtl: true),
    LanguageOption(
        code: 'es', name: 'Spanish', nativeName: 'Español', isRtl: false),
    LanguageOption(
        code: 'nl', name: 'Dutch', nativeName: 'Nederlands', isRtl: false),
  ];

  /// Secondary language options (English strictly excluded)
  static List<LanguageOption> get secondaryLanguageOptions =>
      supportedLanguages.where((lang) => lang.code != 'en').toList();

  /// Check if a language code is RTL
  static bool isRtl(String? code) {
    final c = (code ?? 'en').toLowerCase().trim();
    return c == 'ur' || c == 'fa' || c == 'ar' || c == 'ps';
  }

  /// Get text direction for language code
  static TextDirection textDirection(String? code) =>
      isRtl(code) ? TextDirection.rtl : TextDirection.ltr;

  /// Main translation method following strict user rules
  static String tr(
    String key, {
    BusinessSettings? settings,
    String? primaryOverride,
    String? secondaryOverride,
    bool? enableSecondaryOverride,
  }) {
    final active = settings ?? currentSettings;
    final primary = (primaryOverride ?? active?.activePrimaryLanguage ?? 'en')
        .toLowerCase()
        .trim();
    final isPrimaryEnglish = primary == 'en';

    // If primary is NOT English, secondary is strictly ignored
    final hasSecondary = isPrimaryEnglish &&
        (enableSecondaryOverride ??
            active?.hasEffectiveSecondaryLanguage ??
            false);
    final secondary = (secondaryOverride ?? active?.secondaryLanguage ?? 'ur')
        .toLowerCase()
        .trim();

    final primaryText = _lookup(key, primary) ?? _lookup(key, 'en') ?? key;

    if (!hasSecondary || secondary == 'en' || secondary == primary) {
      return primaryText;
    }

    final secondaryText = _lookup(key, secondary);
    if (secondaryText == null ||
        secondaryText.isEmpty ||
        secondaryText == primaryText) {
      return primaryText;
    }

    // Bilingual output: "Primary (Secondary)"
    // Strip shortcuts ([F1], (F12), [Esc], (?)) and symbols ((+), (-), +, :, *, etc.)
    // from secondary translation so shortcuts and symbols are never shown twice.
    final cleanSecondary =
        _stripSecondaryShortcutsAndSymbols(secondaryText, primaryText);
    if (cleanSecondary.isEmpty ||
        cleanSecondary.toLowerCase() == primaryText.toLowerCase()) {
      return primaryText;
    }
    return '$primaryText ($cleanSecondary)';
  }

  static final RegExp _shortcutTokenRx = RegExp(
    r'\s*(?:\[(?:F\d+|Esc|Enter|Tab|Del|Ins|Ctrl\+[A-Z0-9]+|Alt\+[A-Z0-9]+)\]|\((?:F\d+|Esc|\?)\))',
    caseSensitive: false,
  );
  static final RegExp _leadingShortcutRx = RegExp(
    r'^(?:F\d+|Esc|Ctrl\+[A-Z0-9]+|Alt\+[A-Z0-9]+)\s+',
    caseSensitive: false,
  );
  static final RegExp _symbolTagRx = RegExp(r'\s*\((?:\+|\-)\)');
  static final RegExp _leadingSymbolRx = RegExp(r'^[\+\-•●]\s*');

  static String _stripSecondaryShortcutsAndSymbols(
      String secondaryText, String primaryText) {
    var s = secondaryText.trim();
    s = s.replaceAll(_shortcutTokenRx, '');
    if (_leadingShortcutRx.hasMatch(primaryText)) {
      s = s.replaceFirst(_leadingShortcutRx, '');
    }
    s = s.replaceAll(_symbolTagRx, '');
    s = s.replaceAll(_leadingSymbolRx, '');
    if (primaryText.contains('*') && s.endsWith('*')) {
      s = s.substring(0, s.length - 1).trimRight();
    }
    if ((primaryText.endsWith(':') ||
            primaryText.endsWith('?') ||
            primaryText.endsWith('!')) &&
        (s.endsWith(':') ||
            s.endsWith('?') ||
            s.endsWith('؟') ||
            s.endsWith('!'))) {
      s = s.substring(0, s.length - 1).trimRight();
    }
    // Strip redundant English trailing token like "/ Khata" if already in primary
    if (primaryText.contains('/ Khata') && s.endsWith('/ Khata')) {
      s = s.substring(0, s.length - '/ Khata'.length).trimRight();
    }
    return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Returns only the primary language text (never combined with secondary),
  /// useful when secondary text is rendered on its own subtitle line.
  static String trPrimary(String key, {BusinessSettings? settings}) {
    final active = settings ?? currentSettings;
    final primary =
        (active?.activePrimaryLanguage ?? 'en').toLowerCase().trim();
    return _lookup(key, primary) ?? _lookup(key, 'en') ?? key;
  }

  /// Returns only the active secondary translation when primary is English and
  /// secondary language is enabled; otherwise returns null.
  static String? trSecondary(String key, {BusinessSettings? settings}) {
    final active = settings ?? currentSettings;
    if (active == null || !active.hasEffectiveSecondaryLanguage) {
      return null;
    }
    final sec = active.secondaryLanguage.toLowerCase().trim();
    if (sec.isEmpty || sec == 'en') return null;
    final primaryText = _lookup(key, 'en') ?? key;
    final secText = _lookup(key, sec);
    if (secText == null || secText.isEmpty || secText == primaryText) {
      return null;
    }
    return secText;
  }

  /// Translates [key] and substitutes `{placeholder}` parameters.
  static String trParams(
    String key,
    Map<String, String> params, {
    BusinessSettings? settings,
  }) {
    var out = tr(key, settings: settings);
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  /// Quick quantity / scale label generator
  static String quickQuantityLabel({
    required double val,
    required String unitCategory, // 'weight', 'volume', 'length', 'count'
    BusinessSettings? settings,
    String? primaryOverride,
    String? secondaryOverride,
    bool? enableSecondaryOverride,
  }) {
    final active = settings ?? currentSettings;
    final primary = (primaryOverride ?? active?.activePrimaryLanguage ?? 'en')
        .toLowerCase()
        .trim();
    final isPrimaryEnglish = primary == 'en';
    final hasSecondary = isPrimaryEnglish &&
        (enableSecondaryOverride ??
            active?.hasEffectiveSecondaryLanguage ??
            false);
    final secondary = (secondaryOverride ?? active?.secondaryLanguage ?? 'ur')
        .toLowerCase()
        .trim();

    String primLabel = _getQuantityUnitLabel(val, unitCategory, primary);
    if (!hasSecondary || secondary == 'en' || secondary == primary) {
      return primLabel;
    }

    String secLabel = _getQuantityUnitLabel(val, unitCategory, secondary);
    if (secLabel.isEmpty || secLabel == primLabel) {
      return primLabel;
    }

    return '$primLabel / $secLabel';
  }

  static String _getQuantityUnitLabel(
      double val, String category, String lang) {
    if (category == 'weight') {
      switch (lang) {
        case 'ur':
          if (val == 0.25) return '0.25 (پاؤ)';
          if (val == 0.50) return '0.50 (آدھا کلو)';
          if (val == 0.75) return '0.75 (تین پاؤ)';
          if (val == 1.0) return '1.0 (1 کلو)';
          if (val == 1.5) return '1.5 (ڈیڑھ کلو)';
          if (val == 2.0) return '2.0 (2 کلو)';
          if (val == 2.5) return '2.5 (ڈھائی کلو)';
          if (val == 5.0) return '5.0 (دھڑی / 5 کلو)';
          if (val == 10.0) return '10.0 (10 کلو)';
          if (val == 20.0) return '20.0 (آدھا من)';
          if (val == 40.0) return '40.0 (من / 40 کلو)';
          return '$val کلو';
        case 'fa':
          if (val == 0.25) return '0.25 (یک چهارم کیلو)';
          if (val == 0.50) return '0.50 (نیم کیلو)';
          if (val == 0.75) return '0.75 (سه چهارم کیلو)';
          if (val == 1.0) return '1.0 (۱ کیلوگرم)';
          if (val == 1.5) return '1.5 (۱.۵ کیلوگرم)';
          if (val == 2.0) return '2.0 (۲ کیلوگرم)';
          if (val == 2.5) return '2.5 (۲.۵ کیلوگرم)';
          if (val == 5.0) return '5.0 (۵ کیلوگرم)';
          if (val == 10.0) return '10.0 (۱۰ کیلوگرم)';
          if (val == 20.0) return '20.0 (۲۰ کیلوگرم)';
          if (val == 40.0) return '40.0 (۴۰ کیلوگرم)';
          return '$val کیلوگرم';
        case 'ar':
          if (val == 0.25) return '0.25 (ربع كيلو)';
          if (val == 0.50) return '0.50 (نصف كيلو)';
          if (val == 0.75) return '0.75 (ثلاثة أرباع كيلو)';
          if (val == 1.0) return '1.0 (1 كيلو)';
          if (val == 1.5) return '1.5 (1.5 كيلو)';
          if (val == 2.0) return '2.0 (2 كيلو)';
          if (val == 2.5) return '2.5 (2.5 كيلو)';
          if (val == 5.0) return '5.0 (5 كيلو)';
          if (val == 10.0) return '10.0 (10 كيلو)';
          if (val == 20.0) return '20.0 (20 كيلو)';
          if (val == 40.0) return '40.0 (40 كيلو)';
          return '$val كغ';
        default:
          if (val == 0.25) return '0.25 (Quarter Kg)';
          if (val == 0.50) return '0.50 (Half Kg)';
          if (val == 0.75) return '0.75 (0.75 Kg)';
          if (val == 1.0) return '1.0 (1 Kg)';
          if (val == 1.5) return '1.5 (1.5 Kg)';
          if (val == 2.0) return '2.0 (2 Kg)';
          if (val == 2.5) return '2.5 (2.5 Kg)';
          if (val == 5.0) return '5.0 (5 Kg)';
          if (val == 10.0) return '10.0 (10 Kg)';
          if (val == 20.0) return '20.0 (20 Kg)';
          if (val == 40.0) return '40.0 (40 Kg)';
          return '$val Kg';
      }
    } else if (category == 'volume') {
      switch (lang) {
        case 'ur':
          if (val == 0.25) return '0.25 (پاؤ / 250 ملی لیٹر)';
          if (val == 0.50) return '0.50 (آدھا لیٹر / 500 ملی لیٹر)';
          if (val == 0.75) return '0.75 (تین پاؤ / 750 ملی لیٹر)';
          if (val == 1.0) return '1.0 (1 لیٹر)';
          if (val == 1.5) return '1.5 (ڈیڑھ لیٹر)';
          if (val == 2.0) return '2.0 (2 لیٹر)';
          if (val == 2.5) return '2.5 (ڈھائی لیٹر)';
          if (val == 5.0) return '5.0 (5 لیٹر)';
          if (val == 10.0) return '10.0 (10 لیٹر)';
          return '$val لیٹر';
        case 'fa':
          if (val == 0.25) return '0.25 (۲۵۰ میلی‌لیتر)';
          if (val == 0.50) return '0.50 (نیم لیتر)';
          if (val == 0.75) return '0.75 (۷۵۰ میلی‌لیتر)';
          if (val == 1.0) return '1.0 (۱ لیتر)';
          if (val == 1.5) return '1.5 (۱.۵ لیتر)';
          if (val == 2.0) return '2.0 (۲ لیتر)';
          if (val == 2.5) return '2.5 (۲.۵ لیتر)';
          if (val == 5.0) return '5.0 (۵ لیتر)';
          if (val == 10.0) return '10.0 (۱۰ لیتر)';
          return '$val لیتر';
        case 'ar':
          if (val == 0.25) return '0.25 (ربع لتر)';
          if (val == 0.50) return '0.50 (نصف لتر)';
          if (val == 0.75) return '0.75 (ثلاثة أرباع لتر)';
          if (val == 1.0) return '1.0 (1 لتر)';
          if (val == 1.5) return '1.5 (1.5 لتر)';
          if (val == 2.0) return '2.0 (2 لتر)';
          if (val == 2.5) return '2.5 (2.5 لتر)';
          if (val == 5.0) return '5.0 (5 لتر)';
          if (val == 10.0) return '10.0 (10 لتر)';
          return '$val لتر';
        default:
          if (val == 0.25) return '0.25 (250ml)';
          if (val == 0.50) return '0.50 (500ml / Half Liter)';
          if (val == 0.75) return '0.75 (750ml)';
          if (val == 1.0) return '1.0 (1 Liter)';
          if (val == 1.5) return '1.5 (1.5 Liters)';
          if (val == 2.0) return '2.0 (2 Liters)';
          if (val == 2.5) return '2.5 (2.5 Liters)';
          if (val == 5.0) return '5.0 (5 Liters)';
          if (val == 10.0) return '10.0 (10 Liters)';
          return '$val Liters';
      }
    } else if (category == 'length') {
      switch (lang) {
        case 'ur':
          if (val == 0.50) return '0.50 (آدھا میٹر)';
          if (val == 1.0) return '1.0 (1 میٹر)';
          if (val == 1.5) return '1.5 (ڈیڑھ میٹر)';
          if (val == 2.0) return '2.0 (2 میٹر)';
          if (val == 3.0) return '3.0 (3 میٹر)';
          if (val == 5.0) return '5.0 (5 میٹر)';
          if (val == 10.0) return '10.0 (10 میٹر)';
          return '$val میٹر';
        case 'fa':
          if (val == 0.50) return '0.50 (نیم متر)';
          if (val == 1.0) return '1.0 (۱ متر)';
          if (val == 1.5) return '1.5 (۱.۵ متر)';
          if (val == 2.0) return '2.0 (۲ متر)';
          if (val == 3.0) return '3.0 (۳ متر)';
          if (val == 5.0) return '5.0 (۵ متر)';
          if (val == 10.0) return '10.0 (۱۰ متر)';
          return '$val متر';
        case 'ar':
          if (val == 0.50) return '0.50 (نصف متر)';
          if (val == 1.0) return '1.0 (1 متر)';
          if (val == 1.5) return '1.5 (1.5 متر)';
          if (val == 2.0) return '2.0 (2 متر)';
          if (val == 3.0) return '3.0 (3 أمتار)';
          if (val == 5.0) return '5.0 (5 أمتار)';
          if (val == 10.0) return '10.0 (10 أمتار)';
          return '$val متر';
        default:
          if (val == 0.50) return '0.50 (0.5 Meter)';
          if (val == 1.0) return '1.0 (1 Meter)';
          if (val == 1.5) return '1.5 (1.5 Meters)';
          if (val == 2.0) return '2.0 (2 Meters)';
          if (val == 3.0) return '3.0 (3 Meters)';
          if (val == 5.0) return '5.0 (5 Meters)';
          if (val == 10.0) return '10.0 (10 Meters)';
          return '$val Meters';
      }
    } else {
      // count / pieces
      switch (lang) {
        case 'ur':
          return '$val عدد';
        case 'fa':
          return '$val عدد';
        case 'ar':
          return '$val حبة';
        default:
          return '$val Pcs';
      }
    }
  }

  static String? _lookup(String key, String lang) {
    final dict = _dictionaries[lang];
    if (dict != null && dict.containsKey(key)) {
      return dict[key];
    }
    final cleanStar = key.replaceAll('*', '').trim();
    if (dict != null && dict.containsKey(cleanStar)) {
      final res = dict[cleanStar]!;
      return key.contains('*') ? '$res *' : res;
    }
    if (lang == 'en') {
      return I18nExtra.lookup(lang, key);
    }
    // Fallback lookup for non-English languages when caller passes clean base key
    // (e.g. 'DISCOUNT' -> 'DISCOUNT(-)') or shortcut-suffixed key (e.g. 'Cash [F2]' -> 'Cash').
    final baseKey = key
        .replaceAll(_shortcutTokenRx, '')
        .replaceAll(_symbolTagRx, '')
        .replaceAll(_leadingSymbolRx, '')
        .trim();
    if (baseKey.isNotEmpty && baseKey != key) {
      if (dict != null && dict.containsKey(baseKey)) {
        return dict[baseKey];
      }
      final extraBase = I18nExtra.lookup(lang, baseKey);
      if (extraBase != null) return extraBase;
    }
    final directExtra = I18nExtra.lookup(lang, key);
    if (directExtra != null) return directExtra;
    if (dict != null) {
      for (final suffix in const [
        '(-)',
        '(+)',
        ' [F2]',
        ' [F4]',
        ' [F6]',
        ' [F7]',
        ' [F8]',
        ' [F9]',
        ' [F10]',
        ' [F1]',
        ' (F12)',
        ' (F2)',
        ' (F3)',
        ' (?)',
        ' [Esc]'
      ]) {
        final k = '$key$suffix';
        if (dict.containsKey(k)) {
          return dict[k]!
              .replaceAll(_shortcutTokenRx, '')
              .replaceAll(_symbolTagRx, '')
              .trim();
        }
      }
      final plusK = '+ $key';
      if (dict.containsKey(plusK)) {
        return dict[plusK]!.replaceAll(_leadingSymbolRx, '').trim();
      }
    }
    return null;
  }

  // ================= DICTIONARIES =================
  static final Map<String, Map<String, String>> _dictionaries = {
    // English
    'en': {
      // Navigation
      'Dashboard': 'Dashboard',
      'POS Terminal': 'POS Terminal',
      'Products': 'Products',
      'Stock Transfers': 'Stock Transfers',
      'Stock Adjustments': 'Stock Adjustments',
      'Sales': 'Sales',
      'Purchases': 'Purchases',
      'Expenses': 'Expenses',
      'Contacts': 'Contacts',
      'Contacts & Khata': 'Contacts & Khata',
      'User Management': 'User Management',
      'Reports': 'Reports',
      'SMS & WhatsApp Alerts': 'SMS & WhatsApp Alerts',
      'Settings': 'Settings',
      'Business Settings': 'Business Settings',
      'Payment Accounts': 'Payment Accounts',
      'Annual Fiscal Closing': 'Annual Fiscal Closing',
      'Cloud & MySQL Sync': 'Cloud & MySQL Sync',
      'Modular Features': 'Modular Features',
      'Specialized Industry Modules': 'Specialized Industry Modules',
      'List Products': 'List Products',
      'Add Product': 'Add Product',
      'Print Labels': 'Print Labels',
      'Variations': 'Variations',
      'Import Products': 'Import Products',
      'Price Groups': 'Price Groups',
      'Units': 'Units',
      'Categories': 'Categories',
      'Brands': 'Brands',
      'Warranties': 'Warranties',
      'List Transfers': 'List Transfers',
      'Add Transfer': 'Add Transfer',
      'Stock Adjustment': 'Stock Adjustment',
      'Adjustments List': 'Adjustments List',
      'Add Adjustment': 'Add Adjustment',
      'All Sales': 'All Sales',
      'List POS': 'List POS',
      'Sales Return': 'Sales Return',
      'Purchases List': 'Purchases List',
      'Add Purchase': 'Add Purchase',
      'Purchase Return': 'Purchase Return',
      'List Expenses': 'List Expenses',
      'Add Expense': 'Add Expense',
      'Customers': 'Customers',
      'Suppliers': 'Suppliers',
      'Customer Groups': 'Customer Groups',
      'Users': 'Users',
      'Roles & Permissions': 'Roles & Permissions',
      'Profit / Loss Report': 'Profit / Loss Report',
      'Purchase & Sale': 'Purchase & Sale',
      'Tax Report': 'Tax Report',
      'Contact Dues': 'Contact Dues',
      'Stock & Expiry Audit': 'Stock & Expiry Audit',
      'Trending Products': 'Trending Products',

      // POS Screen
      'PRODUCT': 'PRODUCT',
      'QUANTITY': 'QUANTITY',
      'PRICE INC. TAX': 'PRICE INC. TAX',
      'SUBTOTAL': 'SUBTOTAL',
      'ITEMS': 'ITEMS',
      'DISCOUNT': 'DISCOUNT',
      'ORDER TAX': 'ORDER TAX',
      'SHIPPING': 'SHIPPING',
      'TOTAL PAYABLE': 'TOTAL PAYABLE',
      'No products in cart': 'No products in cart',
      'Scan barcode or select products on the right':
          'Scan barcode or select products on the right',
      'Cart is empty! Add products first':
          'Cart is empty! Please add products to cart first.',
      'Cancel': 'Cancel',
      'Draft': 'Draft',
      'Quotation': 'Quotation',
      'Suspend': 'Suspend',
      'Credit Sale': 'Credit Sale',
      'Recent Sales': 'Recent Sales',
      'Card': 'Card',
      'Multiple Pay': 'Multiple Pay',
      'Cash': 'Cash',
      'Retail Mode': 'Retail Mode',
      'Custom Item': 'Custom Item',
      'Undo': 'Undo',
      'Redo': 'Redo',
      'Multi-Unit & Decimal Scale Enabled':
          'Multi-Unit & Decimal Scale Enabled',
      'Category': 'Category',
      'Featured Products': 'Featured Products',
      'Grid': 'Grid',
      'List': 'List',
      'Search product / barcode / 2*SKU': 'Search product / barcode / 2*SKU',
      'No products found in catalog': 'No products found in catalog',
      'Walk-in Customer': 'Walk-in Customer',
      'Reset to Walk-in Customer': 'Reset to Walk-in Customer',

      // Payment & Dialogs
      'Card Payment (Debit / Credit Card)':
          'Card Payment (Debit / Credit Card)',
      'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.':
          'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.',
      'Bank Machine Slip # / Auth Code:*': 'Bank Machine Slip # / Auth Code:*',
      'Card Network:': 'Card Network:',
      'Complete Card Payment': 'Complete Card Payment',
      'Credit Sale Not Allowed for Walk-in Customer':
          'Credit Sale Not Allowed for Walk-in Customer',
      'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.':
          'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.',
      'Select Customer': 'Select Customer',
      'Adjust Weight': 'Adjust Weight',
      'Adjust Volume': 'Adjust Volume',
      'Adjust Measurement': 'Adjust Measurement',
      'Adjust Quantity': 'Adjust Quantity',
      'Weight Scale': 'Weight Scale',
      'Liquid Volume': 'Liquid Volume',
      'Measurement / Fabric': 'Measurement / Fabric',
      'Count / Discrete Item': 'Count / Discrete Item',
      'Unit of Measure': 'Unit of Measure',
      'Change Active Selling Unit': 'Change Active Selling Unit',

      // Receipts & Invoices
      'INVOICE NO:': 'INVOICE NO:',
      'DATE & TIME:': 'DATE & TIME:',
      'CUSTOMER:': 'CUSTOMER:',
      'PAY METHOD:': 'PAY METHOD:',
      'AMOUNT PAID': 'AMOUNT PAID',
      'CHANGE DUE': 'CHANGE DUE',
      'PREVIOUS BALANCE': 'PREVIOUS BALANCE',
      'CURRENT INVOICE': 'CURRENT INVOICE',
      'RECEIVED TODAY': 'RECEIVED TODAY',
      'NET CLOSING KHATA': 'NET CLOSING KHATA',
      'Thank you for shopping with us! Please retain this receipt for returns/exchange.':
          'Thank you for shopping with us! Please retain this receipt for returns/exchange.',
      'Invoice Preview': 'Invoice Preview',
      'Complete (New Sale)': 'Complete (New Sale)',
      'Done': 'Done',
      'Print': 'Print',
      'WhatsApp': 'WhatsApp',
      'Note: Report expiries with original bill.':
          'Note: Report expiries with original bill.',

      // Setup & Settings
      'Back': 'Back',
      'Continue to Next Step': 'Continue to Next Step',
      'Complete Installation & Launch': 'Complete Installation & Launch',
      'Primary Language': 'Primary Language',
      'When unchecked, only primary language is shown across the app':
          'When unchecked, only primary language is shown across the app',
      'Secondary Language is only available when Primary Language is English':
          'Secondary Language is only available when Primary Language is English',
      'Business / Store Name *': 'Business / Store Name *',
      'Branch / Outlet': 'Branch / Outlet',
      'Official Currency *': 'Official Currency *',
      'Regional Time Zone *': 'Regional Time Zone *',
      'Language for Totals & Invoices *': 'Language for Totals & Invoices *',
      'Contact Email': 'Contact Email',
      'Contact Phone': 'Contact Phone',
      'Physical Address': 'Physical Address',
      'Receipt Footer Note': 'Receipt Footer Note',
      'Verifying security credentials...': 'Verifying security credentials...',
      'Initializing POS Engine & Data Cache...':
          'Initializing POS Engine & Data Cache...',
      'Access Granted! Launching Smart POS...':
          'Access Granted! Launching Smart POS...',
      'Configure Modules': 'Configure Modules',
      'Open Full Page': 'Open Full Page',
      'Copy Statement': 'Copy Statement',
      'Send WhatsApp Reminder': 'Send WhatsApp Reminder',
      'Official Financial Ledger Book': 'Official Financial Ledger Book',
      'Today': 'Today',
      'This Month': 'This Month',
      'Last 30 Days': 'Last 30 Days',
      'All Time': 'All Time',
      'Customer Due Balance': 'Customer Due Balance',
      'Supplier Payable': 'Supplier Payable',
      'Account Completely Cleared (Zero Balance)':
          'Account Completely Cleared (Zero Balance)',
      'All invoices and payments are fully reconciled.':
          'All invoices and payments are fully reconciled.',
      'Outstanding amount owed by customer.':
          'Outstanding amount owed by customer.',
      'Outstanding amount owed to supplier.':
          'Outstanding amount owed to supplier.',
      'Advance Credit Balance': 'Advance Credit Balance',
      'Party has advance balance on account.':
          'Party has advance balance on account.',
      'Send Token': 'Send Token',
      'No Products in Catalog Yet': 'No Products in Catalog Yet',
      'No products in catalog yet': 'No products in catalog yet',
      'Add products with selling price and initial stock to start billing immediately!':
          'Add products with selling price and initial stock to start billing immediately!',
      '+ Add First Product': '+ Add First Product',
      '+ Receive Payment': '+ Receive Payment',
      '+ Pay Supplier': '+ Pay Supplier',
      'Customer': 'Customer',
      'Supplier': 'Supplier',
      'Opening Balance': 'Opening Balance',
      'Total Billed / Debit (Dr)': 'Total Billed / Debit (Dr)',
      'Total Paid / Credit (Cr)': 'Total Paid / Credit (Cr)',
      'TRANSACTIONS': 'TRANSACTIONS',
      'Thank you for your business!': 'Thank you for your business!',
      'Due': 'Due',
      'Cleared': 'Cleared',
      'Quick Stock In': 'Quick Stock In',
      'Quantity to Add': 'Quantity to Add',
      'Purchase Cost per Unit': 'Purchase Cost per Unit',
      'Add Stock': 'Add Stock',
      'Stock In / Purchase': 'Stock In / Purchase',
      'Supplier (Optional)': 'Supplier (Optional)',
      'Product Name': 'Product Name',
      'Selling Price': 'Selling Price',
      'Opening Stock (Units)': 'Opening Stock (Units)',
      'Physical Note Counter': 'Physical Note Counter',
      'Test Connection': 'Test Connection',
      'Save Module Settings': 'Save Module Settings',
      'Operational & Inventory Features': 'Operational & Inventory Features',
      '1. POS COUNTER & SALE CONTROLS': '1. POS COUNTER & SALE CONTROLS',
      'Allow Altering Unit Prices at Counter':
          'Allow Altering Unit Prices at Counter',
      'Allow Giving Discounts': 'Allow Giving Discounts',
      'Allow Voiding & Deleting Completed Sales':
          'Allow Voiding & Deleting Completed Sales',
      '2. PROFIT & FINANCIAL CONFIDENTIALITY':
          '2. PROFIT & FINANCIAL CONFIDENTIALITY',
      'View Purchase / Cost Price & Profit Margins':
          'View Purchase / Cost Price & Profit Margins',
      'Authorize Sales Returns & Cash Refunds':
          'Authorize Sales Returns & Cash Refunds',
      'Access Customer Khata & Credit Ledgers':
          'Access Customer Khata & Credit Ledgers',
      '3. BACK-OFFICE & SYSTEM POWERS': '3. BACK-OFFICE & SYSTEM POWERS',
      'Inventory Stock Transfers & Adjustments':
          'Inventory Stock Transfers & Adjustments',
      'View Sales, Tax & Profit/Loss Reports':
          'View Sales, Tax & Profit/Loss Reports',
      'Access Store Settings & Configurations':
          'Access Store Settings & Configurations',
      'Manage Other Users & Staff Permissions':
          'Manage Other Users & Staff Permissions',
      'PAYMENT CURRENCY': 'PAYMENT CURRENCY',
      'Total Sales': 'Total Sales',
      'Total Sales Revenue': 'Total Sales Revenue',
      'Net': 'Net',
      'Invoice due': 'Invoice due',
      'Total Sell Return': 'Total Sell Return',
      'Total purchase': 'Total purchase',
      'Total Purchases': 'Total Purchases',
      'Purchase due': 'Purchase due',
      'Total Purchase Return': 'Total Purchase Return',
      'Expense': 'Expense',
      'Welcome': 'Welcome',
      'This Quarter': 'This Quarter',
      'This Year': 'This Year',
      'Pending Sales Orders': 'Pending Sales Orders',
      'No pending sales orders awaiting invoicing.':
          'No pending sales orders awaiting invoicing.',
      'Pending Purchase Orders': 'Pending Purchase Orders',
      'No pending supplier purchase orders.':
          'No pending supplier purchase orders.',
      'Sales Last 30 Days': 'Sales Last 30 Days',
      'Daily sales turnover (Sales & Revenue Velocity)':
          'Daily sales turnover (Sales & Revenue Velocity)',
      'Payment Breakdown': 'Payment Breakdown',
      'Volume by tender method': 'Volume by tender method',
      'No Sales': 'No Sales',
      'Total': 'Total',
      'Complete POS sales to see payment breakdown.':
          'Complete POS sales to see payment breakdown.',
      'Inventory Reorder & Low Stock Alerts':
          'Inventory Reorder & Low Stock Alerts',
      'All inventory items are currently at healthy stock levels.':
          'All inventory items are currently at healthy stock levels.',
      'Create Purchase Order': 'Create Purchase Order',
      'Manage': 'Manage',
      'Receive': 'Receive',
      'Revenue': 'Revenue',
      'Orders': 'Orders',
      'POWER SHORTCUTS': 'POWER SHORTCUTS',
      'Register': 'Register',
      'New Product': 'New Product',
      'Sales List': 'Sales List',
      'Refresh Data': 'Refresh Data',
      'Cash Register': 'Cash Register',
      'Stock Audit': 'Stock Audit',
      'Sales Orders': 'Sales Orders',
      'Purchase Orders': 'Purchase Orders',
      'Workstation Sign In': 'Workstation Sign In',
      'Authenticate to open register & billing terminal':
          'Authenticate to open register & billing terminal',
      'Username or Operator ID': 'Username or Operator ID',
      'Password': 'Password',
      'Sign In to Terminal': 'Sign In to Terminal',
      'Run Installation & Database Setup Wizard':
          'Run Installation & Database Setup Wizard',
      'Setup Wizard & Database Management':
          'Setup Wizard & Database Management',
      'How would you like to launch the Setup Wizard?':
          'How would you like to launch the Setup Wizard?',
      'Reconfigure Settings (Keep Data)': 'Reconfigure Settings (Keep Data)',
      'Re-run setup wizard to change business info, languages, currency, or credentials without deleting existing data.':
          'Re-run setup wizard to change business info, languages, currency, or credentials without deleting existing data.',
      'Reset to Fresh Installation': 'Reset to Fresh Installation',
      'Wipe all local demo data, sales, and products to start with a completely fresh installation.':
          'Wipe all local demo data, sales, and products to start with a completely fresh installation.',
      'Confirm Database Reset': 'Confirm Database Reset',
      'Are you sure you want to delete all local business data, products, and users to start a fresh setup? This cannot be undone.':
          'Are you sure you want to delete all local business data, products, and users to start a fresh setup? This cannot be undone.',
      'Reset & Start Setup': 'Reset & Start Setup',
      'Launch Setup Wizard': 'Launch Setup Wizard',
      'Location': 'Location',
      'General Walk-in Shopper': 'General Walk-in Shopper',
      'Search': 'Search',
      'Wholesale Mode': 'Wholesale Mode',
      'Till': 'Till',
      'Smart POS Engine • Multi-Industry': 'Smart POS Engine • Multi-Industry',
      'in stock': 'in stock',
      'stk': 'stk',
      'Enterprise Retail & Wholesale Workstation':
          'Enterprise Retail & Wholesale Workstation',
      'Secure high-speed point of sale, inventory control, and transaction ledger.':
          'Secure high-speed point of sale, inventory control, and transaction ledger.',
      'Fast Counter Billing & Barcode Scanning':
          'Fast Counter Billing & Barcode Scanning',
      'Multi-Cashier & Register Reconciliation':
          'Multi-Cashier & Register Reconciliation',
      'Real-Time Inventory & Batch Tracking':
          'Real-Time Inventory & Batch Tracking',
      'Offline Database Engine Connected (SQLite FFI)':
          'Offline Database Engine Connected (SQLite FFI)',
      'Hybrid Engine Active (Local SQLite FFI + MySQL Cloud Sync)':
          'Hybrid Engine Active (Local SQLite FFI + MySQL Cloud Sync)',
      'e.g. admin, cashier1, or salesman': 'e.g. admin, cashier1, or salesman',
      'Enter account password': 'Enter account password',
      'Please enter username': 'Please enter username',
      'Please enter password': 'Please enter password',
      'Workstation auto-locks after inactivity':
          'Workstation auto-locks after inactivity',
      'Smart POS Enterprise Edition • 256-bit Local AES Encryption':
          'Smart POS Enterprise Edition • 256-bit Local AES Encryption',
      'Scan barcode / search item / 2*SKU':
          'Scan barcode / search item / 2*SKU',
      'Shortcuts': 'Shortcuts',
      'Pack': 'Pack',
      'Bottle': 'Bottle',
      'Box': 'Box',
      'Bag': 'Bag',
      'Pc': 'Pc',
      'Shortcuts Help': 'Shortcuts Help',
      'Cash Checkout': 'Cash Checkout',
      'Hold Bill': 'Hold Bill',
      'Partial / Split Pay': 'Partial / Split Pay',
      'Reset Order': 'Reset Order',
      'Shift Reconciliation': 'Shift Reconciliation',
      'Undo Cart': 'Undo Cart',
      'Search Focus': 'Search Focus',
      'Smart POS • Touch Mode Active': 'Smart POS • Touch Mode Active',
      'POS Terminal Shortcuts': 'POS Terminal Shortcuts',
      'Add Custom Item': 'Add Custom Item',
      'Quick Price & Stock Check': 'Quick Price & Stock Check',
      'Open Cash Drawer': 'Open Cash Drawer',
      'Wholesale Tier (Active)': 'Wholesale Tier (Active)',
      'Out of Stock': 'Out of Stock',
      'Unit': 'Unit',
      'Batch': 'Batch',
      '1. License Lock': '1. License Lock',
      '2. Business & Presets': '2. Business & Presets',
      '3. Topology & DB': '3. Topology & DB',
      '4. Master Admin': '4. Master Admin',
      'Step 1: Machine Hardware-Bound License Activation':
          'Step 1: Machine Hardware-Bound License Activation',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.',
      'Detected Host Machine Hardware ID (HWID):':
          'Detected Host Machine Hardware ID (HWID):',
      'Copy HWID': 'Copy HWID',
      'Verify & Activate': 'Verify & Activate',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'Activate Instant 30-Day Free Trial (Hardware Bound)',
      'No internet required for activation':
          'No internet required for activation',
      'HARDWARE BOUND': 'HARDWARE BOUND',
      'Step 2: Business Profile & Industry Workflows':
          'Step 2: Business Profile & Industry Workflows',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).',
      'Smart POS Activation Key': 'Smart POS Activation Key',
      'Business Logo': 'Business Logo',
      'Business / Store Name': 'Business / Store Name',
      'NTN / Tax ID': 'NTN / Tax ID',
      'Official Currency': 'Official Currency',
      'Regional Time Zone': 'Regional Time Zone',
      'Local Embedded API Server Port': 'Local Embedded API Server Port',
      'Primary Server Local IP': 'Primary Server Local IP',
      'API Port': 'API Port',
      'Remote Cloud API URL': 'Remote Cloud API URL',
      'Branch ID': 'Branch ID',
      'Cloud API Secret Key': 'Cloud API Secret Key',
      'Primary Database Host / IP': 'Primary Database Host / IP',
      'Port': 'Port',
      'Database Name': 'Database Name',
      'DB Username': 'DB Username',
      'DB Password': 'DB Password',
      'Admin Full Name': 'Admin Full Name',
      'Master Username': 'Master Username',
      'Email Address': 'Email Address',
      'Mobile Number': 'Mobile Number',
      'Master Password': 'Master Password',
      'Confirm Master Password': 'Confirm Master Password',
      'Upload Logo': 'Upload Logo',
      'Change': 'Change',
      'Search 130+ Currencies': 'Search 130+ Currencies',
      'Search 80+ Timezones': 'Search 80+ Timezones',
      'Main': 'Main',
      'Enable Secondary Language (Optional)':
          'Enable Secondary Language (Optional)',
      'Select Business Industry Model (16 Supported Industries):':
          'Select Business Industry Model (16 Supported Industries):',
      '1 Business Model At A Time': '1 Business Model At A Time',
      'Pre-load Starter Products, Categories & Suppliers':
          'Pre-load Starter Products, Categories & Suppliers',
      'RECOMMENDED': 'RECOMMENDED',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.',
      'ACTIVE EXCLUSIVE': 'ACTIVE EXCLUSIVE',
      'Step 3: Network Topology & Hybrid Database Engine':
          'Step 3: Network Topology & Hybrid Database Engine',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).',
      'Primary Server & Mobile REST API Server Configuration':
          'Primary Server & Mobile REST API Server Configuration',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC',
      'Connect to Primary Server Machine:':
          'Connect to Primary Server Machine:',
      'Cloud Sync Server Configuration:': 'Cloud Sync Server Configuration:',
      'Primary Central Database Engine (Admin Choice)':
          'Primary Central Database Engine (Admin Choice)',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".',
      'Clear for Laragon': 'Clear for Laragon',
      'Offline-First Local SQLite Sync Guarantee':
          'Offline-First Local SQLite Sync Guarantee',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.',
      'Step 4: Super Admin Master Credentials':
          'Step 4: Super Admin Master Credentials',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.',
      'Installation & Setup Completed!': 'Installation & Setup Completed!',
      'System installation and database configuration completed successfully.':
          'System installation and database configuration completed successfully.',
      'Store / Business Name': 'Store / Business Name',
      'Industry Profile': 'Industry Profile',
      'Database Engine': 'Database Engine',
      'Commercial Catalog': 'Commercial Catalog',
      'Master Admin Username': 'Master Admin Username',
      'Starter products, categories & suppliers pre-loaded':
          'Starter products, categories & suppliers pre-loaded',
      'Clean blank database initialized': 'Clean blank database initialized',
      'Direct Login Bypassed for Security':
          'Direct Login Bypassed for Security',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.',
      'Proceed to Login Screen': 'Proceed to Login Screen',
      'Master Admin username cannot be empty.':
          'Master Admin username cannot be empty.',
      'Passwords do not match. Please re-enter.':
          'Passwords do not match. Please re-enter.',
      'Please enter Business / Store Name.':
          'Please enter Business / Store Name.',
      'Please select at least one Business Industry Preset.':
          'Please select at least one Business Industry Preset.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'Please provide Primary Server IP for LAN terminal mode.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'A verified License Key or Active Free Trial is required to proceed.',
      'MySQL Connection Notice': 'MySQL Connection Notice',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?',
      'Back to Settings': 'Back to Settings',
      'Switch to SQLite & Launch POS': 'Switch to SQLite & Launch POS',
      'Installation Error': 'Installation Error',
      'Close': 'Close',
      'Cheque Management': 'Cheque Management',
      'Turnstile Check-In': 'Turnstile Check-In',
      'Live KDS Screen': 'Live KDS Screen',
      'Cooking': 'Cooking',
      'Ready': 'Ready',
      'Served': 'Served',
      'REPAIR & SERVICE INTAKE VOUCHER': 'REPAIR & SERVICE INTAKE VOUCHER',
      'Terms & Conditions of Service': 'Terms & Conditions of Service',
      'Credit Limit': 'Credit Limit',
      'Period': 'Period',
      'Custom Range': 'Custom Range',
      'No transactions or invoices found for the selected period.':
          'No transactions or invoices found for the selected period.',
      'Record Payment': 'Record Payment',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER':
          'OFFICIAL LEDGER TRANSACTIONS REGISTER',
      'DATE & TIME': 'DATE & TIME',
      'TYPE': 'TYPE',
      'NARRATION & DETAILS': 'NARRATION & DETAILS',
      'DEBIT (Dr)': 'DEBIT (Dr)',
      'CREDIT (Cr)': 'CREDIT (Cr)',
      'RUNNING BAL': 'RUNNING BAL',
      'GRAND TOTALS': 'GRAND TOTALS',
      'PAYMENT': 'PAYMENT',
      'RETURN': 'RETURN',
      'PURCHASE': 'PURCHASE',
      'INVOICE': 'INVOICE',
      'OPENING': 'OPENING',
      'Save Modules': 'Save Modules',
      'Commercial SaaS Tier Presets': 'Commercial SaaS Tier Presets',
      'Quick Presets': 'Quick Presets',
      'Minimalist Core Only': 'Minimalist Core Only',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'Hybrid Local SQLite + Laravel / MySQL Sync Architecture',
      'Save Settings': 'Save Settings',
      'Sync Now': 'Sync Now',
      '1. Deployment & Sync Mode': '1. Deployment & Sync Mode',
      'Offline Only': 'Offline Only',
      'Both Online & Offline - Hybrid Sync':
          'Both Online & Offline - Hybrid Sync',
      'Enable All 16 Modules': 'تفعيل كافة الموديولات الـ 16',
      'Search modules by name or keywords...':
          'البحث بالاسم أو الكلمات الدلالية...',
      'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean.':
          'تخصيص الموديولات النشطة لتنظيم مساحة العمل وإخفاء الميزات غير المستخدمة.',
      'Smart POS Industry Presets': 'نماذج الأنشطة التجارية',
      'Online Cloud Server': 'خادم سحابي مباشر',
      '2. Laravel / MySQL Server Configuration':
          'إعدادات خادم الاتصال عبر الإنترنت',
      'Live exchange rates synced successfully!':
          'تم تحديث أسعار الصرف الحية بنجاح!',
      'Error fetching exchange rates:': 'خطأ في جلب أسعار الصرف:',
      'Adapt software units, categories & POS to your trade':
          'مواءمة الوحدات والفئات ونقطة البيع مع مجال عملك',
    },

    // Urdu (اردو)
    'ur': {
      // Navigation
      'Dashboard': 'ڈیش بورڈ',
      'POS Terminal': 'پوائنٹ آف سیل (POS)',
      'Products': 'پروڈکٹس و انوینٹری',
      'Stock Transfers': 'اسٹاک منتقلی',
      'Stock Adjustments': 'اسٹاک کمی بیشی',
      'Sales': 'سیلز و بلنگ',
      'Purchases': 'خریداری و اسٹاک انٹری',
      'Expenses': 'اخراجات و کیش بُک',
      'Contacts': 'کسٹمرز و سپلائرز',
      'Contacts & Khata': 'کسٹمرز و کھاتہ جات',
      'User Management': 'صارفین اور اختیارات',
      'Reports': 'رپورٹس و مالی تجزیہ',
      'SMS & WhatsApp Alerts': 'ایس ایم ایس اور واٹس ایپ الرٹس',
      'Settings': 'سیٹنگز و کنفیگریشن',
      'Business Settings': 'کاروباری معلومات',
      'Payment Accounts': 'بینک و نقد اکاؤنٹس',
      'Annual Fiscal Closing': 'سالانہ مالی اختتام',
      'Cloud & MySQL Sync': 'کلاؤڈ و مائی ایس کیو ایل سنک',
      'Modular Features': 'ماڈیولر فیچرز',
      'Specialized Industry Modules': 'خصوصی انڈسٹری ماڈیولز',
      'List Products': 'پروڈکٹس کی فہرست',
      'Add Product': 'نیا پروڈکٹ شامل کریں',
      'Print Labels': 'بارکوڈ لیبلز پرنٹ کریں',
      'Variations': 'اقسام و ویری ایشنز',
      'Import Products': 'پروڈکٹس امپورٹ کریں',
      'Price Groups': 'قیمتوں کے گروپس',
      'Units': 'پیمائش کے یونٹس',
      'Categories': 'کیٹیگریز',
      'Brands': 'برانڈز',
      'Warranties': 'وارنٹی پیریڈز',
      'List Transfers': 'منتقلی کی فہرست',
      'Add Transfer': 'نئی منتقلی درج کریں',
      'Stock Adjustment': 'اسٹاک درستگی',
      'Adjustments List': 'درستگیوں کی فہرست',
      'Add Adjustment': 'نئی درستگی درج کریں',
      'All Sales': 'تمام سیلز',
      'List POS': 'پی او ایس سیلز لسٹ',
      'Sales Return': 'سیل واپسی (ریٹرن)',
      'Purchases List': 'خریداری کی فہرست',
      'Add Purchase': 'نئی خریداری درج کریں',
      'Purchase Return': 'خریداری واپسی',
      'List Expenses': 'اخراجات کی فہرست',
      'Add Expense': 'نیا خرچہ درج کریں',
      'Customers': 'کسٹمرز',
      'Suppliers': 'سپلائرز',
      'Customer Groups': 'کسٹمر گروپس',
      'Users': 'صارفین',
      'Roles & Permissions': 'کردار و اختیارات',
      'Profit / Loss Report': 'نفع و نقصان رپورٹ',
      'Purchase & Sale': 'خرید و فروخت',
      'Tax Report': 'ٹیکس رپورٹ',
      'Contact Dues': 'واجب الادا بقایا جات',
      'Stock & Expiry Audit': 'اسٹاک و ایکسپائری آڈٹ',
      'Trending Products': 'زیادہ فروخت ہونے والے پروڈکٹس',

      // POS Screen
      'PRODUCT': 'پروڈکٹ',
      'QUANTITY': 'تعداد / وزن',
      'PRICE INC. TAX': 'قیمت بلحاظ ٹیکس',
      'SUBTOTAL': 'کل رقم',
      'ITEMS': 'کل اشیاء',
      'DISCOUNT': 'رعایت',
      'ORDER TAX': 'ٹیکس',
      'SHIPPING': 'کرایہ',
      'TOTAL PAYABLE': 'کل واجب الادا',
      'No products in cart': 'کارٹ خالی ہے',
      'Scan barcode or select products on the right':
          'دائیں جانب سے آئٹم منتخب کریں یا بارکوڈ اسکین کریں',
      'Cart is empty! Add products first':
          'کارٹ خالی ہے! پہلے بل میں پروڈکٹس شامل کریں۔',
      'Cancel': 'منسوخ کریں',
      'Draft': 'ڈرافٹ',
      'Quotation': 'کوٹیشن',
      'Suspend': 'عارضی محفوظ',
      'Park': 'عارضی محفوظ',
      'Credit Sale': 'ادھار سیل',
      'Credit / Khata': 'ادھار / کریڈٹ',
      'Recent Sales': 'حالیہ سیلز',
      'Card': 'کارڈ',
      'Multiple Pay': 'ملٹی ادائیگی',
      'Cash': 'نقد وصولی',
      'Retail Mode': 'ریٹیل موڈ',
      'Custom Item': 'متفرق آئٹم',
      'Undo': 'واپس',
      'Redo': 'دوبارہ',
      'Multi-Unit & Decimal Scale Enabled': 'ملٹی یونٹ و ترازو اسکیل فعال ہے',
      'Category': 'کیٹیگری',
      'Featured Products': 'نمایاں پروڈکٹس',
      'Grid': 'گرڈ',
      'List': 'لسٹ',
      'Search product / barcode / 2*SKU': 'پروڈکٹ / بارکوڈ / SKU تلاش کریں',
      'No products found in catalog': 'کیٹلاگ میں کوئی پروڈکٹ موجود نہیں ہے',
      'Walk-in Customer': 'عام گاہک (واک اِن)',
      'Reset to Walk-in Customer': 'واک اِن کسٹمر پر ری سیٹ کریں',

      // Payment & Dialogs
      'Card Payment (Debit / Credit Card)': 'کارڈ سے ادائیگی (ڈیبٹ / کریڈٹ)',
      'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.':
          'سسٹم آف لائن موڈ میں ہے۔ بینک مشین سے کارڈ سوائپ کریں اور سلپ نمبر درج کریں۔',
      'Bank Machine Slip # / Auth Code:*': 'بینک مشین سلپ نمبر / Auth کوڈ:*',
      'Card Network:': 'کارڈ نیٹ ورک:',
      'Complete Card Payment': 'کارڈ ادائیگی مکمل کریں',
      'Credit Sale Not Allowed for Walk-in Customer':
          'واک اِن کسٹمر کو ادھار سیل ممنوع ہے',
      'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.':
          'واک اِن کسٹمر کا کھاتہ درج نہیں ہوتا۔ کریڈٹ سیل کے لیے رجسٹرڈ کسٹمر منتخب کریں۔',
      'Select Customer': 'کسٹمر کھاتہ منتخب کریں',
      'Adjust Weight': 'وزن درج کریں',
      'Adjust Volume': 'حجم / لیٹر درج کریں',
      'Adjust Measurement': 'پیمائش درج کریں',
      'Adjust Quantity': 'تعداد درج کریں',
      'Weight Scale': 'تولنے والا وزن',
      'Liquid Volume': 'مائع پیمائش (لیٹر)',
      'Measurement / Fabric': 'پیمائش (میٹر / گز)',
      'Count / Discrete Item': 'گنتی و تعداد والے یونٹس',
      'Unit of Measure': 'پیمائش کا یونٹ',
      'Change Active Selling Unit': 'فروخت کا یونٹ تبدیل کریں',

      // Receipts & Invoices
      'INVOICE NO:': 'بل نمبر:',
      'DATE & TIME:': 'تاریخ و وقت:',
      'CUSTOMER:': 'گاہک:',
      'PAY METHOD:': 'ادائیگی کا طریقہ:',
      'AMOUNT PAID': 'وصول شدہ رقم',
      'CHANGE DUE': 'بقایا واپسی',
      'PREVIOUS BALANCE': 'سابقہ بقایا',
      'CURRENT INVOICE': 'موجودہ بل',
      'RECEIVED TODAY': 'آج وصولی',
      'NET CLOSING KHATA': 'کل واجب الادا کھاتہ',
      'Thank you for shopping with us! Please retain this receipt for returns/exchange.':
          'خریداری کا شکریہ! واپسی یا تبدیلی کے لیے یہ رسید اپنے پاس رکھیں۔',
      'Invoice Preview': 'انوائس کا پیش منظر',
      'Complete (New Sale)': 'مکمل (نئی سیل)',
      'Done': 'مکمل',
      'Print': 'پرنٹ',
      'WhatsApp': 'واٹس ایپ',
      'Note: Report expiries with original bill.':
          'نوٹ: ایکسپائری کی اطلاع 6 ماہ قبل مع اصل بل نمبر کیساتھ دیں۔',

      // Setup & Settings
      'Back': 'واپس',
      'Continue to Next Step': 'اگلا مرحلہ',
      'Complete Installation & Launch': 'انسٹالیشن مکمل کریں اور چلائیں',
      'Primary Language': 'بنیادی زبان (Primary Language)',
      'When unchecked, only primary language is shown across the app':
          'غیر فعال ہونے پر، پوری ایپ صرف بنیادی زبان میں دکھائی دے گی',
      'Secondary Language is only available when Primary Language is English':
          'ثانوی زبان کا آپشن صرف اس وقت فعال ہوتا ہے جب بنیادی زبان انگریزی ہو',
      'Business / Store Name *': 'کاروبار / اسٹور کا نام *',
      'Branch / Outlet': 'برانچ یا آؤٹ لیٹ کا نام',
      'Official Currency *': 'سرکاری کرنسی *',
      'Regional Time Zone *': 'علاقائی ٹائم زون *',
      'Language for Totals & Invoices *':
          'رقم کی لفظی زبان (انوائس اور رسید) *',
      'Contact Email': 'رابطہ ای میل',
      'Contact Phone': 'رابطہ فون نمبر',
      'Physical Address': 'کاروبار کا پتہ',
      'Receipt Footer Note': 'رسید کا نچلا نوٹ',
      'Verifying security credentials...': 'سیکورٹی تصدیق جاری ہے...',
      'Initializing POS Engine & Data Cache...':
          'ڈیٹا بیس اور ٹرمینل کیشے لوڈ ہو رہا ہے...',
      'Access Granted! Launching Smart POS...':
          'خوش آمدید! رسائی منظور ہو گئی...',
      'Configure Modules': 'ماڈیول سیٹنگز',
      'Open Full Page': 'مکمل فل پیج پر کھولیں',
      'Copy Statement': 'کھاتہ کاپی کریں',
      'Send WhatsApp Reminder': 'واٹس ایپ میسج',
      'Official Financial Ledger Book': 'سرکاری مالیاتی کھاتہ رجسٹر',
      'Today': 'آج کا کھاتہ',
      'This Month': 'موجودہ مہینہ',
      'Last 30 Days': 'گزشتہ 30 دن',
      'All Time': 'مکمل ریکارڈ',
      'Customer Due Balance': 'واجب الادا رقم',
      'Supplier Payable': 'واجب الادا ادائیگی',
      'Account Completely Cleared (Zero Balance)': 'کھاتہ بالکل بے باق ہے',
      'All invoices and payments are fully reconciled.':
          'تمام بل اور وصولیاں برابر ہیں، کوئی رقم واجب الادا نہیں۔',
      'Outstanding amount owed by customer.':
          'یہ رقم گاہک کے ذمہ واجب الادا ہے، فوری وصولی کریں۔',
      'Outstanding amount owed to supplier.': 'یہ رقم سپلائر کو ادا کرنی ہے۔',
      'Advance Credit Balance': 'پیشگی رقم جمع ہے',
      'Party has advance balance on account.':
          'پارٹی کے پاس پیشگی رقم جمع ہے۔ آئندہ خریداری پر ایڈجسٹ ہوگی۔',
      'Send Token': 'ٹوکن جاری کریں',
      'No Products in Catalog Yet': 'کیٹلاگ میں کوئی پروڈکٹ موجود نہیں',
      'No products in catalog yet': 'کیٹلاگ میں ابھی کوئی پروڈکٹ موجود نہیں ہے',
      'Add products with selling price and initial stock to start billing immediately!':
          'فوری بلنگ شروع کرنے کے لیے پروڈکٹ اور اسٹاک شامل کریں!',
      'Add First Product': 'پہلی پروڈکٹ شامل کریں',
      '+ Add First Product': 'پہلی پروڈکٹ شامل کریں',
      '+ Receive Payment': 'رقم وصول کریں',
      '+ Pay Supplier': 'سپلائر کو ادائیگی',
      'Customer': 'گاہک',
      'Supplier': 'سپلائر',
      'Opening Balance': 'سابقہ بقایا',
      'Total Billed / Debit (Dr)': 'بنام کل مال (Dr)',
      'Total Paid / Credit (Cr)': 'جمع کل وصولیاں (Cr)',
      'TRANSACTIONS': 'تفصیل کھاتہ لین دین',
      'Thank you for your business!': 'کاروبار کا شکریہ!',
      'Due': 'واجب الادا',
      'Cleared': 'بے باق',
      'Quick Stock In': 'سٹاک شامل کریں',
      'Quantity to Add': 'شامل کرنے والی تعداد',
      'Purchase Cost per Unit': 'فی یونٹ خریداری قیمت',
      'Add Stock': 'سٹاک شامل کریں',
      'Stock In / Purchase': 'خریداری و اسٹاک انٹری',
      'Supplier (Optional)': 'سپلائر (اختیاری)',
      'Product Name': 'پروڈکٹ کا نام',
      'Selling Price': 'فروخت کی قیمت',
      'Opening Stock (Units)': 'ابتدائی سٹاک',
      'Physical Note Counter': 'کرنسی نوٹ کاؤنٹر',
      'Test Connection': 'کنکشن چیک کریں',
      'Save Module Settings': 'محفوظ کریں',
      'Operational & Inventory Features': 'آپریشنل و انوینٹری فیچرز',
      '1. POS COUNTER & SALE CONTROLS': 'کاؤنٹر سیلز پر کنٹرول',
      'Allow Altering Unit Prices at Counter':
          'سیلنگ پرائس تبدیل کرنے کا اختیار',
      'Allow Giving Discounts': 'ڈسکاؤنٹ دینے کا اختیار',
      'Allow Voiding & Deleting Completed Sales': 'بل ڈیلیٹ یا کینسل کرنا',
      '2. PROFIT & FINANCIAL CONFIDENTIALITY': 'خریداری قیمت اور منافع کا تحفظ',
      'View Purchase / Cost Price & Profit Margins':
          'خریداری ریٹ اور نفع دیکھنا',
      'Authorize Sales Returns & Cash Refunds': 'سیلز واپسی اور کیش ریفنڈ',
      'Access Customer Khata & Credit Ledgers': 'کسٹمر ادھار کھاتہ',
      '3. BACK-OFFICE & SYSTEM POWERS': 'بیک آفس اور سسٹم کنٹرول',
      'Inventory Stock Transfers & Adjustments': 'اسٹاک ٹرانسفر اور آڈٹ',
      'View Sales, Tax & Profit/Loss Reports': 'رپورٹس اور منافع دیکھنا',
      'Access Store Settings & Configurations': 'سسٹم سیٹنگز',
      'Manage Other Users & Staff Permissions': 'دیگر اسٹاف کے اختیارات',
      'PAYMENT CURRENCY': 'ادائیگی کی کرنسی',
      'Total Sales': 'کل فروخت',
      'Total Sales Revenue': 'کل ریونیو و آمدن',
      'Net': 'خالص منافع',
      'Invoice due': 'واجب الادا کسٹمر بلز',
      'Total Sell Return': 'سیلز واپسی (ریٹرن)',
      'Total purchase': 'کل خریداری',
      'Total Purchases': 'کل سپلائر خریداری',
      'Purchase due': 'واجب الادا سپلائر رقم',
      'Total Purchase Return': 'پرچیز واپسی (ریٹرن)',
      'Expense': 'دکان کے اخراجات',
      'Welcome': 'خوش آمدید',
      'This Quarter': 'موجودہ سہ ماہی',
      'This Year': 'موجودہ سال',
      'Pending Sales Orders': 'زیر التواء سیلز آرڈرز',
      'No pending sales orders awaiting invoicing.':
          'کوئی زیر التواء سیلز آرڈر موجود نہیں۔',
      'Pending Purchase Orders': 'زیر التواء خریداری آرڈرز',
      'No pending supplier purchase orders.':
          'سپلائر کا کوئی زیر التواء آرڈر موجود نہیں۔',
      'Sales Last 30 Days': 'گزشتہ 30 دنوں کی سیلز',
      'Daily sales turnover (Sales & Revenue Velocity)':
          'یومیہ سیلز ٹرن اوور و آمدن',
      'Payment Breakdown': 'ادائیگیوں کا تناسب',
      'Volume by tender method': 'ادائیگی بمطابق طریقہ کار',
      'No Sales': 'کوئی سیلز نہیں',
      'Total': 'کل',
      'Complete POS sales to see payment breakdown.':
          'سیلز مکمل ہونے پر یہاں ادائیگیوں کا تناسب نظر آئے گا۔',
      'Inventory Reorder & Low Stock Alerts': 'کم اسٹاک الرٹس',
      'All inventory items are currently at healthy stock levels.':
          'تمام آئٹمز مطلوبہ مقدار میں موجود ہیں۔',
      'Create Purchase Order': 'نیا پرچیز آرڈر بنائیں',
      'Manage': 'تفصیل',
      'Receive': 'وصول کریں',
      'Revenue': 'آمدن',
      'Orders': 'آرڈرز',
      'POWER SHORTCUTS': 'فوری شارٹ کٹس',
      'Register': 'کیش رجسٹر',
      'New Product': 'نیا پروڈکٹ',
      'Sales List': 'سیلز لسٹ',
      'Refresh Data': 'ریفریش ڈیٹا',
      'Cash Register': 'کیش رجسٹر',
      'Stock Audit': 'اسٹاک آڈٹ',
      'Sales Orders': 'سیلز آرڈرز',
      'Purchase Orders': 'پرچیز آرڈرز',
      'Workstation Sign In': 'ورک اسٹیشن لاگ ان',
      'Authenticate to open register & billing terminal':
          'بلنگ اور کیش کاؤنٹر شروع کرنے کے لیے لاگ ان کریں',
      'Username or Operator ID': 'یوزر نام یا آپریٹر آئی ڈی',
      'Password': 'پاس ورڈ',
      'Sign In to Terminal': 'سسٹم میں داخل ہوں',
      'Run Installation & Database Setup Wizard':
          'انسٹالیشن و ڈیٹا بیس وزرڈ چلائیں',
      'Setup Wizard & Database Management': 'سیٹ اپ وزرڈ اور ڈیٹا بیس سیٹنگز',
      'How would you like to launch the Setup Wizard?':
          'آپ سیٹ اپ وزرڈ کس طرح چلانا چاہتے ہیں؟',
      'Reconfigure Settings (Keep Data)':
          'سیٹنگز تبدیل کریں (ڈیٹا محفوظ رہے گا)',
      'Re-run setup wizard to change business info, languages, currency, or credentials without deleting existing data.':
          'کاروباری معلومات، زبان، کرنسی یا پاس ورڈ تبدیل کرنے کے لیے وزرڈ چلائیں (سابقہ ڈیٹا برقرار رہے گا)۔',
      'Reset to Fresh Installation': 'نیا فریش انسٹالیشن (تمام ڈیٹا صاف کریں)',
      'Wipe all local demo data, sales, and products to start with a completely fresh installation.':
          'تمام آزمائشی ڈیٹا، پروڈکٹس، سیلز اور یوزرز صاف کر کے بالکل نیا سیٹ اپ شروع کریں۔',
      'Confirm Database Reset': 'ڈیٹا بیس ری سیٹ کی تصدیق',
      'Are you sure you want to delete all local business data, products, and users to start a fresh setup? This cannot be undone.':
          'کیا آپ واقعی تمام مقامی ڈیٹا، پروڈکٹس اور یوزرز کو صاف کر کے نیا سیٹ اپ شروع کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔',
      'Reset & Start Setup': 'ڈیٹا صاف کریں اور سیٹ اپ شروع کریں',
      'Launch Setup Wizard': 'سیٹ اپ وزرڈ کھولیں',
      'Location': 'برانچ / مقام',
      'General Walk-in Shopper': 'عام واک اِن گاہک',
      'Search': 'تلاش',
      'Wholesale Mode': 'ہول سیل موڈ',
      'Till': 'کیش دراز',
      'Smart POS Engine • Multi-Industry': 'سمارٹ پی او ایس انجن',
      'in stock': 'اسٹاک میں موجود',
      'stk': 'عدد',
      'Enterprise Retail & Wholesale Workstation':
          'انٹرپرائز ریٹیل و ہول سیل ورک اسٹیشن',
      'Secure high-speed point of sale, inventory control, and transaction ledger.':
          'محفوظ، تیز رفتار پوائنٹ آف سیل، انوینٹری کنٹرول اور کھاتہ جات۔',
      'Fast Counter Billing & Barcode Scanning':
          'تیز رفتار کاؤنٹر بلنگ اور بارکوڈ اسکیننگ',
      'Multi-Cashier & Register Reconciliation':
          'ملٹی کیشیئر اور کیش رجسٹر تصفیہ',
      'Real-Time Inventory & Batch Tracking':
          'ریئل ٹائم انوینٹری اور اسٹاک ٹریکنگ',
      'Offline Database Engine Connected (SQLite FFI)':
          'آف لائن ڈیٹا بیس انجن منسلک ہے (SQLite FFI)',
      'Hybrid Engine Active (Local SQLite FFI + MySQL Cloud Sync)':
          'ہائبرڈ انجن فعال ہے (لوکل SQLite + کلاؤڈ سنک)',
      'e.g. admin, cashier1, or salesman': 'مثلاً ایڈمن، کیشیئر یا سیلز مین',
      'Enter account password': 'اکاؤنٹ کا پاس ورڈ درج کریں',
      'Please enter username': 'براہ کرم یوزر نام درج کریں',
      'Please enter password': 'براہ کرم پاس ورڈ درج کریں',
      'Workstation auto-locks after inactivity':
          'غیر سرگرمی پر ورک اسٹیشن خودکار لاک ہوجاتا ہے',
      'Smart POS Enterprise Edition • 256-bit Local AES Encryption':
          'سمارٹ پی او ایس انٹرپرائز ایڈیشن • 256-بٹ لوکل AES انکرپشن',
      'Scan barcode / search item / 2*SKU': 'بارکوڈ اسکین یا آئٹم تلاش کریں',
      'Shortcuts': 'شارٹ کٹس',
      'Pack': 'پیکٹ',
      'Bottle': 'بوتل',
      'Box': 'ڈبہ',
      'Bag': 'تھیلا',
      'Pc': 'عدد',
      'Shortcuts Help': 'شارٹ کٹ گائیڈ',
      'Cash Checkout': 'نقد بل',
      'Hold Bill': 'بل ہولڈ',
      'Partial / Split Pay': 'جزوی بل',
      'Reset Order': 'کینسل',
      'Shift Reconciliation': 'شفٹ حساب',
      'Undo Cart': 'واپس',
      'Search Focus': 'تلاش',
      'Smart POS • Touch Mode Active': 'ٹچ موڈ فعال',
      'POS Terminal Shortcuts': 'شارٹ کٹ کلیدیں',
      'Add Custom Item': 'متفرق آئٹم شامل کریں',
      'Quick Price & Stock Check': 'فوری قیمت و اسٹاک چیک',
      'Open Cash Drawer': 'کیش دراز کھولیں',
      'Wholesale Tier (Active)': 'ہول سیل ریٹ (فعال)',
      'Out of Stock': 'ختم ہو چکا ہے',
      'Unit': 'یونٹ',
      'Batch': 'بیچ',
      '1. License Lock': '1. لائسنس کی تنصیب',
      '2. Business & Presets': '2. کاروباری ماڈل و معلومات',
      '3. Topology & DB': '3. نیٹ ورک و ڈیٹا بیس',
      '4. Master Admin': '4. سپر ایڈمن اکاؤنٹ',
      'Step 1: Machine Hardware-Bound License Activation':
          'مرحلہ 1: ہارڈ ویئر باؤنڈ لائسنس کی تنصیب و تصدیق',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'ہر سسٹم (پرائمری سرور یا سیکنڈری لین ٹرمینل) کے لیے ایک مصدقہ لائسنس درکار ہے جو اس کمپیوٹر کے ہارڈ ویئر سے جڑا ہو۔',
      'Detected Host Machine Hardware ID (HWID):':
          'اس کمپیوٹر کا ہارڈ ویئر آئی ڈی (HWID):',
      'Copy HWID': 'ہارڈ ویئر آئی ڈی کاپی کریں',
      'Verify & Activate': 'تصدیق کریں اور فعال کریں',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'فوری 30 دن کی مفت ٹرائل شروع کریں (ہارڈ ویئر باؤنڈ)',
      'No internet required for activation':
          'ایکٹیویشن کے لیے انٹرنیٹ کی ضرورت نہیں ہے',
      'HARDWARE BOUND': 'ہارڈ ویئر سے محفوظ',
      'Step 2: Business Profile & Industry Workflows':
          'مرحلہ 2: کاروباری پروفائل اور انڈسٹری ورک فلو',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'کاروباری ماڈل منتخب کریں تاکہ بارکوڈ، آئی ایم ای آئی، سولر یا ریسٹورنٹ کے متعلقہ فیچرز فعال ہو سکیں۔',
      'Smart POS Activation Key': 'اسمارٹ پی او ایس ایکٹیویشن کی',
      'Business Logo': 'کاروباری لوگو',
      'Business / Store Name': 'دکان / کاروبار کا نام',
      'NTN / Tax ID': 'این ٹی این / ٹیکس شناختی نمبر',
      'Official Currency': 'سرکاری کرنسی',
      'Regional Time Zone': 'علاقائی ٹائم زون',
      'Local Embedded API Server Port': 'مقامی ایمبیڈڈ API سرور پورٹ',
      'Primary Server Local IP': 'مرکزی سرور کا لوکل IP ایڈریس',
      'API Port': 'اے پی آئی پورٹ',
      'Remote Cloud API URL': 'ریموٹ کلاؤڈ API یو آر ایل',
      'Branch ID': 'برانچ کوڈ / شناختی نمبر',
      'Cloud API Secret Key': 'کلاؤڈ API خفیہ کی',
      'Primary Database Host / IP': 'پرائمری ڈیٹا بیس ہوسٹ / IP',
      'Port': 'پورٹ',
      'Database Name': 'ڈیٹا بیس کا نام',
      'DB Username': 'ڈی بی صارف کا نام (Username)',
      'DB Password': 'ڈی بی پاسورڈ',
      'Admin Full Name': 'ایڈمن کا مکمل نام',
      'Master Username': 'ماسٹر یوزر نیم',
      'Email Address': 'ای میل ایڈریس',
      'Mobile Number': 'موبائل نمبر',
      'Master Password': 'ماسٹر پاسورڈ',
      'Confirm Master Password': 'ماسٹر پاسورڈ کی تصدیق کریں',
      'Upload Logo': 'لوگو اپ لوڈ کریں',
      'Change': 'تبدیل کریں',
      'Search 130+ Currencies': '130 سے زائد کرنسیاں تلاش کریں',
      'Search 80+ Timezones': '80 سے زائد ٹائم زونز تلاش کریں',
      'Main': 'بنیادی',
      'Enable Secondary Language (Optional)': 'ثانوی زبان فعال کریں (اختیاری)',
      'Select Business Industry Model (16 Supported Industries):':
          'کاروباری ماڈل منتخب کریں (16 معاونت شدہ شعبہ جات):',
      '1 Business Model At A Time': 'ایک وقت میں صرف ایک کاروباری ماڈل',
      'Pre-load Starter Products, Categories & Suppliers':
          'ابتدائی نمونہ اشیاء، کیٹیگریز اور سپلائرز شامل کریں',
      'RECOMMENDED': 'تجویز کردہ',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'تجرباتی اشیاء، کیٹیگریز اور سپلائرز شامل کریں تاکہ سسٹم فوراً فروخت اور ٹیسٹنگ کے لیے تیار ہو۔',
      'ACTIVE EXCLUSIVE': 'فعال کاروباری ماڈل',
      'Step 3: Network Topology & Hybrid Database Engine':
          'مرحلہ 3: نیٹ ورک ٹوپولوجی اور ہائبرڈ ڈیٹا بیس انجن',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'منتخب کریں کہ یہ کمپیوٹر آپ کے اسٹور نیٹ ورک میں کس طرح کام کرے گا (مین سرور، لین کاؤنٹر، یا کلاؤڈ ہائبرڈ)۔',
      'Primary Server & Mobile REST API Server Configuration':
          'پرائمری سرور اور موبائل ریسٹ اے پی آئی کنفیگریشن',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'نیٹ ورک کے دیگر کاؤنٹرز اور موبائل ایپ اسی کمپیوٹر کے آئی پی سے منسلک ہوں گے۔',
      'Connect to Primary Server Machine:': 'مرکزی سرور کمپیوٹر سے منسلک ہوں:',
      'Cloud Sync Server Configuration:': 'کلاؤڈ سنک سرور کی ترتیبات:',
      'Primary Central Database Engine (Admin Choice)':
          'مرکزی ڈیٹا بیس انجن (ایڈمن کا انتخاب)',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'سینٹرل ڈیٹا بیس کے لیے MySQL یا PostgreSQL منتخب کریں۔ SQLite ہمیشہ لوکل محفوظ رہتی ہے اور سرور سے منسلک ہونے پر خودکار سنک ہو جاتی ہے۔',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'لارگان یا زیمپ میں ڈیفالٹ صارف root بغیر پاسورڈ ہوتا ہے (پاسورڈ خالی چھوڑیں)، یا smartpos استعمال کریں۔',
      'Clear for Laragon': 'لارگان کے لیے خالی کریں',
      'Offline-First Local SQLite Sync Guarantee':
          'آف لائن فرسٹ لوکل SQLite تحفظ',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'تمام سیلز پہلے مقامی کمپیوٹر پر محفوظ ہوتی ہیں۔ اگر مرکزی سرور یا انٹرنیٹ بند بھی ہو تو بھی کیشیئر بلنگ جاری رکھ سکتے ہیں۔',
      'Step 4: Super Admin Master Credentials':
          'مرحلہ 4: سپر ایڈمن ماسٹر لاگ ان کی تفصیلات',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'سسٹم کا بنیادی سپر ایڈمن اکاؤنٹ بنائیں۔ پاسورڈ انتہائی محفوظ ترین Argon2id ٹیکنالوجی سے اینکرپٹ ہوتے ہیں۔',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'سیکیورٹی شیلڈ فعال ہے: تمام پاسورڈز اور ڈیٹا جدید ترین Argon2id اور AES-256-GCM سے محفوظ ہیں۔',
      'Installation & Setup Completed!': 'تنصیب اور سسٹم سیٹ اپ مکمل ہو گیا!',
      'System installation and database configuration completed successfully.':
          'سسٹم کی تنصیب اور ڈیٹا بیس کنفیگریشن کامیابی سے مکمل ہو چکی ہے۔',
      'Store / Business Name': 'اسٹور / کاروبار کا نام',
      'Industry Profile': 'کاروباری شعبہ و پروفائل',
      'Database Engine': 'ڈیٹا بیس انجن',
      'Commercial Catalog': 'تجارتی کیٹلاگ',
      'Master Admin Username': 'ماسٹر ایڈمن یوزر نیم',
      'Starter products, categories & suppliers pre-loaded':
          'ابتدائی اشیاء، کیٹیگریز اور سپلائرز شامل کر دیے گئے ہیں',
      'Clean blank database initialized': 'خالی ڈیٹا بیس تیار کیا گیا ہے',
      'Direct Login Bypassed for Security':
          'سیکیورٹی وجوہات کے باعث براہ راست لاگ ان بائی پاس کیا گیا',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'سرکاری لاگ ان اسکرین پر جانے کے لیے نیچے کلک کریں اور اپنے نئے ایڈمن اکاؤنٹ سے لاگ ان کریں۔',
      'Proceed to Login Screen': 'لاگ ان اسکرین پر جائیں',
      'Master Admin username cannot be empty.':
          'ماسٹر ایڈمن کا یوزر نیم خالی نہیں ہو سکتا۔',
      'Passwords do not match. Please re-enter.':
          'پاسورڈز مماثل نہیں ہیں۔ براہ کرم دوبارہ درج کریں۔',
      'Please enter Business / Store Name.':
          'براہ کرم دکان یا کاروبار کا نام درج کریں۔',
      'Please select at least one Business Industry Preset.':
          'براہ کرم کم از کم ایک کاروباری ماڈل منتخب کریں۔',
      'Please provide Primary Server IP for LAN terminal mode.':
          'لین ٹرمینل موڈ کے لیے مرکزی سرور کا IP ایڈریس درج کریں۔',
      'A verified License Key or Active Free Trial is required to proceed.':
          'آگے بڑھنے کے لیے مصدقہ لائسنس کی یا فعال فری ٹرائل درکار ہے۔',
      'MySQL Connection Notice': 'MySQL کنکشن کی اطلاع',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'اسمارٹ پی او ایس میں تیز رفتار ایمبیڈڈ SQLite شامل ہے جو بغیر کسی سیٹ اپ کے آف لائن کام کرتی ہے۔\n\nکیا آپ اسٹینڈ الون SQLite موڈ پر شروع کرنا چاہتے ہیں؟',
      'Back to Settings': 'سیٹنگز پر واپس جائیں',
      'Switch to SQLite & Launch POS': 'SQLite پر سوئچ کریں اور شروع کریں',
      'Installation Error': 'تنصیب میں خرابی',
      'Close': 'بند کریں',
      'Cheque Management': 'چیک مینجمنٹ',
      'Turnstile Check-In': 'ٹرن اسٹائل چیک ان (کارڈ سکین)',
      'Live KDS Screen': 'لائیو کچن ڈسپلے اسکرین (KDS)',
      'Cooking': 'تیار ہو رہا ہے',
      'Ready': 'تیار ہے',
      'Served': 'پیش کر دیا گیا',
      'REPAIR & SERVICE INTAKE VOUCHER': 'جاب شیٹ و رسید مرمت',
      'Terms & Conditions of Service': 'قوانین و شرائط برائے خدمات',
      'Credit Limit': 'حد قرضہ',
      'Period': 'مدت',
      'Custom Range': 'تاریخ منتخب کریں',
      'No transactions or invoices found for the selected period.':
          'اس منتخب مدت میں کوئی لین دین یا بل ریکارڈ نہیں ہے۔',
      'Record Payment': 'ادائیگی یا وصولی درج کریں',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER': 'کھاتہ رجسٹر مکمل تفصیلات',
      'DATE & TIME': 'تاریخ و وقت',
      'TYPE': 'قسم',
      'NARRATION & DETAILS': 'تفصیل و کیفیت',
      'DEBIT (Dr)': 'بنام (Dr)',
      'CREDIT (Cr)': 'جمع (Cr)',
      'RUNNING BAL': 'بقیہ کھاتہ',
      'GRAND TOTALS': 'کل میزان کھاتہ',
      'PAYMENT': 'وصولی / ادائیگی',
      'RETURN': 'واپسی',
      'PURCHASE': 'خریداری',
      'INVOICE': 'بل / انوائس',
      'OPENING': 'سابقہ بقایا',
      'Save Modules': 'ماڈیولز محفوظ کریں',
      'Commercial SaaS Tier Presets': 'تجارتی سبسکرپشن پیکجز',
      'Quick Presets': 'فوری پری سیٹ',
      'Minimalist Core Only': 'سادہ بلنگ',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'آن لائن و آف لائن ڈیٹا سنک آرکیٹیکچر',
      'Save Settings': 'سیٹنگز محفوظ کریں',
      'Sync Now': 'ابھی سنک کریں',
      '1. Deployment & Sync Mode': 'آپریٹنگ موڈ منتخب کریں',
      'Offline Only': 'صرف آف لائن لوکل SQLite',
      'Both Online & Offline - Hybrid Sync':
          'آن لائن اور آف لائن دونوں - ہائبرڈ سنک',
    },

    // Farsi (فارسی)
    'fa': {
      // Navigation
      'Dashboard': 'داشبورد اصلی',
      'POS Terminal': 'ترمینال فروش (صندوق)',
      'Products': 'محصولات و موجودی',
      'Stock Transfers': 'انتقال کالا و انبار',
      'Stock Adjustments': 'تعدیل و کسری موجودی',
      'Sales': 'فروش و صورتحساب',
      'Purchases': 'خرید و ورود کالا',
      'Expenses': 'هزینه‌ها و تنخواه',
      'Contacts': 'مشتریان و تامین‌کنندگان',
      'Contacts & Khata': 'مشتریان، تامین‌کنندگان و حساب‌ها',
      'User Management': 'کاربران و اختیارات',
      'Reports': 'گزارش‌ها و تحلیل مالی',
      'SMS & WhatsApp Alerts': 'اعلان‌ها و پیامک',
      'Settings': 'تنظیمات و پیکربندی',
      'Business Settings': 'اطلاعات کسب و کار',
      'Payment Accounts': 'بانک و نقدینگی',
      'Annual Fiscal Closing': 'بستن حساب سال مالی',
      'Cloud & MySQL Sync': 'همگام‌سازی ابری و دیتابیس',
      'Modular Features': 'ماژول‌های انتخابی',
      'Specialized Industry Modules': 'ماژول‌های تخصصی صنف',
      'List Products': 'فهرست محصولات',
      'Add Product': 'افزودن محصول جدید',
      'Print Labels': 'چاپ بارکد و لیبل',
      'Variations': 'تنوع کالا',
      'Import Products': 'ورود محصولات از اکسل',
      'Price Groups': 'گروه‌های قیمت',
      'Units': 'واحدهای سنجش',
      'Categories': 'دسته‌بندی‌ها',
      'Brands': 'برندها',
      'Warranties': 'گارانتی‌ها',
      'List Transfers': 'فهرست انتقالات',
      'Add Transfer': 'ثبت انتقال جدید',
      'Stock Adjustment': 'تعدیل موجودی',
      'Adjustments List': 'فهرست تعدیلات',
      'Add Adjustment': 'ثبت تعدیل جدید',
      'All Sales': 'همه فروش‌ها',
      'List POS': 'فاکتورهای صندوق',
      'Sales Return': 'مرجوعی فروش',
      'Purchases List': 'فهرست خریدها',
      'Add Purchase': 'ثبت خرید جدید',
      'Purchase Return': 'مرجوعی خرید',
      'List Expenses': 'فهرست هزینه‌ها',
      'Add Expense': 'ثبت هزینه جدید',
      'Customers': 'مشتریان',
      'Suppliers': 'تامین‌کنندگان',
      'Customer Groups': 'گروه‌های مشتری',
      'Users': 'کاربران',
      'Roles & Permissions': 'نقش‌ها و دسترسی‌ها',
      'Profit / Loss Report': 'گزارش سود و زیان',
      'Purchase & Sale': 'خرید و فروش',
      'Tax Report': 'گزارش مالیات',
      'Contact Dues': 'بدهی اشخاص',
      'Stock & Expiry Audit': 'حسابرسی انبار و انقضا',
      'Trending Products': 'کالاهای پرفروش',

      // POS Screen
      'PRODUCT': 'کالا / خدمت',
      'QUANTITY': 'تعداد / مقدار',
      'PRICE INC. TAX': 'قیمت با مالیات',
      'SUBTOTAL': 'جمع ردیف',
      'ITEMS': 'تعداد اقلام',
      'DISCOUNT': 'تخفیف',
      'ORDER TAX': 'مالیات',
      'SHIPPING': 'هزینه حمل',
      'TOTAL PAYABLE': 'مبلغ کل پرداختی',
      'No products in cart': 'سبد خرید خالی است',
      'Scan barcode or select products on the right':
          'بارکد را اسکن کنید یا از فهرست سمت راست انتخاب نمایید',
      'Cart is empty! Add products first':
          'سبد خرید خالی است! لطفاً ابتدا کالاها را به فاکتور اضافه کنید.',
      'Cancel': 'انصراف',
      'Draft': 'پیش‌نویس',
      'Quotation': 'پیش‌فاکتور',
      'Suspend': 'معلق کردن',
      'Credit Sale': 'فروش نسیه',
      'Recent Sales': 'فروش‌های اخیر',
      'Card': 'کارت‌خوان',
      'Multiple Pay': 'پرداخت ترکیبی',
      'Cash': 'نقد',
      'Retail Mode': 'حالت خرده‌فروشی',
      'Custom Item': 'آیتم دلخواه',
      'Undo': 'بازگردانی',
      'Redo': 'تکرار',
      'Multi-Unit & Decimal Scale Enabled':
          'پشتیبانی از واحدهای چندگانه و مقیاس اعشاری فعال است',
      'Category': 'دسته‌بندی',
      'Featured Products': 'کالاهای منتخب',
      'Grid': 'شبکه‌ای',
      'List': 'فهرست',
      'Search product / barcode / 2*SKU': 'جستجوی کالا / بارکد / کد کالا',
      'No products found in catalog': 'هیچ کالایی در انبار یافت نشد',
      'Walk-in Customer': 'مشتری حضوری',
      'Reset to Walk-in Customer': 'بازنشانی به مشتری حضوری',

      // Payment & Dialogs
      'Card Payment (Debit / Credit Card)': 'پرداخت با کارت بانکی',
      'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.':
          'سیستم در حالت آفلاین است. کارت را روی دستگاه کارت‌خوان بکشید و شماره پیگیری را وارد نمایید.',
      'Bank Machine Slip # / Auth Code:*':
          'شماره پیگیری / کد رهگیری کارت‌خوان:*',
      'Card Network:': 'نوع کارت:',
      'Complete Card Payment': 'تکمیل پرداخت با کارت',
      'Credit Sale Not Allowed for Walk-in Customer':
          'فروش نسیه به مشتری گذری مجاز نمی‌باشد',
      'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.':
          'مشتریان گذری فاقد حساب دفتری هستند. فروش نسیه نیاز به انتخاب مشتری ثبت‌شده دارد.',
      'Select Customer': 'انتخاب حساب مشتری',
      'Adjust Weight': 'تنظیم وزن',
      'Adjust Volume': 'تنظیم حجم',
      'Adjust Measurement': 'تنظیم متراژ',
      'Adjust Quantity': 'تنظیم تعداد',
      'Weight Scale': 'مقیاس وزن و ترازو',
      'Liquid Volume': 'حجم مایعات (لیتر)',
      'Measurement / Fabric': 'متراژ پارچه و لوله',
      'Count / Discrete Item': 'شمارش و اقلام عددی',
      'Unit of Measure': 'واحد سنجش',
      'Change Active Selling Unit': 'تغییر واحد فروش',

      // Receipts & Invoices
      'INVOICE NO:': 'شماره فاکتور:',
      'DATE & TIME:': 'تاریخ و زمان:',
      'CUSTOMER:': 'مشتری:',
      'PAY METHOD:': 'روش پرداخت:',
      'AMOUNT PAID': 'مبلغ پرداختی',
      'CHANGE DUE': 'باقیمانده',
      'PREVIOUS BALANCE': 'مانده قبلی',
      'CURRENT INVOICE': 'فاکتور جاری',
      'RECEIVED TODAY': 'دریافتی امروز',
      'NET CLOSING KHATA': 'مانده نهایی حساب',
      'Thank you for shopping with us! Please retain this receipt for returns/exchange.':
          'از خرید شما متشکریم! لطفاً این فاکتور را برای پیگیری‌های بعدی نگهداری فرمایید.',
      'Invoice Preview': 'پیش‌نمایش فاکتور',
      'Complete (New Sale)': 'تکمیل (فروش جدید)',
      'Done': 'انجام شد',
      'Print': 'چاپ',
      'WhatsApp': 'واتس‌اپ',
      'Note: Report expiries with original bill.':
          'توجه: گزارش انقضا ۶ ماه قبل همراه با اصل فاکتور الزامی است.',

      // Setup & Settings
      'Back': 'بازگشت',
      'Continue to Next Step': 'ادامه به مرحله بعد',
      'Complete Installation & Launch': 'تکمیل نصب و راه‌اندازی',
      'Primary Language': 'زبان اصلی (Primary Language)',
      'When unchecked, only primary language is shown across the app':
          'در صورت غیرفعال بودن، تمام نرم‌افزار صرفاً به زبان اصلی نمایش داده خواهد شد',
      'Secondary Language is only available when Primary Language is English':
          'گزینه زبان دوم صرفاً زمانی فعال می‌شود که زبان اصلی سیستم انگلیسی باشد',
      'Business / Store Name *': 'نام فروشگاه / کسب و کار *',
      'Branch / Outlet': 'نام شعبه',
      'Official Currency *': 'واحد پول رسمی *',
      'Regional Time Zone *': 'منطقه زمانی *',
      'Language for Totals & Invoices *':
          'زبان مبالغ به حروف (در فاکتور و رسید) *',
      'Contact Email': 'ایمیل تماس',
      'Contact Phone': 'شماره تماس',
      'Physical Address': 'آدرس فیزیکی',
      'Receipt Footer Note': 'یادداشت پایین رسید',
      'Verifying security credentials...': 'در حال بررسی مشخصات امنیتی...',
      'Initializing POS Engine & Data Cache...':
          'در حال بارگذاری پایگاه داده و ترمینال...',
      'Access Granted! Launching Smart POS...':
          'دسترسی تأیید شد! در حال راه‌اندازی...',
      'Configure Modules': 'پیکربندی ماژول‌ها',
      'Open Full Page': 'باز کردن تمام صفحه',
      'Copy Statement': 'کپی صورتحساب',
      'Send WhatsApp Reminder': 'ارسال یادآوری واتساپ',
      'Official Financial Ledger Book': 'دفتر رسمی حسابداری و معین',
      'Today': 'امروز',
      'This Month': 'این ماه',
      'Last 30 Days': '۳۰ روز گذشته',
      'All Time': 'کل دوره',
      'Customer Due Balance': 'مانده بدهی مشتری',
      'Supplier Payable': 'بدهی به تامین‌کننده',
      'Account Completely Cleared (Zero Balance)':
          'حساب کاملاً تسویه است (مانده صفر)',
      'All invoices and payments are fully reconciled.':
          'تمامی فاکتورها و دریافت‌ها تطبیق یافته و مانده‌ای وجود ندارد.',
      'Outstanding amount owed by customer.':
          'این مبلغ نزد مشتری بدهکار است و باید پیگیری شود.',
      'Outstanding amount owed to supplier.':
          'این مبلغ باید به تامین‌کننده پرداخت گردد.',
      'Advance Credit Balance': 'مبلغ بستانکار / پیش‌پرداخت',
      'Party has advance balance on account.':
          'مشتری دارای پیش‌پرداخت نزد فروشگاه است.',
      'Send Token': 'ارسال نوبت',
      'No Products in Catalog Yet': 'هنوز محصولی ثبت نشده است',
      'No products in catalog yet': 'هیچ کالایی در کاتالوگ یافت نشد',
      'Add products with selling price and initial stock to start billing immediately!':
          'جهت شروع صدور فاکتور، کالاها و موجودی اولیه را ثبت فرمایید!',
      '+ Add First Product': '+ افزودن اولین محصول',
      '+ Receive Payment': '+ دریافت وجه',
      '+ Pay Supplier': '+ پرداخت به تامین‌کننده',
      'Customer': 'مشتری',
      'Supplier': 'تامین‌کننده',
      'Opening Balance': 'مانده اول دوره',
      'Total Billed / Debit (Dr)': 'جمع بدهکار (Dr)',
      'Total Paid / Credit (Cr)': 'جمع بستانکار (Cr)',
      'TRANSACTIONS': 'گردش حساب و تراکنش‌ها',
      'Thank you for your business!': 'با تشکر از اعتماد و خرید شما!',
      'Due': 'بدهکار',
      'Cleared': 'تسویه',
      'Quick Stock In': 'ورود سریع موجودی',
      'Quantity to Add': 'مقدار جهت افزودن',
      'Purchase Cost per Unit': 'قیمت خرید هر واحد',
      'Add Stock': 'افزودن موجودی',
      'Stock In / Purchase': 'خرید و ورود کالا',
      'Supplier (Optional)': 'تامین‌کننده (اختیاری)',
      'Product Name': 'نام کالا',
      'Selling Price': 'قیمت فروش',
      'Opening Stock (Units)': 'موجودی اولیه',
      'Physical Note Counter': 'شمارش اسکناس',
      'Test Connection': 'آزمایش ارتباط',
      'Save Module Settings': 'ذخیره تنظیمات ماژول‌ها',
      'Operational & Inventory Features': 'ویژگی‌های عملیاتی و انبارداری',
      '1. POS COUNTER & SALE CONTROLS': 'کنترل‌های صندوق و فروش',
      'Allow Altering Unit Prices at Counter': 'مجوز تغییر قیمت کالا در صندوق',
      'Allow Giving Discounts': 'مجوز اعمال تخفیف',
      'Allow Voiding & Deleting Completed Sales':
          'مجوز ابطال و حذف فاکتورهای ثبت شده',
      '2. PROFIT & FINANCIAL CONFIDENTIALITY':
          'حفاظت از قیمت خرید و سود فروشگاه',
      'View Purchase / Cost Price & Profit Margins':
          'مشاهده قیمت خرید و حاشیه سود',
      'Authorize Sales Returns & Cash Refunds':
          'تایید مرجوعی فروش و بازپرداخت نقدی',
      'Access Customer Khata & Credit Ledgers':
          'دسترسی به حساب دفتری و بدهی مشتریان',
      '3. BACK-OFFICE & SYSTEM POWERS': 'اختیارات مدیریتی و سیستم',
      'Inventory Stock Transfers & Adjustments': 'انتقال و تعدیل موجودی انبار',
      'View Sales, Tax & Profit/Loss Reports':
          'مشاهده گزارش‌های مالی و سود و زیان',
      'Access Store Settings & Configurations': 'دسترسی به تنظیمات فروشگاه',
      'Manage Other Users & Staff Permissions':
          'مدیریت کاربران و تعیین اختیارات',
      'PAYMENT CURRENCY': 'واحد پول پرداخت',
      '1. License Lock': '۱. فعال‌سازی لایسنس',
      '2. Business & Presets': '۲. اطلاعات و نوع کسب و کار',
      '3. Topology & DB': '۳. شبکه و پایگاه داده',
      '4. Master Admin': '۴. حساب کاربری مدیر ارشد',
      'Step 1: Machine Hardware-Bound License Activation':
          'مرحله ۱: فعال‌سازی مجوز متصل به سخت‌افزار',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'هر دستگاه نیازمند مجوزی معتبر و متصل به سخت‌افزار همان سیستم است.',
      'Detected Host Machine Hardware ID (HWID):':
          'شناسه سخت‌افزاری شناسایی شده (HWID):',
      'Copy HWID': 'کپی شناسه سخت‌افزار',
      'Verify & Activate': 'بررسی و فعال‌سازی',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'فعال‌سازی آزمایشی رایگان ۳۰ روزه',
      'No internet required for activation': 'فعال‌سازی بدون نیاز به اینترنت',
      'HARDWARE BOUND': 'قفل سخت‌افزاری',
      'Step 2: Business Profile & Industry Workflows':
          'مرحله ۲: پروفایل کسب و کار و گردش کار تخصصی',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'مدل کسب و کار خود را انتخاب کنید تا امکانات اختصاصی فعال شوند.',
      'Smart POS Activation Key': 'کلید فعال‌سازی اسمارت پوز',
      'Business Logo': 'لوگوی کسب و کار',
      'Business / Store Name': 'نام فروشگاه / کسب و کار',
      'NTN / Tax ID': 'شناسه مالیاتی',
      'Official Currency': 'واحد پول رسمی',
      'Regional Time Zone': 'منطقه زمانی',
      'Local Embedded API Server Port': 'پورت سرور محلی API',
      'Primary Server Local IP': 'آی‌پی محلی سرور اصلی',
      'API Port': 'پورت API',
      'Remote Cloud API URL': 'آدرس API ابری',
      'Branch ID': 'کد شعبه',
      'Cloud API Secret Key': 'کلید مخفی API ابری',
      'Primary Database Host / IP': 'میزبان / آی‌پی پایگاه داده اصلی',
      'Port': 'پورت',
      'Database Name': 'نام پایگاه داده',
      'DB Username': 'نام کاربری دیتابیس',
      'DB Password': 'رمز عبور دیتابیس',
      'Admin Full Name': 'نام کامل مدیر سیستم',
      'Master Username': 'نام کاربری اصلی',
      'Email Address': 'آدرس ایمیل',
      'Mobile Number': 'شماره همراه',
      'Master Password': 'رمز عبور اصلی',
      'Confirm Master Password': 'تایید رمز عبور اصلی',
      'Upload Logo': 'بارگذاری لوگو',
      'Change': 'تغییر',
      'Search 130+ Currencies': 'جستجوی بیش از ۱۳۰ واحد پول',
      'Search 80+ Timezones': 'جستجوی مناطق زمانی',
      'Main': 'اصلی',
      'Enable Secondary Language (Optional)': 'فعال‌سازی زبان دوم (اختیاری)',
      'Select Business Industry Model (16 Supported Industries):':
          'انتخاب نوع کسب و کار (۱۶ صنعت پشتیبانی شده):',
      '1 Business Model At A Time': 'یک مدل در هر سیستم',
      'Pre-load Starter Products, Categories & Suppliers':
          'بارگذاری اقلام، دسته‌ها و تامین‌کنندگان نمونه',
      'RECOMMENDED': 'پیشنهادی',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'بارگذاری آزمایشی اقلام و تامین‌کنندگان برای آماده‌سازی فوری سیستم برای فروش و آزمایش.',
      'ACTIVE EXCLUSIVE': 'مدل فعال',
      'Step 3: Network Topology & Hybrid Database Engine':
          'مرحله ۳: توپولوژی شبکه و موتور داده ترکیبی',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'نحوه اتصال این سیستم در شبکه فروشگاه را مشخص کنید.',
      'Primary Server & Mobile REST API Server Configuration':
          'پیکربندی سرور اصلی و رابط موبایل',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'پایانه‌های فرعی و اپلیکیشن موبایل از طریق وای‌فای به این سیستم متصل می‌شوند.',
      'Connect to Primary Server Machine:': 'اتصال به سیستم سرور اصلی:',
      'Cloud Sync Server Configuration:': 'پیکربندی سرور همگام‌سازی ابری:',
      'Primary Central Database Engine (Admin Choice)':
          'موتور پایگاه داده مرکزی',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'پایگاه داده MySQL یا PostgreSQL را به عنوان سرور مرکزی انتخاب کنید. SQLite همیشه به صورت آفلاین فعال است.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'نکته: در Laragon یا XAMPP نام کاربری پیش‌فرض root بدون رمز عبور است.',
      'Clear for Laragon': 'پاک کردن برای لارگون',
      'Offline-First Local SQLite Sync Guarantee':
          'تضمین کارکرد آفلاین پایگاه داده لوکال',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'همه تراکنش‌ها ابتدا در SQLite محلی ثبت می‌شوند. در صورت قطع شبکه، فرآیند فروش بدون وقفه ادامه می‌یابد.',
      'Step 4: Super Admin Master Credentials':
          'مرحله ۴: مشخصات دسترسی مدیر کل',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'حساب کاربری مالک سیستم را تعریف کنید. رمزها با Argon2id به صورت رمزنگاری پیشرفته ذخیره می‌شوند.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'سپر امنیتی فعال: رمزها با Argon2id و AES-256-GCM محافظت می‌شوند.',
      'Installation & Setup Completed!': 'نصب و پیکربندی با موفقیت پایان یافت!',
      'System installation and database configuration completed successfully.':
          'نصب سیستم و پیکربندی پایگاه داده با موفقیت تکمیل شد.',
      'Store / Business Name': 'نام فروشگاه / کسب و کار',
      'Industry Profile': 'پروفایل صنعت',
      'Database Engine': 'موتور پایگاه داده',
      'Commercial Catalog': 'کاتالوگ تجاری',
      'Master Admin Username': 'نام کاربری مدیر ارشد',
      'Starter products, categories & suppliers pre-loaded':
          'کالاها، دسته‌ها و تامین‌کنندگان اولیه بارگذاری شدند',
      'Clean blank database initialized': 'پایگاه داده خالی راه‌اندازی شد',
      'Direct Login Bypassed for Security':
          'ورود مستقیم به دلایل امنیتی غیرفعال شد',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'برای ورود، دکمه زیر را زده و با مشخصات مدیر ارشد وارد شوید.',
      'Proceed to Login Screen': 'ورود به صفحه لاگین',
      'Master Admin username cannot be empty.':
          'نام کاربری مدیر ارشد نمی‌تواند خالی باشد.',
      'Passwords do not match. Please re-enter.':
          'رمزهای عبور یکسان نیستند. دوباره بررسی کنید.',
      'Please enter Business / Store Name.':
          'لطفاً نام فروشگاه یا کسب و کار را وارد کنید.',
      'Please select at least one Business Industry Preset.':
          'لطفاً حداقل یک مدل تجاری را انتخاب کنید.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'لطفاً آی‌پی سرور اصلی را برای حالت پایانه وارد کنید.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'جهت ادامه، کلید لایسنس تایید شده یا دوره آزمایشی فعال الزامی است.',
      'MySQL Connection Notice': 'اطلاعیه اتصال به MySQL',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'اسمارت پوز مجهز به پایگاه داده داخلی و سریع SQLite است که به صورت آفلاین بدون نیاز به تنظیمات کار می‌کند.\n\nآیا مایلید از حالت آفلاین SQLite استفاده کنید؟',
      'Back to Settings': 'بازگشت به تنظیمات',
      'Switch to SQLite & Launch POS': 'تغییر به SQLite و راه‌اندازی فروشگاه',
      'Installation Error': 'خطا در نصب',
      'Close': 'بستن',
      'Cheque Management': 'مدیریت چک‌ها',
      'Turnstile Check-In': 'ثبت ورود گیت و کارت',
      'Live KDS Screen': 'نمایشگر زنده آشپزخانه (KDS)',
      'Cooking': 'در حال پخت',
      'Ready': 'آماده تحویل',
      'Served': 'تحویل داده شد',
      'REPAIR & SERVICE INTAKE VOUCHER': 'قبض پذیرش تعمیرات و خدمات',
      'Terms & Conditions of Service': 'قوانین و شرایط خدمات',
      'Credit Limit': 'سقف اعتبار',
      'Period': 'دوره زمانی',
      'Custom Range': 'بازه انتخابی',
      'No transactions or invoices found for the selected period.':
          'هیچ تراکنش یا فاکتوری در این دوره یافت نشد.',
      'Record Payment': 'ثبت دریافت یا پرداخت',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER': 'دفتر معین رسمی و ریز تراکنش‌ها',
      'DATE & TIME': 'تاریخ و ساعت',
      'TYPE': 'نوع',
      'NARRATION & DETAILS': 'شرح سند و جزئیات',
      'DEBIT (Dr)': 'بدهکار (Dr)',
      'CREDIT (Cr)': 'بستانکار (Cr)',
      'RUNNING BAL': 'مانده حساب',
      'GRAND TOTALS': 'جمع کل حساب',
      'PAYMENT': 'دریافت / پرداخت',
      'RETURN': 'مرجوعی',
      'PURCHASE': 'خرید کالا',
      'INVOICE': 'فاکتور',
      'OPENING': 'مانده قبلی',
      'Save Modules': 'ذخیره ماژول‌ها',
      'Commercial SaaS Tier Presets': 'بسته‌های اشتراک تجاری',
      'Quick Presets': 'پیکربندی سریع',
      'Minimalist Core Only': 'فقط فروش ساده',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'معماری همگام‌سازی آفلاین و آنلاین',
      'Save Settings': 'ذخیره تنظیمات',
      'Sync Now': 'همگام‌سازی فوری',
      '1. Deployment & Sync Mode': 'انتخاب حالت استقرار و همگام‌سازی',
      'Offline Only': 'فقط آفلاین با SQLite',
      'Both Online & Offline - Hybrid Sync':
          'هم آنلاین و هم آفلاین - سنک هیبریدی',
    },

    // Arabic (العربية)
    'ar': {
      // Navigation
      'Dashboard': 'لوحة التحكم',
      'POS Terminal': 'نقطة البيع (الكاشير)',
      'Products': 'المنتجات والمخزون',
      'Stock Transfers': 'تحويل المخزون',
      'Stock Adjustments': 'تسوية المخزون',
      'Sales': 'المبيعات والفواتير',
      'Purchases': 'المشتريات والتوريد',
      'Expenses': 'المصروفات والسندات',
      'Contacts': 'جهات الاتصال',
      'Contacts & Khata': 'العملاء والموردون والحسابات',
      'User Management': 'إدارة المستخدمين والصلاحيات',
      'Reports': 'التقارير والتحليل المالي',
      'SMS & WhatsApp Alerts': 'إشعارات الرسائل والواتساب',
      'Settings': 'الإعدادات والتهيئة',
      'Business Settings': 'بيانات المؤسسة',
      'Payment Accounts': 'الحسابات البنكية والنقدية',
      'Annual Fiscal Closing': 'الإقفال السنوي للحسابات',
      'Cloud & MySQL Sync': 'المزامنة السحابية وقاعدة البيانات',
      'Modular Features': 'الميزات والوحدات',
      'Specialized Industry Modules': 'الأنظمة التخصصية',
      'List Products': 'قائمة المنتجات',
      'Add Product': 'إضافة منتج جديد',
      'Print Labels': 'طباعة الباركود والملصقات',
      'Variations': 'المتغيرات والأحجام',
      'Import Products': 'استيراد المنتجات',
      'Price Groups': 'مجموعات الأسعار',
      'Units': 'وحدات القياس',
      'Categories': 'التصنيفات',
      'Brands': 'العلامات التجارية',
      'Warranties': 'الضمانات',
      'List Transfers': 'قائمة التحويلات',
      'Add Transfer': 'إضافة تحويل مخزني',
      'Stock Adjustment': 'تسوية المخزون',
      'Adjustments List': 'قائمة التسويات',
      'Add Adjustment': 'تسوية جديدة',
      'All Sales': 'جميع المبيعات',
      'List POS': 'فواتير الكاشير',
      'Sales Return': 'مرتجع المبيعات',
      'Purchases List': 'قائمة المشتريات',
      'Add Purchase': 'فاتورة شراء جديدة',
      'Purchase Return': 'مرتجع المشتريات',
      'List Expenses': 'قائمة المصروفات',
      'Add Expense': 'إضافة مصروف جديد',
      'Customers': 'العملاء',
      'Suppliers': 'الموردون',
      'Customer Groups': 'مجموعات العملاء',
      'Users': 'المستخدمون',
      'Roles & Permissions': 'الأدوار والصلاحيات',
      'Profit / Loss Report': 'تقرير الأرباح والخسائر',
      'Purchase & Sale': 'المشتريات والمبيعات',
      'Tax Report': 'تقرير الضريبة',
      'Contact Dues': 'مستحقات الحسابات',
      'Stock & Expiry Audit': 'جرد المخزون والصلاحية',
      'Trending Products': 'المنتجات الأكثر مبيعاً',

      // POS Screen
      'PRODUCT': 'المنتج',
      'QUANTITY': 'الكمية',
      'PRICE INC. TAX': 'السعر شامل الضريبة',
      'SUBTOTAL': 'المجموع الفرعي',
      'ITEMS': 'عدد الأصناف',
      'DISCOUNT': 'الخصم',
      'ORDER TAX': 'الضريبة',
      'SHIPPING': 'الشحن',
      'TOTAL PAYABLE': 'الإجمالي المستحق',
      'No products in cart': 'سلة المشتريات فارغة',
      'Scan barcode or select products on the right':
          'امسح الباركود أو اختر المنتجات من القائمة',
      'Cart is empty! Add products first':
          'سلة المشتريات فارغة! يرجى إضافة المنتجات أولاً.',
      'Cancel': 'إلغاء',
      'Draft': 'مسودة',
      'Quotation': 'عرض أسعار',
      'Suspend': 'تعليق الفاتورة',
      'Credit Sale': 'بيع آجل (على الحساب)',
      'Recent Sales': 'المبيعات الأخيرة',
      'Card': 'بطاقة بنكية',
      'Multiple Pay': 'دفع متعدد',
      'Cash': 'نقداً',
      'Retail Mode': 'وضع التجزئة',
      'Custom Item': 'صنف مخصص',
      'Undo': 'تراجع',
      'Redo': 'إعادة',
      'Multi-Unit & Decimal Scale Enabled':
          'دعم الوحدات المتعددة وميزان الوزن مفعل',
      'Category': 'التصنيف',
      'Featured Products': 'منتجات مميزة',
      'Grid': 'شبكة',
      'List': 'قائمة',
      'Search product / barcode / 2*SKU': 'ابحث عن منتج / باركود',
      'No products found in catalog': 'لم يتم العثور على منتجات في المستودع',
      'Walk-in Customer': 'عميل نقدي عام',
      'Reset to Walk-in Customer': 'إعادة تعيين إلى عميل عام',

      // Payment & Dialogs
      'Card Payment (Debit / Credit Card)': 'الدفع بالبطاقة البنكية',
      'System is running offline. Swipe card on external bank EDC terminal and enter authorization code below.':
          'النظام في وضع عدم الاتصال. مرر البطاقة على جهاز الدفع وأدخل رقم الإيصال.',
      'Bank Machine Slip # / Auth Code:*':
          'رقم إيصال جهاز البنك / كود التفويض:*',
      'Card Network:': 'شبكة البطاقة:',
      'Complete Card Payment': 'إتمام الدفع بالبطاقة',
      'Credit Sale Not Allowed for Walk-in Customer':
          'البيع الآجل غير مسموح للعميل النقدي',
      'Walk-in cash customers do not have a credit ledger account. Credit sales require a registered customer.':
          'العميل النقدي ليس لديه حساب آجل. يلزم اختيار عميل مسجل لإجراء البيع بالآجل.',
      'Select Customer': 'اختر حساب العميل',
      'Adjust Weight': 'تعديل الوزن',
      'Adjust Volume': 'تعديل الحجم',
      'Adjust Measurement': 'تعديل المقاس والقياس',
      'Adjust Quantity': 'تعديل الكمية',
      'Weight Scale': 'وزن وميزان',
      'Liquid Volume': 'حجم السوائل (لتر)',
      'Measurement / Fabric': 'أمتار وأقمشة',
      'Count / Discrete Item': 'أصناف معدودة بالعدد',
      'Unit of Measure': 'وحدة القياس',
      'Change Active Selling Unit': 'تغيير وحدة البيع الحالية',

      // Receipts & Invoices
      'INVOICE NO:': 'رقم الفاتورة:',
      'DATE & TIME:': 'التاريخ والوقت:',
      'CUSTOMER:': 'العميل:',
      'PAY METHOD:': 'طريقة الدفع:',
      'AMOUNT PAID': 'المبلغ المدفوع',
      'CHANGE DUE': 'المبلغ المتبقي',
      'PREVIOUS BALANCE': 'الرصيد السابق',
      'CURRENT INVOICE': 'الفاتورة الحالية',
      'RECEIVED TODAY': 'المستلم اليوم',
      'NET CLOSING KHATA': 'الرصيد الإجمالي النهائي',
      'Thank you for shopping with us! Please retain this receipt for returns/exchange.':
          'شكراً لتسوقكم معنا! يرجى الاحتفاظ بهذه الفاتورة للاسترجاع أو الاستبدال.',
      'Invoice Preview': 'معاينة الفاتورة',
      'Complete (New Sale)': 'إتمام (فاتورة جديدة)',
      'Done': 'تم',
      'Print': 'طباعة',
      'WhatsApp': 'واتساب',
      'Note: Report expiries with original bill.':
          'ملاحظة: الإبلاغ عن انتهاء الصلاحية قبل 6 أشهر مع الفاتورة الأصلية.',

      // Setup & Settings
      'Back': 'رجوع',
      'Continue to Next Step': 'متابعة للخطوة التالية',
      'Complete Installation & Launch': 'إتمام التثبيت وتشغيل النظام',
      'Primary Language': 'اللغة الأساسية (Primary Language)',
      'When unchecked, only primary language is shown across the app':
          'عند عدم التحديد، ستظهر المنظومة بأكملها باللغة الأساسية فقط',
      'Secondary Language is only available when Primary Language is English':
          'خيار اللغة الثانوية متاح فقط عندما تكون اللغة الأساسية هي الإنجليزية',
      'Business / Store Name *': 'اسم المتجر / المؤسسة *',
      'Branch / Outlet': 'الفرع أو المنفذ',
      'Official Currency *': 'العملة الرسمية *',
      'Regional Time Zone *': 'المنطقة الزمنية *',
      'Language for Totals & Invoices *': 'لغة كتابة المبالغ بالحروف *',
      'Contact Email': 'البريد الإلكتروني',
      'Contact Phone': 'رقم الهاتف للتواصل',
      'Physical Address': 'العنوان الفعلي',
      'Receipt Footer Note': 'ملاحظة تذييل الفاتورة',
      'Verifying security credentials...': 'جاري التحقق من بيانات الأمان...',
      'Initializing POS Engine & Data Cache...':
          'جاري تحميل قاعدة البيانات والطرفية...',
      'Access Granted! Launching Smart POS...':
          'تمت الموافقة! جاري تشغيل نقطة البيع...',
      'Configure Modules': 'إعداد الوحدات',
      'Open Full Page': 'فتح بملء الشاشة',
      'Copy Statement': 'نسخ كشف الحساب',
      'Send WhatsApp Reminder': 'إرسال تذكير عبر واتساب',
      'Official Financial Ledger Book': 'دفتر الأستاذ المالي الرسمي',
      'Today': 'اليوم',
      'This Month': 'هذا الشهر',
      'Last 30 Days': 'آخر 30 يوماً',
      'All Time': 'كل السجلات',
      'Customer Due Balance': 'الرصيد المستحق على العميل',
      'Supplier Payable': 'الرصيد المستحق للمورد',
      'Account Completely Cleared (Zero Balance)':
          'الحساب خالص بالكامل (رصيد صفر)',
      'All invoices and payments are fully reconciled.':
          'جميع الفواتير والمقبوضات متطابقة تماماً.',
      'Outstanding amount owed by customer.':
          'هذا المبلغ مستحق على العميل للتحصيل الفوري.',
      'Outstanding amount owed to supplier.': 'هذا المبلغ مستحق السداد للمورد.',
      'Advance Credit Balance': 'رصيد دائن / دفعة مقدمة',
      'Party has advance balance on account.':
          'الطرف لديه رصيد دفع مقدم على الحساب.',
      'Send Token': 'إرسال الرمز',
      'No Products in Catalog Yet': 'لا توجد منتجات مسجلة حتى الآن',
      'No products in catalog yet': 'لا توجد سلع في الدليل حتى الآن',
      'Add products with selling price and initial stock to start billing immediately!':
          'أضف المنتجات مع الأسعار والمخزون لبدء إصدار الفواتير فوراً!',
      '+ Add First Product': '+ إضافة أول منتج',
      '+ Receive Payment': '+ استلام دفعة',
      '+ Pay Supplier': '+ دفع للمورد',
      'Customer': 'العميل',
      'Supplier': 'المورد',
      'Opening Balance': 'الرصيد الافتتاحي',
      'Total Billed / Debit (Dr)': 'إجمالي المدين (Dr)',
      'Total Paid / Credit (Cr)': 'إجمالي الدائن (Cr)',
      'TRANSACTIONS': 'كشف المعاملات والحركات',
      'Thank you for your business!': 'شكراً لتعاملكم معنا!',
      'Due': 'مستحق',
      'Cleared': 'خالص',
      'Quick Stock In': 'إدخال سريع للمخزون',
      'Quantity to Add': 'الكمية المراد إضافتها',
      'Purchase Cost per Unit': 'تكلفة الشراء للوحدة',
      'Add Stock': 'إضافة مخزون',
      'Stock In / Purchase': 'شراء وتوريد مخزون',
      'Supplier (Optional)': 'المورد (اختياري)',
      'Product Name': 'اسم المنتج',
      'Selling Price': 'سعر البيع',
      'Opening Stock (Units)': 'المخزون الافتتاحي',
      'Physical Note Counter': 'عداد الأوراق النقدية',
      'Test Connection': 'اختبار الاتصال',
      'Save Module Settings': 'حفظ إعدادات الوحدات',
      'Operational & Inventory Features': 'الخصائص التشغيلية والمخزنية',
      '1. POS COUNTER & SALE CONTROLS': 'صلاحيات نقطة البيع والكاشير',
      'Allow Altering Unit Prices at Counter':
          'السماح بتعديل سعر البيع عند الكاشير',
      'Allow Giving Discounts': 'السماح بمنح خصومات',
      'Allow Voiding & Deleting Completed Sales':
          'السماح بإلغاء وحذف الفواتير المسجلة',
      '2. PROFIT & FINANCIAL CONFIDENTIALITY':
          'حماية سعر الشراء وأرباح المؤسسة',
      'View Purchase / Cost Price & Profit Margins':
          'عرض سعر التكلفة وهوامش الربح',
      'Authorize Sales Returns & Cash Refunds':
          'اعتماد مرتجعات البيع واسترداد النقد',
      'Access Customer Khata & Credit Ledgers':
          'الاطلاع على حسابات العملاء والديون',
      '3. BACK-OFFICE & SYSTEM POWERS': 'صلاحيات الإدارة والنظام',
      'Inventory Stock Transfers & Adjustments': 'تحويلات وتسويات المخزون',
      'View Sales, Tax & Profit/Loss Reports':
          'عرض تقارير المبيعات والضرائب والأرباح',
      'Access Store Settings & Configurations': 'الوصول إلى إعدادات المتجر',
      'Manage Other Users & Staff Permissions':
          'إدارة الموظفين وتحديد الصلاحيات',
      'PAYMENT CURRENCY': 'عملة الدفع',
      '1. License Lock': '1. تفعيل الترخيص',
      '2. Business & Presets': '2. ملف النشاط التجاري',
      '3. Topology & DB': '3. الشبكة وقاعدة البيانات',
      '4. Master Admin': '4. حساب المشرف العام',
      'Step 1: Machine Hardware-Bound License Activation':
          'الخطوة 1: تفعيل ترخيص النظام المرتبط بالجهاز',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'يتطلب كل جهاز ترخيصاً معتمداً مرتبطاً بالمكونات المادية للجهاز.',
      'Detected Host Machine Hardware ID (HWID):':
          'معرف الجهاز المكتشف (HWID):',
      'Copy HWID': 'نسخ معرف الجهاز',
      'Verify & Activate': 'تحقق وتفعيل',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'تفعيل تجربة مجانية لمدة 30 يوماً',
      'No internet required for activation': 'لا يلزم اتصال بالإنترنت للتفعيل',
      'HARDWARE BOUND': 'مرتبط بالعتاد',
      'Step 2: Business Profile & Industry Workflows':
          'الخطوة 2: ملف النشاط وإعدادات نوع التجارة',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'اختر نموذج عملك لتفعيل الميزات المتخصصة لنشاطك التجاري.',
      'Smart POS Activation Key': 'مفتاح تفعيل سمارت بوس',
      'Business Logo': 'شعار المتجر / النشاط',
      'Business / Store Name': 'اسم المتجر / النشاط التجاري',
      'NTN / Tax ID': 'الرقم الضريبي',
      'Official Currency': 'العملة الرسمية',
      'Regional Time Zone': 'المنطقة الزمنية',
      'Local Embedded API Server Port': 'منفذ خادم API المحلي',
      'Primary Server Local IP': 'عنوان IP المحلي للخادم الرئيسي',
      'API Port': 'منفذ API',
      'Remote Cloud API URL': 'رابط API السحابي',
      'Branch ID': 'معرف الفرع',
      'Cloud API Secret Key': 'المفتاح السري لـ API السحابي',
      'Primary Database Host / IP': 'عنوان مضيف قاعدة البيانات الرئيسية',
      'Port': 'المنفذ',
      'Database Name': 'اسم قاعدة البيانات',
      'DB Username': 'اسم مستخدم قاعدة البيانات',
      'DB Password': 'كلمة مرور قاعدة البيانات',
      'Admin Full Name': 'الاسم الكامل للمدير',
      'Master Username': 'اسم المستخدم الرئيسي',
      'Email Address': 'البريد الإلكتروني',
      'Mobile Number': 'رقم الجوال',
      'Master Password': 'كلمة المرور الرئيسية',
      'Confirm Master Password': 'تأكيد كلمة المرور الرئيسية',
      'Upload Logo': 'رفع الشعار',
      'Change': 'تغيير',
      'Search 130+ Currencies': 'البحث في أكثر من 130 عملة',
      'Search 80+ Timezones': 'البحث في المناطق الزمنية',
      'Main': 'رئيسي',
      'Enable Secondary Language (Optional)': 'تفعيل اللغة الثانوية (اختياري)',
      'Select Business Industry Model (16 Supported Industries):':
          'اختر نموذج النشاط التجاري (16 نموذجاً مدعوماً):',
      '1 Business Model At A Time': 'نموذج عمل واحد في كل مرة',
      'Pre-load Starter Products, Categories & Suppliers':
          'تحميل منتجات وفئات وموردين كعينة أولية',
      'RECOMMENDED': 'موصى به',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'إضافة منتجات تجريبية وموردين ليكون النظام جاهزاً للبيع والاختبار مباشرة.',
      'ACTIVE EXCLUSIVE': 'النموذج النشط',
      'Step 3: Network Topology & Hybrid Database Engine':
          'الخطوة 3: هيكلية الشبكة وقاعدة البيانات المزدوجة',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'حدد طريقة تشغيل هذا الجهاز في شبكة متجرك (خادم رئيسي، نقطة بيع طرفية، أو هجين).',
      'Primary Server & Mobile REST API Server Configuration':
          'إعدادات الخادم الرئيسي وواجهة تطبيقات الجوال',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'ستتصل نقاط البيع الفرعية وتطبيق الجوال عبر نفس الشبكة بهذا الجهاز.',
      'Connect to Primary Server Machine:': 'الاتصال بجهاز الخادم الرئيسي:',
      'Cloud Sync Server Configuration:': 'إعدادات خادم المزامنة السحابية:',
      'Primary Central Database Engine (Admin Choice)':
          'محرك قاعدة البيانات المركزي',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'اختر MySQL أو PostgreSQL كقاعدة بيانات مركزية. سيعمل SQLite محلياً لضمان سرعة المعاملات ومزامنتها تلقائياً.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'ملاحظة: في Laragon أو XAMPP، المستخدم الافتراضي هو root بدون كلمة مرور.',
      'Clear for Laragon': 'تفريغ لـ Laragon',
      'Offline-First Local SQLite Sync Guarantee':
          'ضمان استمرارية العمل دون اتصال مع SQLite',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'تُحفظ كافة المبيعات محلياً أولاً. حتى في حال انقطاع الشبكة، تستمر عمليات البيع والفوترة بلا توقف.',
      'Step 4: Super Admin Master Credentials':
          'الخطوة 4: بيانات اعتماد المشرف العام',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'أنشئ حساب المشرف العام الأولي. كلمات المرور مشفرة بأحدث تقنيات التشفير Argon2id.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'درع الأمان نشط: كلمات المرور والبيانات محمية بتشفير Argon2id و AES-256-GCM.',
      'Installation & Setup Completed!': 'اكتمل التثبيت والإعداد بنجاح!',
      'System installation and database configuration completed successfully.':
          'تم إعداد قاعدة البيانات وتثبيت النظام بنجاح تام.',
      'Store / Business Name': 'اسم المتجر / النشاط',
      'Industry Profile': 'ملف النشاط التجاري',
      'Database Engine': 'محرك قاعدة البيانات',
      'Commercial Catalog': 'كتالوج المنتجات',
      'Master Admin Username': 'اسم مستخدم المشرف الرئيسي',
      'Starter products, categories & suppliers pre-loaded':
          'تم تحميل المنتجات والفئات والموردين الأولية',
      'Clean blank database initialized': 'تمت تهيئة قاعدة بيانات فارغة ونظيفة',
      'Direct Login Bypassed for Security':
          'تم تجاوز الدخول المباشر لأسباب أمنية',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'يرجى النقر أدناه للانتقال إلى شاشة تسجيل الدخول والمصادقة ببيانات المشرف الجديدة.',
      'Proceed to Login Screen': 'الانتقال إلى شاشة الدخول',
      'Master Admin username cannot be empty.':
          'لا يمكن أن يكون اسم مستخدم المشرف فارغاً.',
      'Passwords do not match. Please re-enter.':
          'كلمات المرور غير متطابقة. يرجى إعادة الإدخال.',
      'Please enter Business / Store Name.': 'يرجى إدخال اسم المتجر أو النشاط.',
      'Please select at least one Business Industry Preset.':
          'يرجى اختيار نموذج عمل تجاري واحد على الأقل.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'يرجى تحديد عنوان IP للخادم الرئيسي لوضع نقطة البيع الطرفية.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'يلزم وجود مفتاح ترخيص معتمد أو فترة تجريبية نشطة للمتابعة.',
      'MySQL Connection Notice': 'تنبيه اتصال MySQL',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'يتضمن النظام محرك SQLite مدمج وسريع يعمل دون اتصال وبدون إعدادات إضافية.\n\nهل ترغب في البدء بوضع SQLite المستقل الآن؟',
      'Back to Settings': 'العودة إلى الإعدادات',
      'Switch to SQLite & Launch POS': 'التحويل إلى SQLite وبدء التشغيل',
      'Installation Error': 'خطأ في التثبيت',
      'Close': 'إغلاق',
      'Cheque Management': 'إدارة الشيكات',
      'Turnstile Check-In': 'تسجيل دخول البوابة (البطاقة)',
      'Live KDS Screen': 'شاشة المطبخ المباشرة (KDS)',
      'Cooking': 'قيد التحضير',
      'Ready': 'جاهز',
      'Served': 'تم التقديم',
      'REPAIR & SERVICE INTAKE VOUCHER': 'سند استلام الصيانة والخدمة',
      'Terms & Conditions of Service': 'الشروط والأحكام الخاصة بالخدمة',
      'Credit Limit': 'حد الائتمان',
      'Period': 'الفترة',
      'Custom Range': 'نطاق مخصص',
      'No transactions or invoices found for the selected period.':
          'لا توجد معاملات أو فواتير مسجلة في هذه الفترة.',
      'Record Payment': 'تسجيل دفعة',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER':
          'سجل المعاملات وكشف الحساب الرسمي',
      'DATE & TIME': 'التاريخ والوقت',
      'TYPE': 'النوع',
      'NARRATION & DETAILS': 'البيان والتفاصيل',
      'DEBIT (Dr)': 'مدين (Dr)',
      'CREDIT (Cr)': 'دائن (Cr)',
      'RUNNING BAL': 'الرصيد التراكمي',
      'GRAND TOTALS': 'الإجمالي العام',
      'PAYMENT': 'سداد',
      'RETURN': 'مرتجع',
      'PURCHASE': 'مشتريات',
      'INVOICE': 'فاتورة',
      'OPENING': 'رصيد افتتاحي',
      'Save Modules': 'حفظ الموديولات',
      'Commercial SaaS Tier Presets': 'حزم الاشتراكات التجارية',
      'Quick Presets': 'الإعدادات السريعة',
      'Minimalist Core Only': 'الفوترة البسيطة فقط',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'بنية المزامنة المزدوجة المتكاملة',
      'Save Settings': 'حفظ الإعدادات',
      'Sync Now': 'مزامنة الآن',
      '1. Deployment & Sync Mode': 'وضع التشغيل والمزامنة',
      'Offline Only': 'دون اتصال فقط مع SQLite',
      'Both Online & Offline - Hybrid Sync': 'متصل وغير متصل - مزامنة مزدوجة',
    },

    // Pashto (پښتو)
    'ps': {
      'Dashboard': 'مرکزي ډشبورډ',
      'POS Terminal': 'د خرڅلاو ترمینل (POS)',
      'Products': 'توکي او زېرمه',
      'Sales': 'پلور او بیلونه',
      'Purchases': 'پېرل او درمل ترلاسه کول',
      'Expenses': 'لګښتونه او پیټي کیش',
      'Contacts': 'پېرودونکي او درمل پلورونکي',
      'Contacts & Khata': 'پېرودونکي، عرضه کوونکي او حسابونه',
      'User Management': 'کاروونکي او واکونه',
      'Reports': 'راپورونه او مالي تحلیل',
      'Settings': 'تنظیمات او سازونه',
      'TOTAL PAYABLE': 'ټوله تادیه کېدونکې پیسې',
      'Cash': 'نغدې پیسې',
      'Card': 'بانکي کارت',
      'Multiple Pay': 'ګډه تادیه',
      'Credit Sale': 'قرض پلور',
      'Cancel': 'لغوه کول',
      'SUBTOTAL': 'مجموعه',
      'ITEMS': 'ټول توکي',
      'No products in cart': 'ټوکرۍ خالي ده',
      'Cart is empty! Add products first':
          'ټوکرۍ خالي ده! لومړی په بل کې توکي زیات کړئ.',
      'Verifying security credentials...': 'د امنیتي اسنادو تصدیق روان دی...',
      'Initializing POS Engine & Data Cache...':
          'د ډیټابیس او کیشې لوډ روان دی...',
      'Access Granted! Launching Smart POS...':
          'ښه راغلاست! لاسرسی تایید شو...',
      'Configure Modules': 'د ماډیولونو ترتیبات',
      'Open Full Page': 'په بشپړ پاڼه کې پرانیستل',
      'Copy Statement': 'د حساب کاپي کول',
      'Send WhatsApp Reminder': 'د واټساپ یادونه استول',
      'Official Financial Ledger Book': 'د حسابونو رسمي راجستر',
      'Today': 'نننی حساب',
      'This Month': 'روانه میاشت',
      'Last 30 Days': 'تېرې ۳۰ ورځې',
      'All Time': 'ټول وخت',
      'Customer Due Balance': 'پاتې واجب الادا حساب',
      'Supplier Payable': 'سپلائر ته ورکړې پاتې پیسې',
      'Account Completely Cleared (Zero Balance)': 'حساب په بشپړ ډول پاک دی',
      'All invoices and payments are fully reconciled.':
          'ټول بلونه او تادیات برابر دي، هیڅ حساب پاتې نه دی.',
      'Outstanding amount owed by customer.':
          'دا پیسې د پیرودونکي پر غاړه پاتې دي.',
      'Outstanding amount owed to supplier.':
          'دا پیسې باید عرضه کوونکي ته ورکړل شي.',
      'Advance Credit Balance': 'مخکینۍ اضافي پیسې جمع دي',
      'Party has advance balance on account.':
          'له پیرودونکي سره مخکینۍ پیسې موجودې دي.',
      'Send Token': 'د نوبت ټوکن استول',
      'No Products in Catalog Yet': 'تر اوسه هیڅ توکی نشته',
      'No products in catalog yet': 'په کیټلاګ کې توکي نشته',
      'Add products with selling price and initial stock to start billing immediately!':
          'د سمدستي بل جوړولو لپاره توکي او موجودي اضافه کړئ!',
      'Add First Product': 'لومړنی توکی اضافه کړئ',
      'Receive Payment': 'پیسې ترلاسه کول',
      'Pay Supplier': 'سپلائر ته تادیه',
      'Customer': 'پیرودونکی',
      'Supplier': 'عرضه کوونکی',
      'Opening Balance': 'پخوانی پاتې حساب',
      'Total Billed / Debit (Dr)': 'ټول اخیستل / بنام مال (Dr)',
      'Total Paid / Credit (Cr)': 'ټولې پیسې ورکړې (Cr)',
      'TRANSACTIONS': 'د حساب راکړه ورکړه',
      'Thank you for your business!': 'له موږ سره د راکړې ورکړې مننه!',
      'Due': 'پاتې',
      'Cleared': 'پاک',
      'Quick Stock In': 'سمدستي زېرمه اضافه کول',
      'Quantity to Add': 'د زیاتولو اندازه',
      'Purchase Cost per Unit': 'د هر یونټ د پېر قیمت',
      'Add Stock': 'زېرمه اضافه کول',
      'Stock In / Purchase': 'پېر او زېرمه',
      'Supplier (Optional)': 'عرضه کوونکی (اختیاري)',
      'Product Name': 'د توکي نوم',
      'Selling Price': 'د پلور بیه',
      'Opening Stock (Units)': 'لومړنۍ زېرمه',
      'Physical Note Counter': 'د پیسو نوټونو شمېرنه',
      'Test Connection': 'اړیکه ازمویل',
      'Save Module Settings': 'د ماډیولونو ترتیبات خوندي کول',
      'Operational & Inventory Features': 'عملیاتي او زېرمتون ځانګړتیاوې',
      '1. POS COUNTER & SALE CONTROLS': 'د پلور کاونټر کنټرولونه',
      'Allow Altering Unit Prices at Counter': 'په کاونټر کې د بیې بدلولو واک',
      'Allow Giving Discounts': 'د تخفیف ورکولو واک',
      'Allow Voiding & Deleting Completed Sales':
          'د ثبت شوو بلونو لغوه کول او ډیلیټ کول',
      '2. PROFIT & FINANCIAL CONFIDENTIALITY': 'د پېر بیې او ګټې ساتنه',
      'View Purchase / Cost Price & Profit Margins': 'د پېر لګښت او ګټه کتل',
      'Authorize Sales Returns & Cash Refunds':
          'د مال بېرته راګرځول او د نغدو تادیه',
      'Access Customer Khata & Credit Ledgers':
          'د پیرودونکي پور او کهاتې ته لاسرسی',
      '3. BACK-OFFICE & SYSTEM POWERS': 'د دفتر او سیسټم اختیارات',
      'Inventory Stock Transfers & Adjustments': 'د زېرمې لېږد او تعدیلات',
      'View Sales, Tax & Profit/Loss Reports': 'مالي او د ګټې راپورونه کتل',
      'Access Store Settings & Configurations': 'د هټۍ ترتیباتو ته لاسرسی',
      'Manage Other Users & Staff Permissions':
          'د نورو کاروونکو د واکونو تنظیم',
      'PAYMENT CURRENCY': 'د ورکړې پیسې',
      '1. License Lock': '۱. د لایسنس تایید',
      '2. Business & Presets': '۲. د سوداګرۍ پیژندنه',
      '3. Topology & DB': '۳. شبکه او ډیټابیس',
      '4. Master Admin': '۴. د عمومي مدیر حساب',
      'Step 1: Machine Hardware-Bound License Activation':
          'لومړی پړاو: د هارډویر پورې تړلې لایسنس فعالول',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'هر سیسټم د کار لپاره یو باوري لایسنس ته اړتیا لري چې له دغه کمپیوټر سره تړلی وي.',
      'Detected Host Machine Hardware ID (HWID):':
          'د کمپیوټر پېژندګلوي (HWID):',
      'Copy HWID': 'د HWID کاپي کول',
      'Verify & Activate': 'تایید او فعالول',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'د ۳۰ ورځو وړیا ازمایښت فعالول',
      'No internet required for activation':
          'د فعالولو لپاره انټرنیټ ته اړتیا نشته',
      'HARDWARE BOUND': 'له هارډویر سره تړلی',
      'Step 2: Business Profile & Industry Workflows':
          'دویم پړاو: د سوداګرۍ پیژندنه او کاري جریان',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'خپل سوداګریز ماډل وټاکئ ترڅو اړوندې اسانتیاوې فعالې شي.',
      'Smart POS Activation Key': 'د سمارټ پوز د فعالولو کیلي',
      'Business Logo': 'د کاروبار نښه (لوګو)',
      'Business / Store Name': 'د پلورنځي / شرکت نوم',
      'NTN / Tax ID': 'د مالیې شمېره (NTN)',
      'Official Currency': 'رسمي پیسې',
      'Regional Time Zone': 'سیمه ییز وخت زون',
      'Local Embedded API Server Port': 'د محلي API سرور پورټ',
      'Primary Server Local IP': 'د اصلي سرور محلي IP',
      'API Port': 'د API پورټ',
      'Remote Cloud API URL': 'د ریموټ کلاوډ API ادرس',
      'Branch ID': 'د څانګې پېژند',
      'Cloud API Secret Key': 'د کلاوډ API پټه کیلي',
      'Primary Database Host / IP': 'د اصلي ډیټابیس سرور ادرس',
      'Port': 'پورټ',
      'Database Name': 'د ډیټابیس نوم',
      'DB Username': 'د ډیټابیس کارن نوم',
      'DB Password': 'د ډیټابیس پټنوم',
      'Admin Full Name': 'د مدیر بشپړ نوم',
      'Master Username': 'اصلي کارن نوم',
      'Email Address': 'برېښنالیک',
      'Mobile Number': 'د موبایل شمېره',
      'Master Password': 'اصلي پټنوم',
      'Confirm Master Password': 'د اصلي پټنوم تصدیق',
      'Upload Logo': 'لوګو پورته کړئ',
      'Change': 'بدلول',
      'Search 130+ Currencies': 'په ۱۳۰+ پیسو کې لټون',
      'Search 80+ Timezones': 'د وخت په زونونو کې لټون',
      'Main': 'اصلي',
      'Enable Secondary Language (Optional)': 'دویمه ژبه فعالول (اختیاري)',
      'Select Business Industry Model (16 Supported Industries):':
          'د سوداګرۍ بڼه وټاکئ (۱۶ ملاتړ شوي مسلکونه):',
      '1 Business Model At A Time': 'په یو وخت کې یو ماډل',
      'Pre-load Starter Products, Categories & Suppliers':
          'لومړني نمونه توکي او کټګورۍ شاملول',
      'RECOMMENDED': 'وړاندیز شوی',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'ازمایښتي توکي او سپلائران اضافه کړئ ترڅو سیسټم سمدستي د پلور لپاره چمتو شي.',
      'ACTIVE EXCLUSIVE': 'فعال ماډل',
      'Step 3: Network Topology & Hybrid Database Engine':
          'درېیم پړاو: د شبکې جوړښت او ګډ ډیټابیس انجن',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'وټاکئ چې دا کمپیوټر به ستاسو په پلورنځي کې څنګه کار کوي.',
      'Primary Server & Mobile REST API Server Configuration':
          'د اصلي سرور او موبایل API تنظیمات',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'نور کاونټرونه او د موبایل اپلیکیشن به له دغه کمپیوټر سره وصل شي.',
      'Connect to Primary Server Machine:': 'له مرکزي سرور کمپیوټر سره اړیکه:',
      'Cloud Sync Server Configuration:': 'د کلاوډ سنک سرور ترتیبات:',
      'Primary Central Database Engine (Admin Choice)': 'د مرکزي ډیټابیس ډول',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'د مرکزي ډیټابیس لپاره MySQL یا PostgreSQL وټاکئ. SQLite تل په محلي ډول چمتو وي.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'په لارګون یا زامپ کې ډیفالټ یوزر root پرته له پاسورډ څخه وي.',
      'Clear for Laragon': 'د لارګون لپاره تشول',
      'Offline-First Local SQLite Sync Guarantee':
          'د آفلاین کار ډاډمن SQLite سیسټم',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'ټول بلونه لومړی په کمپیوټر کې ثبت کیږي او په قطعي سره کار نه ودریږي.',
      'Step 4: Super Admin Master Credentials':
          'څلورم پړاو: د عمومي مدیر د ننوتلو معلومات',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'د ادارې اصلي اکاونټ جوړ کړئ. پاسورډونه په بشپړ ډول خوندي ساتل کیږي.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'امنیتي خوندیتوب فعال: ټول پټنومونه په Argon2id او AES-256-GCM خوندي دي.',
      'Installation & Setup Completed!':
          'تنصیب او چمتووالی په بریالیتوب سره بشپړ شو!',
      'System installation and database configuration completed successfully.':
          'د سیسټم لګول او ډیټابیس جوړول په بریالیتوب سره پای ته ورسېدل.',
      'Store / Business Name': 'د هټۍ / شرکت نوم',
      'Industry Profile': 'د سوداګرۍ بڼه',
      'Database Engine': 'د ډیټابیس انجن',
      'Commercial Catalog': 'د توکو لیست',
      'Master Admin Username': 'د عمومي مدیر کارن نوم',
      'Starter products, categories & suppliers pre-loaded':
          'لومړني توکي او کټګورۍ شاملې شوې',
      'Clean blank database initialized': 'پاک ډیټابیس چمتو شو',
      'Direct Login Bypassed for Security':
          'د امنیت په پار مستقیم ننوتل وتړل شول',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'د ننوتلو پاڼې ته د تګ لپاره لاندې کلیک وکړئ او په خپلو نویو معلوماتو ننوځئ.',
      'Proceed to Login Screen': 'د ننوتلو پاڼې ته لاړ شئ',
      'Master Admin username cannot be empty.':
          'د مدیر کارن نوم نشي خالي کیدی.',
      'Passwords do not match. Please re-enter.':
          'پټنومونه سره یو شان نه دي. بیا هڅه وکړئ.',
      'Please enter Business / Store Name.': 'مهرباني وکړئ د هټۍ نوم ولیکئ.',
      'Please select at least one Business Industry Preset.':
          'مهرباني وکړئ لږترلږه یو سوداګریز ماډل وټاکئ.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'مهرباني وکړئ د اصلي سرور IP ادرس ولیکئ.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'مخکې تګ لپاره تایید شوی لایسنس یا آزمایښتي دوره اړینه ده.',
      'MySQL Connection Notice': 'د MySQL اړیکې خبرتیا',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'په سمارټ پوز کې خورا چټک SQLite ډیټابیس شته چې پرته له انټرنیټ کار کوي.\n\nایا غواړئ په SQLite حالت کې پیل وکړئ؟',
      'Back to Settings': 'ترتیباتو ته بېرته تلل',
      'Switch to SQLite & Launch POS': 'SQLite ته اوښتل او د سیسټم پیل',
      'Installation Error': 'د لګولو تېروتنه',
      'Close': 'بندول',
      'Cheque Management': 'د چکونو تنظیم',
      'Turnstile Check-In': 'د دروازې چیک ان (کارډ سکین)',
      'Live KDS Screen': 'د پخلنځي پرده (KDS)',
      'Cooking': 'پخېږي',
      'Ready': 'چمتو دی',
      'Served': 'ورکړل شو',
      'REPAIR & SERVICE INTAKE VOUCHER': 'د ترمیم او خدماتو رسید',
      'Terms & Conditions of Service': 'د خدماتو اصول او شرایط',
      'Credit Limit': 'د پور حد',
      'Period': 'موده',
      'Custom Range': 'ځانګړې نېټه',
      'No transactions or invoices found for the selected period.':
          'په دې ټاکلې موده کې هیڅ حساب یا بل نشته.',
      'Record Payment': 'تادیه ثبتول',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER': 'د رسمي کهاتې او حساب راجستر',
      'DATE & TIME': 'نېټه او وخت',
      'TYPE': 'ډول',
      'NARRATION & DETAILS': 'تفصیل او یادښت',
      'DEBIT (Dr)': 'بنام مال (Dr)',
      'CREDIT (Cr)': 'جمع پیسې (Cr)',
      'RUNNING BAL': 'پاتې حساب',
      'GRAND TOTALS': 'ټولیزه مجموعه',
      'PAYMENT': 'تادیه',
      'RETURN': 'بېرته ګرځول',
      'PURCHASE': 'پېرودنه',
      'INVOICE': 'بل',
      'OPENING': 'پخوانی حساب',
      'Save Modules': 'ماډیولونه خوندي کړئ',
      'Commercial SaaS Tier Presets': 'تجارتی بسته ګانې',
      'Quick Presets': 'چټک ترتیبات',
      'Minimalist Core Only': 'ساده پلور',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'د انلاین او آفلاین سنک سیسټم',
      'Save Settings': 'ترتیبات خوندي کړئ',
      'Sync Now': 'اوس سنک کړئ',
      '1. Deployment & Sync Mode': 'د کار او سنک بڼه وټاکئ',
      'Offline Only': 'یوازې آفلاین SQLite',
      'Both Online & Offline - Hybrid Sync': 'آنلاین او آفلاین دواړه',
      'Enable All 16 Modules': 'ټول ۱۶ واړه ماډیولونه فعال کړئ',
      'Search modules by name or keywords...': 'د نوم له لارې لټون وکړئ...',
      'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean.':
          'فعال ماډیولونه تنظیم کړئ ترڅو کار اسانه شي.',
      'Smart POS Industry Presets': 'د سوداګریزو مسلکونو بڼې',
      'Online Cloud Server': 'مستقیم کلاوډ سرور',
      '2. Laravel / MySQL Server Configuration': 'د انلاین سرور ترتیبات',
      'Live exchange rates synced successfully!':
          'د تبادلې ژوندی نرخونه په بریالیتوب سره تازه شول!',
      'Error fetching exchange rates:':
          'د تبادلې نرخونو په ترلاسه کولو کې تېروتنه:',
      'Adapt software units, categories & POS to your trade':
          'د خپلې سوداګرۍ سره د سیسټم واحدونه او کټګورۍ برابرې کړئ',
    },

    // Spanish (Español)
    'es': {
      '1. License Lock': '1. Bloqueo de licencia',
      '2. Business & Presets': '2. Negocio y perfiles',
      '3. Topology & DB': '3. Topología y BD',
      '4. Master Admin': '4. Administrador maestro',
      'Step 1: Machine Hardware-Bound License Activation':
          'Paso 1: Activación de licencia ligada al hardware',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'Cada sistema requiere una licencia criptográfica vinculada a este equipo.',
      'Detected Host Machine Hardware ID (HWID):':
          'ID de hardware detectado (HWID):',
      'Copy HWID': 'Copiar HWID',
      'Verify & Activate': 'Verificar y activar',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'Activar prueba gratuita de 30 días',
      'No internet required for activation':
          'No requiere internet para la activación',
      'HARDWARE BOUND': 'VINCULADO AL HARDWARE',
      'Step 2: Business Profile & Industry Workflows':
          'Paso 2: Perfil comercial y flujo de trabajo del sector',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'Seleccione su modelo de negocio para habilitar funciones específicas.',
      'Smart POS Activation Key': 'Clave de activación Smart POS',
      'Business Logo': 'Logo del negocio',
      'Business / Store Name': 'Nombre del negocio',
      'NTN / Tax ID': 'Número de identificación fiscal',
      'Official Currency': 'Moneda oficial',
      'Regional Time Zone': 'Zona horaria regional',
      'Local Embedded API Server Port': 'Puerto del servidor API local',
      'Primary Server Local IP': 'IP local del servidor principal',
      'API Port': 'Puerto API',
      'Remote Cloud API URL': 'URL de API en la nube',
      'Branch ID': 'ID de sucursal',
      'Cloud API Secret Key': 'Clave secreta de la API en la nube',
      'Primary Database Host / IP': 'Host / IP de base de datos principal',
      'Port': 'Puerto',
      'Database Name': 'Nombre de base de datos',
      'DB Username': 'Usuario de la base de datos',
      'DB Password': 'Contraseña de la base de datos',
      'Admin Full Name': 'Nombre completo del administrador',
      'Master Username': 'Nombre de usuario principal',
      'Email Address': 'Correo electrónico',
      'Mobile Number': 'Número de móvil',
      'Master Password': 'Contraseña principal',
      'Confirm Master Password': 'Confirmar contraseña principal',
      'Upload Logo': 'Subir logo',
      'Change': 'Cambiar',
      'Search 130+ Currencies': 'Buscar más de 130 monedas',
      'Search 80+ Timezones': 'Buscar zonas horarias',
      'Main': 'Principal',
      'Enable Secondary Language (Optional)':
          'Activar idioma secundario (opcional)',
      'Select Business Industry Model (16 Supported Industries):':
          'Seleccione el modelo comercial (16 industrias compatibles):',
      '1 Business Model At A Time': '1 modelo comercial a la vez',
      'Pre-load Starter Products, Categories & Suppliers':
          'Precargar productos, categorías y proveedores iniciales',
      'RECOMMENDED': 'RECOMENDADO',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'Carga mercancía, unidades y proveedores para que el POS esté listo para vender y probar.',
      'ACTIVE EXCLUSIVE': 'ACTIVO EXCLUSIVO',
      'Step 3: Network Topology & Hybrid Database Engine':
          'Paso 3: Topología de red y motor de base de datos híbrido',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'Seleccione el modo de red de este equipo (Servidor, Terminal LAN o Híbrido).',
      'Primary Server & Mobile REST API Server Configuration':
          'Configuración del servidor principal y API móvil',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'Las terminales secundarias y la app móvil se conectarán a esta IP.',
      'Connect to Primary Server Machine:':
          'Conectar a máquina servidor principal:',
      'Cloud Sync Server Configuration:':
          'Configuración de sincronización en la nube:',
      'Primary Central Database Engine (Admin Choice)':
          'Motor de base de datos central (Elección del admin)',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'Elija MySQL o PostgreSQL como base de datos central. SQLite siempre está activo localmente para transacciones sin conexión.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'En Laragon o XAMPP el usuario MySQL por defecto es root sin contraseña.',
      'Clear for Laragon': 'Limpiar para Laragon',
      'Offline-First Local SQLite Sync Guarantee':
          'Garantía local SQLite sin conexión primero',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'Todas las ventas se guardan primero en SQLite local. Los cajeros continúan facturando sin interrupción.',
      'Step 4: Super Admin Master Credentials':
          'Paso 4: Credenciales del superadministrador',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'Cree la cuenta principal de administrador. Las contraseñas se protegen con Argon2id.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'Escudo de seguridad activo: Contraseñas protegidas con Argon2id y AES-256-GCM.',
      'Installation & Setup Completed!':
          '¡Instalación y configuración completadas!',
      'System installation and database configuration completed successfully.':
          'La instalación del sistema y la base de datos finalizaron con éxito.',
      'Store / Business Name': 'Nombre del negocio / tienda',
      'Industry Profile': 'Perfil del sector',
      'Database Engine': 'Motor de base de datos',
      'Commercial Catalog': 'Catálogo comercial',
      'Master Admin Username': 'Usuario administrador maestro',
      'Starter products, categories & suppliers pre-loaded':
          'Productos, categorías y proveedores iniciales cargados',
      'Clean blank database initialized': 'Base de datos limpia inicializada',
      'Direct Login Bypassed for Security':
          'Acceso directo omitido por seguridad',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'Haga clic a continuación para ir a la pantalla de inicio de sesión e ingresar con sus nuevas credenciales.',
      'Proceed to Login Screen': 'Ir a la pantalla de inicio de sesión',
      'Master Admin username cannot be empty.':
          'El nombre de usuario administrador no puede estar vacío.',
      'Passwords do not match. Please re-enter.':
          'Las contraseñas no coinciden. Vuelva a ingresarlas.',
      'Please enter Business / Store Name.':
          'Por favor ingrese el nombre del negocio.',
      'Please select at least one Business Industry Preset.':
          'Por favor seleccione al menos un modelo de negocio.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'Por favor proporcione la IP del servidor principal para modo LAN.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'Se requiere una clave de licencia verificada o prueba activa para continuar.',
      'MySQL Connection Notice': 'Aviso de conexión MySQL',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'Smart POS incluye SQLite de alta velocidad que funciona sin conexión.\n\n¿Desea iniciar en modo SQLite independiente ahora?',
      'Back to Settings': 'Volver a configuración',
      'Switch to SQLite & Launch POS': 'Cambiar a SQLite e iniciar POS',
      'Installation Error': 'Error de instalación',
      'Close': 'Cerrar',
      'Cheque Management': 'Gestión de cheques',
      'Turnstile Check-In': 'Acceso por torniquete',
      'Live KDS Screen': 'Pantalla de cocina en vivo',
      'Cooking': 'Cocinando',
      'Ready': 'Listo',
      'Served': 'Servido',
      'REPAIR & SERVICE INTAKE VOUCHER': 'COMPROBANTE DE SERVICIO Y REPARACIÓN',
      'Terms & Conditions of Service': 'Términos y condiciones del servicio',
      'Credit Limit': 'Límite de crédito',
      'Period': 'Período',
      'Custom Range': 'Rango personalizado',
      'No transactions or invoices found for the selected period.':
          'No se encontraron transacciones en el período seleccionado.',
      'Record Payment': 'Registrar pago',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER':
          'REGISTRO OFICIAL DE TRANSACCIONES',
      'DATE & TIME': 'FECHA Y HORA',
      'TYPE': 'TIPO',
      'NARRATION & DETAILS': 'DETALLES Y CONCEPTO',
      'DEBIT (Dr)': 'DÉBITO (Dr)',
      'CREDIT (Cr)': 'CRÉDITO (Cr)',
      'RUNNING BAL': 'SALDO ACTUAL',
      'GRAND TOTALS': 'TOTALES GENERALES',
      'PAYMENT': 'PAGO',
      'RETURN': 'DEVOLUCIÓN',
      'PURCHASE': 'COMPRA',
      'INVOICE': 'FACTURA',
      'OPENING': 'APERTURA',
      'Save Modules': 'Guardar módulos',
      'Commercial SaaS Tier Presets': 'Paquetes de suscripción comercial',
      'Quick Presets': 'Ajustes rápidos',
      'Minimalist Core Only': 'Facturación básica solamente',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'Arquitectura de sincronización híbrida',
      'Save Settings': 'Guardar configuración',
      'Sync Now': 'Sincronizar ahora',
      '1. Deployment & Sync Mode': '1. Modo de despliegue y sincronización',
      'Offline Only': 'Solo sin conexión',
      'Both Online & Offline - Hybrid Sync': 'Tanto en línea como sin conexión',
      'Dashboard': 'Panel de control',
      'POS Terminal': 'Terminal POS',
      'Products': 'Productos',
      'Sales': 'Ventas',
      'Purchases': 'Compras',
      'Expenses': 'Gastos',
      'Contacts': 'Contactos',
      'Settings': 'Configuración',
      'Enable All 16 Modules': 'Habilitar los 16 módulos',
      'Search modules by name or keywords...':
          'Buscar por nombre o palabra clave...',
      'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean.':
          'Personalice los módulos activos para mantener limpio su espacio de trabajo.',
      'Smart POS Industry Presets': 'Perfiles comerciales predefinidos',
      'Online Cloud Server': 'Servidor en la nube en línea',
      '2. Laravel / MySQL Server Configuration':
          '2. Configuración del servidor Laravel / MySQL',
      'Live exchange rates synced successfully!':
          '¡Tipos de cambio actualizados con éxito!',
      'Error fetching exchange rates:': 'Error al obtener los tipos de cambio:',
      'Adapt software units, categories & POS to your trade':
          'Adapte las unidades, categorías y el POS a su comercio',
    },

    // Dutch (Nederlands)
    'nl': {
      '1. License Lock': '1. Licentiekoppeling',
      '2. Business & Presets': '2. Bedrijf & profielen',
      '3. Topology & DB': '3. Topologie & DB',
      '4. Master Admin': '4. Hoofdbeheerder',
      'Step 1: Machine Hardware-Bound License Activation':
          'Stap 1: Aan hardware gekoppelde licentieactivatie',
      'Every system (Primary Server or Secondary LAN Terminal) requires an activated license cryptographically bound to this machine.':
          'Elk systeem vereist een geactiveerde licentie gekoppeld aan deze machine.',
      'Detected Host Machine Hardware ID (HWID):':
          'Gedetecteerde hardware-ID (HWID):',
      'Copy HWID': 'Kopieer HWID',
      'Verify & Activate': 'Verifiëren en activeren',
      'Activate Instant 30-Day Free Trial (Hardware Bound)':
          'Start 30 dagen gratis proefperiode',
      'No internet required for activation':
          'Geen internet vereist voor activatie',
      'HARDWARE BOUND': 'GEKOPPELD AAN HARDWARE',
      'Step 2: Business Profile & Industry Workflows':
          'Stap 2: Bedrijfsprofiel en sectorinstellingen',
      'Select one or multiple industry presets to enable domain-specific POS workflows (barcodes, IMEI, solar BOM, restaurant KOT).':
          'Selecteer uw bedrijfsmodel om specifieke functies in te schakelen.',
      'Smart POS Activation Key': 'Smart POS activatiesleutel',
      'Business Logo': 'Bedrijfslogo',
      'Business / Store Name': 'Bedrijfsnaam',
      'NTN / Tax ID': 'Btw-nummer / Fiscaal ID',
      'Official Currency': 'Officiële valuta',
      'Regional Time Zone': 'Regionale tijdzone',
      'Local Embedded API Server Port': 'Lokale ingebouwde API-serverpoort',
      'Primary Server Local IP': 'Lokaal IP van primaire server',
      'API Port': 'API-poort',
      'Remote Cloud API URL': 'Cloud API-URL',
      'Branch ID': 'Filiaal-ID',
      'Cloud API Secret Key': 'Geheime sleutel voor cloud-API',
      'Primary Database Host / IP': 'Primaire databasehost / IP',
      'Port': 'Poort',
      'Database Name': 'Databasenaam',
      'DB Username': 'Database gebruikersnaam',
      'DB Password': 'Database wachtwoord',
      'Admin Full Name': 'Volledige naam beheerder',
      'Master Username': 'Hoofdgebruikersnaam',
      'Email Address': 'E-mailadres',
      'Mobile Number': 'Mobiel nummer',
      'Master Password': 'Hoofdwachtwoord',
      'Confirm Master Password': 'Bevestig hoofdwachtwoord',
      'Upload Logo': 'Logo uploaden',
      'Change': 'Wijzigen',
      'Search 130+ Currencies': 'Zoek in 130+ valuta\'s',
      'Search 80+ Timezones': 'Zoek in tijdzones',
      'Main': 'Hoofd',
      'Enable Secondary Language (Optional)':
          'Secundaire taal inschakelen (optioneel)',
      'Select Business Industry Model (16 Supported Industries):':
          'Selecteer bedrijfsmodel (16 ondersteunde sectoren):',
      '1 Business Model At A Time': '1 bedrijfsmodel tegelijk',
      'Pre-load Starter Products, Categories & Suppliers':
          'Initiële producten, categorieën en leveranciers laden',
      'RECOMMENDED': 'AANBEVOLEN',
      'Seeds realistic merchandise, units, and vendor contacts for your selected business so the POS is immediately ready for sales and testing.':
          'Laadt voorraad, eenheden en contacten zodat de kassa direct gereed is voor verkoop.',
      'ACTIVE EXCLUSIVE': 'ACTIEF EXCLUSIEF',
      'Step 3: Network Topology & Hybrid Database Engine':
          'Stap 3: Netwerktopologie en hybride database-engine',
      'Select how this Smart POS machine interacts with your store network (Server, LAN Terminal, or Cloud Hybrid).':
          'Kies hoe dit systeem in uw netwerk werkt (Server, LAN-terminal of hybride).',
      'Primary Server & Mobile REST API Server Configuration':
          'Primaire server en mobiele API-configuratie',
      'LAN Secondary Terminals & the Flutter Mobile App on the same Wi-Fi will connect to this PC':
          'Secundaire kassa\'s en mobiele app verbinden met dit IP-adres.',
      'Connect to Primary Server Machine:': 'Verbinden met primaire server:',
      'Cloud Sync Server Configuration:':
          'Configuratie cloud-synchronisatieserver:',
      'Primary Central Database Engine (Admin Choice)':
          'Centrale database-engine (Keuze beheerder)',
      'Choose MySQL or PostgreSQL as the central enterprise database. SQLite is always active locally for instant offline transactions and auto-syncs when the primary server is reached.':
          'Kies MySQL of PostgreSQL als centrale database. SQLite blijft lokaal actief voor offline continuïteit.',
      'Tip: In Laragon / XAMPP, default MySQL user is "root" with NO password. Or use "smartpos" / "smartpos123".':
          'In Laragon of XAMPP is de standaard MySQL-gebruiker root zonder wachtwoord.',
      'Clear for Laragon': 'Wissen voor Laragon',
      'Offline-First Local SQLite Sync Guarantee':
          'Offline-first lokale SQLite-garantie',
      'All point-of-sale transactions write to SQLite locally first. Even if your central database server or network is temporarily down, cashiers can continue billing without interruption.':
          'Alle kassa-transacties worden lokaal opgeslagen. Kassiers kunnen zonder onderbreking blijven werken.',
      'Step 4: Super Admin Master Credentials':
          'Stap 4: Inloggegevens voor hoofdbeheerder',
      'Create the sole initial owner/superadmin account. Passwords are hashed using Argon2id with a unique per-user random salt before saving.':
          'Maak het hoofdbeheerdersaccount aan. Wachtwoorden worden beveiligd met Argon2id.',
      'Security Shield Active: Passwords are protected with Argon2id + unique random salt and stored credentials are encrypted with AES-256-GCM.':
          'Beveiligingsschild actief: Wachtwoorden beveiligd met Argon2id en AES-256-GCM.',
      'Installation & Setup Completed!':
          'Installatie en configuratie succesvol voltooid!',
      'System installation and database configuration completed successfully.':
          'Systeeminstallatie en databaseconfiguratie zijn succesvol afgerond.',
      'Store / Business Name': 'Winkel / Bedrijfsnaam',
      'Industry Profile': 'Sectorprofiel',
      'Database Engine': 'Database-engine',
      'Commercial Catalog': 'Commerciële catalogus',
      'Master Admin Username': 'Gebruikersnaam beheerder',
      'Starter products, categories & suppliers pre-loaded':
          'Basisproducten, categorieën en leveranciers geladen',
      'Clean blank database initialized':
          'Schone lege database geïnitialiseerd',
      'Direct Login Bypassed for Security':
          'Direct inloggen overgeslagen wegens veiligheid',
      'Please click below to navigate to the official Login Screen and authenticate using your new administrator credentials.':
          'Klik hieronder om naar het inlogscherm te gaan en in te loggen met uw beheerdersaccount.',
      'Proceed to Login Screen': 'Doorgaan naar inlogscherm',
      'Master Admin username cannot be empty.':
          'Gebruikersnaam van beheerder mag niet leeg zijn.',
      'Passwords do not match. Please re-enter.':
          'Wachtwoorden komen niet overeen. Voer opnieuw in.',
      'Please enter Business / Store Name.':
          'Voer alstublieft de bedrijfsnaam in.',
      'Please select at least one Business Industry Preset.':
          'Selecteer minimaal één bedrijfsmodel.',
      'Please provide Primary Server IP for LAN terminal mode.':
          'Geef het IP-adres van de primaire server op.',
      'A verified License Key or Active Free Trial is required to proceed.':
          'Een geverifieerde licentiesleutel of actieve proefperiode is vereist.',
      'MySQL Connection Notice': 'MySQL-verbindingsbericht',
      'Smart POS includes a high-speed embedded SQLite database engine that works offline with zero setup required.\n\nWould you like to launch using Standalone SQLite Mode now?':
          'Smart POS bevat een snelle embedded SQLite-database die offline werkt.\n\nWilt u nu starten in zelfstandige SQLite-modus?',
      'Back to Settings': 'Terug naar instellingen',
      'Switch to SQLite & Launch POS':
          'Overschakelen naar SQLite en POS starten',
      'Installation Error': 'Installatiefout',
      'Close': 'Sluiten',
      'Cheque Management': 'Chequebeheer',
      'Turnstile Check-In': 'Draaikruis check-in',
      'Live KDS Screen': 'Live keukenscherm (KDS)',
      'Cooking': 'In bereiding',
      'Ready': 'Gereed',
      'Served': 'Geserveerd',
      'REPAIR & SERVICE INTAKE VOUCHER': 'INNAMEBEWIJS REPARATIE & SERVICE',
      'Terms & Conditions of Service': 'Algemene servicevoorwaarden',
      'Credit Limit': 'Kredietlimiet',
      'Period': 'Periode',
      'Custom Range': 'Aangepast bereik',
      'No transactions or invoices found for the selected period.':
          'Geen transacties gevonden voor de geselecteerde periode.',
      'Record Payment': 'Betaling registreren',
      'OFFICIAL LEDGER TRANSACTIONS REGISTER':
          'OFFICIEEL GROOTBOEKTRANSACTIEREGISTER',
      'DATE & TIME': 'DATUM & TIJD',
      'TYPE': 'TYPE',
      'NARRATION & DETAILS': 'OMSCHRIJVING & DETAILS',
      'DEBIT (Dr)': 'DEBET (Dr)',
      'CREDIT (Cr)': 'CREDIT (Cr)',
      'RUNNING BAL': 'LOPENDE SALDO',
      'GRAND TOTALS': 'EINDTOTALEN',
      'PAYMENT': 'BETALING',
      'RETURN': 'RETOUR',
      'PURCHASE': 'INKOOP',
      'INVOICE': 'FACTUUR',
      'OPENING': 'OPENINGSBALANS',
      'Save Modules': 'Modules opslaan',
      'Commercial SaaS Tier Presets': 'Commerciële SaaS-abonnementen',
      'Quick Presets': 'Snelle voorinstellingen',
      'Minimalist Core Only': 'Alleen basis facturatie',
      'Hybrid Local SQLite + Laravel / MySQL Sync Architecture':
          'Hybride synchronisatie-architectuur',
      'Save Settings': 'Instellingen opslaan',
      'Sync Now': 'Nu synchroniseren',
      '1. Deployment & Sync Mode': '1. Implementatie- en synchronisatiemodus',
      'Offline Only': 'Alleen offline',
      'Both Online & Offline - Hybrid Sync': 'Zowel online als offline',
      'Dashboard': 'Dashboard',
      'POS Terminal': 'Kassa',
      'Products': 'Producten',
      'Sales': 'Verkopen',
      'Purchases': 'Inkopen',
      'Expenses': 'Uitgaven',
      'Contacts': 'Contacten',
      'Settings': 'Instellingen',
      'Enable All 16 Modules': 'Schakel alle 16 modules in',
      'Search modules by name or keywords...': 'Zoek op naam of trefwoorden...',
      'Customize active modules. Inactive features are hidden from the sidebar & POS to keep your workspace clean.':
          'Pas actieve modules aan voor een overzichtelijke werkomgeving.',
      'Smart POS Industry Presets': 'Smart POS sectorprofielen',
      'Online Cloud Server': 'Online cloudserver',
      '2. Laravel / MySQL Server Configuration':
          '2. Laravel / MySQL serverconfiguratie',
      'Live exchange rates synced successfully!':
          'Live wisselkoersen succesvol bijgewerkt!',
      'Error fetching exchange rates:': 'Fout bij ophalen wisselkoersen:',
      'Adapt software units, categories & POS to your trade':
          'Pas eenheden, categorieën en kassa aan op uw branche',
    },
  };
}
