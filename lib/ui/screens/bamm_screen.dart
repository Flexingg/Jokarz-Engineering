import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/bamm_models.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/bamm_detail_dialog.dart';

class BammScreen extends ConsumerStatefulWidget {
  final String? targetWo;
  final String? initialFilter;

  const BammScreen({
    super.key,
    this.targetWo,
    this.initialFilter,
  });

  @override
  ConsumerState<BammScreen> createState() => _BammScreenState();
}

class _BammScreenState extends ConsumerState<BammScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _denseView = true;
  bool _hasHandledInitialWo = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetWo != null && widget.targetWo!.isNotEmpty) {
      _searchCtrl.text = widget.targetWo!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bammProvider.notifier).setSearchQuery(widget.targetWo!);
        _autoOpenTargetWo();
      });
    }
  }

  void _autoOpenTargetWo() {
    if (_hasHandledInitialWo) return;
    _hasHandledInitialWo = true;
    final bammState = ref.read(bammProvider);
    final match = bammState.workOrders.where((w) =>
        w.worNoSeq.toLowerCase() == widget.targetWo!.toLowerCase().trim() ||
        w.worId.toString() == widget.targetWo!.trim()).firstOrNull;
    if (match != null && mounted) {
      BammDetailDialog.show(context, match);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNewWorkOrderDialog() {
    final descCtrl = TextEditingController();
    final cellCtrl = TextEditingController();
    final machineCtrl = TextEditingController();
    final priorityCtrl = TextEditingController(text: '1.0');
    final respCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    DateTime? reqDate = DateTime.now().add(const Duration(days: 3));
    int stepId = 1; // 1 = Normal, 3 = Emergency
    int maintId = 107; // 107 = Corrective, 111 = Kaizen, 108 = PM

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: AppTheme.of(context).primary),
                const SizedBox(width: 8),
                const Text('New BAMM Work Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Work Order Description *',
                        hintText: 'e.g. Replace damaged belt on Line 3 conveyor',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: maintId,
                            decoration: const InputDecoration(labelText: 'Maintenance Type', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 107, child: Text('Corrective')),
                              DropdownMenuItem(value: 111, child: Text('Kaizen')),
                              DropdownMenuItem(value: 108, child: Text('Preventive (PM)')),
                              DropdownMenuItem(value: 115, child: Text('Project / CapEx')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => maintId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: stepId,
                            decoration: const InputDecoration(labelText: 'Urgency / Step', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Normal (In Prep)')),
                              DropdownMenuItem(value: 3, child: Text('Emergency')),
                              DropdownMenuItem(value: 5, child: Text('Scheduled')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => stepId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cellCtrl,
                            decoration: const InputDecoration(labelText: 'Cell / Area', hintText: 'Line 3', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: machineCtrl,
                            decoration: const InputDecoration(labelText: 'Machine / Asset', hintText: 'Packer A', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priorityCtrl,
                            decoration: const InputDecoration(labelText: 'EM Priority (0-25)', hintText: '1.0', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hoursCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Est. Labor Hours', hintText: '2.0', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: respCtrl,
                      decoration: const InputDecoration(labelText: 'Responsible Person', hintText: 'e.g. Miller, John', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded, size: 20),
                      title: Text(
                        reqDate != null ? DateFormat('MMM d, y').format(reqDate!) : 'No target date',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Target Required Date', style: TextStyle(fontSize: 11)),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: reqDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() => reqDate = picked);
                          }
                        },
                        child: const Text('Pick Date'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    final created = await ref.read(bammProvider.notifier).createWorkOrder(
                      description: descCtrl.text.trim(),
                      cell: cellCtrl.text.trim(),
                      machine: machineCtrl.text.trim(),
                      maintenanceTypeId: maintId,
                      stepId: stepId,
                      priority: priorityCtrl.text.trim(),
                      responsible: respCtrl.text.trim(),
                      laborHours: double.tryParse(hoursCtrl.text.trim()),
                      requiredDate: reqDate,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Created BAMM Work Order #${created.worNoSeq}!'),
                          action: SnackBarAction(
                            label: 'View',
                            onPressed: () => BammDetailDialog.show(context, created),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating work order: $e')),
                      );
                    }
                  }
                },
                child: const Text('Create Work Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSaveFilterDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Current Filter Preset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Filter Name',
            hintText: 'e.g. Line 3 Emergencies',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await ref.read(bammProvider.notifier).saveCurrentFilterAsPreset(nameCtrl.text.trim());
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Preset'),
          ),
        ],
      ),
    );
  }

  void _showConnectionConfigDialog() {
    final bammState = ref.read(bammProvider);
    final originCtrl = TextEditingController(text: bammState.config.origin);
    final userCtrl = TextEditingController(text: bammState.config.usercode);
    final passCtrl = TextEditingController(text: bammState.config.password);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BAMM Connection Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: originCtrl,
                decoration: const InputDecoration(
                  labelText: 'BAMM Host / Origin URL',
                  hintText: 'http://app02-ao-plt:82',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Usercode (Plant Account)',
                  hintText: 'e.g. jmiller',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••••',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Default plant origin: http://app02-ao-plt:82 on port 82. Requires device to be on the plant network or VPN.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newCfg = bammState.config.copyWith(
                origin: originCtrl.text.trim(),
                usercode: userCtrl.text.trim(),
                password: passCtrl.text.trim(),
              );
              await ref.read(bammProvider.notifier).updateConfig(newCfg);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Test'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bammState = ref.watch(bammProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final workOrders = bammState.filteredWorkOrders;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'BAMM Work Orders',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Live Network Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: bammState.isOnline
                  ? AppTheme.of(context).emerald.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: bammState.isOnline
                    ? AppTheme.of(context).emerald.withValues(alpha: 0.4)
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: bammState.isOnline ? AppTheme.of(context).emerald : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  bammState.isPolling
                      ? 'Polling...'
                      : (bammState.isOnline ? 'Online' : 'Offline'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bammState.isOnline ? AppTheme.of(context).emerald : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),

          // Poll Network Button
          IconButton(
            tooltip: 'Poll Plant Network Now',
            icon: bammState.isPolling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            onPressed: () async {
              final online = await ref.read(bammProvider.notifier).pollNetwork();
              await ref.read(bammProvider.notifier).refreshWorkOrders();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(online
                        ? 'Connected to BAMM at ${bammState.config.origin}!'
                        : 'BAMM offline. Showing cached records.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          // Settings Button
          IconButton(
            tooltip: 'Connection Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showConnectionConfigDialog,
          ),

          // View Toggle (Desktop)
          if (isDesktop)
            IconButton(
              tooltip: _denseView ? 'Card View' : 'Table View',
              icon: Icon(_denseView ? Icons.view_agenda_outlined : Icons.table_rows_outlined),
              onPressed: () => setState(() => _denseView = !_denseView),
            ),

          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Offline Warning Banner (if offline)
          if (!bammState.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not connected to plant network (${bammState.config.origin}). Showing cached work orders. Connect to plant Wi-Fi/VPN to sync live.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(bammProvider.notifier).pollNetwork(),
                    child: const Text('Poll Again', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Savable Filters & Presets Bar
          _buildFilterPresetsBar(bammState),

          // Search & Filter Dropdowns Row
          _buildFilterControlsRow(bammState, isDesktop),

          const Divider(height: 1),

          // List / Table
          Expanded(
            child: bammState.isLoading && bammState.workOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : workOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No BAMM work orders match your criteria.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => ref.read(bammProvider.notifier).clearFilters(),
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(bammProvider.notifier).refreshWorkOrders(),
                        child: isDesktop && _denseView
                            ? _buildDesktopTable(workOrders)
                            : _buildMobileCardList(workOrders),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewWorkOrderDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Work Order'),
      ),
    );
  }

  Widget _buildFilterPresetsBar(BammState bammState) {
    final active = bammState.activeFilter;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.of(context).surface
            : AppTheme.of(context).surface,
        border: Border(bottom: BorderSide(color: AppTheme.of(context).border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Presets:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            // "All" Preset
            ChoiceChip(
              label: const Text('All', style: TextStyle(fontSize: 12)),
              selected: active == null &&
                  bammState.statusFilter == null &&
                  bammState.stepFilter == null &&
                  bammState.searchQuery.isEmpty,
              onSelected: (_) => ref.read(bammProvider.notifier).applySavedFilter(null),
            ),
            const SizedBox(width: 6),
            ...bammState.savedFilters.map((preset) {
              final isSelected = active?.id == preset.id;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InputChip(
                  label: Text(preset.name, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) => ref.read(bammProvider.notifier).applySavedFilter(isSelected ? null : preset),
                  onDeleted: () => ref.read(bammProvider.notifier).deleteSavedFilter(preset.id),
                  deleteIconColor: Colors.grey.shade500,
                  deleteButtonTooltipMessage: 'Delete saved filter',
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('Save Filter', style: TextStyle(fontSize: 12)),
              onPressed: _showSaveFilterDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControlsRow(BammState bammState, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => ref.read(bammProvider.notifier).setSearchQuery(val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search BAMM (WO#, description, machine, responsible)...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(bammProvider.notifier).setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: bammState.statusFilter ?? 'All',
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('Status: All', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'In preparation', child: Text('In preparation', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Ready to schedule', child: Text('Ready to schedule', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Registered', child: Text('Registered', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => ref.read(bammProvider.notifier).setStatusFilter(val),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: bammState.stepFilter ?? 'All',
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('Type: All', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Emergency', child: Text('Emergency', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Normal', child: Text('Normal', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Corrective', child: Text('Corrective', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Kaizen', child: Text('Kaizen', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Preventive', child: Text('Preventive', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => ref.read(bammProvider.notifier).setStepFilter(val),
                ),
                const SizedBox(width: 10),
                Text(
                  '${bammState.filteredWorkOrders.length} orders',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            )
          : Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => ref.read(bammProvider.notifier).setSearchQuery(val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search BAMM work orders...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: bammState.statusFilter ?? 'All',
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Status: All', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'In preparation', child: Text('In preparation', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Registered', child: Text('Registered', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) => ref.read(bammProvider.notifier).setStatusFilter(val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: bammState.stepFilter ?? 'All',
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Type: All', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Emergency', child: Text('Emergency', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Corrective', child: Text('Corrective', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Kaizen', child: Text('Kaizen', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) => ref.read(bammProvider.notifier).setStepFilter(val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTable(List<BammWorkOrder> orders) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, idx) {
        final wo = orders[idx];
        final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(wo.worNoSeq);

        return InkWell(
          onTap: () => BammDetailDialog.show(context, wo),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.of(context).surface
                  : AppTheme.of(context).surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.of(context).border),
            ),
            child: Row(
              children: [
                // WO Number Pill with copy button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${wo.worNoSeq}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.of(context).primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: wo.worNoSeq));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied WO #${wo.worNoSeq}'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Icon(Icons.copy_rounded, size: 12, color: AppTheme.of(context).primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Status & Step Badges
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: wo.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wo.status,
                    style: TextStyle(color: wo.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: wo.stepColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wo.step,
                    style: TextStyle(color: wo.stepColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),

                // Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wo.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          if (wo.machine.isNotEmpty || wo.cell.isNotEmpty) ...[
                            Text(
                              '${wo.machine} (${wo.cell})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                          ],
                          if (wo.responsible.isNotEmpty) ...[
                            Text(
                              'Resp: ${wo.responsible}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                          ],
                          if (wo.priority.isNotEmpty)
                            Text(
                              'EM: ${wo.priority}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Linked Items Badge
                if (linkedItems.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.of(context).emerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, size: 12, color: AppTheme.of(context).emerald),
                        const SizedBox(width: 4),
                        Text(
                          '${linkedItems.length} linked',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).emerald),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Target Date
                if (wo.requiredDate != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      DateFormat('MMM d').format(wo.requiredDate!),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),

                // Edit Action
                IconButton(
                  tooltip: 'View / Edit Work Order',
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onPressed: () => BammDetailDialog.show(context, wo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCardList(List<BammWorkOrder> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (ctx, idx) {
        final wo = orders[idx];
        final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(wo.worNoSeq);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => BammDetailDialog.show(context, wo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${wo.worNoSeq}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.of(context).primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: wo.statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          wo.status,
                          style: TextStyle(color: wo.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: wo.stepColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          wo.step,
                          style: TextStyle(color: wo.stepColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      if (linkedItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.of(context).emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${linkedItems.length} linked',
                            style: TextStyle(color: AppTheme.of(context).emerald, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wo.description,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (wo.machine.isNotEmpty || wo.cell.isNotEmpty)
                        Expanded(
                          child: Text(
                            '${wo.machine} (${wo.cell})',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (wo.responsible.isNotEmpty)
                        Text(
                          wo.responsible,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
