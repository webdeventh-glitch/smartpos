import 'model_helpers.dart';

/// Saved ESC/POS thermal printer profile (Network TCP/9100 or Windows RAW Spooler).
/// Matches UltimatePOS `Printer` capabilities (`connection_type`, `capability_profile`, `char_per_line`).
class ThermalPrinterConfig {
  final int? id;
  final String name;
  final String connectionType; // 'network', 'windows'
  final String capabilityProfile; // 'default', 'simple', 'SP2000', 'TEP-200M', 'P822D'
  final String paperWidth; // '80mm', '58mm'
  final int charPerLine; // 48 for 80mm, 32 for 58mm
  final String ipAddress;
  final int port;
  final String windowsPrinterPath; // Windows shared/installed printer name or UNC path
  final bool isDefault;
  final bool isKotPrinter;
  final bool autoCut;
  final bool openCashDrawer;
  final String createdAt;

  ThermalPrinterConfig({
    this.id,
    required this.name,
    this.connectionType = 'network',
    this.capabilityProfile = 'default',
    this.paperWidth = '80mm',
    int? charPerLine,
    this.ipAddress = '192.168.1.100',
    this.port = 9100,
    this.windowsPrinterPath = '',
    this.isDefault = false,
    this.isKotPrinter = false,
    this.autoCut = true,
    this.openCashDrawer = false,
    String? createdAt,
  })  : charPerLine = charPerLine ?? (paperWidth == '58mm' ? 32 : 48),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  String get endpointLabel => connectionType == 'windows'
      ? (windowsPrinterPath.isNotEmpty ? windowsPrinterPath : 'Default Windows Printer')
      : '$ipAddress:$port';

  ThermalPrinterConfig copyWith({
    int? id,
    String? name,
    String? connectionType,
    String? capabilityProfile,
    String? paperWidth,
    int? charPerLine,
    String? ipAddress,
    int? port,
    String? windowsPrinterPath,
    bool? isDefault,
    bool? isKotPrinter,
    bool? autoCut,
    bool? openCashDrawer,
    String? createdAt,
  }) {
    final nextWidth = paperWidth ?? this.paperWidth;
    return ThermalPrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      capabilityProfile: capabilityProfile ?? this.capabilityProfile,
      paperWidth: nextWidth,
      charPerLine: charPerLine ??
          (paperWidth != null && paperWidth != this.paperWidth
              ? (nextWidth == '58mm' ? 32 : 48)
              : this.charPerLine),
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      windowsPrinterPath: windowsPrinterPath ?? this.windowsPrinterPath,
      isDefault: isDefault ?? this.isDefault,
      isKotPrinter: isKotPrinter ?? this.isKotPrinter,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'connection_type': connectionType,
        'capability_profile': capabilityProfile,
        'paper_width': paperWidth,
        'char_per_line': charPerLine,
        'ip_address': ipAddress,
        'port': port,
        'windows_printer_path': windowsPrinterPath,
        'is_default': isDefault ? 1 : 0,
        'is_kot_printer': isKotPrinter ? 1 : 0,
        'auto_cut': autoCut ? 1 : 0,
        'open_cash_drawer': openCashDrawer ? 1 : 0,
        'created_at': createdAt,
      };

  factory ThermalPrinterConfig.fromMap(Map<String, dynamic> map) => ThermalPrinterConfig(
        id: map['id'] as int?,
        name: modelAsString(map['name'], 'POS Printer'),
        connectionType: modelAsString(map['connection_type'], 'network'),
        capabilityProfile: modelAsString(map['capability_profile'], 'default'),
        paperWidth: modelAsString(map['paper_width'], '80mm'),
        charPerLine: modelAsInt(
          map['char_per_line'],
          modelAsString(map['paper_width'], '80mm') == '58mm' ? 32 : 48,
        ),
        ipAddress: modelAsString(map['ip_address'], '192.168.1.100'),
        port: modelAsInt(map['port'], 9100),
        windowsPrinterPath: modelAsString(map['windows_printer_path']),
        isDefault: modelAsBool(map['is_default'], false),
        isKotPrinter: modelAsBool(map['is_kot_printer'], false),
        autoCut: modelAsBool(map['auto_cut'], true),
        openCashDrawer: modelAsBool(map['open_cash_drawer'], false),
        createdAt: modelAsString(map['created_at'], DateTime.now().toIso8601String()),
      );
}

