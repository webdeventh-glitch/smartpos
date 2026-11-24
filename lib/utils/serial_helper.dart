/// Helper utility for managing serial number ranges, solar pallet lot tracking, and IMEI sequencing.
class SerialHelper {
  /// Generates a sequential list of serial numbers from a [startSerial] and [count].
  /// Example: "LR5-72HBD-550M-2401001" with count 36 generates:
  /// LR5-72HBD-550M-2401001 through LR5-72HBD-550M-2401036
  static List<String> generateRange(String startSerial, int count) {
    final clean = startSerial.trim();
    if (clean.isEmpty || count <= 0) return [];
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(clean);
    if (match == null) {
      if (count == 1) return [clean];
      return List.generate(count, (i) => '$clean-${i + 1}');
    }
    final prefix = match.group(1)!;
    final numStr = match.group(2)!;
    final startNum = int.tryParse(numStr) ?? 0;
    final padLen = numStr.length;

    final result = <String>[];
    for (int i = 0; i < count; i++) {
      final nextNum = (startNum + i).toString().padLeft(padLen, '0');
      result.add('$prefix$nextNum');
    }
    return result;
  }

  /// Calculates the expected end serial given [startSerial] and [count].
  static String calculateEndSerial(String startSerial, int count) {
    if (count <= 1) return startSerial.trim();
    final list = generateRange(startSerial, count);
    return list.isNotEmpty ? list.last : startSerial.trim();
  }

  /// Calculates unit count between [startSerial] and [endSerial].
  static int calculateCount(String startSerial, String endSerial) {
    final matchStart = RegExp(r'^(.*?)(\d+)$').firstMatch(startSerial.trim());
    final matchEnd = RegExp(r'^(.*?)(\d+)$').firstMatch(endSerial.trim());
    if (matchStart != null &&
        matchEnd != null &&
        matchStart.group(1) == matchEnd.group(1)) {
      final s = int.tryParse(matchStart.group(2)!) ?? 0;
      final e = int.tryParse(matchEnd.group(2)!) ?? 0;
      if (e >= s) return (e - s) + 1;
    }
    return 1;
  }
}
