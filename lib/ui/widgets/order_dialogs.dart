import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import 'searchable_dropdown.dart';

/// Shared "Add Unlinked Order" dialog, used by the Open Orders screen and the
/// universal search quick-add. [prefillDescription] is populated from search
/// text when launched from the search flow. [onAdded] fires after a successful
/// save (e.g. to switch the Open Orders tab).
Future<void> showStandaloneOrderDialog(
  BuildContext context,
  WidgetRef ref, {
  String prefillDescription = '',
  VoidCallback? onAdded,
}) {
  final descCtrl = TextEditingController(text: prefillDescription);
  final prCtrl = TextEditingController();
  final poCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final quoteCtrl = TextEditingController();
  final trackingCtrl = TextEditingController();
  String? selectedVendorId;
  String selectedVendorName = '';
  DateTime? eta;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final vendors = ref.read(projectProvider).vendors;

        return AlertDialog(
          title: const Text('Add Unlinked Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Description *'),
                ),
                const SizedBox(height: 10),
                if (vendors.isNotEmpty) ...[
                  SearchableDropdownFormField<String>(
                    value: selectedVendorId,
                    labelText: 'Vendor / Supplier',
                    prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                    items: vendors.map((v) => v.id).toList(),
                    labelOf: (id) => vendors.firstWhere((v) => v.id == id,
                        orElse: () => vendors.isNotEmpty ? vendors.first : throw StateError('')).name,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedVendorId = val;
                        final v = vendors.where((vend) => vend.id == val).firstOrNull;
                        selectedVendorName = v?.name ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'PR #'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: poCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'PO #'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price (\$)', prefixText: '\$ '),
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
                const SizedBox(height: 10),
                TextField(
                  controller: trackingCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Shipment Tracking Link / URL',
                    prefixIcon: Icon(Icons.track_changes_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    eta != null ? 'ETA: ${DateFormat('MMM d, y').format(eta!)}' : 'No ETA',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: eta ?? DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setDialogState(() => eta = picked);
                    },
                    child: const Text('Pick ETA'),
                  ),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final desc = descCtrl.text.trim();
                if (desc.isEmpty) return;
                ref.read(projectProvider.notifier).addStandaloneOrder(
                      StandaloneOrder(
                        description: desc,
                        pr: prCtrl.text.trim(),
                        po: poCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text) ?? 0.0,
                        eta: eta,
                        notes: notesCtrl.text.trim(),
                        vendorId: selectedVendorId,
                        vendorName: selectedVendorName,
                        vendorQuoteNumber: quoteCtrl.text.trim(),
                        trackingUrl: trackingCtrl.text.trim(),
                      ),
                    );
                Navigator.pop(ctx);
                onAdded?.call();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}

