part of '../open_orders_screen.dart';

extension _OpenOrdersDialogs on _OpenOrdersScreenState {
  void _showEditOrderDialog(BuildContext context, _OrderEntry entry) {
    showOrderDialog(context, existingOrder: entry.order!,
      existingOrderProjectId: entry.project!.id,
    );
  }

  Future<void> _showStoreNumberDialog(_OrderEntry e) async {
    final ctrl = TextEditingController(text: e.storeRequestNumber);
    final num = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Store Request Number'),
      content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Store request #')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
      ],
    ));
    if (num == null || num.isEmpty) return;
    if (e.isStandalone) {
      await ref.read(projectProvider.notifier).setStandaloneOrderStoreRequestNumber(e.standalone!.id, num);
    } else {
      await ref.read(projectProvider.notifier).setOrderStoreRequestNumber(e.project!.id, e.order!.id, num);
    }
  }

  void _showAddStandaloneOrderDialog(BuildContext context) {
    showOrderDialog(context, onAdded: () {
      if (mounted) _rebuild(() => _filterTab = 2);
    });
  }

  void _showEditStandaloneOrderDialog(BuildContext context, StandaloneOrder o) {
    showOrderDialog(context, existingStandalone: o);
  }

  /// Type-ahead attach dialog: matches projects as you type and shows a card list.
  void _showAttachToProjectDialog(BuildContext context, _OrderEntry e) {
    final projects = ref.read(projectProvider).activeProjects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active projects to attach to.')));
      return;
    }
    final searchCtrl = TextEditingController();
    String? selectedId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final q = searchCtrl.text.trim().toLowerCase();
        final matches = q.isEmpty
            ? projects
            : projects.where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.machine.toLowerCase().contains(q) ||
                p.tags.any((t) => t.toLowerCase().contains(q))).toList();
        return AlertDialog(
          title: const Text('Attach to Project'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Move "${e.description.isEmpty ? '(order)' : e.description}" to a project:',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'Search project', hintText: 'Type to filter...', prefixIcon: Icon(Icons.search_rounded), isDense: true),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: matches.isEmpty
                    ? const Padding(padding: EdgeInsets.all(12), child: Text('No matching projects', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ListView(
                        shrinkWrap: true,
                        children: matches.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: selectedId == p.id ? AppTheme.of(context).emerald.withValues(alpha: 0.15) : null,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.engineering_rounded, size: 20, color: AppTheme.of(context).primary),
                            title: Text('#${p.priority} ${p.title}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            subtitle: p.machine.isNotEmpty ? Text(p.machine, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis) : null,
                            onTap: () => setDialogState(() => selectedId = p.id),
                          ),
                        )).toList(),
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      await ref.read(projectProvider.notifier).linkOrderToProject(e.standalone!.id, selectedId!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Order linked to project!'), backgroundColor: AppTheme.of(context).emerald));
                        _rebuild(() => _filterTab = 0);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).emerald, foregroundColor: Colors.white),
              child: const Text('Attach'),
            ),
          ],
        );
      }),
    );
  }
}
