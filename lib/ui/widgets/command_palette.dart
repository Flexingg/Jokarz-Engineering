import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/key_bindings.dart';
import '../../providers/keybindings_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import '../shell/app_actions.dart';

/// Opens the Ctrl+K command palette over the whole app: one box that jumps to
/// any page, creates things, and finds projects, orders, tasks and notes.
Future<void> showCommandPalette(WidgetRef ref) async {
  final ctx = appRootContext;
  if (ctx == null) return;
  final motion = Motion.of(ctx);
  await showGeneralDialog<void>(
    context: ctx,
    barrierDismissible: true,
    barrierLabel: 'Close command palette',
    barrierColor: const Color(0x8C06080B),
    transitionDuration: motion.sheet,
    pageBuilder: (context, _, __) => const _CommandPalette(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: motion.spring,
        reverseCurve: motion.exit,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, (1 - curved.value) * -14),
            child: Transform.scale(
              scale: 0.96 + 0.04 * curved.value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

class _Entry {
  final String kind;
  final String label;
  final String? sub;
  final String? hint;
  final IconData icon;
  final void Function(WidgetRef ref) run;
  const _Entry(
    this.kind,
    this.label,
    this.icon,
    this.run, {
    this.sub,
    this.hint,
  });
}

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  static const double _rowHeight = 52;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  String _query = '';
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Entry> _commands(Map<String, String> keys) {
    String? hint(String id) => keys[id] == null ? null : prettyCombo(keys[id]!);
    _Entry go(String label, IconData icon, String id) => _Entry(
      'Go to',
      label,
      icon,
      (r) => dispatchAppAction(r, id),
      hint: hint(id),
    );
    return [
      go('Dashboard', Icons.dashboard_rounded, 'tabDashboard'),
      go('Projects', Icons.assignment_outlined, 'tabProjects'),
      go('Open Orders', Icons.local_shipping_outlined, 'tabOrders'),
      go('Workbench Tools', Icons.handyman_rounded, 'tabWorkbench'),
      go('BAMM Orders', Icons.precision_manufacturing_rounded, 'tabBamm'),
      go('Notes', Icons.edit_note_rounded, 'tabNotes'),
      go('Settings', Icons.settings_rounded, 'tabSettings'),
      _Entry(
        'Create',
        'New project',
        Icons.add_box_outlined,
        (r) => dispatchAppAction(r, 'createProject'),
        hint: hint('createProject'),
      ),
      _Entry(
        'Create',
        'New order',
        Icons.add_shopping_cart_rounded,
        (r) => dispatchAppAction(r, 'createOrder'),
        hint: hint('createOrder'),
      ),
      _Entry(
        'Create',
        'New note',
        Icons.note_add_outlined,
        (r) => dispatchAppAction(r, 'createNote'),
        hint: hint('createNote'),
      ),
      _Entry(
        'Action',
        'Toggle sidebar',
        Icons.view_sidebar_outlined,
        (r) => dispatchAppAction(r, 'toggleSidebar'),
        hint: hint('toggleSidebar'),
      ),
      _Entry(
        'Action',
        'Customize dashboard',
        Icons.tune_rounded,
        (r) => dispatchAppAction(r, 'customizeDashboard'),
      ),
      _Entry(
        'Action',
        'Search everything (full page)',
        Icons.search_rounded,
        (r) => dispatchAppAction(r, 'search'),
        hint: hint('search'),
      ),
      _Entry(
        'Action',
        'Calendar',
        Icons.calendar_month_rounded,
        (_) => appRouter.push('/calendar'),
      ),
      _Entry(
        'Action',
        'Inbox',
        Icons.inbox_rounded,
        (_) => appRouter.push('/inbox'),
      ),
      _Entry(
        'Action',
        'Machines',
        Icons.settings_applications_rounded,
        (_) => appRouter.push('/machines'),
      ),
      _Entry(
        'Action',
        'Vendors',
        Icons.storefront_outlined,
        (_) => appRouter.push('/vendors'),
      ),
      _Entry(
        'Action',
        'Export or restore a backup',
        Icons.archive_outlined,
        (_) => appRouter.go('/settings'),
      ),
    ];
  }

  List<_Entry> _results(Map<String, String> keys) {
    final q = _query.trim().toLowerCase();
    final commands = _commands(keys);
    if (q.isEmpty) return commands.take(10).toList();

    final out = <_Entry>[
      ...commands.where(
        (c) => ('${c.kind} ${c.label}').toLowerCase().contains(q),
      ),
    ];
    final hits = ref.read(projectProvider).searchAll(_query);
    for (final h in hits.projects.take(5)) {
      out.add(
        _Entry(
          'Project',
          h.project.title,
          Icons.assignment_outlined,
          (_) => appRouter.push('/projects/${h.project.id}'),
          sub: '#${h.project.priority}  ${h.project.machine}'.trim(),
        ),
      );
    }
    for (final h in hits.tasks.take(4)) {
      out.add(
        _Entry(
          'Task',
          h.task.description,
          Icons.check_circle_outline_rounded,
          (_) =>
              appRouter.push('/projects/${h.project.id}?taskId=${h.task.id}'),
          sub: h.project.title,
        ),
      );
    }
    for (final h in hits.orders.take(5)) {
      out.add(
        _Entry(
          'Order',
          h.description.isEmpty ? 'PO ${h.po}' : h.description,
          Icons.local_shipping_outlined,
          (_) {
            if (h.project != null) {
              final o = h.id != null ? '&orderId=${h.id}' : '';
              appRouter.push('/projects/${h.project!.id}?tab=orders$o');
            } else {
              appRouter.go(
                h.id != null ? '/orders?orderId=${h.id}' : '/orders',
              );
            }
          },
          sub: h.po.isEmpty
              ? h.projectTitle
              : 'PO ${h.po}  ·  ${h.projectTitle}',
        ),
      );
    }
    for (final h in hits.notes.take(4)) {
      out.add(
        _Entry(
          'Note',
          h.title.isEmpty ? 'Untitled note' : h.title,
          Icons.edit_note_rounded,
          (_) {
            if (h.projectId != null && h.isProjectNote) {
              appRouter.push('/projects/${h.projectId}?tab=logs');
            } else {
              appRouter.go(
                h.id != null ? '/voice-notes?noteId=${h.id}' : '/voice-notes',
              );
            }
          },
          sub: h.projectTitle,
        ),
      );
    }
    return out;
  }

  void _run(_Entry e) {
    Navigator.of(context).pop();
    // Let the dialog finish closing before navigating or opening another.
    Future.microtask(() => e.run(ref));
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _index = (_index + delta).clamp(0, count - 1));
    final top = _index * _rowHeight;
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.animateTo(
        top,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (top + _rowHeight > _scroll.offset + viewport) {
      _scroll.animateTo(
        top + _rowHeight - viewport,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final keys = ref.watch(keyBindingsProvider);
    final results = _results(keys);
    final index = _index.clamp(0, results.isEmpty ? 0 : results.length - 1);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 96, left: 16, right: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Material(
              color: colors.surface,
              elevation: 12,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1, results.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(-1, results.length),
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (results.isNotEmpty) _run(results[index]);
                  },
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.of(context).pop(),
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              autofocus: true,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Type a command, project, PO or note',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: colors.textSecondary,
                                ),
                              ),
                              onChanged: (v) => setState(() {
                                _query = v;
                                _index = 0;
                              }),
                            ),
                          ),
                          _Kbd('Esc', colors),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.border),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _rowHeight * 8,
                      ),
                      child: results.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Nothing matches "$_query".',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(8),
                              shrinkWrap: true,
                              itemExtent: _rowHeight,
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final e = results[i];
                                final selected = i == index;
                                return MouseRegion(
                                  onEnter: (_) => setState(() => _index = i),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _run(e),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? colors.primary.withValues(
                                                alpha: 0.14,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            e.icon,
                                            size: 20,
                                            color: selected
                                                ? colors.primary
                                                : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (e.sub != null &&
                                                    e.sub!.isNotEmpty)
                                                  Text(
                                                    e.sub!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          colors.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (e.hint != null)
                                            _Kbd(e.hint!, colors)
                                          else
                                            _Tag(e.kind, colors),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Divider(height: 1, color: colors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _Kbd('Up/Down', colors),
                          const SizedBox(width: 6),
                          Text(
                            'move',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _Kbd('Enter', colors),
                          const SizedBox(width: 6),
                          Text(
                            'open',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Kbd(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: colors.surfaceHighlight,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: colors.border),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: colors.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Tag(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: colors.surfaceHighlight,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: colors.textSecondary),
    ),
  );
}
