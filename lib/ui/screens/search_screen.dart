import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/search_result.dart';
import '../../providers/project_provider.dart';
import '../../utils/text_utils.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/note_dialogs.dart';
import '../widgets/order_dialogs.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _quickNoteCounter = 0;

  @override
  void initState() {
    super.initState();
    _quickNoteCounter = ref.read(projectProvider).voiceNotes.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addProject() {
    final title = titleCase(_query);
    if (title.isEmpty) return;
    context.push('/projects/new', extra: {'initialTitle': title});
  }

  void _addNote() {
    if (_query.trim().isEmpty) return;
    _quickNoteCounter++;
    showNewFieldNoteDialog(
      context,
      ref,
      prefillTitle: 'Quick Note $_quickNoteCounter',
      prefillContent: _query.trim(),
    );
  }

  void _addOrder() {
    if (_query.trim().isEmpty) return;
    showStandaloneOrderDialog(context, ref, prefillDescription: _query.trim());
  }

  void _openProject(Project p) => context.push('/projects/${p.id}');

  void _openOrder(OrderSearchHit h) {
    if (h.project != null) {
      context.push('/projects/${h.project!.id}?tab=orders');
    } else {
      context.push('/orders');
    }
  }

  void _openNote(NoteSearchHit h) {
    if (h.projectId != null) {
      context.push('/projects/${h.projectId}');
    } else {
      context.push('/voice-notes');
    }
  }

  void _openTask(TaskSearchHit h) {
    context.push('/projects/${h.project.id}');
  }

  void _openFirstResult(SearchResults results) {
    if (results.projects.isNotEmpty) {
      _openProject(results.projects.first.project);
    } else if (results.tasks.isNotEmpty) {
      _openTask(results.tasks.first);
    } else if (results.orders.isNotEmpty) {
      _openOrder(results.orders.first);
    } else if (results.notes.isNotEmpty) {
      _openNote(results.notes.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final results = state.searchAll(_query);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Field (autofocus => keyboard opens on mobile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _openFirstResult(results),
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Quick-Add Row
          if (_query.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _QuickAddButton(
                    icon: Icons.add_box_outlined,
                    label: 'Project',
                    color: AppTheme.of(context).primary,
                    onTap: _addProject,
                  ),
                  const SizedBox(width: 8),
                  _QuickAddButton(
                    icon: Icons.note_add_outlined,
                    label: 'Note',
                    color: AppTheme.of(context).amber,
                    onTap: _addNote,
                  ),
                  const SizedBox(width: 8),
                  _QuickAddButton(
                    icon: Icons.add_shopping_cart_outlined,
                    label: 'Order',
                    color: AppTheme.of(context).emerald,
                    onTap: _addOrder,
                  ),
                ],
              ),
            ),

          const Divider(height: 12),

          Expanded(
            child: _query.trim().isEmpty
                ? const _EmptyPrompt()
                : (results.isEmpty
                    ? _NoResults(
                        query: _query,
                        onProject: _addProject,
                        onNote: _addNote,
                        onOrder: _addOrder,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (results.projects.isNotEmpty) ...[
                            _SectionHeader('Projects (${results.projects.length})'),
                            ...results.projects.map(_buildProjectTile),
                          ],
                          if (results.tasks.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SectionHeader('Tasks (${results.tasks.length})'),
                            ...results.tasks.map(_buildTaskTile),
                          ],
                          if (results.orders.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SectionHeader('Orders (${results.orders.length})'),
                            ...results.orders.map((h) => _buildOrderTile(h, currency)),
                          ],
                          if (results.notes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SectionHeader('Notes (${results.notes.length})'),
                            ...results.notes.map(_buildNoteTile),
                          ],
                          const SizedBox(height: 24),
                        ],
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectTile(ProjectSearchHit hit) {
    final p = hit.project;
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openProject(p),
      child: Row(
        children: [
          Icon(Icons.engineering_outlined, color: AppTheme.of(context).primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    children: _highlightSpans(p.title),
                  ),
                ),
                if (p.machine.isNotEmpty)
                  Text(
                    p.machine,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (p.isCompletedOrCancelled)
            const ExpressiveBadge(label: 'Closed', color: Colors.grey, fontSize: 9)
          else
            ExpressiveBadge(
              label: '#${p.priority}',
              color: AppTheme.of(context).coral,
              fontSize: 9,
            ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(TaskSearchHit hit) {
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openTask(hit),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, color: AppTheme.of(context).amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    children: _highlightSpans(hit.task.description),
                  ),
                ),
                Text(
                  hit.project.title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hit.task.isCompleted)
            ExpressiveBadge(label: '✓ Done', color: AppTheme.of(context).emerald, fontSize: 9)
          else if (hit.task.pendingReason.isNotEmpty)
            ExpressiveBadge(label: '⏳ ${hit.task.pendingReason}', color: AppTheme.of(context).coral, fontSize: 9),
        ],
      ),
    );
  }

  Widget _buildOrderTile(OrderSearchHit h, NumberFormat currency) {
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openOrder(h),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: AppTheme.of(context).amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    children: _highlightSpans(
                      h.description.isEmpty ? 'Parts / Material Order' : h.description,
                    ),
                  ),
                ),
                Text(
                  '${h.projectTitle} • PO: ${h.po.isNotEmpty ? h.po : "—"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            currency.format(h.price),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(NoteSearchHit h) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openNote(h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                h.isProjectNote ? Icons.sticky_note_2_outlined : Icons.edit_note_rounded,
                color: h.isProjectNote ? AppTheme.of(context).amber : AppTheme.of(context).primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  h.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (h.projectTitle != null)
                ExpressiveBadge(
                  label: h.projectTitle!,
                  color: AppTheme.of(context).primaryBlue,
                  isOutlined: true,
                  fontSize: 9,
                ),
            ],
          ),
          if (h.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                ),
                children: _highlightSpans(h.content),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Splits [text] and highlights occurrences of any query token.
  List<InlineSpan> _highlightSpans(String text) {
    if (_query.trim().isEmpty) return [TextSpan(text: text)];
    final tokens = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    int i = 0;
    while (i < text.length) {
      int? matchStart;
      int matchLen = 0;
      for (final t in tokens) {
        final idx = lower.indexOf(t, i);
        if (idx >= 0 && (matchStart == null || idx < matchStart)) {
          matchStart = idx;
          matchLen = t.length;
        }
      }
      if (matchStart == null) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (matchStart > i) spans.add(TextSpan(text: text.substring(i, matchStart)));
      spans.add(TextSpan(
        text: text.substring(matchStart, matchStart + matchLen),
        style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.w900),
      ));
      i = matchStart + matchLen;
    }
    return spans;
  }
}

class _QuickAddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(
                  'Add ${label.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppTheme.of(context).primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          const Text(
            'Search projects, orders, and notes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Type to search. Use Add Project / Note / Order\nto create from your search text.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  final VoidCallback onProject;
  final VoidCallback onNote;
  final VoidCallback onOrder;

  const _NoResults({
    required this.query,
    required this.onProject,
    required this.onNote,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            'No matches for "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create it from your search text:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _QuickAddButton(
                  icon: Icons.add_box_outlined,
                  label: 'Project',
                  color: AppTheme.of(context).primary,
                  onTap: onProject,
                ),
                const SizedBox(width: 8),
                _QuickAddButton(
                  icon: Icons.note_add_outlined,
                  label: 'Note',
                  color: AppTheme.of(context).amber,
                  onTap: onNote,
                ),
                const SizedBox(width: 8),
                _QuickAddButton(
                  icon: Icons.add_shopping_cart_outlined,
                  label: 'Order',
                  color: AppTheme.of(context).emerald,
                  onTap: onOrder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
