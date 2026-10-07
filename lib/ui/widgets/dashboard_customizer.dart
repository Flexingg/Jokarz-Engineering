import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_prefs_provider.dart';
import '../../theme/app_theme.dart';

/// Section ids the desktop dashboard can show, in their default order.
const List<String> dashboardSectionIds = [
  'summary',
  'today',
  'priority',
  'attention',
  'orders',
];

const Map<String, ({String title, String subtitle, IconData icon})>
_sectionInfo = {
  'summary': (
    title: 'Plant overview',
    subtitle: 'Project counts, open PO value and shortcuts',
    icon: Icons.factory_outlined,
  ),
  'today': (
    title: 'Today and weekly KPIs',
    subtitle: "Today's tasks and 7-day task counts",
    icon: Icons.today_rounded,
  ),
  'priority': (
    title: 'Top priority projects',
    subtitle: 'Your highest-ranked active projects',
    icon: Icons.flag_outlined,
  ),
  'attention': (
    title: 'Needs attention',
    subtitle: 'Projects not touched recently',
    icon: Icons.notification_important_outlined,
  ),
  'orders': (
    title: 'Orders due soon',
    subtitle: 'Open orders due within 14 days',
    icon: Icons.local_shipping_outlined,
  ),
};

/// Dialog for choosing which dashboard sections show and in what order.
Future<void> showDashboardCustomizer(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _DashboardCustomizer(),
);

class _DashboardCustomizer extends ConsumerWidget {
  const _DashboardCustomizer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    final prefs = ref.watch(uiPrefsProvider);
    final notifier = ref.read(uiPrefsProvider.notifier);
    final order = <String>[
      ...prefs.dashboardOrder.where(dashboardSectionIds.contains),
      ...dashboardSectionIds.where((id) => !prefs.dashboardOrder.contains(id)),
    ];

    return AlertDialog(
      title: const Text('Customize dashboard'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drag to reorder. Switch off what you do not need.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  if (to > from) to--;
                  final next = [...order];
                  next.insert(to, next.removeAt(from));
                  notifier.update((p) => p.copyWith(dashboardOrder: next));
                },
                children: [
                  for (var i = 0; i < order.length; i++)
                    Container(
                      key: ValueKey(order[i]),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        title: Text(_sectionInfo[order[i]]!.title),
                        subtitle: Text(
                          _sectionInfo[order[i]]!.subtitle,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Switch(
                          value: !prefs.dashboardHidden.contains(order[i]),
                          onChanged: (on) => notifier.update((p) {
                            final hidden = [...p.dashboardHidden]
                              ..remove(order[i]);
                            if (!on) hidden.add(order[i]);
                            return p.copyWith(dashboardHidden: hidden);
                          }),
                        ),
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
          onPressed: () => notifier.update(
            (p) => p.copyWith(dashboardOrder: [], dashboardHidden: []),
          ),
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
