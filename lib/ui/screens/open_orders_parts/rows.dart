part of '../open_orders_screen.dart';

extension _OpenOrdersRows on _OpenOrdersScreenState {
  Widget _buildDesktopOrderRow(
    BuildContext context,
    _OrderEntry e,
    NumberFormat currency,
    DateFormat dateFormat,
    bool isDark,
    dynamic notifier,
  ) {
    final isStandalone = e.isStandalone;
    final isOverdue = !e.delivered && e.eta != null && e.eta!.isBefore(DateTime.now());

    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      isGlowing: isOverdue,
      glowColor: AppTheme.of(context).coral,
      onTap: () {
        if (isStandalone) {
          _showEditStandaloneOrderDialog(context, e.standalone!);
        } else {
          _showEditOrderDialog(context, e);
        }
      },
      child: Row(
        children: [
          // Checkbox: Delivery status
          Checkbox(
            value: e.delivered,
            activeColor: AppTheme.of(context).emerald,
            visualDensity: VisualDensity.compact,
            onChanged: (_) {
              if (isStandalone) {
                notifier.updateStandaloneOrder(e.standalone!.copyWith(delivered: !e.delivered));
              } else {
                notifier.toggleOrderDelivered(e.project!.id, e.order!.id);
              }
            },
          ),
          const SizedBox(width: 4),

          // Status & ETA Badge
          SizedBox(
            width: 110,
            child: e.delivered
                ? ExpressiveBadge(
                    label: '✓ Delivered',
                    color: AppTheme.of(context).emerald,
                    fontSize: 10,
                  )
                : (e.eta != null
                    ? _buildEtaBadge(e.eta!)
                    : Text(
                        'No ETA',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      )),
          ),
          const SizedBox(width: 8),

          // Description & Track Button (Flexible)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    e.description.isEmpty ? 'Parts / Material Order' : e.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: e.delivered ? TextDecoration.lineThrough : null,
                      color: e.delivered ? Colors.grey : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (e.trackingUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      var url = e.trackingUrl.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        url = 'https://$url';
                      }
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.track_changes_rounded, size: 11, color: AppTheme.of(context).primary),
                          const SizedBox(width: 3),
                          Text('Track', style: TextStyle(fontSize: 10, color: AppTheme.of(context).primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // PO / PR badges
          SizedBox(
            width: 140,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (e.po.isNotEmpty)
                  ExpressiveBadge(label: 'PO: ${e.po}', color: AppTheme.of(context).primary, fontSize: 10),
                if (e.pr.isNotEmpty)
                  ExpressiveBadge(label: 'PR: ${e.pr}', color: AppTheme.of(context).amber, fontSize: 10),
                ...e.bammWorkOrders.map((wo) => BammChip(worNo: wo, isDense: true)),
                if (e.po.isEmpty && e.pr.isEmpty && e.bammWorkOrders.isEmpty)
                  const Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Vendor badge
          SizedBox(
            width: 120,
            child: e.vendorName.isNotEmpty
                ? ExpressiveBadge(
                    label: e.vendorName,
                    color: Colors.purpleAccent,
                    icon: Icons.storefront_rounded,
                    fontSize: 10,
                  )
                : const Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          const SizedBox(width: 8),

          // Project / Machine Link
          SizedBox(
            width: 140,
            child: !isStandalone
                ? InkWell(
                    onTap: () => context.push('/projects/${e.project!.id}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 13, color: AppTheme.of(context).primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            e.projectTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.of(context).primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, size: 13, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Unlinked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),

          // Stores badge / quick toggle (works for linked + unlinked orders)
          SizedBox(
            width: 100,
            child: e.addToStores
                ? InkWell(
                    onTap: () => _toggleStores(e, notifier, false),
                    child: e.storeRequestNumber.isNotEmpty
                        ? ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓', color: AppTheme.of(context).emerald, fontSize: 9)
                        : e.storeRequested
                            ? ExpressiveBadge(label: 'Stores: Req', color: AppTheme.of(context).amber, fontSize: 9)
                            : ExpressiveBadge(label: 'Stores: Pend', color: AppTheme.of(context).amber, fontSize: 9),
                  )
                : TextButton.icon(
                    onPressed: () => _toggleStores(e, notifier, true),
                    icon: const Icon(Icons.warehouse_outlined, size: 13),
                    label: const Text('Stores', style: TextStyle(fontSize: 10)),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.grey,
                    ),
                  ),
          ),
          const SizedBox(width: 8),

          // Price
          SizedBox(
            width: 85,
            child: Text(
              currency.format(e.price),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),

          // Actions: Edit / Attach
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
                tooltip: 'Edit Order',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  if (isStandalone) {
                    _showEditStandaloneOrderDialog(context, e.standalone!);
                  } else {
                    _showEditOrderDialog(context, e);
                  }
                },
              ),
              if (isStandalone)
                IconButton(
                  icon: Icon(Icons.link_rounded, size: 16, color: AppTheme.of(context).emerald),
                  tooltip: 'Attach to Project',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _showAttachToProjectDialog(context, e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, _OrderEntry e, NumberFormat currency, DateFormat dateFormat, bool isDark, dynamic notifier) {
    final isStandalone = e.isStandalone;
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      isGlowing: !e.delivered && e.eta != null && e.eta!.isBefore(DateTime.now()),
      glowColor: AppTheme.of(context).coral,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: project context (or Unlinked) + edit/delete
        Row(children: [
          if (!isStandalone)
            InkWell(
              onTap: () => context.push('/projects/${e.project!.id}'),
              child: Row(children: [
                Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppTheme.of(context).primary),
                const SizedBox(width: 6),
                Text(e.projectTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary, decoration: TextDecoration.underline)),
              ]),
            )
          else ...[
            const Icon(Icons.link_off_rounded, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            const Text('Unlinked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
          if (e.machine.isNotEmpty) ...[
            const SizedBox(width: 8),
            ExpressiveBadge(label: e.machine, color: AppTheme.of(context).amber, fontSize: 10),
          ],
          const Spacer(),
          if (isStandalone)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
              tooltip: 'Edit Order',
              onPressed: () => _showEditStandaloneOrderDialog(context, e.standalone!),
            )
          else
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
              tooltip: 'Edit Order',
              onPressed: () => _showEditOrderDialog(context, e),
            ),
        ]),
        const Divider(height: 12),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: e.delivered,
            activeColor: AppTheme.of(context).emerald,
            onChanged: (_) {
              if (isStandalone) {
                notifier.updateStandaloneOrder(e.standalone!.copyWith(delivered: !e.delivered));
              } else {
                notifier.toggleOrderDelivered(e.project!.id, e.order!.id);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.description.isEmpty ? 'Parts / Material Order' : e.description,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    decoration: e.delivered ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (e.po.isNotEmpty) ExpressiveBadge(label: 'PO: ${e.po}', color: AppTheme.of(context).primary, fontSize: 10),
              if (e.pr.isNotEmpty) ExpressiveBadge(label: 'PR: ${e.pr}', color: AppTheme.of(context).amber, fontSize: 10),
              ...e.bammWorkOrders.map((wo) => BammChip(worNo: wo, isDense: true)),
              if (e.vendorName.isNotEmpty)
                ExpressiveBadge(label: e.vendorName, color: Colors.purpleAccent, icon: Icons.storefront_rounded, fontSize: 10),
              if (e.vendorQuoteNumber.isNotEmpty)
                ExpressiveBadge(label: 'Quote #${e.vendorQuoteNumber}', color: Colors.blueGrey, fontSize: 10),
              if (e.addToStores)
                e.storeRequestNumber.isNotEmpty
                    ? ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓', color: AppTheme.of(context).emerald, fontSize: 10)
                    : e.storeRequested
                        ? ExpressiveBadge(label: 'Stores: Requested', color: AppTheme.of(context).amber, fontSize: 10)
                        : e.po.isNotEmpty
                            ? ExpressiveBadge(label: 'Stores: Pending', color: AppTheme.of(context).amber, fontSize: 10)
                            : const ExpressiveBadge(label: 'Add to Stores', color: Colors.grey, fontSize: 10),
            ]),
            if (e.trackingUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              ActionChip(
                avatar: Icon(Icons.track_changes_rounded, size: 12, color: AppTheme.of(context).primary),
                label: Text('Track Shipment', style: TextStyle(fontSize: 10, color: AppTheme.of(context).primary)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  var url = e.trackingUrl.trim();
                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    url = 'https://$url';
                  }
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],

          ])),
          Text(currency.format(e.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),

        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (e.eta != null) _buildEtaBadge(e.eta!)
          else Text('No ETA specified', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
          if (e.delivered) ExpressiveBadge(label: '✓ Delivered', color: AppTheme.of(context).emerald, fontSize: 10),
        ]),

        // Stores workflow
        _buildStoresSection(e, notifier),

        // Attach to project (standalone only)
        if (isStandalone) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAttachToProjectDialog(context, e),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Attach to Project', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.of(context).emerald,
              side: BorderSide(color: AppTheme.of(context).emerald),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ]),
    );
  }

  void _toggleStores(_OrderEntry e, dynamic notifier, bool value) {
    if (e.isStandalone) {
      notifier.setStandaloneOrderAddToStores(e.standalone!.id, value);
    } else {
      notifier.setOrderAddToStores(e.project!.id, e.order!.id, value);
    }
  }

  Widget _buildStoresSection(_OrderEntry e, dynamic notifier) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 16),
      Row(children: [
        Icon(Icons.warehouse_outlined, size: 16, color: e.addToStores ? AppTheme.of(context).emerald : Colors.grey),
        const SizedBox(width: 8),
        const Expanded(child: Text('Add to Stores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Switch(
          value: e.addToStores,
          activeColor: AppTheme.of(context).emerald,
          onChanged: (v) {
            if (e.isStandalone) {
              notifier.setStandaloneOrderAddToStores(e.standalone!.id, v);
            } else {
              notifier.setOrderAddToStores(e.project!.id, e.order!.id, v);
            }
          },
        ),
      ]),
      if (e.addToStores) ...[
        const SizedBox(height: 6),
        if (e.po.isEmpty)
          Padding(padding: const EdgeInsets.only(left: 2), child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.of(context).amber),
            const SizedBox(width: 6),
            Expanded(child: Text('Add a PO number, then request from storeroom.',
                style: TextStyle(fontSize: 11, color: AppTheme.of(context).amber, fontStyle: FontStyle.italic))),
          ]))
        else if (!e.storeRequested)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Request for Stores?'),
                content: Text('Send "${e.description}" to the storeroom?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
                ],
              ));
              if (confirm == true) {
                if (e.isStandalone) {
                  notifier.markStandaloneOrderStoreRequested(e.standalone!.id);
                } else {
                  notifier.markOrderStoreRequested(e.project!.id, e.order!.id);
                }
              }
            },
            icon: const Icon(Icons.warehouse_rounded, size: 16),
            label: const Text('Request for Stores'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.of(context).emerald, side: BorderSide(color: AppTheme.of(context).emerald)),
          ))
        else if (e.storeRequestNumber.isEmpty)
          Row(children: [
            const Expanded(child: Text('Requested — add store request #', style: TextStyle(fontSize: 11))),
            OutlinedButton.icon(
              onPressed: () => _showStoreNumberDialog(e),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Add #'),
            ),
          ])
        else
          ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓ Requested', icon: Icons.warehouse_rounded, color: AppTheme.of(context).emerald, fontSize: 10),
      ],
    ]);
  }

  Widget _buildEtaBadge(DateTime eta) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final etaDate = DateTime(eta.year, eta.month, eta.day);
    final days = etaDate.difference(today).inDays;

    String label;
    Color col;
    if (days < 0) {
      label = '⚠️ Overdue (${days.abs()}d ago)';
      col = AppTheme.of(context).coral;
    } else if (days == 0) {
      label = '🚚 Arriving Today';
      col = AppTheme.of(context).emerald;
    } else if (days == 1) {
      label = '📦 Arriving Tomorrow';
      col = AppTheme.of(context).primary;
    } else {
      label = 'ETA in $days days (${DateFormat("MMM d").format(eta)})';
      col = AppTheme.of(context).primary;
    }
    return ExpressiveBadge(label: label, color: col, fontSize: 11);
  }
}
