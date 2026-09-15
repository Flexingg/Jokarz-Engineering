import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

/// Clickable badge/chip representing an assigned BAMM Work Order.
/// Tapping it navigates to the BAMM page focusing on this work order.
class BammChip extends StatelessWidget {
  final String worNo;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool isDense;

  const BammChip({
    super.key,
    String? worNo,
    String? workOrderNo,
    this.onDeleted,
    this.onTap,
    this.isDense = false,
  }) : worNo = (worNo ?? workOrderNo ?? '');

  @override
  Widget build(BuildContext context) {
    final cleanNo = worNo.trim();
    if (cleanNo.isEmpty) return const SizedBox.shrink();

    final labelText = cleanNo.toUpperCase().startsWith('WO') || cleanNo.toUpperCase().startsWith('BAMM')
        ? cleanNo
        : '#$cleanNo';

    return InkWell(
      onTap: onTap ??
          () {
            context.push('/bamm?wo=${Uri.encodeComponent(cleanNo)}');
          },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDense ? 6 : 8,
          vertical: isDense ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: AppTheme.of(context).primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: AppTheme.of(context).primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.precision_manufacturing_rounded,
              size: isDense ? 11 : 13,
              color: AppTheme.of(context).primary,
            ),
            const SizedBox(width: 4),
            Text(
              'BAMM $labelText',
              style: TextStyle(
                fontSize: isDense ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.of(context).primary,
                letterSpacing: 0.2,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(
                  Icons.close_rounded,
                  size: isDense ? 12 : 14,
                  color: AppTheme.of(context).primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
