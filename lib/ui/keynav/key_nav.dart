import '../fluid/fluid_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Which row of a list is highlighted, and the keyboard focus that drives it.
/// One controller per list screen; rows read [selected], the screen reads it
/// to act on the highlighted row.
class KeyNavController extends ChangeNotifier {
  final FocusNode focus = FocusNode(debugLabel: 'list key navigation');
  int _selected = -1;
  int _count = 0;

  /// Index of the highlighted row, or -1 when nothing is highlighted.
  int get selected => _selected;

  void setCount(int count) {
    _count = count;
    if (_selected >= count) {
      _selected = count - 1;
      // Safe: only called from build, notifications run next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void select(int index) {
    final next = _count == 0 ? -1 : index.clamp(0, _count - 1);
    if (next == _selected) return;
    _selected = next;
    notifyListeners();
  }

  void move(int delta) => select(_selected < 0 ? 0 : _selected + delta);

  void clear() {
    if (_selected == -1) return;
    _selected = -1;
    notifyListeners();
  }

  /// Takes keyboard focus (call when a row is clicked so the keys work).
  void takeFocus() => focus.requestFocus();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }
}

bool _typingInATextField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
      ctx.widget is EditableText;
}

/// Gives a list screen Up/Down (or J/K), Home/End, Enter, Space and Esc, plus
/// any extra single-key actions in [keys], without ever stealing keys from a
/// text field. `?` shows the cheat sheet.
class KeyNav extends StatelessWidget {
  final KeyNavController controller;
  final int count;

  /// Enter on the highlighted row.
  final ValueChanged<int>? onActivate;

  /// Space on the highlighted row.
  final ValueChanged<int>? onToggle;

  /// Esc.
  final VoidCallback? onEscape;

  /// The highlight moved to a new row (arrow keys, Home, End).
  final ValueChanged<int>? onMoved;

  /// Grab keyboard focus when the screen first shows. Off for a list nested
  /// beside another one (the project detail beside the project list).
  final bool autofocus;

  /// Extra keys, e.g. `{LogicalKeyboardKey.keyD: (i) => ...}`.
  final Map<LogicalKeyboardKey, ValueChanged<int>> keys;

  /// What the extra keys do, for the `?` sheet: `'D': 'Mark delivered'`.
  final Map<String, String> help;
  final Widget child;

  const KeyNav({
    super.key,
    required this.controller,
    required this.count,
    required this.child,
    this.onActivate,
    this.onToggle,
    this.onEscape,
    this.onMoved,
    this.autofocus = true,
    this.keys = const {},
    this.help = const {},
  });

  @override
  Widget build(BuildContext context) {
    controller.setCount(count);
    return Focus(
      focusNode: controller.focus,
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (_typingInATextField()) return KeyEventResult.ignored;
        // Leave Ctrl/Alt/Meta shortcuts to the app-wide handler.
        final hk = HardwareKeyboard.instance;
        if (hk.isControlPressed || hk.isAltPressed || hk.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final sel = controller.selected;

        if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.keyJ) {
          controller.move(1);
          onMoved?.call(controller.selected);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.keyK) {
          controller.move(-1);
          onMoved?.call(controller.selected);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.home) {
          controller.select(0);
          onMoved?.call(controller.selected);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.end) {
          controller.select(count - 1);
          onMoved?.call(controller.selected);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          if (onEscape != null) onEscape!();
          controller.clear();
          return onEscape != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (event.character == '?') {
          showKeyboardHelp(context, help);
          return KeyEventResult.handled;
        }
        if (sel < 0 || sel >= count) return KeyEventResult.ignored;
        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        if (key == LogicalKeyboardKey.enter && onActivate != null) {
          onActivate!(sel);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.space && onToggle != null) {
          onToggle!(sel);
          return KeyEventResult.handled;
        }
        final extra = keys[key];
        if (extra != null) {
          extra(sel);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // Clicking anywhere in the list hands it the keyboard. A text field or
      // button clicked afterwards still takes focus itself.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!controller.focus.hasFocus) controller.takeFocus();
        },
        child: child,
      ),
    );
  }
}

/// Wraps one row: outlines it while highlighted, and scrolls it into view
/// when the highlight arrives (only then, and only as far as needed, so a
/// rebuild while typing elsewhere never moves the list).
class KeyNavItem extends StatefulWidget {
  final KeyNavController controller;
  final int index;
  final Widget child;
  final double radius;

  const KeyNavItem({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
    this.radius = AppTheme.radiusLg,
  });

  @override
  State<KeyNavItem> createState() => _KeyNavItemState();
}

class _KeyNavItemState extends State<KeyNavItem> {
  late bool _on = widget.controller.selected == widget.index;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(KeyNavItem old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _on = widget.controller.selected == widget.index;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final on = widget.controller.selected == widget.index;
    if (on == _on) return;
    setState(() => _on = on);
    if (!on) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const d = Duration(milliseconds: 120);
      Scrollable.ensureVisible(context,
          duration: d, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      Scrollable.ensureVisible(context,
          duration: d, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _on ? AppTheme.of(context).primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: widget.child,
    );
  }
}

const Map<String, String> _commonKeys = {
  'Up / Down  (or K / J)': 'Move through the list',
  'Home / End': 'First / last row',
  'Enter': 'Open the highlighted row',
  'Esc': 'Close the panel / clear the highlight',
  '?': 'This list',
  'Ctrl+K': 'Command palette',
};

Future<void> showKeyboardHelp(BuildContext context, Map<String, String> extra) {
  final rows = {..._commonKeys, ...extra};
  return showFluidDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in rows.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
