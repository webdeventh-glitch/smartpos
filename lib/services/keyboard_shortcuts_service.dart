import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';

/// Canonical POS & form keyboard shortcut actions (Step 7.3).
class ShortcutActionSpec {
  final String id;
  final String label;
  final String defaultKeyLabel;
  final bool isGlobalOrForm;

  const ShortcutActionSpec({
    required this.id,
    required this.label,
    required this.defaultKeyLabel,
    this.isGlobalOrForm = false,
  });
}

/// Manages customizable F-key mappings and Ctrl shortcuts across POS & data-entry forms.
class KeyboardShortcutsService {
  KeyboardShortcutsService._();

  static const List<ShortcutActionSpec> actions = [
    ShortcutActionSpec(
        id: 'help', label: 'Keyboard Shortcuts Help', defaultKeyLabel: 'F1'),
    ShortcutActionSpec(
        id: 'quickCash', label: 'Quick Cash Checkout', defaultKeyLabel: 'F2'),
    ShortcutActionSpec(
        id: 'customerSearch',
        label: 'Live Customer Search',
        defaultKeyLabel: 'F3'),
    ShortcutActionSpec(
        id: 'suspendSale', label: 'Suspend / Park Sale', defaultKeyLabel: 'F4'),
    ShortcutActionSpec(
        id: 'toggleView',
        label: 'Toggle Grid / List View',
        defaultKeyLabel: 'F5'),
    ShortcutActionSpec(
        id: 'quickCustomer',
        label: 'Quick Add Customer',
        defaultKeyLabel: 'F6'),
    ShortcutActionSpec(
        id: 'multiPay', label: 'Multiple / Split Pay', defaultKeyLabel: 'F7'),
    ShortcutActionSpec(
        id: 'clearCart', label: 'Clear / Cancel Sale', defaultKeyLabel: 'F8'),
    ShortcutActionSpec(
        id: 'recentSales',
        label: 'Recent Sales & Reprints',
        defaultKeyLabel: 'F9'),
    ShortcutActionSpec(
        id: 'registerDetails',
        label: 'Cash Register Details',
        defaultKeyLabel: 'F10'),
    ShortcutActionSpec(
        id: 'undoCart',
        label: 'Undo Last Cart Edit',
        defaultKeyLabel: 'Ctrl+Z',
        isGlobalOrForm: true),
    ShortcutActionSpec(
        id: 'redoCart',
        label: 'Redo Cart Edit',
        defaultKeyLabel: 'Ctrl+Y',
        isGlobalOrForm: true),
    ShortcutActionSpec(
        id: 'saveForm',
        label: 'Quick Save Form (Add/Settings)',
        defaultKeyLabel: 'Ctrl+S',
        isGlobalOrForm: true),
    ShortcutActionSpec(
        id: 'toggleProductPanel',
        label: 'Toggle Barcode Superstore Mode (Hide/Show Catalog)',
        defaultKeyLabel: 'Ctrl+B',
        isGlobalOrForm: true),
    ShortcutActionSpec(
        id: 'focusSearch',
        label: 'Focus Barcode / Search Box',
        defaultKeyLabel: 'Esc',
        isGlobalOrForm: true),
  ];

  static const List<String> customizableFKeys = [
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'F7',
    'F8',
    'F9',
    'F10',
    'F11',
    'F12',
  ];

  /// Decodes custom JSON map `{actionId: "F2", ...}` merged onto defaults.
  static Map<String, String> resolveBindings(String rawJson) {
    final map = <String, String>{
      for (final a in actions) a.id: a.defaultKeyLabel,
    };
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return map;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          final keyStr = k.toString();
          final valStr = v?.toString().trim() ?? '';
          if (map.containsKey(keyStr) && valStr.isNotEmpty) {
            map[keyStr] = valStr;
          }
        });
      }
    } catch (e, st) {
      AppLogger.warning(
          'KeyboardShortcuts', 'Failed decoding shortcuts JSON', e, st);
    }
    return map;
  }

  static String encodeBindings(Map<String, String> bindings) {
    final clean = <String, String>{};
    for (final a in actions) {
      if (!a.isGlobalOrForm) {
        clean[a.id] = bindings[a.id] ?? a.defaultKeyLabel;
      }
    }
    return jsonEncode(clean);
  }

  static LogicalKeyboardKey? parseFunctionKey(String keyLabel) {
    switch (keyLabel.trim().toUpperCase()) {
      case 'F1':
        return LogicalKeyboardKey.f1;
      case 'F2':
        return LogicalKeyboardKey.f2;
      case 'F3':
        return LogicalKeyboardKey.f3;
      case 'F4':
        return LogicalKeyboardKey.f4;
      case 'F5':
        return LogicalKeyboardKey.f5;
      case 'F6':
        return LogicalKeyboardKey.f6;
      case 'F7':
        return LogicalKeyboardKey.f7;
      case 'F8':
        return LogicalKeyboardKey.f8;
      case 'F9':
        return LogicalKeyboardKey.f9;
      case 'F10':
        return LogicalKeyboardKey.f10;
      case 'F11':
        return LogicalKeyboardKey.f11;
      case 'F12':
        return LogicalKeyboardKey.f12;
      default:
        return null;
    }
  }
}
