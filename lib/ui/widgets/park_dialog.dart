import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

/// What the user chose in [showParkDialog].
typedef ParkChoice = ({DateTime until, String reason});

const List<String> kParkReasons = [
  'Waiting on parts',
  'Downtime window',
  'Waiting on approval',
  'Other',
];

/// Next Monday strictly after [from].
DateTime nextMonday(DateTime from) {
  final d = DateTime(from.year, from.month, from.day);
  final add = (DateTime.monday - d.weekday) % 7;
  return d.add(Duration(days: add == 0 ? 7 : add));
}

/// Earliest ETA among the project's undelivered orders that is today or later;
/// null when there is none. Lets "until the part arrives" be one click.
DateTime? nextOrderEta(Project project, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime? best;
  for (final o in project.orders) {
    final eta = o.eta;
    if (o.delivered || eta == null) continue;
    final d = DateTime(eta.year, eta.month, eta.day);
    if (d.isBefore(today)) continue;
    if (best == null || d.isBefore(best)) best = d;
  }
  return best;
}

/// "Parked until Fri, Oct 10 · back to #2"
String parkBadgeText(Project p) {
  final until = p.parkedUntil;
  if (until == null) return '';
  return 'Parked until ${DateFormat('EEE, MMM d').format(until)} · back to #${p.parkRestorePriority ?? p.priority}';
}

/// Shows the dialog and parks (or re-dates the park of) [project].
Future<void> parkWithDialog(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final choice = await showParkDialog(context, project);
  if (choice == null) return;
  await ref
      .read(projectProvider.notifier)
      .parkProject(project.id, choice.until, reason: choice.reason);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Parked until ${DateFormat('EEE, MMM d').format(choice.until)}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              ref.read(projectProvider.notifier).unparkProject(project.id),
        ),
      ),
    );
}

/// Asks until when (and why) to park [project]. Null if cancelled.
Future<ParkChoice?> showParkDialog(
  BuildContext context,
  Project project, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  return showDialog<ParkChoice>(
    context: context,
    builder: (_) => _ParkDialog(project: project, now: clock),
  );
}

class _ParkDialog extends StatefulWidget {
  final Project project;
  final DateTime now;
  const _ParkDialog({required this.project, required this.now});

  @override
  State<_ParkDialog> createState() => _ParkDialogState();
}

class _ParkDialogState extends State<_ParkDialog> {
  DateTime? _until;
  String _reason = kParkReasons.first;
  final _other = TextEditingController();

  @override
  void initState() {
    super.initState();
    _until = widget.project.parkedUntil;
    if (widget.project.parkReason.isNotEmpty) {
      if (kParkReasons.contains(widget.project.parkReason)) {
        _reason = widget.project.parkReason;
      } else {
        _reason = 'Other';
        _other.text = widget.project.parkReason;
      }
    }
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  DateTime get _today =>
      DateTime(widget.now.year, widget.now.month, widget.now.day);

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final fmt = DateFormat('EEE, MMM d');
    final eta = nextOrderEta(widget.project, widget.now);
    final restore = widget.project.isParked
        ? (widget.project.parkRestorePriority ?? widget.project.priority)
        : widget.project.priority;

    final quick = <({String label, DateTime date})>[
      (label: 'Tomorrow', date: _today.add(const Duration(days: 1))),
      (label: 'Next Monday', date: nextMonday(_today)),
      (label: 'In 1 week', date: _today.add(const Duration(days: 7))),
      (label: 'In 2 weeks', date: _today.add(const Duration(days: 14))),
      if (eta != null) (label: 'When the next order arrives', date: eta),
    ];

    return AlertDialog(
      title: Text(
        widget.project.isParked ? 'Change park date' : 'Park this project',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.project.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'It drops to the bottom of the queue and comes back to #$restore on the day you pick.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Return on',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in quick)
                    ChoiceChip(
                      label: Text(
                        q.label == 'When the next order arrives'
                            ? '${q.label} (${fmt.format(q.date)})'
                            : q.label,
                      ),
                      selected: _until == q.date,
                      onSelected: (_) => setState(() => _until = q.date),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Pick a date...'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _until ?? _today.add(const Duration(days: 3)),
                        firstDate: _today.add(const Duration(days: 1)),
                        lastDate: _today.add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setState(
                          () => _until = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              if (_until != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Returns ${fmt.format(_until!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Why',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in kParkReasons)
                    ChoiceChip(
                      label: Text(r),
                      selected: _reason == r,
                      onSelected: (_) => setState(() => _reason = r),
                    ),
                ],
              ),
              if (_reason == 'Other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _other,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _until == null
              ? null
              : () => Navigator.pop<ParkChoice>(context, (
                  until: _until!,
                  reason: _reason == 'Other' ? _other.text.trim() : _reason,
                )),
          child: const Text('Park'),
        ),
      ],
    );
  }
}
