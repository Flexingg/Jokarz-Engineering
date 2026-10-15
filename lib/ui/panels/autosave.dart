import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';

enum SaveStatus { idle, pending, saving, saved, failed }

/// Autosave for an edit form that lives in a side panel.
///
/// Edits are written when the user clicks off the form ([AutosaveScope]),
/// when the panel is closed or swapped for another record (State dispose),
/// and after [idleDelay] with no typing, so a crash loses at most a moment.
/// Implement [saveDraft]; call [markDirty] from every change.
mixin AutosaveMixin<T extends StatefulWidget> on State<T> {
  static const Duration idleDelay = Duration(milliseconds: 1500);

  final ValueNotifier<SaveStatus> saveStatus = ValueNotifier(SaveStatus.idle);
  Timer? _idle;
  Timer? _fade;
  bool _dirty = false;
  bool _saving = false;

  /// Persist the current form values. Throw to report a failure. Do nothing
  /// (return) when the form is not valid yet, e.g. a required field is empty.
  Future<void> saveDraft();

  /// False while the form cannot be saved (keeps the status at "pending").
  bool get canSave => true;

  void markDirty() {
    _dirty = true;
    saveStatus.value = SaveStatus.pending;
    _idle?.cancel();
    _idle = Timer(idleDelay, flush);
  }

  /// Saves now if there is anything unsaved.
  Future<void> flush() async {
    _idle?.cancel();
    if (!_dirty || _saving) return;
    if (!canSave) return;
    _dirty = false;
    _saving = true;
    saveStatus.value = SaveStatus.saving;
    try {
      await saveDraft();
      saveStatus.value = SaveStatus.saved;
      _fade?.cancel();
      _fade = Timer(const Duration(seconds: 3), () {
        if (saveStatus.value == SaveStatus.saved)
          saveStatus.value = SaveStatus.idle;
      });
    } catch (e, stack) {
      _dirty = true;
      log.error('autosave', 'Could not save edits', e, stack);
      saveStatus.value = SaveStatus.failed;
    } finally {
      _saving = false;
    }
  }

  /// Call from `dispose()` BEFORE `super.dispose()`: writes unsaved edits when
  /// the user closes the panel or selects another record. The notifier calls
  /// inside [saveDraft] must therefore not depend on this widget's `context`.
  void disposeAutosave() {
    _idle?.cancel();
    _fade?.cancel();
    if (_dirty && canSave) {
      _dirty = false;
      // Deferred: dispose runs while the framework is tearing the tree down,
      // and providers cannot be modified then.
      unawaited(
        Future<void>.microtask(saveDraft).catchError(
          (Object e, StackTrace s) =>
              log.error('autosave', 'Save on close failed', e, s),
        ),
      );
    }
    saveStatus.dispose();
  }
}

/// Flushes [onBlur] whenever focus leaves everything inside [child].
class AutosaveScope extends StatelessWidget {
  final VoidCallback onBlur;
  final Widget child;
  const AutosaveScope({super.key, required this.onBlur, required this.child});

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (hasFocus) {
      if (!hasFocus) onBlur();
    },
    child: child,
  );
}

/// Small "Saving... / Saved / Could not save" label for a panel header.
class SaveStatusLabel extends StatelessWidget {
  final ValueListenable<SaveStatus> status;
  final VoidCallback? onRetry;
  const SaveStatusLabel({super.key, required this.status, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return ValueListenableBuilder<SaveStatus>(
      valueListenable: status,
      builder: (context, s, _) {
        final (text, color) = switch (s) {
          SaveStatus.idle => ('', colors.textSecondary),
          SaveStatus.pending => ('Unsaved changes', colors.textSecondary),
          SaveStatus.saving => ('Saving...', colors.textSecondary),
          SaveStatus.saved => ('Saved', colors.emerald),
          SaveStatus.failed => ('Could not save. Click to retry', colors.coral),
        };
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: s == SaveStatus.idle ? 0 : 1,
          child: InkWell(
            onTap: s == SaveStatus.failed ? onRetry : null,
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        );
      },
    );
  }
}
