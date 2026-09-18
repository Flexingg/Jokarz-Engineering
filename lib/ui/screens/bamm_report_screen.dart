import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bamm_report_config.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/bamm_report_provider.dart';
import '../../services/bamm_report_integrity.dart';
import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/bamm_report_pdf.dart';
import '../widgets/bamm_table_columns.dart';

/// The customizable BAMM work-order print report: field picker reuses the
/// real table column catalogue, plus saved filters, sort, grouping, and
/// named templates (e.g. "Monday walk-around").
class BammReportScreen extends ConsumerStatefulWidget {
  const BammReportScreen({super.key});

  @override
  ConsumerState<BammReportScreen> createState() => _BammReportScreenState();
}

class _BammReportScreenState extends ConsumerState<BammReportScreen> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(bammReportSettingsProvider);
    final cfg = settings.current;
    final bammState = ref.watch(bammProvider);
    final allColumns = buildBammColumns();

    void update(BammReportConfig Function(BammReportConfig) fn) {
      ref.read(bammReportSettingsProvider.notifier).setConfig(fn(cfg));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BAMM Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TemplateBar(cfg: cfg, templates: settings.templates),
          const SizedBox(height: 16),
          const Text('Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('Reuses the same column catalogue as the table.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          for (final col in allColumns)
            CheckboxListTile(
              key: Key('report_col_${col.id}'),
              dense: true,
              title: Text(col.header),
              value: cfg.columnIds.contains(col.id),
              onChanged: (checked) {
                final ids = List<String>.from(cfg.columnIds);
                if (checked == true) {
                  if (!ids.contains(col.id)) ids.add(col.id);
                } else {
                  ids.remove(col.id);
                }
                update((c) => c.copyWith(columnIds: ids));
              },
            ),
          const Divider(),
          const Text('Filter, sort, grouping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          DropdownButtonFormField<String?>(
            key: const Key('report_saved_filter'),
            initialValue: cfg.savedFilterName,
            decoration: const InputDecoration(labelText: 'Saved filter'),
            items: [
              const DropdownMenuItem(value: null, child: Text('(current table filter)')),
              for (final f in bammState.savedFilters) DropdownMenuItem(value: f.name, child: Text(f.name)),
            ],
            onChanged: (v) => update((c) => c.copyWith(savedFilterName: v, clearSavedFilterName: v == null)),
          ),
          DropdownButtonFormField<BammReportGroupBy>(
            key: const Key('report_group_by'),
            initialValue: cfg.groupBy,
            decoration: const InputDecoration(labelText: 'Group by'),
            items: const [
              DropdownMenuItem(value: BammReportGroupBy.none, child: Text('None')),
              DropdownMenuItem(value: BammReportGroupBy.asset, child: Text('Asset')),
              DropdownMenuItem(value: BammReportGroupBy.area, child: Text('Area')),
              DropdownMenuItem(value: BammReportGroupBy.status, child: Text('Status')),
            ],
            onChanged: (v) {
              if (v != null) update((c) => c.copyWith(groupBy: v));
            },
          ),
          const Divider(),
          const Text('Print layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SegmentedButton<BammReportOrientation>(
            key: const Key('report_orientation'),
            segments: const [
              ButtonSegment(value: BammReportOrientation.landscape, label: Text('Landscape')),
              ButtonSegment(value: BammReportOrientation.portrait, label: Text('Portrait')),
            ],
            selected: {cfg.orientation},
            onSelectionChanged: (s) => update((c) => c.copyWith(orientation: s.first)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Columns per row: '),
              SegmentedButton<int>(
                key: const Key('report_columns_per_row'),
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {cfg.columnsPerCardRow},
                onSelectionChanged: (s) => update((c) => c.copyWith(columnsPerCardRow: s.first)),
              ),
            ],
          ),
          _LabeledSlider(
            key: const Key('report_font_size'),
            label: 'Font size',
            value: cfg.fontSize,
            min: 6,
            max: 9,
            divisions: 3,
            onChanged: (v) => update((c) => c.copyWith(fontSize: v)),
          ),
          _LabeledSlider(
            key: const Key('report_row_height'),
            label: 'Row height',
            value: cfg.rowHeight,
            min: 10,
            max: 24,
            divisions: 14,
            onChanged: (v) => update((c) => c.copyWith(rowHeight: v)),
          ),
          SwitchListTile(
            key: const Key('report_zebra'),
            title: const Text('Zebra striping'),
            value: cfg.zebraStriping,
            onChanged: (v) => update((c) => c.copyWith(zebraStriping: v)),
          ),
          SwitchListTile(
            key: const Key('report_qr_deep_link'),
            title: const Text('QR: open in app'),
            value: cfg.showDeepLinkQr,
            onChanged: (v) => update((c) => c.copyWith(showDeepLinkQr: v)),
          ),
          SwitchListTile(
            key: const Key('report_qr_web'),
            title: const Text('QR: BAMM web page'),
            value: cfg.showBammWebQr,
            onChanged: (v) => update((c) => c.copyWith(showBammWebQr: v)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('report_generate_button'),
            onPressed: _generating ? null : () => _generateAndShare(cfg),
            icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_generating ? 'Generating...' : 'Generate PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShare(BammReportConfig cfg) async {
    setState(() => _generating = true);
    try {
      final notifier = ref.read(bammProvider.notifier);
      if (cfg.savedFilterName != null) {
        final filter = ref.read(bammProvider).savedFilters.where((f) => f.name == cfg.savedFilterName).firstOrNull;
        if (filter != null) {
          notifier.applySavedFilter(filter);
        }
      }
      // Live-only: always re-run the query right before printing rather
      // than trusting whatever happens to already be in memory.
      await notifier.refreshWorkOrders();
      final rows = ref.read(bammProvider).filteredWorkOrders;
      final service = notifier.service;
      final generatedAt = DateTime.now();

      final bytes = await bammReportToPdf(
        rows,
        cfg,
        generatedAt: generatedAt,
        webUrlOf: (wo) => service.bammWebUrl(wo),
        deepLinkOf: (wo) => buildDeepLinkUri(worId: wo.worId, snapshotHash: bammSnapshotHash(wo), printedAt: generatedAt),
      );

      final dir = await getTemporaryDirectory();
      final name = cfg.templateName.isEmpty ? 'bamm_report' : cfg.templateName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
      final file = File('${dir.path}/$name.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: cfg.templateName);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text('$label: ${value.toStringAsFixed(0)}')),
        Expanded(
          child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _TemplateBar extends ConsumerStatefulWidget {
  final BammReportConfig cfg;
  final Map<String, BammReportConfig> templates;
  const _TemplateBar({required this.cfg, required this.templates});

  @override
  ConsumerState<_TemplateBar> createState() => _TemplateBarState();
}

class _TemplateBarState extends ConsumerState<_TemplateBar> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.cfg.templateName);
  }

  @override
  void didUpdateWidget(covariant _TemplateBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cfg.templateName != widget.cfg.templateName && _nameCtrl.text != widget.cfg.templateName) {
      _nameCtrl.text = widget.cfg.templateName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('report_template_name'),
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Template name', hintText: 'e.g. Monday walk-around'),
                onChanged: (v) => ref.read(bammReportSettingsProvider.notifier).setConfig(widget.cfg.copyWith(templateName: v)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('report_save_template'),
              tooltip: 'Save template',
              icon: const Icon(Icons.save_outlined),
              onPressed: _nameCtrl.text.trim().isEmpty
                  ? null
                  : () => ref.read(bammReportSettingsProvider.notifier).saveTemplate(_nameCtrl.text.trim(), widget.cfg),
            ),
          ],
        ),
        if (widget.templates.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final name in widget.templates.keys)
                InputChip(
                  key: Key('report_template_chip_$name'),
                  label: Text(name),
                  onPressed: () => ref.read(bammReportSettingsProvider.notifier).loadTemplate(name),
                  onDeleted: () => ref.read(bammReportSettingsProvider.notifier).deleteTemplate(name),
                  deleteIconColor: AppTheme.of(context).coral,
                ),
            ],
          ),
      ],
    );
  }
}
