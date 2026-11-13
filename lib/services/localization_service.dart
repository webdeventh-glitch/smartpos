import 'package:flutter/material.dart';
import '../models/business_settings.dart';

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
    final primary = (primaryOverride ?? settings?.activePrimaryLanguage ?? 'en')
        .toLowerCase()
        .trim();
    final isPrimaryEnglish = primary == 'en';

    // If primary is NOT English, secondary is strictly ignored
    final hasSecondary = isPrimaryEnglish &&
        (enableSecondaryOverride ??
            settings?.hasEffectiveSecondaryLanguage ??
            false);
    final secondary = (secondaryOverride ?? settings?.secondaryLanguage ?? 'ur')
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
    return '$primaryText ($secondaryText)';
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
    final primary = (primaryOverride ?? settings?.activePrimaryLanguage ?? 'en')
        .toLowerCase()
        .trim();
    final isPrimaryEnglish = primary == 'en';
    final hasSecondary = isPrimaryEnglish &&
        (enableSecondaryOverride ??
            settings?.hasEffectiveSecondaryLanguage ??
            false);
    final secondary = (secondaryOverride ?? settings?.secondaryLanguage ?? 'ur')
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
    final clean = key.replaceAll('*', '').trim();
    if (dict != null && dict.containsKey(clean)) {
      final res = dict[clean]!;
      return key.contains('*') ? '$res *' : res;
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
      'DISCOUNT(-)': 'DISCOUNT(-)',
      'ORDER TAX(+)': 'ORDER TAX(+)',
      'SHIPPING(+)': 'SHIPPING(+)',
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
      'Recent Sales [F9]': 'Recent Sales [F9]',
      'Card': 'Card',
      'Multiple Pay': 'Multiple Pay',
      'Cash': 'Cash',
      'Retail Mode (F12)': 'Retail Mode (F12)',
      '+ Custom Item': '+ Custom Item',
      'Undo': 'Undo',
      'Redo': 'Redo',
      'Multi-Unit & Decimal Scale Enabled':
          'Multi-Unit & Decimal Scale Enabled',
      'Category': 'Category',
      'Brands': 'Brands',
      'Featured Products': 'Featured Products',
      'Grid': 'Grid',
      'List': 'List',
      'Search product / barcode / 2*SKU [Esc]':
          'Search product / barcode / 2*SKU [Esc]',
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
      'Select Customer (F3)': 'Select Customer (F3)',
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
      '1. License Lock': '1. License Lock',
      '2. Business & Presets': '2. Business & Presets',
      '3. Topology & DB': '3. Topology & DB',
      '4. Master Admin': '4. Master Admin',
      'Back': 'Back',
      'Continue to Next Step': 'Continue to Next Step',
      'Complete Installation & Launch': 'Complete Installation & Launch',
      'Primary Language': 'Primary Language',
      'Enable Secondary Language (Optional)':
          'Enable Secondary Language (Optional)',
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
      'DISCOUNT(-)': 'رعایت(-)',
      'ORDER TAX(+)': 'ٹیکس(+)',
      'SHIPPING(+)': 'کرایہ(+)',
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
      'Credit Sale': 'ادھار سیل',
      'Recent Sales [F9]': 'حالیہ سیلز [F9]',
      'Card': 'کارڈ',
      'Multiple Pay': 'ملٹی ادائیگی',
      'Cash': 'نقد وصولی',
      'Retail Mode (F12)': 'ریٹیل موڈ (F12)',
      '+ Custom Item': '+ متفرق آئٹم',
      'Undo': 'واپس',
      'Redo': 'دوبارہ',
      'Multi-Unit & Decimal Scale Enabled': 'ملٹی یونٹ و ترازو اسکیل فعال ہے',
      'Category': 'کیٹیگری',
      'Brands': 'برانڈز',
      'Featured Products': 'نمایاں پروڈکٹس',
      'Grid': 'گرڈ',
      'List': 'لسٹ',
      'Search product / barcode / 2*SKU [Esc]':
          'پروڈکٹ / بارکوڈ / SKU تلاش کریں [Esc]',
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
      'Select Customer (F3)': 'کسٹمر کھاتہ منتخب کریں (F3)',
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
      '1. License Lock': '1. لائسنس کی',
      '2. Business & Presets': '2. کاروباری تفصیلات',
      '3. Topology & DB': '3. نیٹ ورک و ڈیٹا بیس',
      '4. Master Admin': '4. ماسٹر ایڈمن',
      'Back': 'واپس',
      'Continue to Next Step': 'اگلا مرحلہ',
      'Complete Installation & Launch': 'انسٹالیشن مکمل کریں اور چلائیں',
      'Primary Language': 'بنیادی زبان (Primary Language)',
      'Enable Secondary Language (Optional)': 'ثانوی زبان فعال کریں (اختیاری)',
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
      '+ Add First Product': '+ پہلی پروڈکٹ شامل کریں',
      '+ Receive Payment': '+ رقم وصول کریں',
      '+ Pay Supplier': '+ سپلائر کو ادائیگی',
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
      'DISCOUNT(-)': 'تخفیف(-)',
      'ORDER TAX(+)': 'مالیات(+)',
      'SHIPPING(+)': 'هزینه حمل(+)',
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
      'Recent Sales [F9]': 'فروش‌های اخیر [F9]',
      'Card': 'کارت‌خوان',
      'Multiple Pay': 'پرداخت ترکیبی',
      'Cash': 'نقد',
      'Retail Mode (F12)': 'حالت خرده‌فروشی (F12)',
      '+ Custom Item': '+ آیتم دلخواه',
      'Undo': 'بازگردانی',
      'Redo': 'تکرار',
      'Multi-Unit & Decimal Scale Enabled':
          'پشتیبانی از واحدهای چندگانه و مقیاس اعشاری فعال است',
      'Category': 'دسته‌بندی',
      'Brands': 'برندها',
      'Featured Products': 'کالاهای منتخب',
      'Grid': 'شبکه‌ای',
      'List': 'فهرست',
      'Search product / barcode / 2*SKU [Esc]':
          'جستجوی کالا / بارکد / کد کالا [Esc]',
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
      'Select Customer (F3)': 'انتخاب حساب مشتری (F3)',
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
      '1. License Lock': '۱. لایسنس',
      '2. Business & Presets': '۲. کسب و کار',
      '3. Topology & DB': '۳. شبکه و دیتابیس',
      '4. Master Admin': '۴. مدیر ارشد',
      'Back': 'بازگشت',
      'Continue to Next Step': 'ادامه به مرحله بعد',
      'Complete Installation & Launch': 'تکمیل نصب و راه‌اندازی',
      'Primary Language': 'زبان اصلی (Primary Language)',
      'Enable Secondary Language (Optional)': 'فعال‌سازی زبان دوم (اختیاری)',
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
      'DISCOUNT(-)': 'الخصم(-)',
      'ORDER TAX(+)': 'الضريبة(+)',
      'SHIPPING(+)': 'الشحن(+)',
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
      'Recent Sales [F9]': 'المبيعات الأخيرة [F9]',
      'Card': 'بطاقة بنكية',
      'Multiple Pay': 'دفع متعدد',
      'Cash': 'نقداً',
      'Retail Mode (F12)': 'وضع التجزئة (F12)',
      '+ Custom Item': '+ صنف مخصص',
      'Undo': 'تراجع',
      'Redo': 'إعادة',
      'Multi-Unit & Decimal Scale Enabled':
          'دعم الوحدات المتعددة وميزان الوزن مفعل',
      'Category': 'التصنيف',
      'Brands': 'العلامة التجارية',
      'Featured Products': 'منتجات مميزة',
      'Grid': 'شبكة',
      'List': 'قائمة',
      'Search product / barcode / 2*SKU [Esc]': 'ابحث عن منتج / باركود [Esc]',
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
      'Select Customer (F3)': 'اختر حساب العميل (F3)',
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
      '1. License Lock': '1. مفتاح الترخيص',
      '2. Business & Presets': '2. بيانات المنشأة',
      '3. Topology & DB': '3. الشبكة وقاعدة البيانات',
      '4. Master Admin': '4. المدير العام',
      'Back': 'رجوع',
      'Continue to Next Step': 'متابعة للخطوة التالية',
      'Complete Installation & Launch': 'إتمام التثبيت وتشغيل النظام',
      'Primary Language': 'اللغة الأساسية (Primary Language)',
      'Enable Secondary Language (Optional)': 'تفعيل لغة ثانوية (اختياري)',
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
      '+ Add First Product': '+ لومړنی توکی اضافه کړئ',
      '+ Receive Payment': '+ پیسې ترلاسه کول',
      '+ Pay Supplier': '+ سپلائر ته تادیه',
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
    },
  };
}
