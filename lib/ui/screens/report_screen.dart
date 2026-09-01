import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/report_config.dart';
import '../../providers/project_provider.dart';
import '../../providers/report_provider.dart';
import '../../utils/report_builder.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final DateTime _today = DateTime.now();
  String? _selectedTemplate;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final settings = ref.watch(reportSettingsProvider);
    final cfg = settings.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = buildReportData(state, cfg, _today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Customize Report',
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryCyan),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => _ReportCustomizeSheet(initial: cfg),
            ),
          ),
          IconButton(
            tooltip: 'Save as Template',
            icon: const Icon(Icons.bookmark_add_outlined, color: AppTheme.accentAmber),
            onPressed: () => _saveAsTemplate(cfg),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Report',
            onSelected: (v) => _export(v, cfg),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'share_pdf', child: Text('PDF — Share')),
              PopupMenuItem(value: 'save_pdf', child: Text('PDF — Save to Downloads')),
              PopupMenuItem(value: 'share_txt', child: Text('Plain Text — Share')),
              PopupMenuItem(value: 'save_txt', child: Text('Plain Text — Save to Downloads')),
              PopupMenuItem(value: 'share_csv', child: Text('CSV — Share')),
              PopupMenuItem(value: 'save_csv', child: Text('CSV — Save to Downloads')),
              PopupMenuItem(value: 'share_png', child: Text('PNG Image — Share')),
              PopupMenuItem(value: 'save_png', child: Text('PNG Image — Save to Downloads')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Template toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTemplate,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Template',
                      prefixIcon: Icon(Icons.file_copy_outlined, size: 18),
                    ),
                    items: [
                      if (_selectedTemplate == null)
                        const DropdownMenuItem<String>(
                            value: null, child: Text('— current config —')),
                      ...settings.templates.keys.map(
                        (k) => DropdownMenuItem<String>(
                            value: k, child: Text(k, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (name) {
                      if (name == null) return;
                      setState(() => _selectedTemplate = name);
                      ref.read(reportSettingsProvider.notifier).loadTemplate(name);
                    },
                  ),
                ),
                if (_selectedTemplate != null)
                  IconButton(
                    tooltip: 'Delete Template',
                    icon: const Icon(Icons.delete_outline, color: AppTheme.accentCoral),
                    onPressed: () {
                      final n = _selectedTemplate!;
                      ref.read(reportSettingsProvider.notifier).deleteTemplate(n);
                      setState(() => _selectedTemplate = null);
                    },
                  ),
              ],
            ),
          ),

          // Scrollable report
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _repaintKey,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.black87 : Colors.black87,
                  ),
                  child: _buildReportContent(data, cfg, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(ReportData data, ReportConfig cfg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d, y').format(_today),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const Divider(color: Colors.black87, height: 14),

          if (cfg.showPriority) ...[
            _Section('Top Projects & Next Steps', () {
              if (data.projects.isEmpty) return const _None();
              if (cfg.groupByMachine) {
                final groups = <String, List<ReportProject>>{};
                for (final p in data.projects) {
                  final key = p.machine.isNotEmpty ? p.machine : 'General';
                  groups.putIfAbsent(key, () => []).add(p);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('▸ ${entry.key}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                      ...entry.value.map((p) => _projectRow(p)),
                    ],
                  ],
                );
              }
              return Column(children: [for (final p in data.projects) _projectRow(p)]);
            }),
            const _Sp(),
          ],

          if (cfg.showOrders) ...[
            _Section('Orders Due (${cfg.ordersDueDays} Days)', () {
              if (data.orders.isEmpty) return const _None();
              return Column(children: [for (final o in data.orders) _orderRow(o)]);
            }),
            const _Sp(),
          ],

          if (cfg.showStores) ...[
            _Section('Stores Requests Pending', () {
              if (data.stores.isEmpty) return const _None();
              return Column(children: [for (final o in data.stores) _orderRow(o)]);
            }),
            const _Sp(),
          ],

          if (cfg.showDueToday) ...[
            _Section('Due / Happening Today', () {
              if (data.dueToday.isEmpty) return const _None();
              return Column(
                children: [
                  for (final t in data.dueToday)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${t.project}: ${t.task}',
                          style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                ],
              );
            }),
            const _Sp(),
          ],

          if (cfg.showNotes) ...[
            _Section('Notes (${DateFormat('MM/dd/yyyy').format(_today)})', () {
              if (data.notes.isEmpty) return const _None();
              return Column(
                children: [
                  for (final n in data.notes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• ${n.label}: ${n.text}',
                          style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3)),
                    ),
                ],
              );
            }),
            const _Sp(),
          ],

          if (cfg.showCost) ...[
            _Section('Cost Summary', () {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Open PO: \$${data.totalOpenCost.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                  for (final p in data.topByCost)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('  ${p.title} — \$${p.cost.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                ],
              );
            }),
            const _Sp(),
          ],

          if (cfg.showClosed) ...[
            _Section('Recently Closed', () {
              if (data.closed.isEmpty) return const _None();
              return Column(children: [for (final p in data.closed) _projectRow(p)]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _projectRow(ReportProject p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#${p.priority}  ${p.title}  [${p.phase}]',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
          if (p.machine.isNotEmpty)
            Text('   Machine: ${p.machine}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text('   Next: ${p.nextStep}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _orderRow(ReportOrder o) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '${o.eta}  ${o.project}  PO ${o.po.isEmpty ? '—' : o.po}  \$${o.price.toStringAsFixed(2)}  ${o.desc}'
        '${o.store.isNotEmpty ? '  [${o.store}]' : ''}',
        style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
      ),
    );
  }

  Future<void> _saveAsTemplate(ReportConfig cfg) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Report Template'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name', hintText: 'e.g. Morning 5-day'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : 'Template'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await ref.read(reportSettingsProvider.notifier).saveTemplate(name, cfg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Template "$name" saved'),
        backgroundColor: AppTheme.accentEmerald,
      ));
    }
  }

  /// Builds and writes the requested report format to [dir], returning the File.
  /// `format` is one of: png, pdf, txt, csv.
  Future<File> _writeReportFile(
      Directory dir, String format, String filename, ReportConfig cfg) async {
    final state = ref.read(projectProvider);
    final data = buildReportData(state, cfg, _today);
    final f = File('${dir.path}/$filename');
    if (format == 'png') {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await f.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } else if (format == 'pdf') {
      final pdfBytes = await reportToPdf(data, cfg, _today);
      await f.writeAsBytes(pdfBytes, flush: true);
    } else if (format == 'txt') {
      await f.writeAsString(reportToText(data, cfg, _today), flush: true);
    } else if (format == 'csv') {
      await f.writeAsString(reportToCsv(data, cfg, _today), flush: true);
    }
    return f;
  }

  static String _mime(String format) {
    switch (format) {
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'csv':
        return 'text/csv';
      default:
        return 'text/plain';
    }
  }

  /// Dispatch a menu action of the form `<share|save>_<format>`.
  Future<void> _export(String action, ReportConfig cfg) async {
    final idx = action.indexOf('_');
    final mode = action.substring(0, idx);
    final format = action.substring(idx + 1);
    if (mode == 'save') {
      await _saveToDownloads(format, cfg);
    } else {
      await _share(format, cfg);
    }
  }

  /// Writes the report to a permanent, user-visible location (Downloads on
  /// Windows/Linux/desktop, Documents elsewhere) so the engineer can find and
  /// keep the file — not just hand it to the OS share sheet.
  Future<void> _saveToDownloads(String format, ReportConfig cfg) async {
    final base = 'jokarz_report_${DateFormat('MMddyy').format(_today)}';
    final stamp = DateFormat('HHmmss').format(DateTime.now());
    try {
      Directory dir;
      String locationLabel;
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          dir = downloads;
          locationLabel = 'Downloads';
        } else {
          dir = await getApplicationDocumentsDirectory();
          locationLabel = 'Documents';
        }
      } catch (_) {
        dir = await getTemporaryDirectory();
        locationLabel = 'temp';
      }
      final f = await _writeReportFile(dir, format, '$base-$stamp.$format', cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report saved to $locationLabel: ${f.path.split('/').last}'),
          backgroundColor: AppTheme.accentEmerald,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  /// Builds the report in the temp dir and hands it to the OS share sheet.
  Future<void> _share(String format, ReportConfig cfg) async {
    final base = 'jokarz_report_${DateFormat('MMddyy').format(_today)}';
    try {
      final dir = await getTemporaryDirectory();
      final f = await _writeReportFile(dir, format, '$base.$format', cfg);
      await Share.shareXFiles(
          [XFile(f.path, mimeType: _mime(format))], text: 'Jokarz Daily Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget Function() buildChild;
  const _Section(this.title, this.buildChild);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
        const Divider(color: Colors.black54, height: 10),
        buildChild(),
      ],
    );
  }
}

class _None extends StatelessWidget {
  const _None();
  @override
  Widget build(BuildContext context) =>
      const Text('None.', style: TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic));
}

