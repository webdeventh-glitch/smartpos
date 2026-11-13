import 'dart:convert';
import '../services/app_logger.dart';

/// Variation Template in Smart POS (e.g. Size, Color)
class VariationTemplate {
  final int? id;
  final String name;
  final List<String> values;

  VariationTemplate({this.id, required this.name, required this.values});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'values_json': jsonEncode(values),
      };

  factory VariationTemplate.fromMap(Map<String, dynamic> map) {
    List<String> parsedValues = [];
    if (map['values_json'] != null) {
      try {
        final decoded = jsonDecode(map['values_json'] as String);
        if (decoded is List) {
          parsedValues = decoded.map((e) => e.toString()).toList();
        }
      } catch (e, st) {
        AppLogger.warning(
            'Models', 'Failed parsing VariationTemplate values_json', e, st);
      }
    }
    return VariationTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
      values: parsedValues,
    );
  }
}
