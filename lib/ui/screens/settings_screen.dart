import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final state = ref.watch(projectProvider);
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
          // App Header
          Row(
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
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jokarz Engineering',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Randall Engineering Suite • v1.0.0 Release',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const ExpressiveBadge(
                label: 'v1.0.0',
                color: AppTheme.accentEmerald,
              ),
            ],
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
                      'projects': state.projects.map((e) => e.toJson()).toList(),
                      'voiceNotes': state.voiceNotes.map((e) => e.toJson()).toList(),
                      'filaments': state.filaments.map((e) => e.toJson()).toList(),
                    };
                    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Jokarz Engineering JSON Export'),
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Randall Engineering
          const Text(
            'About Jokarz Engineering',
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
                  'Built with Flutter, Riverpod, GoRouter, and Material Expressive design system. Features offline-first local persistence, multi-discipline BOM costing, 3D printing slicer estimation, hardware bolt specs, electronics circuit solvers, and workshop voice speech-to-text dictation for Windows and Android.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
