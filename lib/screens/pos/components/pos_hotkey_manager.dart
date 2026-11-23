import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/keyboard_shortcuts_service.dart';

/// Handles dynamic keyboard shortcuts, function key mappings, and action dispatching
/// for the POS terminal interface.
class PosHotkeyManager {
  PosHotkeyManager._();

  /// Builds the complete map of [ShortcutActivator] to [VoidCallback] for the POS terminal.
  static Map<ShortcutActivator, VoidCallback> buildShortcuts({
    required VoidCallback onToggleProductPanel,
    VoidCallback? onOpenDrawer,
    required VoidCallback onOpenCustomProductDialog,
    required VoidCallback onToggleWholesaleMode,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
    required VoidCallback onIncrementLastItem,
    required VoidCallback onDecrementLastItem,
    required VoidCallback onRemoveLastItem,
    required VoidCallback onEscape,
    required VoidCallback onShowShortcuts,
    required bool isCartNotEmpty,
    required bool isEditingText,
    required Map<String, String> shortcutBindings,
    required VoidCallback Function(String actionId) callbackForAction,
  }) {
    final map = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          onToggleProductPanel,
      if (onOpenDrawer != null)
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            onOpenDrawer,
      const SingleActivator(LogicalKeyboardKey.f11): onOpenCustomProductDialog,
      const SingleActivator(LogicalKeyboardKey.f12): onToggleWholesaleMode,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): onUndo,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): onRedo,
      const SingleActivator(LogicalKeyboardKey.numpadAdd): () {
        if (isCartNotEmpty && !isEditingText) {
          onIncrementLastItem();
        }
      },
      const SingleActivator(LogicalKeyboardKey.equal): () {
        if (isCartNotEmpty && !isEditingText) {
          onIncrementLastItem();
        }
      },
      const SingleActivator(LogicalKeyboardKey.numpadSubtract): () {
        if (isCartNotEmpty && !isEditingText) {
          onDecrementLastItem();
        }
      },
      const SingleActivator(LogicalKeyboardKey.minus): () {
        if (isCartNotEmpty && !isEditingText) {
          onDecrementLastItem();
        }
      },
      const SingleActivator(LogicalKeyboardKey.delete): () {
        if (isCartNotEmpty && !isEditingText) {
          onRemoveLastItem();
        }
      },
      const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      const SingleActivator(LogicalKeyboardKey.slash, shift: true):
          onShowShortcuts,
    };

    for (final spec in KeyboardShortcutsService.actions) {
      if (spec.isGlobalOrForm) continue;
      final assignedKey = shortcutBindings[spec.id] ?? spec.defaultKeyLabel;
      final logicalKey = KeyboardShortcutsService.parseFunctionKey(assignedKey);
      if (logicalKey != null) {
        map[SingleActivator(logicalKey)] = callbackForAction(spec.id);
      }
    }

    return map;
  }
}
