import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/auth_service.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/auth_account_modal.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final state = ref.watch(projectProvider);
    final user = ref.watch(authStateProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workshop Settings & Data',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Google Account & Cloud Sync Section
          const Text(
            'Google Account & Cloud Synchronization',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.cloud_sync_rounded,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user != null
                                  ? (user.displayName ?? 'Google User')
                                  : 'Cross-Device Cloud Sync',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user != null
                                  ? user.email!
                                  : 'Sync Android ⇄ Windows in real time',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SyncStatusBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      user != null
                          ? Icons.manage_accounts_rounded
                          : Icons.g_mobiledata_rounded,
                      size: 20,
                    ),
                    label: Text(
                      user != null
                          ? 'Manage Cloud Sync / Account'
                          : 'Sign In with Google to Sync',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user != null
                          ? AppTheme.primaryCyan
                          : Colors.white,
                      foregroundColor: user != null
                          ? Colors.black87
                          : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => showAuthAccountModal(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Theme Section
          const Text(
            'Appearance & UI Style',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppTheme.primaryCyan,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Theme Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          themeMode == ThemeMode.dark
                              ? 'Material Expressive Dark (Obsidian)'
                              : 'Material Expressive Light (Clean Steel)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: themeMode == ThemeMode.dark,
                  activeColor: AppTheme.primaryCyan,
                  onChanged: (_) => themeNotifier.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Backup & Export
          const Text(
            'Data Persistence & Backup',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.data_object_rounded, color: AppTheme.primaryCyan),
                  title: const Text('Export Complete Engineering JSON Database'),
                  subtitle: Text(
                    '${state.projects.length} projects, ${state.voiceNotes.length} voice notes',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final data = {
                      'version': 3,
                      'updatedAt': DateTime.now().toIso8601String(),
                      'projects': state.projects.map((e) => e.toJson()).toList(),
                      'voiceNotes': state.voiceNotes.map((e) => e.toJson()).toList(),
                    };
                    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Engineering JSON Database Export'),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            jsonStr,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_upload_outlined, color: AppTheme.accentEmerald),
                  title: const Text('Import Engineering JSON Database'),
                  subtitle: const Text(
                    'Populate or restore projects, tasks, orders, and notes from JSON.',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final jsonCtrl = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Import JSON Database'),
                        content: SizedBox(
                          width: 500,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Paste JSON data below:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    TextButton.icon(
                                      icon: const Icon(Icons.help_outline_rounded, size: 14),
                                      label: const Text('Format Guide & Template', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _showJsonGuideDialog(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: jsonCtrl,
                                  maxLines: 8,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                  decoration: const InputDecoration(
                                    hintText: '{\n  "projects": [...],\n  "voiceNotes": [...]\n}',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final text = jsonCtrl.text.trim();
                              if (text.isEmpty) return;
                              final success = await ref.read(projectProvider.notifier).importJson(text);
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Database successfully imported!'
                                          : 'Invalid JSON format. Check Guide for schema.',
                                    ),
                                    backgroundColor: success ? AppTheme.accentEmerald : AppTheme.accentCoral,
                                  ),
                                );
                              }
                            },
                            child: const Text('Import & Restore'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_rounded, color: AppTheme.accentCoral),
                  title: const Text('Reset All Data to Blank Slate', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Permanently clears all projects, tasks, orders, and field notes.',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Engineering Data?'),
                        content: const Text('This will wipe all active and completed projects, tasks, orders, and notes back to a clean blank slate.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
                            onPressed: () async {
                              await ref.read(projectProvider.notifier).clearAllData();
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('All data reset to blank slate')),
                                );
                              }
                            },
                            child: const Text('Reset to Blank Slate'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Application & Plant Engineering Suite
          const Text(
            'About Application',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Engineered by Jonathan Randall (Flexingg / Randall Engineering).',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tailored for plant floor mechanical engineers managing line maintenance, Kaizen improvements, CapEx machinery projects, downtime tasks, and open purchase orders with offline persistence and workshop mechanical diagnostics.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bottom Branding Footer (Only location in app)
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryCyan, AppTheme.primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Colors.black87,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Jokarz Engineering',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Randall Engineering Suite • v1.0.1 Release',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const ExpressiveBadge(
                  label: 'v1.0.1',
                  color: AppTheme.accentEmerald,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showJsonGuideDialog(BuildContext context) {
    const exampleJson = '''{
  "version": 3,
  "projects": [
    {
      "id": "proj-uuid-1",
      "title": "Line 1 Filler Starwheel Guide Overhaul",
      "category": "maintenance",
      "phase": "Installation",
      "machine": "Line 1 Filler",
      "subAssembly": "Infeed Starwheel",
      "priority": 1,
      "cost": 3200.0,
      "description": "Replace worn UHMW guides and rebuild indexer gearbox.",
      "tags": ["Filler", "Line 1", "Overhaul"],
      "tasks": [
        {
          "id": "task-uuid-101",
          "description": "Machine new 1/2in UHMW starwheel guides",
          "scheduledDate": "2026-08-28T00:00:00.000Z",
          "pendingReason": "Pending mill downtime",
          "isCompleted": false
        }
      ],
      "orders": [
        {
          "id": "ord-uuid-201",
          "pr": "PR-48901",
          "po": "PO-9921004",
          "description": "McMaster UHMW 1/2in Sheet",
          "price": 184.50,
          "eta": "2026-08-27T00:00:00.000Z",
          "delivered": false
        }
      ]
    }
  ],
  "voiceNotes": [
    {
      "id": "note-uuid-1",
      "title": "Drive Gear Backlash Measurement",
      "transcript": "Measured 0.012in backlash on infeed drive gear with dial indicator.",
      "timestamp": "2026-08-25T08:30:00.000Z",
      "durationSeconds": 0,
      "projectId": "proj-uuid-1"
    }
  ]
}''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('JSON Database Schema Guide'),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📋 Schema Key Reference:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                ),
                const SizedBox(height: 6),
                const Text('• projects: Array of projects.\n  - title (Required String): Name of project.\n  - category (Optional): "maintenance", "kaizen", or "capital".\n  - phase (Optional): "Idea", "Pending", "Installation", "Validation", "Complete", "Cancelled", or custom string.\n  - machine & subAssembly (Optional Strings): Plant equipment.\n  - priority (Optional Int): 1 to X unique rank.\n  - cost (Optional Double): Budget or PO total.\n  - tasks (Optional Array): Objects with description, scheduledDate (ISO string), pendingReason, isCompleted (bool).\n  - orders (Optional Array): Objects with pr, po, description, price (double), eta (ISO string), delivered (bool).\n• voiceNotes: Array of written/voice field notes with title, transcript, timestamp, projectId.', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sample JSON Template:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy Template', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: exampleJson));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sample JSON template copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: const SelectableText(
                    exampleJson,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
