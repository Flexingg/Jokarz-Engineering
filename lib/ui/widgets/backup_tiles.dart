import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/backup_provider.dart';
import '../../providers/keybindings_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/time_block_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/bamm_report_provider.dart';
import '../../services/app_logger.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../screens/diagnostics_screen.dart';

/// Full-dataset backup / restore and the diagnostics log entry point. Lives in
/// the Settings "Data Persistence & Backup" card.
class BackupTiles extends ConsumerWidget {
  const BackupTiles({super.key});

  Future<Directory> _exportDir() async {
    try {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  void _toast(BuildContext context, String msg, {bool error = false}) {
    final colors = AppTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? colors.coral : colors.emerald,
    ));
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    try {
      final bytes = await service.buildBackup();
      final now = DateTime.now();
      final name =
          'jokarz_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.zip';
      final dir = await _exportDir();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      log.info('backup', 'Exported backup to ${file.path}');
      if (!context.mounted) return;
      _toast(context, 'Backup saved: ${file.path}');
      try {
        await Share.shareXFiles([XFile(file.path, mimeType: 'application/zip')],
            text: 'Jokarz Engineering backup');
      } catch (e) {
        log.warn('backup', 'Share sheet unavailable; file kept on disk', e);
      }
    } catch (e, stack) {
      log.error('backup', 'Backup export failed', e, stack);
      if (context.mounted) _toast(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );
      final picked0 = picked?.files.firstOrNull;
      if (picked0 == null) return;
      final List<int> bytes = picked0.bytes ??
          await File(picked0.path!).readAsBytes();

      final BackupInfo info = service.inspect(bytes);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text(
            'Backup from ${info.createdAt.toLocal().toString().substring(0, 16)} '
            'with ${info.fileCount} data files.\n\n'
            'Your current data is snapshotted first (Settings > backups folder), '
            'then replaced. If cloud sync is on, newer cloud edits may merge back in.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Restore')),
          ],
        ),
      );
      if (ok != true) return;

      await service.restore(bytes);
      // Recreate every provider that reads from disk so the UI reflects it.
      ref.invalidate(projectProvider);
      ref.invalidate(timeBlockProvider);
      ref.invalidate(keyBindingsProvider);
      ref.invalidate(reportSettingsProvider);
      ref.invalidate(bammReportSettingsProvider);
      if (context.mounted) _toast(context, 'Backup restored');
    } on BackupException catch (e) {
      log.warn('backup', 'Restore rejected', e.message);
      if (context.mounted) _toast(context, e.message, error: true);
    } catch (e, stack) {
      log.error('backup', 'Restore failed', e, stack);
      if (context.mounted) _toast(context, 'Restore failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.archive_rounded, color: colors.primary),
          title: const Text('Export Full Backup (.zip)'),
          subtitle: const Text(
            'Everything: projects, orders, notes, schedule, settings. Checksummed.',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _export(context, ref),
        ),
        const Divider(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.settings_backup_restore_rounded, color: colors.emerald),
          title: const Text('Restore From Backup (.zip)'),
          subtitle: const Text(
            'Validates the archive and snapshots current data first.',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _restore(context, ref),
        ),
        const Divider(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.bug_report_rounded, color: colors.amber),
          title: const Text('Diagnostics Log'),
          subtitle: ValueListenableBuilder<int>(
            valueListenable: log.revision,
            builder: (_, __, ___) => Text(
              '${log.entries.length} entries, ${log.errorCount} errors',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
        ),
        const Divider(height: 16),
      ],
    );
  }
}
