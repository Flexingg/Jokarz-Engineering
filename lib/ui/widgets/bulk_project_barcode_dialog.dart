import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/barcode_label_pdf.dart';
import '../fluid/fluid_dialog.dart';
import 'expressive_badge.dart';

/// Shows the Bulk Project Barcode Printer dialog.
/// Allows selecting multiple projects to generate an 8.5" x 11" (US Letter)
/// cut-sheet PDF with 8 good-sized 2D barcode labels per page.
Future<void> showBulkProjectBarcodeDialog(
  BuildContext context, {
  List<Project>? initialProjects,
}) {
  return showFluidDialog(
    context: context,
    builder: (ctx) => BulkProjectBarcodeDialog(initialProjects: initialProjects),
  );
}

class BulkProjectBarcodeDialog extends ConsumerStatefulWidget {
  final List<Project>? initialProjects;
  const BulkProjectBarcodeDialog({super.key, this.initialProjects});

  @override
  ConsumerState<BulkProjectBarcodeDialog> createState() => _BulkProjectBarcodeDialogState();
}

class _BulkProjectBarcodeDialogState extends ConsumerState<BulkProjectBarcodeDialog> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isExporting = false;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    final state = ref.read(projectProvider);
    final projects = widget.initialProjects ?? state.projects;

    // Default to selecting all active (non-completed) projects
    for (final p in projects) {
      if (!p.isCompletedOrCancelled) {
        _selectedIds.add(p.id);
      }
    }
    // If no active projects, select all
    if (_selectedIds.isEmpty) {
      for (final p in projects) {
        _selectedIds.add(p.id);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectAll(List<Project> list) {
    setState(() {
      for (final p in list) {
        _selectedIds.add(p.id);
      }
    });
  }

  void _selectActiveOnly(List<Project> list) {
    setState(() {
      _selectedIds.clear();
      for (final p in list) {
        if (!p.isCompletedOrCancelled) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _exportCutSheet(List<Project> allProjects) async {
    final selectedProjects = allProjects.where((p) => _selectedIds.contains(p.id)).toList();
    if (selectedProjects.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final labels = selectedProjects.map((p) => BarcodeLabelData.fromProject(p)).toList();
      final pdfBytes = await generateMultiLabelSheetPdf(labels);

      final dir = await getTemporaryDirectory();
      final dateStr = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/project_barcodes_8.5x11_$dateStr.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Project Barcode Cut Sheet (${selectedProjects.length} Labels)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate cut sheet PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final state = ref.watch(projectProvider);
    final allProjects = widget.initialProjects ?? state.projects;

    final q = _filterQuery.trim().toLowerCase();
    final displayedProjects = q.isEmpty
        ? allProjects
        : allProjects.where((p) {
            return p.title.toLowerCase().contains(q) ||
                p.machine.toLowerCase().contains(q) ||
                p.phase.toLowerCase().contains(q) ||
                p.category.label.toLowerCase().contains(q) ||
                '#${p.priority}'.contains(q);
          }).toList();

    final selectedCount = _selectedIds.length;
    final pageCount = (selectedCount / 8).ceil();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, color: colors.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Print Project Barcodes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '8.5" × 11" Paper Cut Sheet (8 Labels / Page)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search projects, machines, steps...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filterQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _filterQuery = val),
            ),
            const SizedBox(height: 8),

            // Selection Quick Actions
            Row(
              children: [
                ActionChip(
                  label: Text('Select All (${allProjects.length})', style: const TextStyle(fontSize: 11)),
                  onPressed: () => _selectAll(allProjects),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(
                    'Active (${allProjects.where((p) => !p.isCompletedOrCancelled).length})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _selectActiveOnly(allProjects),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  onPressed: _clearAll,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.primary.withAlpha(80)),
                  ),
                  child: Text(
                    '$selectedCount selected ($pageCount page${pageCount == 1 ? "" : "s"})',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Checklist
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: displayedProjects.isEmpty
                    ? Center(
                        child: Text(
                          'No matching projects found.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: displayedProjects.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: colors.border.withAlpha(80)),
                        itemBuilder: (context, index) {
                          final project = displayedProjects[index];
                          final isSelected = _selectedIds.contains(project.id);

                          return CheckboxListTile(
                            value: isSelected,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(project.id);
                                } else {
                                  _selectedIds.remove(project.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                ExpressiveBadge(
                                  label: '#${project.priority}',
                                  color: project.priority == 1
                                      ? colors.coral
                                      : (project.priority <= 3 ? colors.amber : colors.primary),
                                  fontSize: 10,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    project.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Step: ${project.phase} • Type: ${project.category.label}${project.machine.isNotEmpty ? " • Machine: ${project.machine}" : ""}',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Plant printing helper note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.content_cut_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Formats 8 labels per 8.5"×11" US Letter page with dashed scissor cut guides. Perfect for standard plant laser/inkjet printers.',
                      style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting || selectedCount == 0
              ? null
              : () => _exportCutSheet(allProjects),
          icon: _isExporting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print_rounded, size: 16),
          label: Text('Print $selectedCount Label${selectedCount == 1 ? "" : "s"} (8.5"×11" Sheet)'),
        ),
      ],
    );
  }
}
