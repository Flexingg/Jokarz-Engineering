import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor.dart';
import '../../providers/project_provider.dart';
import '../adaptive/master_detail.dart';
import '../widgets/context_menu.dart';
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
  String? _selectedId;

  void _showAddEditVendorDialog(BuildContext context, [Vendor? existing]) {
    showVendorDialog(context, ref, existing: existing);
  }

  void _launchUrlHelper(String urlStr) async {
    if (urlStr.isEmpty) return;
    String formatted = urlStr.trim();
    if (!formatted.startsWith('http://') &&
        !formatted.startsWith('https://') &&
        !formatted.startsWith('mailto:') &&
        !formatted.startsWith('tel:')) {
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
            const Flexible(
              child: Text(
                'Vendor & Supplier Directory',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: AdaptiveMasterDetail(
        masterWidth: 440,
        detailBuilder: (ctx) => _VendorDetail(
          vendor:
              state.vendors.where((v) => v.id == _selectedId).firstOrNull ??
              (vendors.isNotEmpty ? vendors.first : null),
          onEdit: (v) => _showAddEditVendorDialog(context, v),
        ),
        list: Column(
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                          const Icon(
                            Icons.storefront_outlined,
                            size: 54,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            state.vendors.isEmpty
                                ? 'No Vendors in Directory'
                                : 'No Matching Vendors',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add your key suppliers, parts distributors, and machine shops\nfor 1-tap ordering, phone contacts, and tracking.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.of(context).textSecondary
                                  : AppTheme.of(context).textSecondary,
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
                          isGlowing: false,
                          borderColor: _selectedId == v.id
                              ? AppTheme.of(context).primary
                              : null,
                          onTap: () => setState(() => _selectedId = v.id),
                          contextActions: [
                            MenuAction(
                              'Edit...',
                              Icons.edit_outlined,
                              () => _showAddEditVendorDialog(context, v),
                            ),
                            MenuAction(
                              'Delete',
                              Icons.delete_outline,
                              () => ref
                                  .read(projectProvider.notifier)
                                  .deleteVendor(v.id),
                              danger: true,
                              dividerBefore: true,
                            ),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & edit menu
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _showAddEditVendorDialog(
                                              context,
                                              v,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => ref
                                            .read(projectProvider.notifier)
                                            .deleteVendor(v.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (v.contactPerson.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      v.contactPerson,
                                      style: const TextStyle(fontSize: 13),
                                    ),
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
                                      avatar: Icon(
                                        Icons.phone_rounded,
                                        size: 12,
                                        color: AppTheme.of(context).emerald,
                                      ),
                                      label: Text(
                                        v.phone,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () =>
                                          _launchUrlHelper('tel:${v.phone}'),
                                    ),
                                  if (v.email.isNotEmpty)
                                    ActionChip(
                                      avatar: Icon(
                                        Icons.email_rounded,
                                        size: 12,
                                        color: AppTheme.of(context).primary,
                                      ),
                                      label: Text(
                                        v.email,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () =>
                                          _launchUrlHelper('mailto:${v.email}'),
                                    ),
                                ],
                              ),
                              if (v.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  v.notes,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
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

/// Right-hand pane on wide windows: who the vendor is and what has been
/// ordered from them.
class _VendorDetail extends ConsumerWidget {
  final Vendor? vendor;
  final void Function(Vendor) onEdit;
  const _VendorDetail({required this.vendor, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vendor;
    final colors = AppTheme.of(context);
    if (v == null) {
      return const Center(child: Text('Select a vendor to see its orders'));
    }
    final state = ref.watch(projectProvider);
    bool mine(String? id, String name) =>
        id == v.id ||
        (id == null &&
            name.isNotEmpty &&
            name.toLowerCase() == v.name.toLowerCase());

    final rows =
        <
            ({
              String desc,
              String po,
              double price,
              DateTime? eta,
              bool delivered,
              String where,
              VoidCallback open,
            })
          >[
            for (final p in state.projects)
              for (final o in p.orders)
                if (mine(o.vendorId, o.vendorName))
                  (
                    desc: o.description,
                    po: o.po,
                    price: o.price,
                    eta: o.eta,
                    delivered: o.delivered,
                    where: p.title,
                    open: () => context.push(
                      '/projects/${p.id}?tab=orders&orderId=${o.id}',
                    ),
                  ),
            for (final o in state.standaloneOrders)
              if (mine(o.vendorId, o.vendorName))
                (
                  desc: o.description,
                  po: o.po,
                  price: o.price,
                  eta: o.eta,
                  delivered: o.delivered,
                  where: 'Unlinked',
                  open: () => context.go('/orders?orderId=${o.id}'),
                ),
          ]
          ..sort((a, b) {
            if (a.delivered != b.delivered) return a.delivered ? 1 : -1;
            if (a.eta == null || b.eta == null) return a.eta == null ? 1 : -1;
            return a.eta!.compareTo(b.eta!);
          });

    final open = rows.where((r) => !r.delivered).toList();
    final spend = rows.fold<double>(0, (a, r) => a + r.price);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                v.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => onEdit(v),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
        if (v.contactPerson.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              v.contactPerson,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            stat('Open orders', '${open.length}'),
            const SizedBox(width: 12),
            stat('All orders', '${rows.length}'),
            const SizedBox(width: 12),
            stat('Total spend', money.format(spend)),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Orders from this vendor',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No orders have been placed with ${v.name} yet.',
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        else
          for (final r in rows)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: r.open,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.desc.isEmpty ? 'Parts / Material Order' : r.desc,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: r.delivered
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: r.delivered ? colors.textSecondary : null,
                            ),
                          ),
                          Text(
                            '${r.po.isEmpty ? 'No PO' : 'PO ${r.po}'}  ·  ${r.where}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (r.delivered)
                      ExpressiveBadge(
                        label: 'Delivered',
                        color: colors.emerald,
                        fontSize: 11,
                      )
                    else if (r.eta != null)
                      Text(
                        DateFormat('MMM d').format(r.eta!),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Text(
                      money.format(r.price),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
