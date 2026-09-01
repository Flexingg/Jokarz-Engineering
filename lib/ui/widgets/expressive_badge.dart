import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ExpressiveBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isOutlined;
  final double fontSize;

  const ExpressiveBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.isOutlined = false,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.of(context).primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? c.withValues(alpha: 0.08) : c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(
          color: c.withValues(alpha: isOutlined ? 0.8 : 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? c,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
