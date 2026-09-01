import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _search = '';

  void _showAddEditVendorDialog(BuildContext context, [Vendor? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final websiteCtrl = TextEditingController(text: existing?.website ?? '');
    final accountCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              TextField(
                controller: websiteCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website / Portal URL',
                  prefixIcon: Icon(Icons.language_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer / Account #',
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

              if (existing == null) {
                final v = Vendor(
                  name: name,
                  contactPerson: contactCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  website: websiteCtrl.text.trim(),
                  accountNumber: accountCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                await ref.read(projectProvider.notifier).addVendor(v);
              } else {
                final updated = existing.copyWith(
                  name: name,
                  contactPerson: contactCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  website: websiteCtrl.text.trim(),
                  accountNumber: accountCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                await ref.read(projectProvider.notifier).updateVendor(updated);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add Vendor' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _launchUrlHelper(String urlStr) async {
    if (urlStr.isEmpty) return;
    String formatted = urlStr.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://') && !formatted.startsWith('mailto:') && !formatted.startsWith('tel:')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var vendors = state.vendors;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      vendors = vendors.where((v) {
        return v.name.toLowerCase().contains(q) ||
            v.contactPerson.toLowerCase().contains(q) ||
            v.notes.toLowerCase().contains(q) ||
            v.accountNumber.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('Vendor & Supplier Directory', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vendors, contact reps, account #...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Vendor List
          Expanded(
            child: vendors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 54, color: Colors.grey),
                        const SizedBox(height: 14),
                        Text(
                          state.vendors.isEmpty
                              ? 'No Vendors in Directory'
                              : 'No Matching Vendors',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add your key suppliers, parts distributors, and machine shops\nfor 1-tap ordering, phone contacts, and tracking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vendors.length,
                    itemBuilder: (context, index) {
                      final v = vendors[index];
                      return ExpressiveCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & edit menu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.primaryCyan,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showAddEditVendorDialog(context, v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () =>
                                          ref.read(projectProvider.notifier).deleteVendor(v.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (v.contactPerson.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(v.contactPerson, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),

                            // Badges strip
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (v.accountNumber.isNotEmpty)
                                  ExpressiveBadge(
                                    label: 'Acct: ${v.accountNumber}',
                                    icon: Icons.badge_rounded,
                                    color: AppTheme.accentEmerald,
                                    fontSize: 10,
                                  ),
                                if (v.phone.isNotEmpty)
                                  ActionChip(
                                    avatar: const Icon(Icons.phone_rounded, size: 12, color: AppTheme.accentEmerald),
                                    label: Text(v.phone, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _launchUrlHelper('tel:${v.phone}'),
                                  ),
                                if (v.email.isNotEmpty)
                                  ActionChip(
                                    avatar: const Icon(Icons.email_rounded, size: 12, color: AppTheme.primaryCyan),
                                    label: Text(v.email, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _launchUrlHelper('mailto:${v.email}'),
                                  ),
                                if (v.website.isNotEmpty)
                                  ActionChip(
                                    avatar: const Icon(Icons.language_rounded, size: 12, color: AppTheme.accentAmber),
                                    label: const Text('Website', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _launchUrlHelper(v.website),
                                  ),
                              ],
                            ),
                            if (v.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                v.notes,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditVendorDialog(context),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Vendor'),
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.black87,
      ),
    );
  }
}
