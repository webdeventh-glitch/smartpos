import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Persistent vendor-only license record stored locally alongside the portable License Master tool.
class VendorLicenseRecord {
  final String id;
  final String clientName;
  final String businessType;
  final String contactInfo;
  final String machineId;
  final String tierCode;
  final String tierLabel;
  final String generatedAt;
  final String nextRenewalDate; // YYYY-MM-DD or 'Lifetime'
  final bool allowUpdates;
  final String licenseKey;
  final String appVersionIssued;

  const VendorLicenseRecord({
    required this.id,
    required this.clientName,
    required this.businessType,
    this.contactInfo = '',
    required this.machineId,
    required this.tierCode,
    required this.tierLabel,
    required this.generatedAt,
    required this.nextRenewalDate,
    this.allowUpdates = true,
    required this.licenseKey,
    this.appVersionIssued = '1.1.1+3',
  });

  VendorLicenseRecord copyWith({
    String? clientName,
    String? businessType,
    String? contactInfo,
    String? machineId,
    String? tierCode,
    String? tierLabel,
    String? generatedAt,
    String? nextRenewalDate,
    bool? allowUpdates,
    String? licenseKey,
    String? appVersionIssued,
  }) {
    return VendorLicenseRecord(
      id: id,
      clientName: clientName ?? this.clientName,
      businessType: businessType ?? this.businessType,
      contactInfo: contactInfo ?? this.contactInfo,
      machineId: machineId ?? this.machineId,
      tierCode: tierCode ?? this.tierCode,
      tierLabel: tierLabel ?? this.tierLabel,
      generatedAt: generatedAt ?? this.generatedAt,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      allowUpdates: allowUpdates ?? this.allowUpdates,
      licenseKey: licenseKey ?? this.licenseKey,
      appVersionIssued: appVersionIssued ?? this.appVersionIssued,
    );
  }

  String get statusLabel {
    if (tierCode == 'LFT' || nextRenewalDate == 'Lifetime') {
      return 'Lifetime';
    }
    final exp = DateTime.tryParse(nextRenewalDate);
    if (exp == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(exp.year, exp.month, exp.day);
    final diff = expDay.difference(today).inDays;
    if (diff < 0) return 'Expired';
    if (diff <= 14) return 'Renewal Due (${diff}d)';
    return 'Active (${diff}d)';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_name': clientName,
        'business_type': businessType,
        'contact_info': contactInfo,
        'machine_id': machineId,
        'tier_code': tierCode,
        'tier_label': tierLabel,
        'generated_at': generatedAt,
        'next_renewal_date': nextRenewalDate,
        'allow_updates': allowUpdates,
        'license_key': licenseKey,
        'app_version_issued': appVersionIssued,
      };

  factory VendorLicenseRecord.fromJson(Map<String, dynamic> map) {
    return VendorLicenseRecord(
      id: (map['id'] ?? '').toString(),
      clientName: (map['client_name'] ?? '').toString(),
      businessType: (map['business_type'] ?? 'universal').toString(),
      contactInfo: (map['contact_info'] ?? '').toString(),
      machineId: (map['machine_id'] ?? '').toString(),
      tierCode: (map['tier_code'] ?? 'YRL').toString(),
      tierLabel: (map['tier_label'] ?? 'Yearly (12 Months)').toString(),
      generatedAt: (map['generated_at'] ?? '').toString(),
      nextRenewalDate: (map['next_renewal_date'] ?? '').toString(),
      allowUpdates: map['allow_updates'] != false,
      licenseKey: (map['license_key'] ?? '').toString(),
      appVersionIssued: (map['app_version_issued'] ?? '1.1.1+3').toString(),
    );
  }
}

/// Manages local portable vendor license registry, website sync, CSV/JSON export, and `version.json` generation.
class VendorLicenseRegistryService {
  final File? registryFileOverride;
  final File? configFileOverride;

  const VendorLicenseRegistryService({
    this.registryFileOverride,
    this.configFileOverride,
  });

