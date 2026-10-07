part of '../bamm_detail_dialog.dart';

class _AddActivityLineSheet extends ConsumerStatefulWidget {
  final BammWorkOrder workOrder;

  const _AddActivityLineSheet({required this.workOrder});

  @override
  ConsumerState<_AddActivityLineSheet> createState() => _AddActivityLineSheetState();
}

class _AddActivityLineSheetState extends ConsumerState<_AddActivityLineSheet> {
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  LookupOption? _activity;
  LookupOption? _subActivity;
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final outcome = await ref.read(bammProvider.notifier).addActivityLine(
            worId: widget.workOrder.worId,
            activityId: _activity!.id,
            subActivityId: _subActivity!.id,
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            hours: double.tryParse(_hoursCtrl.text.trim()),
            memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, outcome);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add line: $e')));
      }
    }
  }

  Widget _buildPickerRow({required String label, required LookupOption? current, VoidCallback? onTap}) {
    final display = current == null
        ? 'Not set'
        : (current.label.isNotEmpty ? current.label : 'ID ${current.id}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          TextButton(onPressed: onTap, child: const Text('Change', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add activity line', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            _buildPickerRow(
              label: 'Activity *',
              current: _activity,
              onTap: () async {
                final selected = await showBammLookupPicker(
                  context,
                  title: 'Activity',
                  fetch: (_) => ref.read(bammServiceProvider).lookups.activities(
                        stepId: widget.workOrder.stepId?.toString(),
                        assetId: widget.workOrder.assetId,
                      ),
                );
                if (selected != null && mounted) {
                  setState(() {
                    _activity = selected;
                    _subActivity = null;
                  });
                }
              },
            ),
            _buildPickerRow(
              label: 'Sub-activity *',
              current: _subActivity,
              onTap: _activity == null
                  ? null
                  : () async {
                      final selected = await showBammLookupPicker(
                        context,
                        title: 'Sub-activity',
                        fetch: (_) => ref.read(bammServiceProvider).lookups.subActivities(
                              activityId: _activity!.id,
                              assetId: widget.workOrder.assetId,
                            ),
                      );
                      if (selected != null && mounted) {
                        setState(() => _subActivity = selected);
                      }
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', isDense: true),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
              decoration: const InputDecoration(labelText: 'Hours', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: 'Memo', isDense: true),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_activity == null || _subActivity == null || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add, size: 18),
              label: const Text('Add line'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
            ),
          ],
        ),
      ),
    );
  }
}
