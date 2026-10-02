import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/vendor_dialog.dart';
import '../widgets/expressive_badge.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _search = '';

  void _showAddEditVendorDialog(BuildContext context, [Vendor? existing]) {
    showVendorDialog(context, ref, existing: existing);
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
        title: Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppTheme.of(context).primary),
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
                            color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.of(context).primary,
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
                                    color: AppTheme.of(context).emerald,
                                    fontSize: 10,
                                  ),
                                if (v.phone.isNotEmpty)
                                  ActionChip(
                                    avatar: Icon(Icons.phone_rounded, size: 12, color: AppTheme.of(context).emerald),
                                    label: Text(v.phone, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _launchUrlHelper('tel:${v.phone}'),
                                  ),
                                if (v.email.isNotEmpty)
                                  ActionChip(
                                    avatar: Icon(Icons.email_rounded, size: 12, color: AppTheme.of(context).primary),
                                    label: Text(v.email, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _launchUrlHelper('mailto:${v.email}'),
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
        backgroundColor: AppTheme.of(context).primary,
        foregroundColor: Colors.black87,
      ),
    );
  }
}
