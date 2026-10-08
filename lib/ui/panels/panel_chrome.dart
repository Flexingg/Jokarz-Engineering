import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'autosave.dart';

/// The rounded card, title row, save-status label and close button shared by
/// the right-hand editors.
class PanelChrome extends StatelessWidget {
  final String title;
  final ValueListenable<SaveStatus> status;
  final VoidCallback onRetry;
  final Future<void> Function() onClose;
  final Future<void> Function() onBlur;
  final Widget child;

  const PanelChrome({
    super.key,
    required this.title,
    required this.status,
    required this.onRetry,
    required this.onClose,
    required this.onBlur,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return AutosaveScope(
      onBlur: () => onBlur(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    SaveStatusLabel(status: status, onRetry: onRetry),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await onClose();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
