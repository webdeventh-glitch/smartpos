import 'dart:async';
import 'dart:io';
import 'app_logger.dart';

/// Represents a validated weight reading from an electronic retail weighing scale.
class WeightReading {
  final double weight;
  final String unit; // 'kg', 'g', 'lb', 'oz'
  final bool isStable;
  final String rawData;
  final DateTime timestamp;

  const WeightReading({
    required this.weight,
    this.unit = 'kg',
    this.isStable = true,
    this.rawData = '',
    required this.timestamp,
  });

  @override
  String toString() =>
      '$weight $unit (${isStable ? "STABLE" : "UNSTABLE"}) [raw: $rawData]';
}

/// Service for communicating with RS232 / USB Virtual COM port digital weighing scales
/// commonly used in grocery, supermarket, butchery, and retail POS environments
/// (e.g. CAS, Mettler Toledo, Dibal, Avery Berkel, DIGI, Fairbanks, NCI).
class WeightScaleService {
  WeightScaleService._();
  static final WeightScaleService instance = WeightScaleService._();

  String _activePort = 'AUTO';
  int _activeBaudRate = 9600;

  String get activePort => _activePort;
  int get activeBaudRate => _activeBaudRate;

  void configure({String? port, int? baudRate}) {
    if (port != null && port.isNotEmpty) _activePort = port;
    if (baudRate != null && baudRate > 0) _activeBaudRate = baudRate;
  }

  /// Lists all currently connected serial COM ports on the operating system.
  Future<List<String>> getAvailableComPorts() async {
    final ports = <String>[];
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-Command',
            '[System.IO.Ports.SerialPort]::GetPortNames()'
          ],
        );
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && trimmed.toUpperCase().startsWith('COM')) {
              ports.add(trimmed.toUpperCase());
            }
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final dir = Directory('/dev');
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          for (final e in entities) {
            final name = e.path.split('/').last;
            if (name.startsWith('ttyUSB') ||
                name.startsWith('ttyACM') ||
                name.startsWith('ttyS') ||
                name.startsWith('cu.usbserial')) {
              ports.add(e.path);
            }
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning(
          'WeightScaleService', 'Failed to list COM ports', e, st);
    }
    return ports;
  }

  /// Parses a raw sentence stream or response from a digital scale into a structured [WeightReading].
  /// Supports:
  /// - CAS protocol: `ST,GS,+00.450kg` or `US,GS,+00.450kg`
  /// - Toledo protocol: `P  0.450 kg` or `S  0.450 kg`
  /// - NCI / Fairbanks: `<STX>  0.450LB<CR>`
  /// - Generic Decimal: `0.450` or `+00.450`
  static WeightReading? parseWeightSentence(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
    if (clean.isEmpty) return null;

    bool isStable = true;
    if (clean.toUpperCase().contains('US,') ||
        clean.toUpperCase().contains('UNSTABLE')) {
      isStable = false;
    } else if (clean.toUpperCase().contains('ST,') ||
        clean.toUpperCase().contains('STABLE')) {
      isStable = true;
    }

    String unit = 'kg';
    final lower = clean.toLowerCase();
    if (lower.contains('kg')) {
      unit = 'kg';
    } else if (lower.contains('lb')) {
      unit = 'lb';
    } else if (lower.contains('oz')) {
      unit = 'oz';
    } else if (lower.contains(' g ') || lower.endsWith('g')) {
      unit = 'g';
    }

    // Match floating-point weight value
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(clean);
    if (match != null) {
      final valStr = match.group(0);
      if (valStr != null) {
        final val = double.tryParse(valStr);
        if (val != null) {
          return WeightReading(
            weight: val,
            unit: unit,
            isStable: isStable,
            rawData: clean,
            timestamp: DateTime.now(),
          );
        }
      }
    }
    return null;
  }

  /// Queries the connected physical scale via RS232 / USB-Serial.
  /// If [targetPort] is omitted, uses [_activePort] or probes the first available port.
  Future<WeightReading?> readScaleWeight({
    String? targetPort,
    int? baudRate,
    int timeoutMs = 1200,
  }) async {
    final port = (targetPort != null && targetPort.isNotEmpty)
        ? targetPort
        : _activePort;
    final baud = baudRate ?? _activeBaudRate;

    if (!Platform.isWindows) {
      AppLogger.info('WeightScaleService',
          'Serial COM reading currently optimized for Windows POS desktop');
      return null;
    }

    String portToUse = port;
    if (portToUse == 'AUTO') {
      final available = await getAvailableComPorts();
      if (available.isEmpty) {
        AppLogger.warning('WeightScaleService',
            'No active COM ports detected for weighing scale');
        return null;
      }
      portToUse = available.first;
    }

    try {
      // Execute standard .NET SerialPort poll command via PowerShell
      // Opens port, transmits query command 'W\r' (common for CAS/Toledo), reads line
      final psScript = '''
\$port = New-Object System.IO.Ports.SerialPort '$portToUse', $baud, 'None', 8, 'One';
\$port.ReadTimeout = $timeoutMs;
\$port.WriteTimeout = 600;
try {
  \$port.Open();
  try { \$port.WriteLine("W`r"); } catch {}
  Start-Sleep -Milliseconds 120;
  \$line = \$port.ReadLine();
  \$port.Close();
  Write-Output \$line;
} catch {
  try { \$port.Close(); } catch {}
  Write-Error \$_.Exception.Message;
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psScript],
      );

      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) {
        final reading = parseWeightSentence(out);
        if (reading != null) {
          AppLogger.info(
              'WeightScaleService', 'Scale weight reading received: $reading');
          return reading;
        }
      }

      if (res.stderr.toString().isNotEmpty) {
        AppLogger.warning(
            'WeightScaleService', 'Scale read warning: ${res.stderr}');
      }
    } catch (e, st) {
      AppLogger.warning('WeightScaleService',
          'Error reading from scale on $portToUse', e, st);
    }
    return null;
  }

  /// Helper to generate a realistic simulated reading for testing or demonstration.
  WeightReading generateSimulatedReading(
      {double weight = 1.25, String unit = 'kg'}) {
    return WeightReading(
      weight: weight,
      unit: unit,
      isStable: true,
      rawData: 'ST,GS,+${weight.toStringAsFixed(3)}$unit',
      timestamp: DateTime.now(),
    );
  }
}
