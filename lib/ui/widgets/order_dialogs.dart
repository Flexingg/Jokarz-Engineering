import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import 'searchable_dropdown.dart';
import 'order_form.dart';

/// The single order dialog used everywhere (Open Orders, project Orders tab,
/// universal search quick-add, keyboard shortcut) for BOTH project-attached
/// orders and unlinked orders, in add and edit mode.
///
/// * Add from the Open Orders screen: leave everything null - a "Project"
///   picker lets the order be created unlinked or attached.
/// * Add from a project: pass [fixedProjectId].
/// * Edit a project order: pass [existingOrder] + [existingOrderProjectId].
/// * Edit an unlinked order: pass [existingStandalone].
///
/// [prefillDescription] is populated from search text when launched from the
/// search flow. [onAdded] fires after a successful *add*.
Future<void> showOrderDialog(
  BuildContext context, {
  OrderItem? existingOrder,
  String? existingOrderProjectId,
  StandaloneOrder? existingStandalone,
  String? fixedProjectId,
  String prefillDescription = '',
  VoidCallback? onAdded,
}) {
  // Read through the app's container, not a widget's `ref`: callers such as the
  // command palette close right after launching this dialog, which disposes
  // their `ref` while the dialog (and its rebuilds) is still alive.
  final container = ProviderScope.containerOf(context, listen: false);
  final isEdit = existingOrder != null || existingStandalone != null;
  final draft = existingOrder != null
      ? OrderDraft.fromOrder(existingOrder)
      : existingStandalone != null
      ? OrderDraft.fromStandalone(existingStandalone)
      : OrderDraft.blank(prefillDescription: prefillDescription);
  // Project the new order will be attached to (add mode only); null = unlinked.
  String? targetProjectId = fixedProjectId;
  final canPickProject = !isEdit && fixedProjectId == null;

  String title;
  if (isEdit) {
    title = existingOrder != null
        ? 'Edit Purchase Order'
        : 'Edit Unlinked Order';
  } else {
    title = fixedProjectId != null ? 'Add Order / Requisition' : 'Add Order';
  }

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final projects = container.read(projectProvider).activeProjects;

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: OrderFields(
                draft: draft,
                autofocusDescription: !isEdit,
                showDeliveredToggle: isEdit,
                header: canPickProject
                    ? SearchableDropdownFormField<String>(
                        value: targetProjectId,
                        labelText:
                            'Project (optional - leave empty for Unlinked)',
                        prefixIcon: const Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 18,
                        ),
                        items: projects.map((p) => p.id).toList(),
                        labelOf: (id) =>
                            projects
                                .where((p) => p.id == id)
                                .firstOrNull
                                ?.title ??
                            '',
                        onChanged: (val) =>
                            setDialogState(() => targetProjectId = val),
                      )
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!draft.isValid) return;
                final notifier = container.read(projectProvider.notifier);
                final vendors = container.read(projectProvider).vendors;

                if (existingOrder != null) {
                  final projectId = existingOrderProjectId ?? fixedProjectId;
                  if (projectId == null) return;
                  await notifier.updateOrder(
                    projectId,
                    draft.applyToOrder(existingOrder, vendors),
                  );
                } else if (existingStandalone != null) {
                  await notifier.updateStandaloneOrder(
                    draft.applyToStandalone(existingStandalone, vendors),
                  );
                } else if (targetProjectId != null) {
                  await notifier.addOrder(
                    targetProjectId!,
                    draft.toNewOrder(vendors),
                  );
                } else {
                  await notifier.addStandaloneOrder(
                    draft.toNewStandalone(vendors),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!isEdit) onAdded?.call();
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Order'),
            ),
          ],
        );
      },
    ),
    // The route's exit animation still paints the fields after the future
    // completes, so release the controllers a moment later.
  ).whenComplete(
    () =>
        Future<void>.delayed(const Duration(milliseconds: 500), draft.dispose),
  );
}

/// Back-compat entry point for the search quick-add and keyboard shortcut.
Future<void> showStandaloneOrderDialog(
  BuildContext context, {
  String prefillDescription = '',
  VoidCallback? onAdded,
}) => showOrderDialog(
  context,
  prefillDescription: prefillDescription,
  onAdded: onAdded,
);
