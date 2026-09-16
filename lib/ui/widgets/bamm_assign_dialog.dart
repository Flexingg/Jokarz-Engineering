import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bamm_provider.dart';
import '../../theme/app_theme.dart';
import 'bamm_chip.dart';

class BammAssignDialog extends ConsumerStatefulWidget {
  final List<String> initialSelected;
  final String title;

  const BammAssignDialog({
    super.key,
    required this.initialSelected,
    this.title = 'Assign BAMM Work Orders',
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> currentSelections,
    String title = 'Assign BAMM Work Orders',
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => BammAssignDialog(
        initialSelected: currentSelections,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<BammAssignDialog> createState() => _BammAssignDialogState();
}

class _BammAssignDialogState extends ConsumerState<BammAssignDialog> {
  late final List<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _manualCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _addManual() {
    final text = _manualCtrl.text.trim();
    if (text.isNotEmpty && !_selected.contains(text)) {
      setState(() {
        _selected.add(text);
        _manualCtrl.clear();
      });
    }
  }

  void _toggleWorkOrder(String woNo) {
    setState(() {
      if (_selected.contains(woNo)) {
        _selected.remove(woNo);
      } else {
        _selected.add(woNo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bammState = ref.watch(bammProvider);
    final allOrders = bammState.workOrders;

    final filtered = allOrders.where((wo) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return wo.worNoSeq.toLowerCase().contains(q) ||
          wo.description.toLowerCase().contains(q) ||
          wo.area.toLowerCase().contains(q) ||
          wo.machine.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currently Selected BAMMs
            if (_selected.isNotEmpty) ...[
              const Text(
                'Assigned BAMM Work Orders:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected.map((woNo) {
                  return BammChip(
                    worNo: woNo,
                    onDeleted: () {
                      setState(() => _selected.remove(woNo));
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 20),
            ],

            // Quick Search
            TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search BAMMs (WO#, description, machine)...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            // Work Orders List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            allOrders.isEmpty ? 'No cached BAMM work orders found.' : 'No matching work orders.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'You can type any BAMM WO# below to link manually.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final wo = filtered[index];
                        final isChecked = _selected.contains(wo.worNoSeq);

                        return CheckboxListTile(
                          dense: true,
                          value: isChecked,
                          onChanged: (_) => _toggleWorkOrder(wo.worNoSeq),
                          title: Row(
                            children: [
                              Text(
                                '#${wo.worNoSeq}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: wo.statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  wo.status,
                                  style: TextStyle(color: wo.statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (wo.area.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  wo.area,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            wo.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 16),

            // Manual Entry Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Or enter BAMM WO Number',
                      hintText: 'e.g. 185586',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onSubmitted: (_) => _addManual(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _addManual,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add WO#'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('Assign (${_selected.length})'),
        ),
      ],
    );
  }
}
