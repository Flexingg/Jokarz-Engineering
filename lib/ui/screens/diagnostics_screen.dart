import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';

/// Live view of the in-app diagnostics log (see [AppLogger]).
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics Log'),
        actions: [
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log.exportText()));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Log copied')));
              }
            },
          ),
          IconButton(
            tooltip: 'Share log',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(
              log.exportText(),
              subject: 'Jokarz Engineering diagnostics',
            ),
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => log.clear(),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: log.revision,
        builder: (context, _, __) {
          final entries = log.entries.reversed.toList();
          if (entries.isEmpty) {
            return const Center(child: Text('No log entries yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              final color = switch (e.level) {
                LogLevel.error => colors.coral,
                LogLevel.warning => colors.amber,
                LogLevel.info => colors.textSecondary,
              };
              return SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${e.time.toIso8601String().substring(11, 19)} '
                          '${e.level.name.toUpperCase()} ${e.tag}\n',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text:
                          e.message +
                          (e.error != null ? '\n${e.error}' : '') +
                          (e.stack != null ? '\n${e.stack}' : ''),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
