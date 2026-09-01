import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/inbox_item.dart';
import '../../models/project.dart';
import '../../models/standalone_order.dart';
import '../../models/downtime_event.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/inbox_quick_capture_modal.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _showProcessed = false;

  void _showTriageToTaskDialog(BuildContext context, InboxItem item, List<Project> projects) {
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active projects available to attach task.')),
      );
      return;
    }

    String selectedProjectId = projects.first.id;
    DateTime? scheduledDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateText = scheduledDate != null
              ? DateFormat('MMM d, y').format(scheduledDate!)
              : 'No date';

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_task_rounded, color: AppTheme.primaryCyan),
                SizedBox(width: 8),
                Text('Convert to Project Task'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      item.text,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Target Project *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.folder_open_rounded),
                    ),
                    items: projects
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '#${p.priority} ${p.title}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedProjectId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.accentAmber),
                    title: Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Scheduled Execution Date', style: TextStyle(fontSize: 11)),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: scheduledDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => scheduledDate = picked);
                        }
                      },
                      child: const Text('Pick Date'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(projectProvider.notifier)
                      .triageToTask(item.id, selectedProjectId, scheduledDate: scheduledDate);
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Task added to project & inbox item cleared!'),
                      backgroundColor: AppTheme.accentEmerald,
                    ),
                  );
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Convert to Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTriageToOrderDialog(BuildContext context, InboxItem item) {
    final descCtrl = TextEditingController(text: item.text);
    final prCtrl = TextEditingController();
    final poCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    DateTime? eta;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: AppTheme.accentAmber),
                SizedBox(width: 8),
                Text('Convert to Standalone Order'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Part / Item Description *'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prCtrl,
                          decoration: const InputDecoration(labelText: 'PR #'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: poCtrl,
                          decoration: const InputDecoration(labelText: 'PO #'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price / Cost (\$)',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      eta != null ? 'ETA: ${DateFormat('MMM d, y').format(eta!)}' : 'No ETA Assigned',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 3)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setDialogState(() => eta = picked);
                      },
                      child: const Text('Pick ETA'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final desc = descCtrl.text.trim();
                  if (desc.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final order = StandaloneOrder(
                    description: desc,
                    pr: prCtrl.text.trim(),
                    po: poCtrl.text.trim(),
                    price: double.tryParse(priceCtrl.text) ?? 0.0,
                    eta: eta,
                  );
                  await ref.read(projectProvider.notifier).triageToOrder(item.id, order);
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Converted to Standalone Order!'),
                      backgroundColor: AppTheme.accentEmerald,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Create Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTriageToDowntimeDialog(BuildContext context, InboxItem item, List<String> machines) {
    final reasonCtrl = TextEditingController(text: item.text);
    String machine = machines.isNotEmpty ? machines.first : 'Line 1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.report_problem_rounded, color: AppTheme.accentCoral),
                SizedBox(width: 8),
                Text('Log Line Downtime'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: machines.contains(machine) ? machine : null,
                    hint: const Text('Select Machine / Line'),
                    decoration: const InputDecoration(labelText: 'Machine *'),
                    items: machines
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => machine = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Downtime Reason / Symptoms *'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final downtime = DowntimeEvent(
                    machine: machine,
                    title: reason,
                    date: DateTime.now(),
                  );

                  await ref.read(projectProvider.notifier).triageToDowntime(item.id, downtime);
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Downtime event logged!'),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCoral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log Downtime'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayItems = _showProcessed
        ? state.inboxItems
        : state.unprocessedInboxItems;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: AppTheme.accentAmber),
            const SizedBox(width: 8),
            const Text('Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (state.unprocessedInboxCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unprocessedInboxCount}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showProcessed ? Icons.visibility_rounded : Icons.visibility_outlined,
              color: _showProcessed ? AppTheme.primaryCyan : Colors.grey,
            ),
            tooltip: _showProcessed ? 'Showing All (Including Processed)' : 'Showing Pending Only',
            onPressed: () => setState(() => _showProcessed = !_showProcessed),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: displayItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showProcessed ? 'Inbox is empty' : 'Inbox zero! All caught up.',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap + Quick Dump when walking the floor\nto capture ideas, issues, or requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _InboxItemCard(
                  item: item,
                  isDark: isDark,
                  onTriageTask: () => _showTriageToTaskDialog(context, item, state.activeProjects),
                  onTriageProject: () {
                    context.push('/projects/new', extra: {'initialTitle': item.text});
                    ref.read(projectProvider.notifier).dismissInboxItem(item.id);
                  },
                  onTriageOrder: () => _showTriageToOrderDialog(context, item),
                  onTriageDowntime: () =>
                      _showTriageToDowntimeDialog(context, item, state.availableMachines),
                  onTriageNote: () async {
                    final note = VoiceNote(
                      title: 'Note: ${item.text.length > 25 ? "${item.text.substring(0, 25)}..." : item.text}',
                      transcript: item.text,
                    );
                    await ref.read(projectProvider.notifier).triageToNote(item.id, note);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved as Field Note!'), backgroundColor: AppTheme.primaryCyan),
                      );
                    }
                  },
                  onDismiss: () => ref.read(projectProvider.notifier).dismissInboxItem(item.id),
                  onDelete: () => ref.read(projectProvider.notifier).deleteInboxItem(item.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => InboxQuickCaptureModal.show(context),
        icon: const Icon(Icons.flash_on_rounded),
        label: const Text('Quick Dump'),
        backgroundColor: AppTheme.accentAmber,
        foregroundColor: Colors.black87,
      ),
    );
  }
}

