import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../services/database_encryption_service.dart';
import 'base_repository.dart';

/// Manages business settings, locations, tax rates, invoice schemes, SMS gateways, and AI settings.
class SettingsRepository extends BaseRepository {
  const SettingsRepository([super.dbService]);

  // Settings (transparently encrypts/decrypts sensitive credentials)
  Future<BusinessSettings> getBusinessSettings() async {
    final rows =
        await db.query('business_settings', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return BusinessSettings();
    final map = Map<String, dynamic>.from(rows.first);
    if (map['db_password'] is String &&
        (map['db_password'] as String).isNotEmpty) {
      map['db_password'] = await DatabaseEncryptionService.decryptString(
          map['db_password'] as String);
    }
    if (map['sync_api_key'] is String &&
        (map['sync_api_key'] as String).isNotEmpty) {
      map['sync_api_key'] = await DatabaseEncryptionService.decryptString(
          map['sync_api_key'] as String);
    }
    return BusinessSettings.fromMap(map);
  }

  Future<void> updateBusinessSettings(
    BusinessSettings settings, {
    bool allowBusinessTypeChange = false,
  }) async {
    final current = await getBusinessSettings();
    final map = settings.toMap();
    if (!allowBusinessTypeChange &&
        current.isConfigured &&
        current.businessType.isNotEmpty) {
      // Protect against unintended type drift on routine saves unless explicitly switched
      map['business_type'] = current.businessType;
    }
    final rawDbPass = (map['db_password'] as String? ?? '');
    if (rawDbPass.isNotEmpty) {
      map['db_password'] =
          await DatabaseEncryptionService.encryptString(rawDbPass);
    }
    final rawSyncKey = (map['sync_api_key'] as String? ?? '');
    if (rawSyncKey.isNotEmpty) {
      map['sync_api_key'] =
          await DatabaseEncryptionService.encryptString(rawSyncKey);
    }
    final targetId = settings.id != 0 ? settings.id : current.id;
    map['id'] = targetId;
    final count = await db.update('business_settings', map,
        where: 'id = ?', whereArgs: [targetId]);
    if (count == 0) {
      await db.insert('business_settings', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await recordActivity(
      action: 'updated',
      entityType: 'business_settings',
      entityId: targetId,
      oldValues: {
        'business_name': current.businessName,
        'branch_name': current.branchName,
        'currency_symbol': current.currencySymbol,
        'default_tax_rate': current.defaultTaxRate,
      },
      newValues: {
        'business_name': settings.businessName,
        'branch_name': settings.branchName,
        'currency_symbol': settings.currencySymbol,
        'default_tax_rate': settings.defaultTaxRate,
      },
    );
    dbService.triggerAsyncMySqlSync();
  }

  // Business Locations
  Future<List<BusinessLocation>> getBusinessLocations() async {
    final rows = await db.query('business_locations', orderBy: 'id ASC');
    return rows.map((r) => BusinessLocation.fromMap(r)).toList();
  }

  Future<int> addBusinessLocation(BusinessLocation location) async {
    final map = location.toMap();
    final id = await db.insert('business_locations', map);
    await recordActivity(
      action: 'created',
      entityType: 'business_location',
      entityId: id,
      newValues: map..['id'] = id,
    );
    return id;
  }

  Future<void> updateBusinessLocation(BusinessLocation location) async {
    if (location.id != null) {
      final map = location.toMap();
      await db.update('business_locations', map,
          where: 'id = ?', whereArgs: [location.id]);
      await recordActivity(
        action: 'updated',
        entityType: 'business_location',
        entityId: location.id,
        newValues: map,
      );
    }
  }

  Future<void> deleteBusinessLocation(int id) async {
    await db.delete('business_locations', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'business_location',
      entityId: id,
    );
  }

  // Tax Rates
  Future<List<TaxRate>> getTaxRates() async {
    final rows = await db.query('tax_rates', orderBy: 'amount ASC');
    return rows.map((r) => TaxRate.fromMap(r)).toList();
  }

  Future<int> addTaxRate(TaxRate taxRate) async {
    final map = taxRate.toMap();
    final id = await db.insert('tax_rates', map);
    await recordActivity(
      action: 'created',
      entityType: 'tax_rate',
      entityId: id,
      newValues: map..['id'] = id,
    );
    return id;
  }

  Future<void> deleteTaxRate(int id) async {
    final groups = await getTaxGroups();
    for (final group in groups) {
      if (group.subTaxIds.contains(id)) {
        throw StateError(
          'Cannot delete tax rate: it is used in Tax Group "${group.name}".',
        );
      }
    }
    await db.delete('tax_rates', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'tax_rate',
      entityId: id,
    );
  }

  // ===================== TAX GROUPS (COMPOUND TAXES) =====================

  Future<List<TaxGroup>> getTaxGroups() async {
    final rows = await db.query('tax_groups', orderBy: 'id ASC');
    return rows.map((r) => TaxGroup.fromMap(r)).toList();
  }

  Future<int> addTaxGroup(TaxGroup group) async {
    final rates = await getTaxRates();
    final effective = group.subTaxIds.isNotEmpty
        ? group.computeEffectiveRate(rates)
        : group.effectiveRate;
    final map = TaxGroup(
      name: group.name,
      subTaxIds: group.subTaxIds,
      isCompound: group.isCompound,
      effectiveRate: effective,
      isActive: group.isActive,
    ).toMap();
    final id = await db.insert('tax_groups', map);
    await recordActivity(
      action: 'created',
      entityType: 'tax_group',
      entityId: id,
      newValues: map..['id'] = id,
    );
    return id;
  }

  Future<void> updateTaxGroup(TaxGroup group) async {
    if (group.id == null) return;
    final rates = await getTaxRates();
    final effective = group.subTaxIds.isNotEmpty
        ? group.computeEffectiveRate(rates)
        : group.effectiveRate;
    final map = TaxGroup(
      id: group.id,
      name: group.name,
      subTaxIds: group.subTaxIds,
      isCompound: group.isCompound,
      effectiveRate: effective,
      isActive: group.isActive,
      createdAt: group.createdAt,
    ).toMap();
    await db.update('tax_groups', map, where: 'id = ?', whereArgs: [group.id]);
    await recordActivity(
      action: 'updated',
      entityType: 'tax_group',
      entityId: group.id,
      newValues: map,
    );
  }

  Future<void> deleteTaxGroup(int id) async {
    await db.delete('tax_groups', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'tax_group',
      entityId: id,
    );
  }

  // ===================== SMS GATEWAYS =====================
  Future<Map<String, dynamic>> _decryptSmsRow(Map<String, dynamic> row) async {
    final m = Map<String, dynamic>.from(row);
    m['api_key'] =
        await DatabaseEncryptionService.decryptString(m['api_key'] as String?);
    m['api_secret'] = await DatabaseEncryptionService.decryptString(
        m['api_secret'] as String?);
    return m;
  }

  Future<Map<String, dynamic>> _encryptSmsMap(Map<String, dynamic> map) async {
    final m = Map<String, dynamic>.from(map);
    final k = m['api_key'] as String? ?? '';
    final s = m['api_secret'] as String? ?? '';
    if (k.isNotEmpty)
      m['api_key'] = await DatabaseEncryptionService.encryptString(k);
    if (s.isNotEmpty)
      m['api_secret'] = await DatabaseEncryptionService.encryptString(s);
    return m;
  }

  Future<List<SmsGateway>> getSmsGateways() async {
    final rows = await db.query('sms_gateways', orderBy: 'id ASC');
    final result = <SmsGateway>[];
    for (final r in rows) {
      result.add(SmsGateway.fromMap(await _decryptSmsRow(r)));
    }
    return result;
  }

  Future<SmsGateway?> getActiveSmsGateway() async {
    final rows =
        await db.query('sms_gateways', where: 'is_active = 1', limit: 1);
    if (rows.isNotEmpty) {
      return SmsGateway.fromMap(await _decryptSmsRow(rows.first));
    }
    return null;
  }

  Future<int> addSmsGateway(SmsGateway gateway) async {
    final map = await _encryptSmsMap(gateway.toMap());
    return await db.insert('sms_gateways', map);
  }

  Future<void> updateSmsGateway(SmsGateway gateway) async {
    if (gateway.id != null) {
      final map = await _encryptSmsMap(gateway.toMap());
      await db.update('sms_gateways', map,
          where: 'id = ?', whereArgs: [gateway.id]);
    }
  }

  Future<void> deleteSmsGateway(int id) async {
    await db.delete('sms_gateways', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== MESSAGE LOGS =====================
  Future<List<MessageLog>> getMessageLogs({int limit = 100}) async {
    final rows =
        await db.query('message_logs', orderBy: 'id DESC', limit: limit);
    return rows.map((r) => MessageLog.fromMap(r)).toList();
  }

  Future<int> addMessageLog(MessageLog log) async {
    return await db.insert('message_logs', log.toMap());
  }

  // ===================== AI SETTINGS =====================
  Future<AiSettings> getAiSettings() async {
    final rows = await db.query('ai_settings', limit: 1);
    if (rows.isNotEmpty) {
      final m = Map<String, dynamic>.from(rows.first);
      m['api_key'] = await DatabaseEncryptionService.decryptString(
          m['api_key'] as String?);
      return AiSettings.fromMap(m);
    }
    return AiSettings();
  }

  Future<void> saveAiSettings(AiSettings settings) async {
    final map = Map<String, dynamic>.from(settings.toMap());
    final rawKey = map['api_key'] as String? ?? '';
    if (rawKey.isNotEmpty) {
      map['api_key'] = await DatabaseEncryptionService.encryptString(rawKey);
    }
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM ai_settings');
    final count = (countRes.first['c'] as int?) ?? 0;
    if (count == 0) {
      await db.insert('ai_settings', map);
    } else {
      await db.update('ai_settings', map);
    }
  }

  // Invoice Schemes
  Future<List<InvoiceScheme>> getInvoiceSchemes() async {
    final rows = await db.query('invoice_schemes', orderBy: 'id ASC');
    return rows.map((r) => InvoiceScheme.fromMap(r)).toList();
  }

  Future<int> addInvoiceScheme(InvoiceScheme scheme) async {
    return await db.insert('invoice_schemes', scheme.toMap());
  }

  Future<void> updateInvoiceScheme(InvoiceScheme scheme) async {
    if (scheme.id != null) {
      await db.update('invoice_schemes', scheme.toMap(),
          where: 'id = ?', whereArgs: [scheme.id]);
    }
  }

  Future<void> deleteInvoiceScheme(int id) async {
    await db.delete('invoice_schemes', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> generateNextInvoiceNumber({int? schemeId}) async {
    List<Map<String, dynamic>> schemes;
    if (schemeId != null) {
      schemes = await db.query('invoice_schemes',
          where: 'id = ?', whereArgs: [schemeId], limit: 1);
    } else {
      schemes =
          await db.query('invoice_schemes', where: 'is_default = 1', limit: 1);
    }
    if (schemes.isEmpty) {
      schemes = await db.query('invoice_schemes', limit: 1);
    }

    if (schemes.isNotEmpty) {
      final s = InvoiceScheme.fromMap(schemes.first);
      final nextNumber = s.startNumber + s.invoiceCount;
      final padded = nextNumber.toString().padLeft(s.totalDigits, '0');
      final code = s.schemeType == 'year'
          ? '${s.prefix}${DateTime.now().year}-$padded'
          : '${s.prefix}$padded';
      // Increment count
      await db.rawUpdate(
          'UPDATE invoice_schemes SET invoice_count = invoice_count + 1 WHERE id = ?',
          [s.id]);
      return code;
    }
    return 'INV-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  // ===================== THERMAL PRINTERS (ESC/POS) =====================

  Future<List<ThermalPrinterConfig>> getPrinters() async {
    final rows =
        await db.query('receipt_printers', orderBy: 'is_default DESC, id ASC');
    return rows.map((r) => ThermalPrinterConfig.fromMap(r)).toList();
  }

  Future<ThermalPrinterConfig?> getDefaultPrinter() async {
    final defRows = await db.query(
      'receipt_printers',
      where: 'is_default = 1',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (defRows.isNotEmpty) return ThermalPrinterConfig.fromMap(defRows.first);
    final anyRows =
        await db.query('receipt_printers', orderBy: 'id ASC', limit: 1);
    return anyRows.isNotEmpty
        ? ThermalPrinterConfig.fromMap(anyRows.first)
        : null;
  }

  Future<ThermalPrinterConfig?> getKotPrinter() async {
    final kotRows = await db.query(
      'receipt_printers',
      where: 'is_kot_printer = 1',
      orderBy: 'is_default DESC, id ASC',
      limit: 1,
    );
    if (kotRows.isNotEmpty) return ThermalPrinterConfig.fromMap(kotRows.first);
    return await getDefaultPrinter();
  }

  Future<int> savePrinter(ThermalPrinterConfig printer) async {
    final int savedId = await db.transaction((txn) async {
      if (printer.isDefault) {
        await txn.update('receipt_printers', {'is_default': 0});
      }
      final map = printer.toMap();
      if (printer.id != null) {
        await txn.update(
          'receipt_printers',
          map,
          where: 'id = ?',
          whereArgs: [printer.id],
        );
        return printer.id!;
      }
      return await txn.insert('receipt_printers', map);
    });
    await recordActivity(
      action: printer.id == null ? 'created' : 'updated',
      entityType: 'receipt_printer',
      entityId: savedId,
      newValues: {
        'name': printer.name,
        'connection_type': printer.connectionType,
        'paper_width': printer.paperWidth,
      },
    );
    return savedId;
  }

  Future<void> setDefaultPrinter(int id) async {
    await db.transaction((txn) async {
      await txn.update('receipt_printers', {'is_default': 0});
      await txn.update(
        'receipt_printers',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await recordActivity(
      action: 'updated',
      entityType: 'receipt_printer',
      entityId: id,
      newValues: {'is_default': true},
    );
  }

  Future<void> deletePrinter(int id) async {
    await db.delete('receipt_printers', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'receipt_printer',
      entityId: id,
    );
  }

  // ===================== INVOICE LAYOUTS (TEMPLATES) =====================

  Future<List<InvoiceLayout>> getInvoiceLayouts() async {
    final rows =
        await db.query('invoice_layouts', orderBy: 'is_default DESC, id ASC');
    return rows.map((r) => InvoiceLayout.fromMap(r)).toList();
  }

  Future<InvoiceLayout?> getDefaultInvoiceLayout() async {
    final defRows = await db.query(
      'invoice_layouts',
      where: 'is_default = 1',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (defRows.isNotEmpty) return InvoiceLayout.fromMap(defRows.first);
    final anyRows =
        await db.query('invoice_layouts', orderBy: 'id ASC', limit: 1);
    return anyRows.isNotEmpty ? InvoiceLayout.fromMap(anyRows.first) : null;
  }

  Future<int> saveInvoiceLayout(InvoiceLayout layout) async {
    final int savedId = await db.transaction((txn) async {
      if (layout.isDefault) {
        await txn.update('invoice_layouts', {'is_default': 0});
      }
      final map = layout.toMap();
      if (layout.id != null) {
        await txn.update(
          'invoice_layouts',
          map,
          where: 'id = ?',
          whereArgs: [layout.id],
        );
        return layout.id!;
      }
      return await txn.insert('invoice_layouts', map);
    });
    await recordActivity(
      action: layout.id == null ? 'created' : 'updated',
      entityType: 'invoice_layout',
      entityId: savedId,
      newValues: {
        'name': layout.name,
        'design': layout.design,
        'paper_size': layout.paperSize,
      },
    );
    return savedId;
  }

  Future<void> setDefaultInvoiceLayout(int id) async {
    await db.transaction((txn) async {
      await txn.update('invoice_layouts', {'is_default': 0});
      await txn.update(
        'invoice_layouts',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await recordActivity(
      action: 'updated',
      entityType: 'invoice_layout',
      entityId: id,
      newValues: {'is_default': true},
    );
  }

  Future<void> deleteInvoiceLayout(int id) async {
    await db.delete('invoice_layouts', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'invoice_layout',
      entityId: id,
    );
  }
}