class _Sp extends StatelessWidget {
  const _Sp();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}

class _ReportCustomizeSheet extends ConsumerStatefulWidget {
  final ReportConfig initial;
  const _ReportCustomizeSheet({required this.initial});

  @override
  ConsumerState<_ReportCustomizeSheet> createState() => _ReportCustomizeSheetState();
}

class _ReportCustomizeSheetState extends ConsumerState<_ReportCustomizeSheet> {
  late ReportConfig _cfg = widget.initial;

  void _apply(ReportConfig next) {
    setState(() => _cfg = next);
    ref.read(reportSettingsProvider.notifier).setConfig(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customize Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sections', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Top Projects & Next Steps'),
              value: _cfg.showPriority,
              onChanged: (v) => _apply(_cfg.copyWith(showPriority: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Orders Due'),
              value: _cfg.showOrders,
              onChanged: (v) => _apply(_cfg.copyWith(showOrders: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Stores Requests Pending'),
              value: _cfg.showStores,
              onChanged: (v) => _apply(_cfg.copyWith(showStores: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Due / Happening Today'),
              value: _cfg.showDueToday,
              onChanged: (v) => _apply(_cfg.copyWith(showDueToday: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Notes (today\u2019s date)'),
              value: _cfg.showNotes,
              onChanged: (v) => _apply(_cfg.copyWith(showNotes: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Cost Summary'),
              value: _cfg.showCost,
              onChanged: (v) => _apply(_cfg.copyWith(showCost: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Recently Closed'),
              value: _cfg.showClosed,
              onChanged: (v) => _apply(_cfg.copyWith(showClosed: v)),
            ),
            const Divider(),
            const Text('Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            _SliderRow('Orders due within N days', _cfg.ordersDueDays, 1, 30, (v) => _apply(_cfg.copyWith(ordersDueDays: v))),
            _SliderRow('Recently closed within N days', _cfg.notTouchedDays, 1, 60, (v) => _apply(_cfg.copyWith(notTouchedDays: v))),
            _SliderRow('Top projects shown', _cfg.topProjectsLimit, 1, 25, (v) => _apply(_cfg.copyWith(topProjectsLimit: v))),
            _SliderRow('Max orders per section', _cfg.maxOrders, 1, 30, (v) => _apply(_cfg.copyWith(maxOrders: v))),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReportSort>(
              value: _cfg.sortBy,
              decoration: const InputDecoration(labelText: 'Sort top projects by', isDense: true),
              items: const [
                DropdownMenuItem(value: ReportSort.priority, child: Text('Priority')),
                DropdownMenuItem(value: ReportSort.cost, child: Text('Cost')),
                DropdownMenuItem(value: ReportSort.nextAction, child: Text('Next action (last touched)')),
              ],
              onChanged: (v) => v == null ? null : _apply(_cfg.copyWith(sortBy: v)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Group projects by Machine/Line'),
              value: _cfg.groupByMachine,
              onChanged: (v) => _apply(_cfg.copyWith(groupByMachine: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include completed projects'),
              value: _cfg.includeCompleted,
              onChanged: (v) => _apply(_cfg.copyWith(includeCompleted: v)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _SliderRow(this.label, this.value, this.min, this.max, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        SizedBox(width: 120, child: Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        )),
        SizedBox(width: 30, child: Text('$value', style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}
