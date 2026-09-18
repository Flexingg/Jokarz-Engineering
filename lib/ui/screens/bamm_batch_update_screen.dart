/// Batch update: tick several BAMM work orders and apply the same
/// status/step/note change in one go - what makes a printed report a
/// controller instead of a copy.
///
/// Reuses the existing closed write whitelist end to end - no new BAMM
/// field, no new write path. Status/Step go through the same
/// `BammService.updateWorkOrder` -> `WhitelistedFieldWriter` lock/save/
/// read-back sequence every single-work-order edit already uses, called
/// once per selected work order. "A note" is a uniform overwrite of the
/// existing whitelisted `workDone` (`WOR_TASK`) field, NOT an appended
/// `WO_DETAIL` activity line: `addActivityLine` requires an
/// activity/sub-activity pair that BAMM scopes per asset
/// (`~/repos/BAMM/docs/10-lookups-and-activity-lines.md`), so a batch
/// spanning work orders on different assets has no single activity/
/// sub-activity pair that is valid for all of them - reusing `workDone`
/// is what "apply the SAME change... in one go" can actually mean across
/// a heterogeneous batch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bamm/schema/lookups.dart';
import '../../models/bamm_models.dart';
import '../../providers/bamm_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/bamm_lookup_picker.dart';

/// Closing statuses (Completed/Cancelled/Closed) per
/// `~/repos/BAMM/docs/11-field-inventory.md` - same set
/// `bamm_detail_dialog.dart` gates a single-edit closing status on, applied
/// here once for the whole batch rather than once per row.
const Set<String> _closingStatusIds = {'3', '4', '6'};

class BammBatchUpdateScreen extends ConsumerStatefulWidget {
  const BammBatchUpdateScreen({super.key});

  @override
  ConsumerState<BammBatchUpdateScreen> createState() => _BammBatchUpdateScreenState();
}

class _BammBatchUpdateScreenState extends ConsumerState<BammBatchUpdateScreen> {
  final Set<int> _selected = {};
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(bammProvider).filteredWorkOrders;
    final allSelected = rows.isNotEmpty && rows.every((w) => _selected.contains(w.worId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Update'),
        actions: [
          TextButton(
            key: const Key('batch_select_all'),
            onPressed: rows.isEmpty
                ? null
                : () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(rows.map((w) => w.worId));
                      }
                    }),
            child: Text(allSelected ? 'Deselect all' : 'Select all'),
          ),
        ],
      ),
      body: rows.isEmpty
          ? const Center(child: Text('No work orders loaded - adjust the table filter first'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final wo = rows[index];
                return CheckboxListTile(
                  key: Key('batch_row_${wo.worId}'),
                  // Big touch target - phone-usable.
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  value: _selected.contains(wo.worId),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(wo.worId);
                    } else {
                      _selected.remove(wo.worId);
                    }
                  }),
                  title: Text('#${wo.worNoSeq} - ${wo.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${wo.status} / ${wo.step}', style: const TextStyle(fontSize: 12)),
                );
              },
            ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const Key('batch_apply_button'),
                  onPressed: _applying ? null : () => _openApplySheet(rows),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(_applying ? 'Applying...' : 'Apply to ${_selected.length} selected'),
                ),
              ),
            ),
    );
  }

  Future<void> _openApplySheet(List<BammWorkOrder> rows) async {
    final change = await showModalBottomSheet<_BatchChange>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BatchChangeSheet(),
    );
    if (change == null || !mounted) return;
    if (change.isEmpty) return;

    if (change.statusId != null && _closingStatusIds.contains(change.statusId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm status change'),
          content: Text(
            'This will set ${_selected.length} work order(s) to a CLOSING status (${change.statusLabel ?? change.statusId}). Continue?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _applyBatch(rows, change);
  }

  Future<void> _applyBatch(List<BammWorkOrder> rows, _BatchChange change) async {
    setState(() => _applying = true);
    final byId = {for (final w in rows) w.worId: w};
    final notifier = ref.read(bammProvider.notifier);
    final failures = <String>[];
    var successCount = 0;

    for (final worId in _selected.toList()) {
      final wo = byId[worId];
      if (wo == null) continue;
      try {
        final outcome = await notifier.service.updateWorkOrder(
          worId: worId,
          description: wo.description,
          stepId: change.stepId,
          statusId: change.statusId,
          workDone: change.note,
        );
        if (outcome.writeResult.isSuccess) {
          successCount++;
        } else {
          failures.add('#${wo.worNoSeq}: ${outcome.writeResult.summary}');
        }
      } catch (e) {
        failures.add('#${wo.worNoSeq}: $e');
      }
    }

    await notifier.refreshWorkOrders();

    if (!mounted) return;
    setState(() {
      _applying = false;
      _selected.clear();
    });

    final message = failures.isEmpty
        ? '$successCount work order(s) updated'
        : '$successCount updated, ${failures.length} failed: ${failures.join('; ')}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: failures.isEmpty ? AppTheme.of(context).emerald : AppTheme.of(context).coral,
      duration: Duration(seconds: failures.isEmpty ? 3 : 8),
    ));
  }
}

class _BatchChange {
  final String? statusId;
  final String? statusLabel;
  final String? stepId;
  final String? note;

  const _BatchChange({this.statusId, this.statusLabel, this.stepId, this.note});

  bool get isEmpty => statusId == null && stepId == null && (note == null || note!.trim().isEmpty);
}

class _BatchChangeSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BatchChangeSheet> createState() => _BatchChangeSheetState();
}

class _BatchChangeSheetState extends ConsumerState<_BatchChangeSheet> {
  LookupOption? _status;
  LookupOption? _step;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apply to selected work orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _pickerRow(
              label: 'Status',
              value: _status?.label,
              key: const Key('batch_pick_status'),
              onTap: () async {
                final selected = await showBammLookupPicker(
                  context,
                  title: 'Status',
                  fetch: (_) => ref.read(bammServiceProvider).lookups.status(),
                );
                if (selected != null && mounted) setState(() => _status = selected);
              },
            ),
            _pickerRow(
              label: 'Step',
              value: _step?.label,
              key: const Key('batch_pick_step'),
              onTap: () async {
                final selected = await showBammLookupPicker(
                  context,
                  title: 'Step',
                  fetch: (_) => ref.read(bammServiceProvider).lookups.steps(),
                );
                if (selected != null && mounted) setState(() => _step = selected);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('batch_note_field'),
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (overwrites Work Done on every selected order)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('batch_change_apply'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(
                  context,
                  _BatchChange(
                    statusId: _status?.id,
                    statusLabel: _status?.label,
                    stepId: _step?.id,
                    note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerRow({required String label, required String? value, required Key key, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value ?? 'No change', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          TextButton(key: key, onPressed: onTap, child: const Text('Choose')),
        ],
      ),
    );
  }
}
