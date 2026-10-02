import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import 'searchable_dropdown.dart';
import 'bamm_chip.dart';
import 'bamm_assign_dialog.dart';
import 'vendor_dialog.dart';

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
  BuildContext context,
  WidgetRef ref, {
  OrderItem? existingOrder,
  String? existingOrderProjectId,
  StandaloneOrder? existingStandalone,
  String? fixedProjectId,
  String prefillDescription = '',
  VoidCallback? onAdded,
}) {
  final isEdit = existingOrder != null || existingStandalone != null;
  final descCtrl = TextEditingController(
      text: existingOrder?.description ?? existingStandalone?.description ?? prefillDescription);
  final prCtrl = TextEditingController(text: existingOrder?.pr ?? existingStandalone?.pr ?? '');
  final poCtrl = TextEditingController(text: existingOrder?.po ?? existingStandalone?.po ?? '');
  final initialPrice = existingOrder?.price ?? existingStandalone?.price ?? 0.0;
  final priceCtrl =
      TextEditingController(text: initialPrice > 0 ? initialPrice.toStringAsFixed(2) : '');
  final notesCtrl =
      TextEditingController(text: existingOrder?.notes ?? existingStandalone?.notes ?? '');
  final quoteCtrl = TextEditingController(
      text: existingOrder?.vendorQuoteNumber ?? existingStandalone?.vendorQuoteNumber ?? '');
  final trackingCtrl = TextEditingController(
      text: existingOrder?.trackingUrl ?? existingStandalone?.trackingUrl ?? '');
  String? selectedVendorId = existingOrder?.vendorId ?? existingStandalone?.vendorId;
  String selectedVendorName = existingOrder?.vendorName ?? existingStandalone?.vendorName ?? '';
  DateTime? eta = existingOrder?.eta ?? existingStandalone?.eta;
  bool delivered = existingOrder?.delivered ?? existingStandalone?.delivered ?? false;
  bool addToStores = existingOrder?.addToStores ?? existingStandalone?.addToStores ?? false;
  List<String> bammWorkOrders =
      List.from(existingOrder?.bammWorkOrders ?? existingStandalone?.bammWorkOrders ?? const []);
  // Project the new order will be attached to (add mode only); null = unlinked.
  String? targetProjectId = fixedProjectId;
  final canPickProject = !isEdit && fixedProjectId == null;

  String title;
  if (isEdit) {
    title = existingOrder != null ? 'Edit Purchase Order' : 'Edit Unlinked Order';
  } else {
    title = fixedProjectId != null ? 'Add Order / Requisition' : 'Add Order';
  }

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final state = ref.read(projectProvider);
        final vendors = state.vendors;
        final projects = state.activeProjects;
        final colors = AppTheme.of(ctx);
        final vendorIdValid = vendors.any((v) => v.id == selectedVendorId);

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: descCtrl,
                    autofocus: !isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Part / Material Description *',
                      hintText: 'e.g. SKF 6205 Bearings, UHMW Sheet',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canPickProject) ...[
                    SearchableDropdownFormField<String>(
                      value: targetProjectId,
                      labelText: 'Project (optional - leave empty for Unlinked)',
                      prefixIcon: const Icon(Icons.precision_manufacturing_outlined, size: 18),
                      items: projects.map((p) => p.id).toList(),
                      labelOf: (id) => projects.where((p) => p.id == id).firstOrNull?.title ?? '',
                      onChanged: (val) => setDialogState(() => targetProjectId = val),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Vendor picker + quick add
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: vendors.isEmpty
                            ? const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Vendor / Supplier',
                                  prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                                ),
                                child: Text('No vendors yet - add one →'),
                              )
                            : SearchableDropdownFormField<String>(
                                value: vendorIdValid ? selectedVendorId : null,
                                labelText: 'Vendor / Supplier',
                                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                                items: vendors.map((v) => v.id).toList(),
                                labelOf: (id) =>
                                    vendors.where((v) => v.id == id).firstOrNull?.name ?? '',
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedVendorId = val;
                                    final v = vendors.where((vend) => vend.id == val).firstOrNull;
                                    selectedVendorName = v?.name ?? '';
                                  });
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Quick add vendor',
                        child: IconButton.filledTonal(
                          onPressed: () async {
                            final created = await showVendorDialog(ctx, ref);
                            if (created != null) {
                              setDialogState(() {
                                selectedVendorId = created.id;
                                selectedVendorName = created.name;
                              });
                            }
                          },
                          icon: const Icon(Icons.add_business_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'PR (Requisition)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: poCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'PO Number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Price (\$)', prefixText: '\$ '),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: quoteCtrl,
                          decoration: const InputDecoration(labelText: 'Quote #'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trackingCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Shipment Tracking Link / URL',
                      prefixIcon: Icon(Icons.track_changes_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.local_shipping_outlined, color: colors.primary),
                    title: Text(
                      eta != null ? DateFormat('MMM d, y').format(eta!) : 'No ETA',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Estimated Delivery (ETA)', style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eta != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => eta = null),
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: eta ?? DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setDialogState(() => eta = picked);
                          },
                          child: const Text('Set ETA'),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.build_circle_rounded, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'BAMM Work Orders',
                        style: Theme.of(ctx)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final selected = await showDialog<List<String>>(
                            context: ctx,
                            builder: (c) => BammAssignDialog(
                              initialSelected: bammWorkOrders,
                              title: 'Assign BAMM to Order',
                            ),
                          );
                          if (selected != null) {
                            setDialogState(() => bammWorkOrders = selected);
                          }
                        },
                        icon: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text('Assign BAMM'),
                      ),
                    ],
                  ),
                  if (bammWorkOrders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: bammWorkOrders.map((wo) {
                          return BammChip(
                            workOrderNo: wo,
                            onDeleted: () => setDialogState(() {
                              bammWorkOrders = bammWorkOrders.where((w) => w != wo).toList();
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.warehouse_outlined,
                        color: addToStores ? colors.emerald : Colors.grey),
                    title: const Text('Add to Stores', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Stock this part in the plant storeroom',
                        style: TextStyle(fontSize: 11)),
                    value: addToStores,
                    onChanged: (v) => setDialogState(() => addToStores = v),
                  ),
                  if (isEdit)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Marked as Delivered',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Part has arrived at plant/crib',
                          style: TextStyle(fontSize: 11)),
                      value: delivered,
                      onChanged: (val) {
                        if (val != null) setDialogState(() => delivered = val);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final desc = descCtrl.text.trim();
                if (desc.isEmpty) return;
                final notifier = ref.read(projectProvider.notifier);
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final vendorId = vendors.any((v) => v.id == selectedVendorId) ? selectedVendorId : null;
                final vendorName = vendorId == null ? '' : selectedVendorName;

                if (existingOrder != null) {
                  final projectId = existingOrderProjectId ?? fixedProjectId;
                  if (projectId == null) return;
                  await notifier.updateOrder(
                    projectId,
                    existingOrder.copyWith(
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      description: desc,
                      price: price,
                      eta: eta,
                      clearEta: eta == null,
                      delivered: delivered,
                      addToStores: addToStores,
                      vendorId: vendorId,
                      clearVendorId: vendorId == null,
                      vendorName: vendorName,
                      vendorQuoteNumber: quoteCtrl.text.trim(),
                      trackingUrl: trackingCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      bammWorkOrders: bammWorkOrders,
                    ),
                  );
                } else if (existingStandalone != null) {
                  await notifier.updateStandaloneOrder(
                    existingStandalone.copyWith(
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      description: desc,
                      price: price,
                      eta: eta,
                      clearEta: eta == null,
                      delivered: delivered,
                      addToStores: addToStores,
                      vendorId: vendorId,
                      clearVendorId: vendorId == null,
                      vendorName: vendorName,
                      vendorQuoteNumber: quoteCtrl.text.trim(),
                      trackingUrl: trackingCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      bammWorkOrders: bammWorkOrders,
                    ),
                  );
                } else if (targetProjectId != null) {
                  await notifier.addOrder(
                    targetProjectId!,
                    OrderItem(
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      description: desc,
                      price: price,
                      eta: eta,
                      addToStores: addToStores,
                      vendorId: vendorId,
                      vendorName: vendorName,
                      vendorQuoteNumber: quoteCtrl.text.trim(),
                      trackingUrl: trackingCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      bammWorkOrders: bammWorkOrders,
                    ),
                  );
                } else {
                  await notifier.addStandaloneOrder(
                    StandaloneOrder(
                      description: desc,
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      price: price,
                      eta: eta,
                      addToStores: addToStores,
                      notes: notesCtrl.text.trim(),
                      vendorId: vendorId,
                      vendorName: vendorName,
                      vendorQuoteNumber: quoteCtrl.text.trim(),
                      trackingUrl: trackingCtrl.text.trim(),
                      bammWorkOrders: bammWorkOrders,
                    ),
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
  );
}

/// Back-compat entry point for the search quick-add and keyboard shortcut.
Future<void> showStandaloneOrderDialog(
  BuildContext context,
  WidgetRef ref, {
  String prefillDescription = '',
  VoidCallback? onAdded,
}) =>
    showOrderDialog(context, ref, prefillDescription: prefillDescription, onAdded: onAdded);
