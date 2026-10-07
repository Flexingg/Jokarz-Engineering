import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// A vendor's SAP vendor code, shown next to the vendor wherever the vendor is
/// picked or displayed. Tap to copy. Renders nothing for an empty code.
class SapCodeChip extends StatelessWidget {
  final String code;
  final bool dense;
  const SapCodeChip(this.code, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final colors = AppTheme.of(context);
    return Tooltip(
      message: 'SAP vendor code. Click to copy.',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: trimmed));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('Copied SAP code $trimmed')));
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 2 : 6),
          decoration: BoxDecoration(
            color: colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SAP',
                  style: TextStyle(
                      fontSize: dense ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
              SizedBox(width: dense ? 4 : 6),
              Text(trimmed,
                  style: TextStyle(
                      fontSize: dense ? 11 : 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ),
    );
  }
}
