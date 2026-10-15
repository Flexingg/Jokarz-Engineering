import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/order_form.dart';
import 'autosave.dart';

/// Right-hand editor for one order (project-attached or unlinked). Edits are
/// saved automatically: when you click off the panel, close it, or select
/// another order, and after a short pause in typing.
///
/// Give it a `key` of the order id so selecting another order disposes this
/// state, which flushes any unsaved edits first.
class OrderEditorPanel extends ConsumerStatefulWidget {
  final OrderItem? order;
  final String? projectId;
  final StandaloneOrder? standalone;
  final String projectTitle;

  /// Status badge (delivered / ETA) built by the screen.
  final Widget statusBadge;

  /// Extra buttons shown under the title (mark delivered, copy PO, ...).
  final List<Widget> actions;
  final VoidCallback onClose;

  const OrderEditorPanel({
    super.key,
    this.order,
    this.projectId,
    this.standalone,
    required this.projectTitle,
    required this.statusBadge,
    required this.onClose,
    this.actions = const [],
  }) : assert((order != null && projectId != null) || standalone != null);

  @override
  ConsumerState<OrderEditorPanel> createState() => _OrderEditorPanelState();
}

class _OrderEditorPanelState extends ConsumerState<OrderEditorPanel>
    with AutosaveMixin {
  late ProviderContainer _container;
  late final OrderDraft _draft = widget.order != null
      ? OrderDraft.fromOrder(widget.order!)
      : OrderDraft.fromStandalone(widget.standalone!);
  late final String _id = widget.order?.id ?? widget.standalone!.id;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _draft.addListener(markDirty);
  }

  @override
  bool get canSave => _draft.isValid;

  @override
  Future<void> saveDraft() async {
    // Everything that reads the draft happens before the first await, so this
    // is safe to run while the panel is being disposed.
    final state = _container.read(projectProvider);
    final notifier = _container.read(projectProvider.notifier);
    final vendors = state.vendors;
    if (widget.order != null) {
      final project = state.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      final current = project?.orders.where((o) => o.id == _id).firstOrNull;
      if (current == null) return; // deleted elsewhere
      final updated = _draft.applyToOrder(
        current,
        vendors,
        includeDelivered: false,
      );
      await notifier.updateOrder(widget.projectId!, updated);
    } else {
      final current = state.standaloneOrders
          .where((o) => o.id == _id)
          .firstOrNull;
      if (current == null) return;
      final updated = _draft.applyToStandalone(
        current,
        vendors,
        includeDelivered: false,
      );
      await notifier.updateStandaloneOrder(updated);
    }
  }

  @override
  void dispose() {
    disposeAutosave();
    _draft.removeListener(markDirty);
    // Child fields are unmounted (and detached from the controllers) before
    // this runs, so the draft can be released right away.
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return AutosaveScope(
      onBlur: flush,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        // ListTiles in the form need a Material between them and the
        // decorated container above.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _draft.po,
                        builder: (context, _) => Text(
                          _draft.po.text.isEmpty
                              ? 'No PO yet'
                              : 'PO ${_draft.po.text}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SaveStatusLabel(status: saveStatus, onRetry: flush),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await flush();
                        widget.onClose();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.projectTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: widget.statusBadge,
                      ),
                      if (widget.actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.actions,
                        ),
                      ],
                      const SizedBox(height: 16),
                      OrderFields(draft: _draft),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
