import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/bamm_models.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

class BammDetailDialog extends ConsumerStatefulWidget {
  final BammWorkOrder workOrder;

  const BammDetailDialog({super.key, required this.workOrder});

  static Future<void> show(BuildContext context, BammWorkOrder workOrder) {
    return showDialog(
      context: context,
      builder: (ctx) => BammDetailDialog(workOrder: workOrder),
    );
  }

  @override
  ConsumerState<BammDetailDialog> createState() => _BammDetailDialogState();
}

class _BammDetailDialogState extends ConsumerState<BammDetailDialog> {
  late BammWorkOrder _wo;
  bool _isEditing = false;
  late final TextEditingController _descCtrl;
  late final TextEditingController _respCtrl;
  late final TextEditingController _workDoneCtrl;
  DateTime? _requiredDate;
  bool _isSaving = false;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _wo = widget.workOrder;
    _descCtrl = TextEditingController(text: _wo.description);
    _respCtrl = TextEditingController(text: _wo.responsible);
    _workDoneCtrl = TextEditingController(text: _wo.workDone);
    _requiredDate = _wo.requiredDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFullDetail();
    });
  }

  Future<void> _fetchFullDetail() async {
    if (_wo.worId <= 0) return;
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await ref.read(bammProvider.notifier).fetchWorkOrderDetail(_wo.worId);
      if (detail != null && mounted) {
        setState(() {
          _wo = detail;
          _descCtrl.text = detail.description;
          _respCtrl.text = detail.responsible;
          _workDoneCtrl.text = detail.workDone;
          _requiredDate = detail.requiredDate;
          _isLoadingDetail = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _respCtrl.dispose();
    _workDoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final outcome = await ref.read(bammProvider.notifier).updateWorkOrder(
        worId: _wo.worId,
        description: _descCtrl.text.trim(),
        workDone: _workDoneCtrl.text.trim(),
        responsible: _respCtrl.text.trim(),
        requiredDate: _requiredDate,
      );
      setState(() {
        _wo = outcome.workOrder;
        _descCtrl.text = outcome.workOrder.description;
        _respCtrl.text = outcome.workOrder.responsible;
        _workDoneCtrl.text = outcome.workOrder.workDone;
        _requiredDate = outcome.workOrder.requiredDate;
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        final result = outcome.writeResult;
        final verdict = result.fields.map((f) => f.describe()).join('\n');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess ? 'Saved to BAMM:\n$verdict' : 'BAMM save incomplete:\n$verdict',
            ),
            backgroundColor: result.isSuccess ? null : Theme.of(context).colorScheme.errorContainer,
            duration: Duration(seconds: result.isSuccess ? 4 : 8),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update BAMM: $e')),
        );
      }
    }
  }

  void _showAssignToItemModal() {
    final engState = ref.read(projectProvider);
    final projects = engState.projects;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assign BAMM #${_wo.worNoSeq} to...',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: projects.length,
                      itemBuilder: (ctx, idx) {
                        final p = projects[idx];
                        final isAlreadyLinked = p.bammWorkOrders.contains(_wo.worNoSeq);

                        return ExpansionTile(
                          leading: Icon(
                            isAlreadyLinked ? Icons.check_circle_rounded : Icons.folder_outlined,
                            color: isAlreadyLinked ? AppTheme.of(context).emerald : AppTheme.of(context).primary,
                          ),
                          title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.phase} • ${p.tasks.length} tasks • ${p.orders.length} orders'),
                          trailing: IconButton(
                            tooltip: isAlreadyLinked ? 'Unlink from Project' : 'Link to Project',
                            icon: Icon(
                              isAlreadyLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                              color: isAlreadyLinked ? Colors.red : AppTheme.of(context).primary,
                            ),
                            onPressed: () async {
                              if (isAlreadyLinked) {
                                await ref.read(projectProvider.notifier).removeBammFromProject(p.id, _wo.worNoSeq);
                              } else {
                                await ref.read(projectProvider.notifier).assignBammToProject(p.id, _wo.worNoSeq);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                            },
                          ),
                          children: [
                            if (p.tasks.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Tasks in project:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                              ),
                              ...p.tasks.map((t) {
                                final taskLinked = t.bammWorkOrders.contains(_wo.worNoSeq);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                  title: Text(t.description, style: const TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      taskLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                                      size: 18,
                                      color: taskLinked ? Colors.red : AppTheme.of(context).primary,
                                    ),
                                    onPressed: () async {
                                      if (taskLinked) {
                                        await ref.read(projectProvider.notifier).removeBammFromTask(p.id, t.id, _wo.worNoSeq);
                                      } else {
                                        await ref.read(projectProvider.notifier).assignBammToTask(p.id, t.id, _wo.worNoSeq);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                );
                              }),
                            ],
                            if (p.orders.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Orders in project:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                              ),
                              ...p.orders.map((o) {
                                final orderLinked = o.bammWorkOrders.contains(_wo.worNoSeq);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                  title: Text(o.description.isNotEmpty ? o.description : (o.po.isNotEmpty ? 'PO: ${o.po}' : 'PR: ${o.pr}'), style: const TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      orderLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                                      size: 18,
                                      color: orderLinked ? Colors.red : AppTheme.of(context).primary,
                                    ),
                                    onPressed: () async {
                                      if (orderLinked) {
                                        await ref.read(projectProvider.notifier).removeBammFromOrder(p.id, o.id, _wo.worNoSeq);
                                      } else {
                                        await ref.read(projectProvider.notifier).assignBammToOrder(p.id, o.id, _wo.worNoSeq);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                );
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(projectProvider);
    final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(_wo.worNoSeq);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.of(context).primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'BAMM Work Order #${_wo.worNoSeq}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: _isEditing ? 'Cancel Editing' : 'Edit Work Order',
            icon: Icon(_isEditing ? Icons.close : Icons.edit_rounded, size: 20),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status & Step Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _wo.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _wo.statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _wo.status,
                      style: TextStyle(color: _wo.statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _wo.stepColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _wo.stepColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _wo.step,
                      style: TextStyle(color: _wo.stepColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_wo.priority.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Priority: ${_wo.priority}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isEditing) ...[
                // Edit Form - only fields BAMM will actually accept
                // (BammWritableField) get an input; everything else is
                // read-only here too, so nothing is ever shown as editable
                // without a way to save it.
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Work Order Description *',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workDoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Work Done',
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _respCtrl,
                  decoration: const InputDecoration(labelText: 'Responsible Person', isDense: true),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not editable from this app yet',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow('Status', _wo.status.isNotEmpty ? _wo.status : 'Unknown'),
                      _buildInfoRow('Step', _wo.step.isNotEmpty ? _wo.step : 'Unknown'),
                      _buildInfoRow('Priority', _wo.priority.isNotEmpty ? _wo.priority : 'None'),
                      _buildInfoRow('Machine / Area', '${_wo.machine.isNotEmpty ? _wo.machine : 'None'} (${_wo.area.isNotEmpty ? _wo.area : 'Unspecified'})'),
                      if (_wo.laborHours != null) _buildInfoRow('Est. Labor Hours', '${_wo.laborHours} hrs'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, size: 20),
                  title: Text(
                    _requiredDate != null ? DateFormat('yyyy-MM-dd').format(_requiredDate!) : 'No target date',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text('Target Required Date', style: TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requiredDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _requiredDate = picked);
                      }
                    },
                    child: const Text('Change Date'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save to BAMM'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                ),
              ] else ...[
                // View Mode
                if (_isLoadingDetail)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                Text(
                  _wo.description,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (_wo.workDone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.of(context).primary),
                            const SizedBox(width: 6),
                            Text(
                              'Work Done / Activity Log',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.of(context).primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _wo.workDone,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoRow('Machine / Area', '${_wo.machine.isNotEmpty ? _wo.machine : 'None'} (${_wo.area.isNotEmpty ? _wo.area : 'Unspecified'})'),
                _buildInfoRow('Responsible', _wo.responsible.isNotEmpty ? _wo.responsible : 'Unassigned'),
                _buildInfoRow('Requester', _wo.requester.isNotEmpty ? _wo.requester : 'None'),
                if (_wo.issueDate != null)
                  _buildInfoRow('Registered Date', DateFormat('MMM d, y').format(_wo.issueDate!)),
                if (_wo.requiredDate != null)
                  _buildInfoRow('Target Date', DateFormat('MMM d, y').format(_wo.requiredDate!)),
                if (_wo.laborHours != null)
                  _buildInfoRow('Est. Labor Hours', '${_wo.laborHours} hrs'),
              ],

              const Divider(height: 28),

              // Linked Items in AOR Engineering
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Linked in AOR Engineering:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showAssignToItemModal,
                    icon: const Icon(Icons.add_link_rounded, size: 16),
                    label: const Text('Link Item', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (linkedItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Not linked to any projects, tasks, or orders yet. Tap "Link Item" above to connect it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                ...linkedItems.map((item) {
                  final type = item['type'] as String;
                  IconData icon;
                  String label;

                  if (type == 'project') {
                    icon = Icons.assignment_rounded;
                    label = 'Project: ${item['title']}';
                  } else if (type == 'task') {
                    icon = Icons.task_alt_rounded;
                    label = 'Task: ${item['title']} (${item['projectTitle']})';
                  } else if (type == 'order') {
                    icon = Icons.local_shipping_rounded;
                    label = 'Order: ${item['title']} (${item['projectTitle']})';
                  } else {
                    icon = Icons.receipt_long_rounded;
                    label = 'Standalone Order: ${item['title']}';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(icon, color: AppTheme.of(context).primary, size: 18),
                      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
                      onTap: () {
                        Navigator.pop(context);
                        if (type == 'project' || type == 'task' || type == 'order') {
                          final pId = item['projectId'] as String;
                          context.push('/projects/$pId');
                        } else {
                          context.push('/orders');
                        }
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
