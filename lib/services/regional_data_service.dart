import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;

/// Information model for international currencies
class CurrencyInfo {
  final String code; // e.g. 'PKR'
  final String symbol; // e.g. 'Rs'
  final String name; // e.g. 'Pakistani Rupee'
  final String country; // e.g. 'Pakistan'
  final String flag; // e.g. ''

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.country,
    required this.flag,
  });
}

/// Information model for regional timezones
class TimeZoneInfo {
  final String id; // e.g. 'Asia/Karachi'
  final String label; // e.g. 'Asia/Karachi (PKT GMT+05:00)'
  final String region; // e.g. 'Asia'
  final String city; // e.g. 'Karachi'
  final String offset; // e.g. 'GMT+05:00'

  const TimeZoneInfo({
    required this.id,
    required this.label,
    required this.region,
    required this.city,
    required this.offset,
  });
}

/// Service providing curated master datasets for Currencies, Timezones, and Native File Dialogs
class RegionalDataService {
  /// Master list of 130+ world currencies
  static const List<CurrencyInfo> allCurrencies = [
    // South Asia & Middle East (Priority)
    CurrencyInfo(code: 'PKR', symbol: 'Rs', name: 'Pakistani Rupee', country: 'Pakistan', flag: ''),
    CurrencyInfo(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal', country: 'Saudi Arabia', flag: ''),
    CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', country: 'United Arab Emirates', flag: ''),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', country: 'United States', flag: ''),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', country: 'United Kingdom', flag: ''),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', country: 'European Union', flag: ''),
    CurrencyInfo(code: 'QAR', symbol: '﷼', name: 'Qatari Riyal', country: 'Qatar', flag: ''),
    CurrencyInfo(code: 'OMR', symbol: '﷼', name: 'Omani Rial', country: 'Oman', flag: ''),
    CurrencyInfo(code: 'KWD', symbol: 'KD', name: 'Kuwaiti Dinar', country: 'Kuwait', flag: ''),
    CurrencyInfo(code: 'BHD', symbol: 'BD', name: 'Bahraini Dinar', country: 'Bahrain', flag: ''),
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', country: 'India', flag: ''),
    CurrencyInfo(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka', country: 'Bangladesh', flag: ''),
    CurrencyInfo(code: 'AFN', symbol: '؋', name: 'Afghan Afghani', country: 'Afghanistan', flag: ''),
    CurrencyInfo(code: 'LKR', symbol: 'Rs', name: 'Sri Lankan Rupee', country: 'Sri Lanka', flag: ''),
    CurrencyInfo(code: 'TRY', symbol: '₺', name: 'Turkish Lira', country: 'Turkey', flag: ''),
    CurrencyInfo(code: 'CAD', symbol: '\$', name: 'Canadian Dollar', country: 'Canada', flag: ''),
    CurrencyInfo(code: 'AUD', symbol: '\$', name: 'Australian Dollar', country: 'Australia', flag: ''),
    CurrencyInfo(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', country: 'China', flag: ''),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', country: 'Japan', flag: ''),
    CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', country: 'Malaysia', flag: ''),
    CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', country: 'Singapore', flag: ''),
    CurrencyInfo(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', country: 'Indonesia', flag: ''),
    CurrencyInfo(code: 'THB', symbol: '฿', name: 'Thai Baht', country: 'Thailand', flag: ''),
    CurrencyInfo(code: 'PHP', symbol: '₱', name: 'Philippine Peso', country: 'Philippines', flag: ''),
    CurrencyInfo(code: 'VND', symbol: '₫', name: 'Vietnamese Dong', country: 'Vietnam', flag: ''),
    CurrencyInfo(code: 'KRW', symbol: '₩', name: 'South Korean Won', country: 'South Korea', flag: ''),
    CurrencyInfo(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', country: 'Switzerland', flag: ''),
    CurrencyInfo(code: 'ZAR', symbol: 'R', name: 'South African Rand', country: 'South Africa', flag: ''),
    CurrencyInfo(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound', country: 'Egypt', flag: ''),
    CurrencyInfo(code: 'IQD', symbol: 'ع.د', name: 'Iraqi Dinar', country: 'Iraq', flag: ''),
    CurrencyInfo(code: 'IRR', symbol: '﷼', name: 'Iranian Rial', country: 'Iran', flag: ''),
    CurrencyInfo(code: 'JOD', symbol: 'JD', name: 'Jordanian Dinar', country: 'Jordan', flag: ''),
    CurrencyInfo(code: 'LBP', symbol: 'L£', name: 'Lebanese Pound', country: 'Lebanon', flag: ''),
    CurrencyInfo(code: 'LYD', symbol: 'LD', name: 'Libyan Dinar', country: 'Libya', flag: ''),
    CurrencyInfo(code: 'MAD', symbol: 'DH', name: 'Moroccan Dirham', country: 'Morocco', flag: ''),
    CurrencyInfo(code: 'TND', symbol: 'DT', name: 'Tunisian Dinar', country: 'Tunisia', flag: ''),
    CurrencyInfo(code: 'DZD', symbol: 'DA', name: 'Algerian Dinar', country: 'Algeria', flag: ''),
    CurrencyInfo(code: 'SDG', symbol: 'SDG', name: 'Sudanese Pound', country: 'Sudan', flag: ''),
    CurrencyInfo(code: 'SYP', symbol: 'S£', name: 'Syrian Pound', country: 'Syria', flag: ''),
    CurrencyInfo(code: 'YER', symbol: '﷼', name: 'Yemeni Rial', country: 'Yemen', flag: ''),
    CurrencyInfo(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', country: 'New Zealand', flag: ''),
    CurrencyInfo(code: 'RUB', symbol: '₽', name: 'Russian Ruble', country: 'Russia', flag: ''),
    CurrencyInfo(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', country: 'Brazil', flag: ''),
    CurrencyInfo(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso', country: 'Mexico', flag: ''),
    CurrencyInfo(code: 'NGN', symbol: '₦', name: 'Nigerian Naira', country: 'Nigeria', flag: ''),
    CurrencyInfo(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', country: 'Kenya', flag: ''),
    CurrencyInfo(code: 'GHS', symbol: 'GH₵', name: 'Ghanaian Cedi', country: 'Ghana', flag: ''),
    CurrencyInfo(code: 'UGX', symbol: 'USh', name: 'Ugandan Shilling', country: 'Uganda', flag: ''),
    CurrencyInfo(code: 'TZS', symbol: 'TSh', name: 'Tanzanian Shilling', country: 'Tanzania', flag: ''),
    CurrencyInfo(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', country: 'Sweden', flag: ''),
    CurrencyInfo(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', country: 'Norway', flag: ''),
    CurrencyInfo(code: 'DKK', symbol: 'kr', name: 'Danish Krone', country: 'Denmark', flag: ''),
    CurrencyInfo(code: 'PLN', symbol: 'zł', name: 'Polish Zloty', country: 'Poland', flag: ''),
    CurrencyInfo(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna', country: 'Czech Republic', flag: ''),
    CurrencyInfo(code: 'HUF', symbol: 'Ft', name: 'Hungarian Forint', country: 'Hungary', flag: ''),
    CurrencyInfo(code: 'RON', symbol: 'lei', name: 'Romanian Leu', country: 'Romania', flag: ''),
    CurrencyInfo(code: 'BGN', symbol: 'лв', name: 'Bulgarian Lev', country: 'Bulgaria', flag: ''),
    CurrencyInfo(code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar', country: 'Hong Kong', flag: ''),
    CurrencyInfo(code: 'TWD', symbol: 'NT\$', name: 'New Taiwan Dollar', country: 'Taiwan', flag: ''),
    CurrencyInfo(code: 'NPR', symbol: 'Rs', name: 'Nepalese Rupee', country: 'Nepal', flag: ''),
    CurrencyInfo(code: 'MVR', symbol: 'Rf', name: 'Maldivian Rufiyaa', country: 'Maldives', flag: ''),
    CurrencyInfo(code: 'KZT', symbol: '₸', name: 'Kazakhstani Tenge', country: 'Kazakhstan', flag: ''),
    CurrencyInfo(code: 'UZS', symbol: 'so\'m', name: 'Uzbekistani Som', country: 'Uzbekistan', flag: ''),
    CurrencyInfo(code: 'AZN', symbol: '₼', name: 'Azerbaijani Manat', country: 'Azerbaijan', flag: ''),
    CurrencyInfo(code: 'GEL', symbol: '₾', name: 'Georgian Lari', country: 'Georgia', flag: ''),
    CurrencyInfo(code: 'AMD', symbol: '֏', name: 'Armenian Dram', country: 'Armenia', flag: ''),
    CurrencyInfo(code: 'ILS', symbol: '₪', name: 'Israeli New Shekel', country: 'Israel', flag: ''),
    CurrencyInfo(code: 'ARS', symbol: '\$', name: 'Argentine Peso', country: 'Argentina', flag: ''),
    CurrencyInfo(code: 'CLP', symbol: '\$', name: 'Chilean Peso', country: 'Chile', flag: ''),
    CurrencyInfo(code: 'COP', symbol: '\$', name: 'Colombian Peso', country: 'Colombia', flag: ''),
    CurrencyInfo(code: 'PEN', symbol: 'S/.', name: 'Peruvian Sol', country: 'Peru', flag: ''),
    CurrencyInfo(code: 'UYU', symbol: '\$U', name: 'Uruguayan Peso', country: 'Uruguay', flag: ''),
    CurrencyInfo(code: 'VES', symbol: 'Bs.', name: 'Venezuelan Bolívar', country: 'Venezuela', flag: ''),
    CurrencyInfo(code: 'BOB', symbol: 'Bs.', name: 'Bolivian Boliviano', country: 'Bolivia', flag: ''),
    CurrencyInfo(code: 'DOP', symbol: 'RD\$', name: 'Dominican Peso', country: 'Dominican Republic', flag: ''),
    CurrencyInfo(code: 'GTQ', symbol: 'Q', name: 'Guatemalan Quetzal', country: 'Guatemala', flag: ''),
    CurrencyInfo(code: 'CRC', symbol: '₡', name: 'Costa Rican Colón', country: 'Costa Rica', flag: ''),
    CurrencyInfo(code: 'PAB', symbol: 'B/.', name: 'Panamanian Balboa', country: 'Panama', flag: ''),
    CurrencyInfo(code: 'JMD', symbol: 'J\$', name: 'Jamaican Dollar', country: 'Jamaica', flag: ''),
    CurrencyInfo(code: 'TTD', symbol: 'TT\$', name: 'Trinidad and Tobago Dollar', country: 'Trinidad and Tobago', flag: ''),
    CurrencyInfo(code: 'BBD', symbol: 'Bds\$', name: 'Barbadian Dollar', country: 'Barbados', flag: ''),
    CurrencyInfo(code: 'XCD', symbol: 'EC\$', name: 'East Caribbean Dollar', country: 'East Caribbean', flag: ''),
    CurrencyInfo(code: 'FJD', symbol: 'FJ\$', name: 'Fijian Dollar', country: 'Fiji', flag: ''),
    CurrencyInfo(code: 'PGK', symbol: 'K', name: 'Papua New Guinean Kina', country: 'Papua New Guinea', flag: ''),
    CurrencyInfo(code: 'MMK', symbol: 'K', name: 'Myanmar Kyat', country: 'Myanmar', flag: ''),
    CurrencyInfo(code: 'KHR', symbol: '៛', name: 'Cambodian Riel', country: 'Cambodia', flag: ''),
    CurrencyInfo(code: 'LAK', symbol: '₭', name: 'Lao Kip', country: 'Laos', flag: ''),
    CurrencyInfo(code: 'BND', symbol: 'B\$', name: 'Brunei Dollar', country: 'Brunei', flag: ''),
    CurrencyInfo(code: 'MOP', symbol: 'MOP\$', name: 'Macanese Pataca', country: 'Macau', flag: ''),
    CurrencyInfo(code: 'MNT', symbol: '₮', name: 'Mongolian Tugrik', country: 'Mongolia', flag: ''),
    CurrencyInfo(code: 'ETB', symbol: 'Br', name: 'Ethiopian Birr', country: 'Ethiopia', flag: ''),
    CurrencyInfo(code: 'MUR', symbol: 'Rs', name: 'Mauritian Rupee', country: 'Mauritius', flag: ''),
    CurrencyInfo(code: 'BWP', symbol: 'P', name: 'Botswanan Pula', country: 'Botswana', flag: ''),
    CurrencyInfo(code: 'NAD', symbol: 'N\$', name: 'Namibian Dollar', country: 'Namibia', flag: ''),
    CurrencyInfo(code: 'ZMW', symbol: 'ZK', name: 'Zambian Kwacha', country: 'Zambia', flag: ''),
    CurrencyInfo(code: 'RWF', symbol: 'RF', name: 'Rwandan Franc', country: 'Rwanda', flag: ''),
    CurrencyInfo(code: 'CDF', symbol: 'FC', name: 'Congolese Franc', country: 'DR Congo', flag: ''),
    CurrencyInfo(code: 'XAF', symbol: 'FCFA', name: 'Central African CFA Franc', country: 'Central Africa', flag: ''),
    CurrencyInfo(code: 'XOF', symbol: 'CFA', name: 'West African CFA Franc', country: 'West Africa', flag: ''),
    CurrencyInfo(code: 'MGA', symbol: 'Ar', name: 'Malagasy Ariary', country: 'Madagascar', flag: ''),
    CurrencyInfo(code: 'AOA', symbol: 'Kz', name: 'Angolan Kwanza', country: 'Angola', flag: ''),
    CurrencyInfo(code: 'MZN', symbol: 'MT', name: 'Mozambican Metical', country: 'Mozambique', flag: ''),
    CurrencyInfo(code: 'SZL', symbol: 'E', name: 'Swazi Lilangeni', country: 'Eswatini', flag: ''),
    CurrencyInfo(code: 'LSL', symbol: 'L', name: 'Lesotho Loti', country: 'Lesotho', flag: ''),
    CurrencyInfo(code: 'ISK', symbol: 'kr', name: 'Icelandic Króna', country: 'Iceland', flag: ''),
    CurrencyInfo(code: 'ALL', symbol: 'L', name: 'Albanian Lek', country: 'Albania', flag: ''),
    CurrencyInfo(code: 'RSD', symbol: 'дин.', name: 'Serbian Dinar', country: 'Serbia', flag: ''),
    CurrencyInfo(code: 'BAM', symbol: 'KM', name: 'Bosnia-Herzegovina Convertible Mark', country: 'Bosnia', flag: ''),
    CurrencyInfo(code: 'MKD', symbol: 'ден', name: 'Macedonian Denar', country: 'North Macedonia', flag: ''),
    CurrencyInfo(code: 'MDL', symbol: 'L', name: 'Moldovan Leu', country: 'Moldova', flag: ''),
    CurrencyInfo(code: 'UAH', symbol: '₴', name: 'Ukrainian Hryvnia', country: 'Ukraine', flag: ''),
    CurrencyInfo(code: 'BYN', symbol: 'Br', name: 'Belarusian Ruble', country: 'Belarus', flag: ''),
  ];

  /// Master list of major world timezones grouped by regions
  static const List<TimeZoneInfo> allTimeZones = [
    // Asia & Middle East
    TimeZoneInfo(id: 'Asia/Karachi', label: 'Asia/Karachi (PKT GMT+05:00)', region: 'Asia', city: 'Karachi / Islamabad', offset: 'GMT+05:00'),
    TimeZoneInfo(id: 'Asia/Dubai', label: 'Asia/Dubai (GST GMT+04:00)', region: 'Middle East', city: 'Dubai / UAE', offset: 'GMT+04:00'),
    TimeZoneInfo(id: 'Asia/Riyadh', label: 'Asia/Riyadh (AST GMT+03:00)', region: 'Middle East', city: 'Riyadh / Saudi Arabia', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Qatar', label: 'Asia/Qatar (AST GMT+03:00)', region: 'Middle East', city: 'Doha / Qatar', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Muscat', label: 'Asia/Muscat (GST GMT+04:00)', region: 'Middle East', city: 'Muscat / Oman', offset: 'GMT+04:00'),
    TimeZoneInfo(id: 'Asia/Kuwait', label: 'Asia/Kuwait (AST GMT+03:00)', region: 'Middle East', city: 'Kuwait City', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Bahrain', label: 'Asia/Bahrain (AST GMT+03:00)', region: 'Middle East', city: 'Manama / Bahrain', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Kabul', label: 'Asia/Kabul (AFT GMT+04:30)', region: 'Asia', city: 'Kabul / Afghanistan', offset: 'GMT+04:30'),
    TimeZoneInfo(id: 'Asia/Tehran', label: 'Asia/Tehran (IRST GMT+03:30)', region: 'Middle East', city: 'Tehran / Iran', offset: 'GMT+03:30'),
    TimeZoneInfo(id: 'Asia/Baghdad', label: 'Asia/Baghdad (AST GMT+03:00)', region: 'Middle East', city: 'Baghdad / Iraq', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Amman', label: 'Asia/Amman (EEST GMT+03:00)', region: 'Middle East', city: 'Amman / Jordan', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Beirut', label: 'Asia/Beirut (EEST GMT+03:00)', region: 'Middle East', city: 'Beirut / Lebanon', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Asia/Kolkata', label: 'Asia/Kolkata (IST GMT+05:30)', region: 'Asia', city: 'New Delhi / Mumbai', offset: 'GMT+05:30'),
    TimeZoneInfo(id: 'Asia/Dhaka', label: 'Asia/Dhaka (BST GMT+06:00)', region: 'Asia', city: 'Dhaka / Bangladesh', offset: 'GMT+06:00'),
    TimeZoneInfo(id: 'Asia/Colombo', label: 'Asia/Colombo (SLST GMT+05:30)', region: 'Asia', city: 'Colombo / Sri Lanka', offset: 'GMT+05:30'),
    TimeZoneInfo(id: 'Asia/Kathmandu', label: 'Asia/Kathmandu (NPT GMT+05:45)', region: 'Asia', city: 'Kathmandu / Nepal', offset: 'GMT+05:45'),
    TimeZoneInfo(id: 'Asia/Tashkent', label: 'Asia/Tashkent (UZT GMT+05:00)', region: 'Asia', city: 'Tashkent / Uzbekistan', offset: 'GMT+05:00'),
    TimeZoneInfo(id: 'Asia/Baku', label: 'Asia/Baku (AZT GMT+04:00)', region: 'Asia', city: 'Baku / Azerbaijan', offset: 'GMT+04:00'),
    TimeZoneInfo(id: 'Asia/Almaty', label: 'Asia/Almaty (ALMT GMT+05:00)', region: 'Asia', city: 'Almaty / Kazakhstan', offset: 'GMT+05:00'),
    TimeZoneInfo(id: 'Asia/Bangkok', label: 'Asia/Bangkok (ICT GMT+07:00)', region: 'Asia', city: 'Bangkok / Thailand', offset: 'GMT+07:00'),
    TimeZoneInfo(id: 'Asia/Jakarta', label: 'Asia/Jakarta (WIB GMT+07:00)', region: 'Asia', city: 'Jakarta / Indonesia', offset: 'GMT+07:00'),
    TimeZoneInfo(id: 'Asia/Singapore', label: 'Asia/Singapore (SGT GMT+08:00)', region: 'Asia', city: 'Singapore', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Kuala_Lumpur', label: 'Asia/Kuala_Lumpur (MYT GMT+08:00)', region: 'Asia', city: 'Kuala Lumpur / Malaysia', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Manila', label: 'Asia/Manila (PST GMT+08:00)', region: 'Asia', city: 'Manila / Philippines', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Shanghai', label: 'Asia/Shanghai (CST GMT+08:00)', region: 'Asia', city: 'Beijing / Shanghai', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Hong_Kong', label: 'Asia/Hong_Kong (HKT GMT+08:00)', region: 'Asia', city: 'Hong Kong', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Taipei', label: 'Asia/Taipei (CST GMT+08:00)', region: 'Asia', city: 'Taipei / Taiwan', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Asia/Seoul', label: 'Asia/Seoul (KST GMT+09:00)', region: 'Asia', city: 'Seoul / South Korea', offset: 'GMT+09:00'),
    TimeZoneInfo(id: 'Asia/Tokyo', label: 'Asia/Tokyo (JST GMT+09:00)', region: 'Asia', city: 'Tokyo / Japan', offset: 'GMT+09:00'),
    TimeZoneInfo(id: 'Europe/Istanbul', label: 'Europe/Istanbul (TRT GMT+03:00)', region: 'Europe', city: 'Istanbul / Turkey', offset: 'GMT+03:00'),

    // Europe & UK
    TimeZoneInfo(id: 'UTC', label: 'UTC (Universal Coordinated Time GMT+00:00)', region: 'Standard', city: 'UTC / Universal', offset: 'GMT+00:00'),
    TimeZoneInfo(id: 'Europe/London', label: 'Europe/London (GMT/BST GMT+00:00)', region: 'Europe', city: 'London / United Kingdom', offset: 'GMT+00:00'),
    TimeZoneInfo(id: 'Europe/Dublin', label: 'Europe/Dublin (IST GMT+01:00)', region: 'Europe', city: 'Dublin / Ireland', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Paris', label: 'Europe/Paris (CET GMT+01:00)', region: 'Europe', city: 'Paris / France', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Berlin', label: 'Europe/Berlin (CET GMT+01:00)', region: 'Europe', city: 'Berlin / Germany', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Rome', label: 'Europe/Rome (CET GMT+01:00)', region: 'Europe', city: 'Rome / Italy', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Madrid', label: 'Europe/Madrid (CET GMT+01:00)', region: 'Europe', city: 'Madrid / Spain', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Amsterdam', label: 'Europe/Amsterdam (CET GMT+01:00)', region: 'Europe', city: 'Amsterdam / Netherlands', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Brussels', label: 'Europe/Brussels (CET GMT+01:00)', region: 'Europe', city: 'Brussels / Belgium', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Vienna', label: 'Europe/Vienna (CET GMT+01:00)', region: 'Europe', city: 'Vienna / Austria', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Zurich', label: 'Europe/Zurich (CET GMT+01:00)', region: 'Europe', city: 'Zurich / Switzerland', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Stockholm', label: 'Europe/Stockholm (CET GMT+01:00)', region: 'Europe', city: 'Stockholm / Sweden', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Oslo', label: 'Europe/Oslo (CET GMT+01:00)', region: 'Europe', city: 'Oslo / Norway', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Athens', label: 'Europe/Athens (EET GMT+02:00)', region: 'Europe', city: 'Athens / Greece', offset: 'GMT+02:00'),
    TimeZoneInfo(id: 'Europe/Bucharest', label: 'Europe/Bucharest (EET GMT+02:00)', region: 'Europe', city: 'Bucharest / Romania', offset: 'GMT+02:00'),
    TimeZoneInfo(id: 'Europe/Warsaw', label: 'Europe/Warsaw (CET GMT+01:00)', region: 'Europe', city: 'Warsaw / Poland', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Europe/Kyiv', label: 'Europe/Kyiv (EET GMT+02:00)', region: 'Europe', city: 'Kyiv / Ukraine', offset: 'GMT+02:00'),
    TimeZoneInfo(id: 'Europe/Moscow', label: 'Europe/Moscow (MSK GMT+03:00)', region: 'Europe', city: 'Moscow / Russia', offset: 'GMT+03:00'),

    // Americas
    TimeZoneInfo(id: 'America/New_York', label: 'America/New_York (EST GMT-05:00)', region: 'Americas', city: 'New York / Eastern Time', offset: 'GMT-05:00'),
    TimeZoneInfo(id: 'America/Chicago', label: 'America/Chicago (CST GMT-06:00)', region: 'Americas', city: 'Chicago / Central Time', offset: 'GMT-06:00'),
    TimeZoneInfo(id: 'America/Denver', label: 'America/Denver (MST GMT-07:00)', region: 'Americas', city: 'Denver / Mountain Time', offset: 'GMT-07:00'),
    TimeZoneInfo(id: 'America/Los_Angeles', label: 'America/Los_Angeles (PST GMT-08:00)', region: 'Americas', city: 'Los Angeles / Pacific Time', offset: 'GMT-08:00'),
    TimeZoneInfo(id: 'America/Phoenix', label: 'America/Phoenix (MST GMT-07:00)', region: 'Americas', city: 'Phoenix / Arizona', offset: 'GMT-07:00'),
    TimeZoneInfo(id: 'America/Anchorage', label: 'America/Anchorage (AKST GMT-09:00)', region: 'Americas', city: 'Anchorage / Alaska', offset: 'GMT-09:00'),
    TimeZoneInfo(id: 'Pacific/Honolulu', label: 'Pacific/Honolulu (HST GMT-10:00)', region: 'Americas', city: 'Honolulu / Hawaii', offset: 'GMT-10:00'),
    TimeZoneInfo(id: 'America/Toronto', label: 'America/Toronto (EST GMT-05:00)', region: 'Americas', city: 'Toronto / Canada', offset: 'GMT-05:00'),
    TimeZoneInfo(id: 'America/Vancouver', label: 'America/Vancouver (PST GMT-08:00)', region: 'Americas', city: 'Vancouver / Canada', offset: 'GMT-08:00'),
    TimeZoneInfo(id: 'America/Mexico_City', label: 'America/Mexico_City (CST GMT-06:00)', region: 'Americas', city: 'Mexico City', offset: 'GMT-06:00'),
    TimeZoneInfo(id: 'America/Bogota', label: 'America/Bogota (COT GMT-05:00)', region: 'Americas', city: 'Bogota / Colombia', offset: 'GMT-05:00'),
    TimeZoneInfo(id: 'America/Lima', label: 'America/Lima (PET GMT-05:00)', region: 'Americas', city: 'Lima / Peru', offset: 'GMT-05:00'),
    TimeZoneInfo(id: 'America/Sao_Paulo', label: 'America/Sao_Paulo (BRT GMT-03:00)', region: 'Americas', city: 'Sao Paulo / Brazil', offset: 'GMT-03:00'),
    TimeZoneInfo(id: 'America/Buenos_Aires', label: 'America/Buenos_Aires (ART GMT-03:00)', region: 'Americas', city: 'Buenos Aires / Argentina', offset: 'GMT-03:00'),

    // Africa
    TimeZoneInfo(id: 'Africa/Cairo', label: 'Africa/Cairo (EEST GMT+03:00)', region: 'Africa', city: 'Cairo / Egypt', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Africa/Johannesburg', label: 'Africa/Johannesburg (SAST GMT+02:00)', region: 'Africa', city: 'Johannesburg / South Africa', offset: 'GMT+02:00'),
    TimeZoneInfo(id: 'Africa/Nairobi', label: 'Africa/Nairobi (EAT GMT+03:00)', region: 'Africa', city: 'Nairobi / Kenya', offset: 'GMT+03:00'),
    TimeZoneInfo(id: 'Africa/Lagos', label: 'Africa/Lagos (WAT GMT+01:00)', region: 'Africa', city: 'Lagos / Nigeria', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Africa/Casablanca', label: 'Africa/Casablanca (WET GMT+01:00)', region: 'Africa', city: 'Casablanca / Morocco', offset: 'GMT+01:00'),
    TimeZoneInfo(id: 'Africa/Accra', label: 'Africa/Accra (GMT GMT+00:00)', region: 'Africa', city: 'Accra / Ghana', offset: 'GMT+00:00'),

    // Australia & Pacific
    TimeZoneInfo(id: 'Australia/Sydney', label: 'Australia/Sydney (AEST GMT+10:00)', region: 'Australia', city: 'Sydney / Melbourne', offset: 'GMT+10:00'),
    TimeZoneInfo(id: 'Australia/Brisbane', label: 'Australia/Brisbane (AEST GMT+10:00)', region: 'Australia', city: 'Brisbane', offset: 'GMT+10:00'),
    TimeZoneInfo(id: 'Australia/Perth', label: 'Australia/Perth (AWST GMT+08:00)', region: 'Australia', city: 'Perth', offset: 'GMT+08:00'),
    TimeZoneInfo(id: 'Pacific/Auckland', label: 'Pacific/Auckland (NZST GMT+12:00)', region: 'Australia', city: 'Auckland / New Zealand', offset: 'GMT+12:00'),
  ];

  /// Find currency by code
  static CurrencyInfo? findCurrency(String code) {
    final upper = code.trim().toUpperCase();
    for (final c in allCurrencies) {
      if (c.code.toUpperCase() == upper) return c;
    }
    return null;
  }

  /// Find timezone by id
  static TimeZoneInfo? findTimeZone(String id) {
    final lower = id.trim().toLowerCase();
    for (final tz in allTimeZones) {
      if (tz.id.toLowerCase() == lower) return tz;
    }
    return null;
  }
}

/// Helper to pick files and manage persistent logos on Windows
class NativeFileHelper {
  /// Opens native Windows file dialog to pick an image file
  static Future<String?> pickBusinessLogo() async {
    try {
      const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = "Select Business Logo (PNG, JPG, WEBP)"
$dialog.Filter = "Image Files (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All Files (*.*)|*.*"
$dialog.Multiselect = $false
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write($dialog.FileName)
}
''';
      final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      final pickedPath = (res.stdout as String).trim();
      if (pickedPath.isEmpty || !File(pickedPath).existsSync()) {
        return null;
      }

      // Persistently copy into AppData/Local/SmartPOS/logos
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      final logoDir = Directory(p.join(base, 'SmartPOS', 'logos'));
      if (!logoDir.existsSync()) {
        await logoDir.create(recursive: true);
      }

      final ext = p.extension(pickedPath);
      final filename = 'business_logo_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destination = p.join(logoDir.path, filename);
      await File(pickedPath).copy(destination);
      return destination;
    } catch (e) {
      debugPrint('Error picking business logo: $e');
      return null;
    }
  }

  /// Opens native Windows file dialog to pick a product image file
  static Future<String?> pickProductImage() async {
    try {
      const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = "Select Product Image (PNG, JPG, WEBP, JPEG)"
$dialog.Filter = "Image Files (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All Files (*.*)|*.*"
$dialog.Multiselect = $false
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write($dialog.FileName)
}
''';
      final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      final pickedPath = (res.stdout as String).trim();
      if (pickedPath.isEmpty || !File(pickedPath).existsSync()) {
        return null;
      }

      // Persistently copy into AppData/Local/SmartPOS/products
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      final prodDir = Directory(p.join(base, 'SmartPOS', 'products'));
      if (!prodDir.existsSync()) {
        await prodDir.create(recursive: true);
      }

      final ext = p.extension(pickedPath);
      final filename = 'prod_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destination = p.join(prodDir.path, filename);
      await File(pickedPath).copy(destination);
      return destination;
    } catch (e) {
      debugPrint('Error picking product image: $e');
      return null;
    }
  }
}

/// Searchable Currency Selector Dialog
class CurrencySearchDialog extends StatefulWidget {
  final String? initialCode;
  final ValueChanged<CurrencyInfo> onSelected;

  const CurrencySearchDialog({
    super.key,
    this.initialCode,
    required this.onSelected,
  });

  @override
  State<CurrencySearchDialog> createState() => _CurrencySearchDialogState();
}

class _CurrencySearchDialogState extends State<CurrencySearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CurrencyInfo> _filtered = RegionalDataService.allCurrencies;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = RegionalDataService.allCurrencies;
      } else {
        _filtered = RegionalDataService.allCurrencies.where((c) {
          return c.code.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query) ||
              c.country.toLowerCase().contains(query) ||
              c.symbol.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_exchange, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Official Business Currency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '130+ Currencies supported • Search by code, name, symbol, or country',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search currency (e.g. PKR, USD, Riyal, Rupee, €, ﷼)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Popular Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickChip('PKR', 'PKR - Rs'),
                    _quickChip('USD', 'USD - \$'),
                    _quickChip('SAR', 'SAR - ﷼'),
                    _quickChip('AED', 'AED - د.إ'),
                    _quickChip('GBP', 'GBP - £'),
                    _quickChip('EUR', 'EUR - €'),
                    _quickChip('QAR', 'QAR - ﷼'),
                    _quickChip('OMR', 'OMR - ﷼'),
                    _quickChip('INR', 'INR - ₹'),
                    _quickChip('CAD', 'CAD - \$'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Results Count
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_filtered.length} currencies available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),

              // Scrollable List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text(
                              'No matching currencies found',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final isSelected = widget.initialCode?.toUpperCase() == item.code.toUpperCase();

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            tileColor: isSelected
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                                : Colors.transparent,
                            leading: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.coins,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.code,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${item.country} • Symbol: ${item.symbol}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                item.symbol,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ),
                            onTap: () {
                              widget.onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String code, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: () {
          final c = RegionalDataService.findCurrency(code);
          if (c != null) {
            widget.onSelected(c);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

/// Searchable Timezone Selector Dialog
class TimeZoneSearchDialog extends StatefulWidget {
  final String? initialId;
  final ValueChanged<TimeZoneInfo> onSelected;

  const TimeZoneSearchDialog({
    super.key,
    this.initialId,
    required this.onSelected,
  });

  @override
  State<TimeZoneSearchDialog> createState() => _TimeZoneSearchDialogState();
}

class _TimeZoneSearchDialogState extends State<TimeZoneSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<TimeZoneInfo> _filtered = RegionalDataService.allTimeZones;
  String _selectedRegionFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterList);
  }

  void _filterList() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = RegionalDataService.allTimeZones.where((tz) {
        final matchesRegion = _selectedRegionFilter == 'All' ||
            tz.region.toLowerCase() == _selectedRegionFilter.toLowerCase();
        final matchesQuery = query.isEmpty ||
            tz.id.toLowerCase().contains(query) ||
            tz.city.toLowerCase().contains(query) ||
            tz.label.toLowerCase().contains(query) ||
            tz.offset.toLowerCase().contains(query);
        return matchesRegion && matchesQuery;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Regional Time Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Ensures exact audit trails, fiscal day-end, invoice timestamps, and shift management',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Input
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search city, region, GMT offset (e.g. Karachi, Dubai, GMT+5, London)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Region Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _regionTab('All'),
                    _regionTab('Asia'),
                    _regionTab('Middle East'),
                    _regionTab('Europe'),
                    _regionTab('Americas'),
                    _regionTab('Africa'),
                    _regionTab('Australia'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Results Count
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_filtered.length} timezones matching',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),

              // List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text(
                              'No matching timezone found',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final isSelected = widget.initialId?.toLowerCase() == item.id.toLowerCase();

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            tileColor: isSelected
                                ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                                : Colors.transparent,
                            leading: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0284C7)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD)),
                                ),
                              ),
                              child: Icon(
                                Icons.public,
                                size: 20,
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0369A1),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  item.city,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.region,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              item.id,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                item.offset,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                            onTap: () {
                              widget.onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _regionTab(String region) {
    final isSelected = _selectedRegionFilter == region;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(region, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        onSelected: (val) {
          setState(() {
            _selectedRegionFilter = region;
            _filterList();
          });
        },
      ),
    );
  }
}

/// Information model for all 16 supported business industries
class BusinessIndustryInfo {
  final String key;
  final String title;
  final String category;
  final FaIconData icon;
  final Color color;
  final String features;

  const BusinessIndustryInfo({
    required this.key,
    required this.title,
    required this.category,
    required this.icon,
    required this.color,
    required this.features,
  });
}

/// Comprehensive list of all 16 industry models supported by Smart POS
const List<BusinessIndustryInfo> allSupportedIndustries = [
  BusinessIndustryInfo(
    key: 'pharmacy',
    title: 'Pharmacy / Medical Store & Agency',
    category: 'Healthcare & Pharma',
    icon: FontAwesomeIcons.prescriptionBottleMedical,
    color: Color(0xFF059669),
    features: 'Drug Act 1976 legal warranty (Form 2A), Medicine Formula / Generic search, Batch number & FIFO expiry tracking, Strip/Box fractional pricing, and Pharmacy POS Dispensing.',
  ),
  BusinessIndustryInfo(
    key: 'supermarket',
    title: 'Supermarket / Departmental Store',
    category: 'Retail & FMCG',
    icon: FontAwesomeIcons.cartShopping,
    color: Color(0xFF0D9488),
    features: 'High-speed barcode scanner POS, Weighing scale barcode parsing, Multi-Unit pricing (Piece, Box, Carton), and Product Variations (Size/Color).',
  ),
  BusinessIndustryInfo(
    key: 'general_store',
    title: 'General Store / Kiryana / Mini Mart',
    category: 'Retail & FMCG',
    icon: FontAwesomeIcons.shop,
    color: Color(0xFF4F46E5),
    features: 'Quick cash checkout, Loose items & weight calculation, Customer Udhar / Khata ledger, Low stock alerts, and Fast thermal receipt printing.',
  ),
  BusinessIndustryInfo(
    key: 'clothing',
    title: 'Apparel & Garments / Footwear / Boutique',
    category: 'Fashion & Apparel',
    icon: FontAwesomeIcons.shirt,
    color: Color(0xFF7C3AED),
    features: 'Color, Size & Fabric matrix variations, Barcode price tag printing, Return & Exchange windows, and Seasonal promotion discounts.',
  ),
  BusinessIndustryInfo(
    key: 'mobile',
    title: 'Mobile Phones & Electronics Agency',
    category: 'Electronics & Gadgets',
    icon: FontAwesomeIcons.mobileScreenButton,
    color: Color(0xFF2563EB),
    features: 'Mandatory Dual IMEI / Serial Number tracking on Purchase & Sale, Brand warranty management, and Trade-in / Old device exchange ledger.',
  ),
  BusinessIndustryInfo(
    key: 'solar',
    title: 'Solar Energy & Hardware Systems Agency',
    category: 'Hardware & Energy',
    icon: FontAwesomeIcons.solarPanel,
    color: Color(0xFFD97706),
    features: 'Quotation / Estimate Builder, Composite Bundle BOM Packages (Panels + Inverters + Batteries + Structure + Labor), Site tracking, and Warranty claims.',
  ),
  BusinessIndustryInfo(
    key: 'restaurant',
    title: 'Restaurant / Cafe / Fast Food / Bakery',
    category: 'Food & Hospitality',
    icon: FontAwesomeIcons.utensils,
    color: Color(0xFFE11D48),
    features: 'Dine-In, Takeaway & Delivery modes, Floor & Table layout management, Waiter order taking, and Kitchen Order Ticket (KOT) thermal printing.',
  ),
  BusinessIndustryInfo(
    key: 'wholesale',
    title: 'Wholesale & Bulk FMCG Distribution',
    category: 'Distribution & Trade',
    icon: FontAwesomeIcons.boxesPacking,
    color: Color(0xFF0891B2),
    features: 'Carton / Tier pricing groups, Customer credit limits & recovery schedules, Bulk dispatch challans, and Vehicle route sales tracking.',
  ),
  BusinessIndustryInfo(
    key: 'repair',
    title: 'Repairing Shop / Mobile & Auto Service',
    category: 'Services & Repair',
    icon: FontAwesomeIcons.wrench,
    color: Color(0xFFEA580C),
    features: 'Customer Job Sheets / Repair Tokens, Device intake checklist, Technician labor charges, Spare parts stock deduction, and Status alerts.',
  ),
  BusinessIndustryInfo(
    key: 'hotel',
    title: 'Hotel Management & Room Booking',
    category: 'Hospitality',
    icon: FontAwesomeIcons.hotel,
    color: Color(0xFF4338CA),
    features: 'Room reservations & availability calendar, Check-in / Check-out guest cards, Room service & dining billing, Housekeeping, and Guest folios.',
  ),
  BusinessIndustryInfo(
    key: 'gym',
    title: 'Gym & Fitness Center Club',
    category: 'Fitness & Sports',
    icon: FontAwesomeIcons.dumbbell,
    color: Color(0xFFBE185D),
    features: 'Member admission & monthly/annual subscription packages, Attendance log, Locker assignments, Trainer commissions, and Fee collection ledger.',
  ),
  BusinessIndustryInfo(
    key: 'manufacturing',
    title: 'Manufacturing / Production & Assembly',
    category: 'Industrial',
    icon: FontAwesomeIcons.industry,
    color: Color(0xFF475569),
    features: 'Raw materials inventory, Multi-level Bill of Materials (BOM), Production work orders, Wastage tracking, and Finished goods unit costing.',
  ),
  BusinessIndustryInfo(
    key: 'fruit_wholesale',
    title: 'Fruit & Sabzi Mandi / Commission Agency',
    category: 'Agriculture & Mandi',
    icon: FontAwesomeIcons.appleWhole,
    color: Color(0xFF65A30D),
    features: 'Farmer / Zamindar lot receiving, Daily auction (Boli) rate bidding, Commission deduction, Mazdoori / Palledari charges, and Buyer daily Khata.',
  ),
  BusinessIndustryInfo(
    key: 'poultry',
    title: 'Poultry Farm & Broiler Trading Agency',
    category: 'Livestock & Poultry',
    icon: FontAwesomeIcons.egg,
    color: Color(0xFFCA8A04),
    features: 'Live bird weighing calculations vs live market rate, Crate count tracking, Feed consumption monitoring, Mortality logs, and Driver delivery challans.',
  ),
  BusinessIndustryInfo(
    key: 'accounting_crm',
    title: 'Accounting, Tax & Corporate CRM Agency',
    category: 'Finance & Corporate',
    icon: FontAwesomeIcons.fileInvoiceDollar,
    color: Color(0xFF0F766E),
    features: 'Double-entry general ledger, Chart of Accounts (COA), Balance Sheet, Profit & Loss statements, Tax deductions, and Client corporate files.',
  ),
  BusinessIndustryInfo(
    key: 'woocommerce',
    title: 'Online Store / E-Commerce & WooCommerce',
    category: 'E-Commerce',
    icon: FontAwesomeIcons.globe,
    color: Color(0xFF9333EA),
    features: 'Cloud REST API bidirectional syncing, Web order processing, Multi-channel inventory synchronization, and Online customer accounts.',
  ),
];