class _InboxItemCard extends StatelessWidget {
  final InboxItem item;
  final bool isDark;
  final VoidCallback onTriageTask;
  final VoidCallback onTriageProject;
  final VoidCallback onTriageOrder;
  final VoidCallback onTriageDowntime;
  final VoidCallback onTriageNote;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;

  const _InboxItemCard({
    required this.item,
    required this.isDark,
    required this.onTriageTask,
    required this.onTriageProject,
    required this.onTriageOrder,
    required this.onTriageDowntime,
    required this.onTriageNote,
    required this.onDismiss,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: timestamp + delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.isProcessed ? Icons.check_circle_rounded : Icons.pending_rounded,
                    size: 14,
                    color: item.isProcessed ? AppTheme.accentEmerald : AppTheme.accentAmber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          Text(
            item.text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: item.isProcessed ? TextDecoration.lineThrough : null,
              color: item.isProcessed ? Colors.grey : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 14),

          // Triage action strip
          if (!item.isProcessed) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_task_rounded, size: 14, color: AppTheme.primaryCyan),
                  label: const Text('Task', style: TextStyle(fontSize: 11)),
                  onPressed: onTriageTask,
                ),
                ActionChip(
                  avatar: const Icon(Icons.rocket_launch_rounded, size: 14, color: AppTheme.accentEmerald),
                  label: const Text('Project', style: TextStyle(fontSize: 11)),
                  onPressed: onTriageProject,
                ),
                ActionChip(
                  avatar: const Icon(Icons.local_shipping_outlined, size: 14, color: AppTheme.accentAmber),
                  label: const Text('Order', style: TextStyle(fontSize: 11)),
                  onPressed: onTriageOrder,
                ),
                ActionChip(
                  avatar: const Icon(Icons.report_problem_rounded, size: 14, color: AppTheme.accentCoral),
                  label: const Text('Downtime', style: TextStyle(fontSize: 11)),
                  onPressed: onTriageDowntime,
                ),
                ActionChip(
                  avatar: const Icon(Icons.edit_note_rounded, size: 14, color: Colors.purpleAccent),
                  label: const Text('Note', style: TextStyle(fontSize: 11)),
                  onPressed: onTriageNote,
                ),
                ActionChip(
                  avatar: const Icon(Icons.done_all_rounded, size: 14, color: Colors.grey),
                  label: const Text('Done', style: TextStyle(fontSize: 11)),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
