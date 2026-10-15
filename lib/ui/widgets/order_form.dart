import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../models/vendor.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import 'bamm_assign_dialog.dart';
import 'bamm_chip.dart';
import 'sap_code_chip.dart';
import 'searchable_dropdown.dart';
import 'vendor_dialog.dart';

/// SAP vendor code of the vendor with [id], or '' when none is selected/known.
String selectedVendorCode(List<Vendor> vendors, String? id) =>
    vendors.where((v) => v.id == id).firstOrNull?.accountNumber.trim() ?? '';

/// The editable values of one order, shared by the Add/Edit dialog and the
/// sidebar editor so there is a single form. It is a [ChangeNotifier]: any
/// edit (typing, picking a vendor or date, ...) notifies listeners.
class OrderDraft extends ChangeNotifier {
  final TextEditingController desc;
  final TextEditingController pr;
  final TextEditingController po;
  final TextEditingController price;
  final TextEditingController notes;
  final TextEditingController quote;
  final TextEditingController tracking;
  String? vendorId;
  String vendorName;
  DateTime? eta;
  bool delivered;
  bool addToStores;
  List<String> bamm;

  OrderDraft._({
    required String description,
    required String prText,
    required String poText,
    required double priceValue,
    required String notesText,
    required String quoteText,
    required String trackingText,
    required this.vendorId,
    required this.vendorName,
    required this.eta,
    required this.delivered,
    required this.addToStores,
    required List<String> bammWorkOrders,
  }) : desc = TextEditingController(text: description),
       pr = TextEditingController(text: prText),
       po = TextEditingController(text: poText),
       price = TextEditingController(
         text: priceValue > 0 ? priceValue.toStringAsFixed(2) : '',
       ),
       notes = TextEditingController(text: notesText),
       quote = TextEditingController(text: quoteText),
       tracking = TextEditingController(text: trackingText),
       bamm = List.of(bammWorkOrders) {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  factory OrderDraft.blank({String prefillDescription = ''}) => OrderDraft._(
    description: prefillDescription,
    prText: '',
    poText: '',
    priceValue: 0,
    notesText: '',
    quoteText: '',
    trackingText: '',
    vendorId: null,
    vendorName: '',
    eta: null,
    delivered: false,
    addToStores: false,
    bammWorkOrders: const [],
  );

  factory OrderDraft.fromOrder(OrderItem o) => OrderDraft._(
    description: o.description,
    prText: o.pr,
    poText: o.po,
    priceValue: o.price,
    notesText: o.notes,
    quoteText: o.vendorQuoteNumber,
    trackingText: o.trackingUrl,
    vendorId: o.vendorId,
    vendorName: o.vendorName,
    eta: o.eta,
    delivered: o.delivered,
    addToStores: o.addToStores,
    bammWorkOrders: o.bammWorkOrders,
  );

  factory OrderDraft.fromStandalone(StandaloneOrder o) => OrderDraft._(
    description: o.description,
    prText: o.pr,
    poText: o.po,
    priceValue: o.price,
    notesText: o.notes,
    quoteText: o.vendorQuoteNumber,
    trackingText: o.trackingUrl,
    vendorId: o.vendorId,
    vendorName: o.vendorName,
    eta: o.eta,
    delivered: o.delivered,
    addToStores: o.addToStores,
    bammWorkOrders: o.bammWorkOrders,
  );

  List<TextEditingController> get _controllers => [
    desc,
    pr,
    po,
    price,
    notes,
    quote,
    tracking,
  ];

  /// An order needs a description to be saved.
  bool get isValid => desc.text.trim().isNotEmpty;

  double get priceValue => double.tryParse(price.text.trim()) ?? 0.0;

  /// Changes a non-text value and notifies.
  void update(void Function(OrderDraft d) change) {
    change(this);
    notifyListeners();
  }

  /// The vendor id only counts if that vendor still exists.
  ({String? id, String name}) resolvedVendor(List<Vendor> vendors) {
    final valid = vendors.any((v) => v.id == vendorId);
    return (id: valid ? vendorId : null, name: valid ? vendorName : '');
  }

  /// [base] with every edited field applied. [includeDelivered] is false for the
  /// sidebar, which marks delivery through its own button (store/log side effects).
  OrderItem applyToOrder(
    OrderItem base,
    List<Vendor> vendors, {
    bool includeDelivered = true,
  }) {
    final v = resolvedVendor(vendors);
    return base.copyWith(
      pr: pr.text.trim(),
      po: po.text.trim(),
      description: desc.text.trim(),
      price: priceValue,
      eta: eta,
      clearEta: eta == null,
      delivered: includeDelivered ? delivered : base.delivered,
      addToStores: addToStores,
      vendorId: v.id,
      clearVendorId: v.id == null,
      vendorName: v.name,
      vendorQuoteNumber: quote.text.trim(),
      trackingUrl: tracking.text.trim(),
      notes: notes.text.trim(),
      bammWorkOrders: bamm,
    );
  }

  StandaloneOrder applyToStandalone(
    StandaloneOrder base,
    List<Vendor> vendors, {
    bool includeDelivered = true,
  }) {
    final v = resolvedVendor(vendors);
    return base.copyWith(
      pr: pr.text.trim(),
      po: po.text.trim(),
      description: desc.text.trim(),
      price: priceValue,
      eta: eta,
      clearEta: eta == null,
      delivered: includeDelivered ? delivered : base.delivered,
      addToStores: addToStores,
      vendorId: v.id,
      clearVendorId: v.id == null,
      vendorName: v.name,
      vendorQuoteNumber: quote.text.trim(),
      trackingUrl: tracking.text.trim(),
      notes: notes.text.trim(),
      bammWorkOrders: bamm,
    );
  }

  OrderItem toNewOrder(List<Vendor> vendors) {
    final v = resolvedVendor(vendors);
    return OrderItem(
      pr: pr.text.trim(),
      po: po.text.trim(),
      description: desc.text.trim(),
      price: priceValue,
      eta: eta,
      addToStores: addToStores,
      vendorId: v.id,
      vendorName: v.name,
      vendorQuoteNumber: quote.text.trim(),
      trackingUrl: tracking.text.trim(),
      notes: notes.text.trim(),
      bammWorkOrders: bamm,
    );
  }

  StandaloneOrder toNewStandalone(List<Vendor> vendors) {
    final v = resolvedVendor(vendors);
    return StandaloneOrder(
      description: desc.text.trim(),
      pr: pr.text.trim(),
      po: po.text.trim(),
      price: priceValue,
      eta: eta,
      addToStores: addToStores,
      notes: notes.text.trim(),
      vendorId: v.id,
      vendorName: v.name,
      vendorQuoteNumber: quote.text.trim(),
      trackingUrl: tracking.text.trim(),
      bammWorkOrders: bamm,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// The order form fields. Rebuilds as [draft] changes.
class OrderFields extends ConsumerWidget {
  final OrderDraft draft;
  final bool autofocusDescription;

  /// The Add/Edit dialog shows a "Marked as delivered" checkbox when editing;
  /// the sidebar has its own delivery button.
  final bool showDeliveredToggle;

  /// Optional widget above the description (the dialog's project picker).
  final Widget? header;

  const OrderFields({
    super.key,
    required this.draft,
    this.autofocusDescription = false,
    this.showDeliveredToggle = false,
    this.header,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(projectProvider.select((s) => s.vendors));
    final colors = AppTheme.of(context);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final vendorIdValid = vendors.any((v) => v.id == draft.vendorId);
        final sapCode = selectedVendorCode(vendors, draft.vendorId);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 12)],
            TextField(
              controller: draft.desc,
              autofocus: autofocusDescription,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Part / Material Description *',
                hintText: 'e.g. SKF 6205 Bearings, UHMW Sheet',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: vendors.isEmpty
                      ? const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Vendor / Supplier',
                            prefixIcon: Icon(
                              Icons.storefront_rounded,
                              size: 18,
                            ),
                          ),
                          child: Text('No vendors yet - add one →'),
                        )
                      : SearchableDropdownFormField<String>(
                          value: vendorIdValid ? draft.vendorId : null,
                          labelText: 'Vendor / Supplier',
                          prefixIcon: const Icon(
                            Icons.storefront_rounded,
                            size: 18,
                          ),
                          items: vendors.map((v) => v.id).toList(),
                          labelOf: (id) =>
                              vendors
                                  .where((v) => v.id == id)
                                  .firstOrNull
                                  ?.name ??
                              '',
                          onChanged: (val) => draft.update((d) {
                            d.vendorId = val;
                            d.vendorName =
                                vendors
                                    .where((v) => v.id == val)
                                    .firstOrNull
                                    ?.name ??
                                '';
                          }),
                        ),
                ),
                if (sapCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SapCodeChip(sapCode),
                  ),
                ],
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Quick add vendor',
                  child: IconButton.filledTonal(
                    onPressed: () async {
                      final created = await showVendorDialog(context);
                      if (created != null) {
                        draft.update((d) {
                          d.vendorId = created.id;
                          d.vendorName = created.name;
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
                    controller: draft.pr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PR (Requisition)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.po,
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
                    controller: draft.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (\$)',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.quote,
                    decoration: const InputDecoration(labelText: 'Quote #'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.tracking,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Shipment Tracking Link / URL',
                prefixIcon: Icon(Icons.track_changes_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.local_shipping_outlined,
                color: colors.primary,
              ),
              title: Text(
                draft.eta != null
                    ? DateFormat('MMM d, y').format(draft.eta!)
                    : 'No ETA',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Estimated Delivery (ETA)',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (draft.eta != null)
                    IconButton(
                      tooltip: 'Clear ETA',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => draft.update((d) => d.eta = null),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            draft.eta ??
                            DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) draft.update((d) => d.eta = picked);
                    },
                    child: const Text('Set ETA'),
                  ),
                ],
              ),
            ),
            TextField(
              controller: draft.notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.build_circle_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'BAMM Work Orders',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDialog<List<String>>(
                      context: context,
                      builder: (c) => BammAssignDialog(
                        initialSelected: draft.bamm,
                        title: 'Assign BAMM to Order',
                      ),
                    );
                    if (selected != null)
                      draft.update((d) => d.bamm = selected);
                  },
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: const Text('Assign BAMM'),
                ),
              ],
            ),
            if (draft.bamm.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: draft.bamm.map((wo) {
                    return BammChip(
                      workOrderNo: wo,
                      onDeleted: () => draft.update(
                        (d) => d.bamm = d.bamm.where((w) => w != wo).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.warehouse_outlined,
                color: draft.addToStores ? colors.emerald : Colors.grey,
              ),
              title: const Text(
                'Add to Stores',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Stock this part in the plant storeroom',
                style: TextStyle(fontSize: 11),
              ),
              value: draft.addToStores,
              onChanged: (v) => draft.update((d) => d.addToStores = v),
            ),
            if (showDeliveredToggle)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Marked as Delivered',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Part has arrived at plant/crib',
                  style: TextStyle(fontSize: 11),
                ),
                value: draft.delivered,
                onChanged: (val) {
                  if (val != null) draft.update((d) => d.delivered = val);
                },
              ),
          ],
        );
      },
    );
  }
}
