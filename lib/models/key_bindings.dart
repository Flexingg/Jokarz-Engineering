import 'package:flutter/services.dart';

/// Default key combinations (lowercase, `+`-separated modifiers then key).
const Map<String, String> defaultKeyBindings = {
  'createNote': 'ctrl+n',
  'createProject': 'ctrl+shift+n',
  'createOrder': 'ctrl+o',
  'tabDashboard': 'ctrl+1',
  'tabProjects': 'ctrl+2',
  'tabOrders': 'ctrl+3',
  'tabWorkbench': 'ctrl+4',
  'tabNotes': 'ctrl+5',
  'tabSettings': 'ctrl+6',
  'tabBamm': 'ctrl+7',
  'palette': 'ctrl+k',
  'toggleSidebar': 'ctrl+b',
};

/// Human-readable labels for each action.
const Map<String, String> keyBindingsLabels = {
  'createNote': 'Create Note',
  'createProject': 'Create Project',
  'createOrder': 'Create Order',
  'tabDashboard': 'Go to Dashboard',
  'tabProjects': 'Go to Projects',
  'tabOrders': 'Go to Open Orders',
  'tabWorkbench': 'Go to Workbench',
  'tabNotes': 'Go to Notes',
  'tabSettings': 'Go to Settings',
  'tabBamm': 'Go to BAMM Orders',
  'palette': 'Search and Commands',
  'toggleSidebar': 'Toggle Sidebar',
};

/// Brings a saved shortcut file up to date: the removed Search screen's
/// binding moves to the command palette (only if the user had customised it),
/// and bindings for actions that no longer exist are dropped.
Map<String, String> migrateSavedBindings(Map<String, String> saved) {
  const oldSearchDefault = 'ctrl+shift+s';
  final out = Map<String, String>.of(saved);
  final oldSearch = out.remove('search');
  if (oldSearch != null && oldSearch != oldSearchDefault && !out.containsKey('palette')) {
    out['palette'] = oldSearch;
  }
  out.removeWhere((id, _) => !defaultKeyBindings.containsKey(id));
  return out;
}

/// `ctrl+shift+n` -> `Ctrl+Shift+N`, for menus and hints.
String prettyCombo(String combo) => combo
    .split('+')
    .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
    .join('+');

/// Computes the pressed key combination (e.g. `ctrl+shift+s`) for a key event,
/// ignoring pure modifier presses. Returns null for non-keydown or modifier-only
/// events.
String? comboForEvent(KeyEvent event, {HardwareKeyboard? keyboard}) {
  if (event is! KeyDownEvent) return null;
  final lk = event.logicalKey;
  if (lk == LogicalKeyboardKey.controlLeft ||
      lk == LogicalKeyboardKey.controlRight ||
      lk == LogicalKeyboardKey.shiftLeft ||
      lk == LogicalKeyboardKey.shiftRight ||
      lk == LogicalKeyboardKey.altLeft ||
      lk == LogicalKeyboardKey.altRight ||
      lk == LogicalKeyboardKey.metaLeft ||
      lk == LogicalKeyboardKey.metaRight) {
    return null;
  }
  final hw = keyboard ?? HardwareKeyboard.instance;
  final parts = <String>[];
  if (hw.isControlPressed) parts.add('ctrl');
  if (hw.isAltPressed) parts.add('alt');
  if (hw.isShiftPressed) parts.add('shift');
  if (hw.isMetaPressed) parts.add('meta');
  final label = lk.keyLabel.toLowerCase().trim();
  if (label.isEmpty || label == ' ') return null;
  parts.add(label);
  return parts.join('+');
}
