import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vendor.dart';
import '../../providers/project_provider.dart';

/// Shared add/edit vendor dialog. Returns the saved [Vendor] (or null if
/// cancelled) so callers like the order dialog can select a freshly added
/// vendor immediately.
Future<Vendor?> showVendorDialog(BuildContext context, {Vendor? existing, String prefillName = ''}) {
  // Read through the app's container, not a widget's `ref`: callers such as the
  // command palette close right after launching this dialog, which disposes
  // their `ref` while the dialog (and its rebuilds) is still alive.
  final container = ProviderScope.containerOf(context, listen: false);
  final nameCtrl = TextEditingController(text: existing?.name ?? prefillName);
  final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final accountCtrl = TextEditingController(text: existing?.accountNumber ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final typeCtrl = TextEditingController(text: existing?.type ?? '');
  String type = existing?.type ?? '';
  bool editingNewType = false;

  return showDialog<Vendor>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        // Unique, non-empty types already used across vendors (for the dropdown).
        final vendors = container.read(projectProvider).vendors;
        final typeOptions = <String>{
          for (final v in vendors)
            if (v.type.trim().isNotEmpty) v.type.trim(),
        }.toList()..sort();
        final typeItems = <DropdownMenuItem<String?>>[
          for (final t in typeOptions) DropdownMenuItem(value: t, child: Text(t)),
          if (type.isNotEmpty && !typeOptions.contains(type))
            DropdownMenuItem(value: type, child: Text('$type (new)')),
          const DropdownMenuItem(value: '__new__', child: Text('＋ Add new type…')),
        ];
        final typeValue = editingNewType
            ? '__new__'
            : (type.isNotEmpty ? type : null);

        return AlertDialog(
          title: Text(existing == null ? 'Add Supplier / Vendor' : 'Edit Vendor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Company Name *',
                    hintText: 'e.g. McMaster-Carr, Grainger, Keyence',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sales Rep / Contact Person',
                    hintText: 'e.g. John Smith',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_rounded, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Vendor Type dropdown (options from existing + add new)
                DropdownButtonFormField<String?>(
                  value: typeValue,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined, size: 18),
                  ),
                  hint: const Text('Select or add a type'),
                  isExpanded: true,
                  items: typeItems,
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == '__new__') {
                        editingNewType = true;
                        type = typeCtrl.text.trim();
                      } else {
                        editingNewType = false;
                        type = v ?? '';
                      }
                    });
                  },
                ),
                if (editingNewType) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: typeCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'New type',
                      hintText: 'e.g. Parts Distributor, Fabricator, Machining',
                    ),
                    // Keep the field open while typing; the value is read on save.
                    onChanged: (_) => type = typeCtrl.text.trim(),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: accountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SAP Vendor Code',
                    prefixIcon: Icon(Icons.badge_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Discount Terms / Specialties',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (editingNewType) type = typeCtrl.text.trim();
                Vendor? saved;

                if (existing == null) {
                  final v = Vendor(
                    name: name,
                    contactPerson: contactCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    type: type,
                    accountNumber: accountCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );
                  await container.read(projectProvider.notifier).addVendor(v);
                  saved = v;
                } else {
                  final updated = existing.copyWith(
                    name: name,
                    contactPerson: contactCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    type: type,
                    accountNumber: accountCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );
                  await container.read(projectProvider.notifier).updateVendor(updated);
                  saved = updated;
                }
                if (ctx.mounted) Navigator.pop(ctx, saved);
              },
              child: Text(existing == null ? 'Add Vendor' : 'Save Changes'),
            ),
          ],
        );
      },
    ),
  );
}