  static Directory resolvePortableVendorDir() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent;
        final probe = File(p.join(exeDir.path, '.vendor_write_test'));
        probe.writeAsStringSync('ok');
        probe.deleteSync();
        return exeDir;
      } catch (_) {
        // Read-only location fallback below
      }
    }
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    final dir = Directory(p.join(base, 'SmartPOS_Vendor'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File get _registryFile =>
      registryFileOverride ??
      File(p.join(resolvePortableVendorDir().path, 'vendor_licenses.json'));

  File get _configFile =>
      configFileOverride ??
      File(p.join(resolvePortableVendorDir().path, 'vendor_sync_config.json'));

  String get registryPath => _registryFile.path;

  Future<List<VendorLicenseRecord>> loadRecords() async {
    try {
      if (!_registryFile.existsSync()) return [];
      final raw = await _registryFile.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      final List<dynamic> list = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['licenses'] is List
              ? decoded['licenses'] as List<dynamic>
              : const []);
      return list
          .whereType<Map>()
          .map(
              (m) => VendorLicenseRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecords(List<VendorLicenseRecord> records) async {
    final parent = _registryFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final payload = {
      'schema': 'smartpos_vendor_registry_v1',
      'updated_at': DateTime.now().toIso8601String(),
      'total_clients': records.length,
      'licenses': records.map((r) => r.toJson()).toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await _registryFile.writeAsString(encoder.convert(payload), flush: true);
  }

  Future<List<VendorLicenseRecord>> upsertRecord(
      VendorLicenseRecord record) async {
    final existing = await loadRecords();
    final idx = existing.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      existing[idx] = record;
    } else {
      existing.insert(0, record);
    }
    await saveRecords(existing);
    return existing;
  }

  Future<List<VendorLicenseRecord>> deleteRecord(String id) async {
    final existing = await loadRecords();
    existing.removeWhere((r) => r.id == id);
    await saveRecords(existing);
    return existing;
  }

  Future<Map<String, String>> loadSyncConfig() async {
    try {
      if (!_configFile.existsSync()) return {};
      final decoded = jsonDecode(await _configFile.readAsString());
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveSyncConfig({
    required String websiteSyncUrl,
    required String apiToken,
    required String publicUpdateBaseUrl,
  }) async {
    final parent = _configFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await _configFile.writeAsString(
      encoder.convert({
        'website_sync_url': websiteSyncUrl.trim(),
        'api_token': apiToken.trim(),
        'public_update_base_url': publicUpdateBaseUrl.trim(),
      }),
      flush: true,
    );
  }

  String buildExportJson(List<VendorLicenseRecord> records) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'exported_at': DateTime.now().toIso8601String(),
      'total_clients': records.length,
      'licenses': records.map((r) => r.toJson()).toList(),
    });
  }

  String buildExportCsv(List<VendorLicenseRecord> records) {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final buf = StringBuffer();
    buf.writeln(
      'id,client_name,business_type,contact_info,machine_id,tier_code,tier_label,generated_at,next_renewal_date,allow_updates,status,license_key',
    );
    for (final r in records) {
      buf.writeln([
        esc(r.id),
        esc(r.clientName),
        esc(r.businessType),
        esc(r.contactInfo),
        esc(r.machineId),
        esc(r.tierCode),
        esc(r.tierLabel),
        esc(r.generatedAt),
        esc(r.nextRenewalDate),
        esc(r.allowUpdates ? '1' : '0'),
        esc(r.statusLabel),
        esc(r.licenseKey),
      ].join(','));
    }
    return buf.toString();
  }

  /// Pushes all vendor license records to the vendor's website endpoint via HTTP POST JSON.
  Future<Map<String, dynamic>> pushRegistryToWebsite({
    required String syncUrl,
    required String apiToken,
    required List<VendorLicenseRecord> records,
  }) async {
    final uri = Uri.tryParse(syncUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return {
        'success': false,
        'message': 'Please enter a valid https:// website API URL.',
      };
    }
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (apiToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiToken.trim()}',
        if (apiToken.trim().isNotEmpty) 'X-Vendor-Token': apiToken.trim(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: buildExportJson(records),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'status_code': response.statusCode,
          'message':
              'Synced ${records.length} license record(s) to website (HTTP ${response.statusCode}).',
        };
      }
      return {
        'success': false,
        'status_code': response.statusCode,
        'message':
            'Website returned HTTP ${response.statusCode}: ${response.body}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Website sync failed: $e',
      };
    }
  }

  /// Builds a ready-to-upload `version.json` manifest from a built installer `.exe`.
  static Future<Map<String, dynamic>> buildUpdateManifestForFile({
    required String installerFilePath,
    required String version,
    required int buildNumber,
    required String downloadUrl,
    required String releaseNotes,
    String licenseVerifyUrl = '',
    bool requiresActiveLicense = true,
  }) async {
    final file = File(installerFilePath.trim());
    if (!file.existsSync()) {
      throw FileSystemException('Installer file not found', installerFilePath);
    }
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString().toLowerCase();
    final sizeMb =
        double.parse((bytes.length / (1024 * 1024)).toStringAsFixed(2));
    final today = DateTime.now().toIso8601String().split('T').first;

    return {
      'version': version.trim(),
      'build': buildNumber,
      'release_date': today,
      'download_url': downloadUrl.trim(),
      'sha256': digest,
      'download_size_mb': sizeMb,
      'release_notes': releaseNotes.trim(),
      'requires_active_license': requiresActiveLicense,
      if (licenseVerifyUrl.trim().isNotEmpty)
        'license_verify_url': licenseVerifyUrl.trim(),
    };
  }
}
