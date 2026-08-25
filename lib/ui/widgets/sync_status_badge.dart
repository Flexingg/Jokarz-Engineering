import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import 'auth_account_modal.dart';

class SyncStatusBadge extends ConsumerWidget {
  final bool compact;
  const SyncStatusBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final user = ref.watch(authStateProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String label;
    Color color;
    IconData icon;

    if (user == null) {
      label = 'Local Only';
      color = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
      icon = Icons.cloud_off_rounded;
    } else {
      switch (syncState.status) {
        case SyncStatus.synced:
          label = 'Cloud Synced';
          color = AppTheme.accentEmerald;
          icon = Icons.cloud_done_rounded;
          break;
        case SyncStatus.syncing:
          label = 'Syncing...';
          color = AppTheme.accentAmber;
          icon = Icons.sync_rounded;
          break;
        case SyncStatus.offline:
          label = 'Offline Cache';
          color = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
          icon = Icons.cloud_queue_rounded;
          break;
        case SyncStatus.error:
          label = 'Sync Issue';
          color = AppTheme.accentCoral;
          icon = Icons.cloud_off_rounded;
          break;
      }
    }

    if (compact) {
      return IconButton(
        tooltip: '$label (${user?.email ?? "Not signed in"})',
        icon: Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (user?.photoURL != null)
              CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(user!.photoURL!),
                backgroundColor: isDark ? AppTheme.darkSurfaceCard : AppTheme.lightSurfaceCard,
              )
            else
              Icon(
                user != null ? Icons.account_circle_rounded : Icons.cloud_sync_rounded,
                color: color,
                size: 24,
              ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
        onPressed: () {
          showAuthAccountModal(context);
        },
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showAuthAccountModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
