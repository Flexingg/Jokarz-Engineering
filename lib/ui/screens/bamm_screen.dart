import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/bamm_models.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/bamm_detail_dialog.dart';
import '../widgets/bamm_table_columns.dart';

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
    final bammState = ref.read(bammProvider);
    final descCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
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
                    if (!bammState.isOnline) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'BAMM server is offline. Creating a work order requires connecting to the plant network (${bammState.config.origin}).',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                            value: bammState.maintLookups.any((m) => m.id == maintId)
                                ? maintId
                                : (bammState.maintLookups.firstOrNull?.id ?? 111),
                            decoration: const InputDecoration(labelText: 'Maintenance Type', isDense: true),
                            items: bammState.maintLookups.map((m) {
                              return DropdownMenuItem<int>(
                                value: m.id,
                                child: Text(m.description, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => maintId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: bammState.stepLookups.any((s) => s.id == stepId)
                                ? stepId
                                : (bammState.stepLookups.firstOrNull?.id ?? 1),
                            decoration: const InputDecoration(labelText: 'Urgency / Step', isDense: true),
                            items: bammState.stepLookups.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(s.description, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
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
                            controller: areaCtrl,
                            decoration: const InputDecoration(labelText: 'Area', hintText: 'e.g. 100, 200, 300, Carts', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: machineCtrl,
                            decoration: const InputDecoration(labelText: 'Machine (3rd level)', hintText: 'e.g. Packer A', isDense: true),
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
                      area: areaCtrl.text.trim(),
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
                        SnackBar(content: Text('Failed to create work order: $e')),
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
            labelText: 'Preset Name',
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

  void _showMoreFiltersDialog() {
    final bammState = ref.read(bammProvider);
    final criteria = bammState.criteria;
    final respCtrl = TextEditingController(text: criteria.responsible ?? '');
    final reqCtrl = TextEditingController(text: criteria.requester ?? '');
    final machCtrl = TextEditingController(text: criteria.machine ?? '');
    String selectedMaint = criteria.maintenanceType ?? 'All';
    String selectedExec = criteria.executionMode ?? 'All';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.filter_alt_rounded, color: AppTheme.of(context).primary),
                const SizedBox(width: 8),
                const Text('More Filter Options', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: respCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Responsible Technician / Person',
                        hintText: 'e.g. Miller, John',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reqCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Requester',
                        hintText: 'e.g. Operator Bill',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: machCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Machine (3rd level asset description)',
                        hintText: 'e.g. Packer A, Conveyor, Filler',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMaint,
                      decoration: const InputDecoration(labelText: 'Maintenance Type', isDense: true),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Maintenance Types')),
                        ...bammState.maintLookups.map((m) {
                          return DropdownMenuItem(
                            value: m.description,
                            child: Text(m.description, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMaint = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedExec,
                      decoration: const InputDecoration(labelText: 'Machine Status / Mode', isDense: true),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Machine Statuses')),
                        ...bammState.execLookups.map((e) {
                          return DropdownMenuItem(
                            value: e.description,
                            child: Text(e.code.isNotEmpty ? '${e.description} (${e.code})' : e.description),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedExec = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(bammProvider.notifier).clearFilters();
                  Navigator.pop(ctx);
                },
                child: const Text('Reset All'),
              ),
              ElevatedButton(
                onPressed: () {
                  final notifier = ref.read(bammProvider.notifier);
                  notifier.setResponsibleFilter(respCtrl.text.trim());
                  notifier.setRequesterFilter(reqCtrl.text.trim());
                  notifier.setMachineFilter(machCtrl.text.trim());
                  final mItem = bammState.maintLookups.where((m) => m.description == selectedMaint).firstOrNull;
                  notifier.setMaintenanceTypeFilter(selectedMaint, mItem?.id);
                  final eItem = bammState.execLookups.where((e) => e.description == selectedExec).firstOrNull;
                  notifier.setExecutionModeFilter(selectedExec, eItem?.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Filters'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bammState = ref.watch(bammProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
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
            const Flexible(
              child: Text(
                'BAMM Work Orders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
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
                      'Not connected to plant network (${bammState.config.origin}). Queries and updates require plant Wi-Fi / VPN.',
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

          // Active Filter Chips Bar (if any filters active)
          if (bammState.criteria.activeFilterCount > 0)
            _buildActiveFilterChipsRow(bammState),

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
                            Text(
                              bammState.criteria.isEmpty
                                  ? (bammState.isOnline ? 'No BAMM work orders found on server.' : 'Not connected to plant network. Connect to load work orders.')
                                  : 'No BAMM work orders match your active filters.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (bammState.criteria.activeFilterCount > 0)
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
        color: AppTheme.of(context).surface,
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
            // "All Open" Preset (Default)
            ChoiceChip(
              label: const Text('All Open (Active)', style: TextStyle(fontSize: 12)),
              selected: active == null && (bammState.criteria.isEmpty || bammState.criteria.status == null || bammState.criteria.status == 'All Open'),
              onSelected: (_) => ref.read(bammProvider.notifier).clearFilters(),
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
                  deleteButtonTooltipMessage: 'Delete saved preset',
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('Save Preset', style: TextStyle(fontSize: 12)),
              onPressed: _showSaveFilterDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControlsRow(BammState bammState, bool isDesktop) {
    final c = bammState.criteria;
    final statusItems = [
      'All Open',
      'All (Including Closed)',
      ...bammState.statusLookups.map((s) => s.description),
    ];
    final stepItems = [
      'All',
      ...bammState.stepLookups.map((s) => s.description),
    ];
    final areaItems = [
      'All',
      ...bammState.areaLookups.map((a) => a.description),
    ];

    void onStatusChanged(String? val) {
      if (val == null || val == 'All Open') {
        ref.read(bammProvider.notifier).setStatusFilter('All Open');
      } else if (val == 'All' || val == 'All (Including Closed)') {
        ref.read(bammProvider.notifier).setStatusFilter('All');
      } else {
        final sItem = bammState.statusLookups.where((s) => s.description == val).firstOrNull;
        ref.read(bammProvider.notifier).setStatusFilter(val, sItem?.id);
      }
    }

    void onStepChanged(String? val) {
      if (val == null || val == 'All') {
        ref.read(bammProvider.notifier).setStepFilter(null);
      } else {
        final sItem = bammState.stepLookups.where((s) => s.description == val).firstOrNull;
        ref.read(bammProvider.notifier).setStepFilter(val, sItem?.id);
      }
    }

    void onAreaChanged(String? val) {
      if (val == null || val == 'All') {
        ref.read(bammProvider.notifier).setAreaFilter(null);
      } else {
        final aItem = bammState.areaLookups.where((a) => a.description == val).firstOrNull;
        ref.read(bammProvider.notifier).setAreaFilter(val, aItem?.id);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: isDesktop
          ? Row(
              children: [
                // Search Input
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (val) => ref.read(bammProvider.notifier).setSearchQuery(val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search BAMM (WO#, description, responsible)...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

                // Status Dropdown
                Flexible(
                  child: _buildDropdownFilter(
                    label: 'Status',
                    currentValue: (c.status == null || c.status!.isEmpty || c.status == 'All Open')
                        ? 'All Open'
                        : (c.status == 'All' ? 'All (Including Closed)' : c.status!),
                    items: statusItems,
                    onChanged: onStatusChanged,
                  ),
                ),
                const SizedBox(width: 8),

                // Step / Urgency Dropdown
                Flexible(
                  child: _buildDropdownFilter(
                    label: 'Step',
                    currentValue: c.step ?? 'All',
                    items: stepItems,
                    onChanged: onStepChanged,
                  ),
                ),
                const SizedBox(width: 8),

                // Area Dropdown
                Flexible(
                  child: _buildDropdownFilter(
                    label: 'Area',
                    currentValue: c.area ?? 'All',
                    items: areaItems,
                    onChanged: onAreaChanged,
                  ),
                ),
                const SizedBox(width: 8),

                // More Filters Button
                OutlinedButton.icon(
                  onPressed: _showMoreFiltersDialog,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('More Filters', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(width: 10),

                // Results Count
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
                  onSubmitted: (val) => ref.read(bammProvider.notifier).setSearchQuery(val.trim()),
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
                      child: _buildDropdownFilter(
                        label: 'Status',
                        currentValue: (c.status == null || c.status!.isEmpty || c.status == 'All Open')
                            ? 'All Open'
                            : (c.status == 'All' ? 'All (Including Closed)' : c.status!),
                        items: statusItems,
                        onChanged: onStatusChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdownFilter(
                        label: 'Step',
                        currentValue: c.step ?? 'All',
                        items: stepItems,
                        onChanged: onStepChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdownFilter(
                        label: 'Area',
                        currentValue: c.area ?? 'All',
                        items: areaItems,
                        onChanged: onAreaChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'More Filters',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: _showMoreFiltersDialog,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isDefault = currentValue == 'All' || currentValue == 'All Open';
    final hasFilter = !isDefault;
    final effectiveValue = items.contains(currentValue)
        ? currentValue
        : (items.contains('All Open') ? 'All Open' : (items.contains('All') ? 'All' : items.firstOrNull ?? 'All'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: hasFilter
            ? AppTheme.of(context).primary.withValues(alpha: 0.1)
            : AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasFilter ? AppTheme.of(context).primary : AppTheme.of(context).border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          isExpanded: true,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: hasFilter ? FontWeight.bold : FontWeight.normal,
          ),
          items: items.map((val) {
            String display = val;
            if (val == 'All') display = '$label: All';
            if (val == 'All Open') display = '$label: All Open (Active)';
            if (val == 'All (Including Closed)') display = '$label: All (Inc. Closed)';
            return DropdownMenuItem(
              value: val,
              child: Text(display, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildActiveFilterChipsRow(BammState bammState) {
    final c = bammState.criteria;
    final chips = <Widget>[];

    if (c.searchQuery.isNotEmpty) {
      chips.add(Chip(
        label: Text('Query: "${c.searchQuery}"', style: const TextStyle(fontSize: 11)),
        onDeleted: () {
          _searchCtrl.clear();
          ref.read(bammProvider.notifier).setSearchQuery('');
        },
      ));
    }
    if (c.status != null && c.status != 'All Open' && c.status!.isNotEmpty) {
      final statusLabel = c.status == 'All' ? 'Status: All (Inc. Closed)' : 'Status: ${c.status}';
      chips.add(Chip(
        label: Text(statusLabel, style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setStatusFilter('All Open'),
      ));
    }
    if (c.step != null && c.step != 'All') {
      chips.add(Chip(
        label: Text('Step: ${c.step}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setStepFilter(null),
      ));
    }
    if (c.maintenanceType != null && c.maintenanceType != 'All') {
      chips.add(Chip(
        label: Text('Type: ${c.maintenanceType}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setMaintenanceTypeFilter(null),
      ));
    }
    final areaVal = c.area;
    if (areaVal != null && areaVal != 'All' && areaVal.isNotEmpty) {
      chips.add(Chip(
        label: Text('Area: $areaVal', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setAreaFilter(null),
      ));
    }
    if (c.responsible != null && c.responsible!.isNotEmpty) {
      chips.add(Chip(
        label: Text('Resp: ${c.responsible}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setResponsibleFilter(null),
      ));
    }
    if (c.requester != null && c.requester!.isNotEmpty) {
      chips.add(Chip(
        label: Text('Requester: ${c.requester}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setRequesterFilter(null),
      ));
    }
    if (c.machine != null && c.machine!.isNotEmpty) {
      chips.add(Chip(
        label: Text('Machine: ${c.machine}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setMachineFilter(null),
      ));
    }
    if (c.executionMode != null && c.executionMode != 'All') {
      chips.add(Chip(
        label: Text('Status: ${c.executionMode}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setExecutionModeFilter(null),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black26
          : Colors.grey.shade100,
      child: Row(
        children: [
          const Text('Active Filters:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...chips.map((w) => Padding(padding: const EdgeInsets.only(right: 6), child: w)),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(bammProvider.notifier).clearFilters();
                    },
                    child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _trailingColumnsWidth = 170;
  static const double _columnGap = 12;

  /// The BAMM table columns this app can render, ordered/filtered per the
  /// user's saved layout (`BammState.columnLayout`) - see
  /// `bamm_table_columns.dart` for why this is not the full live BAMM
  /// column catalogue.
  List<BammColumnDef> _allColumns(BammColumnLayout layout) => applyColumnLayout(buildBammColumns(), layout);

  List<BammColumnDef> _visibleColumns(List<BammColumnDef> all, BammColumnLayout layout) =>
      all.where((c) => isColumnVisible(c, layout)).toList();

  /// Total width of the table's content: each visible column plus its trailing gap, the fixed
  /// trailing cells, and the container chrome around a row - 12px horizontal padding plus 1px of
  /// border on BOTH sides (see [_tableChromeWidth]). The header and the rows apply the same padding
  /// so their content lines up, and the row `ListView` itself carries no horizontal padding - the
  /// 16px page inset lives outside the horizontal scroller instead. Undercounting this by even 2px
  /// throws a RenderFlex overflow, because every cell is laid out at its own fixed width in that Row.
  double _tableWidth(List<BammColumnDef> visible) =>
      visible.fold<double>(0, (sum, c) => sum + c.width + _columnGap) +
      _trailingColumnsWidth +
      _tableChromeWidth;

  /// 12px padding + 1px border, on each side of the header/row containers.
  static const double _tableChromeWidth = 26.0;

  /// Rebuilds the saved layout so [visibleKeysInOrder] becomes the new
  /// visible order, keeping every hidden column's relative order untouched.
  BammColumnLayout _layoutWithVisibleOrder(BammColumnLayout current, List<String> visibleKeysInOrder) {
    final hiddenInOrder = _allColumns(current).map((c) => c.key).where((k) => current.hidden.contains(k)).toList();
    return BammColumnLayout(order: [...visibleKeysInOrder, ...hiddenInOrder], hidden: current.hidden);
  }

  void _reorderColumn(String draggedKey, String targetKey, List<BammColumnDef> visibleColumns) {
    if (draggedKey == targetKey) return;
    final keys = visibleColumns.map((c) => c.key).toList();
    final oldIndex = keys.indexOf(draggedKey);
    final newIndex = keys.indexOf(targetKey);
    if (oldIndex == -1 || newIndex == -1) return;
    keys.removeAt(oldIndex);
    keys.insert(newIndex, draggedKey);
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(_layoutWithVisibleOrder(layout, keys));
  }

  void _moveColumn(String key, int delta, List<BammColumnDef> visibleColumns) {
    final keys = visibleColumns.map((c) => c.key).toList();
    final index = keys.indexOf(key);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= keys.length) return;
    keys.removeAt(index);
    keys.insert(target, key);
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(_layoutWithVisibleOrder(layout, keys));
  }

  void _hideColumn(String key) {
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(BammColumnLayout(order: layout.order, hidden: {...layout.hidden, key}));
  }

  void _showColumn(String key) {
    final layout = ref.read(bammProvider).columnLayout;
    // A column that isn't default-visible (e.g. Requester) and has never
    // been explicitly ordered is invisible purely because `isColumnVisible`
    // falls through to `defaultVisible == false` - removing it from
    // `hidden` alone is a no-op for that case, since it was never in
    // `hidden` to begin with. Adding it to `order` makes `isColumnVisible`
    // return true regardless of its default.
    final order = layout.order.contains(key) ? layout.order : [...layout.order, key];
    ref.read(bammProvider.notifier).setColumnLayout(
          BammColumnLayout(order: order, hidden: layout.hidden.where((k) => k != key).toSet()),
        );
  }

  /// Applies the existing quick-filter setter for [column] when BAMM has
  /// one (mirrors the toolbar dropdowns); falls back to the free-text
  /// search field for columns with no dedicated filter (description, work
  /// done, priority, labor hours, dates).
  void _applyColumnFilter(BammColumnDef column, String value) {
    final notifier = ref.read(bammProvider.notifier);
    switch (column.key) {
      case 'woStatusDescription':
        notifier.setStatusFilter(value.isEmpty ? null : value);
      case 'woStepDescription':
        notifier.setStepFilter(value.isEmpty ? null : value);
      case 'regrouping1Description':
        notifier.setAreaFilter(value.isEmpty ? null : value);
      case 'recipientName':
        notifier.setResponsibleFilter(value.isEmpty ? null : value);
      case 'requesterName':
        notifier.setRequesterFilter(value.isEmpty ? null : value);
      case 'funCodeLevelNiv3Description':
        notifier.setMachineFilter(value.isEmpty ? null : value);
      case 'executionModeDescription':
        notifier.setExecutionModeFilter(value.isEmpty ? null : value);
      default:
        _searchCtrl.text = value;
        notifier.setSearchQuery(value);
    }
  }

  Future<String?> _promptFilterValue(BammColumnDef column) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Filter by ${column.header}'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Value')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
  }

  /// The header/cell right-click (desktop) or long-press (mobile) menu:
  /// filter by value, sort asc/desc, hide column, move left/right.
  /// [prefillValue] is set when triggered from a data cell (so "Filter by
  /// this value" applies immediately); null when triggered from the header
  /// itself (prompts for a value instead).
  Future<void> _showColumnMenu(
    Offset globalPosition,
    BammColumnDef column,
    List<BammColumnDef> visibleColumns, {
    String? prefillValue,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final index = visibleColumns.indexWhere((c) => c.key == column.key);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 'filter',
          child: Text(prefillValue != null && prefillValue.isNotEmpty ? 'Filter by this value' : 'Filter by value...'),
        ),
        const PopupMenuItem(value: 'sort_asc', child: Text('Sort ascending')),
        const PopupMenuItem(value: 'sort_desc', child: Text('Sort descending')),
        if (column.hideable) const PopupMenuItem(value: 'hide', child: Text('Hide column')),
        PopupMenuItem(value: 'move_left', enabled: index > 0, child: const Text('Move left')),
        PopupMenuItem(value: 'move_right', enabled: index != -1 && index < visibleColumns.length - 1, child: const Text('Move right')),
      ],
    );
    if (selected == null || !mounted) return;
    final notifier = ref.read(bammProvider.notifier);
    switch (selected) {
      case 'filter':
        final value = prefillValue ?? await _promptFilterValue(column);
        if (value != null && mounted) _applyColumnFilter(column, value);
      case 'sort_asc':
        notifier.setSortField(column.key, ascending: true);
      case 'sort_desc':
        notifier.setSortField(column.key, ascending: false);
      case 'hide':
        _hideColumn(column.key);
      case 'move_left':
        _moveColumn(column.key, -1, visibleColumns);
      case 'move_right':
        _moveColumn(column.key, 1, visibleColumns);
    }
  }

  Widget _headerCell(BammColumnDef column, List<BammColumnDef> visibleColumns) {
    final criteria = ref.watch(bammProvider).criteria;
    final sortedAsc = criteria.sortField == column.key && criteria.sortAscending;
    final sortedDesc = criteria.sortField == column.key && !criteria.sortAscending;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != column.key,
      onAcceptWithDetails: (details) => _reorderColumn(details.data, column.key, visibleColumns),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: column.width,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(border: Border(left: BorderSide(color: AppTheme.of(context).primary, width: 2)))
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(bammProvider.notifier).setSort(column.key),
            onSecondaryTapDown: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns),
            onLongPressStart: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns),
            child: Row(
              children: [
                Draggable<String>(
                  data: column.key,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.of(context).surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.of(context).border)),
                      child: Text(column.header, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  child: Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    column.header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (sortedAsc) const Icon(Icons.arrow_upward_rounded, size: 12),
                if (sortedDesc) const Icon(Icons.arrow_downward_rounded, size: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(List<BammColumnDef> visibleColumns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey.shade100,
      child: Row(
        children: [
          for (final column in visibleColumns) ...[
            _headerCell(column, visibleColumns),
            const SizedBox(width: _columnGap),
          ],
          SizedBox(
            width: _trailingColumnsWidth,
            child: Row(
              children: [
                const Expanded(child: Text('Linked', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'Choose columns',
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  onPressed: _showColumnChooser,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColumnChooser() {
    final layout = ref.read(bammProvider).columnLayout;
    final all = _allColumns(layout);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              for (final column in all)
                CheckboxListTile(
                  title: Text(column.header),
                  value: isColumnVisible(column, ref.read(bammProvider).columnLayout),
                  onChanged: column.hideable
                      ? (checked) {
                          if (checked == true) {
                            _showColumn(column.key);
                          } else {
                            _hideColumn(column.key);
                          }
                          setSheetState(() {});
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BammWorkOrder wo, List<BammColumnDef> visibleColumns) {
    final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(wo.worNoSeq);

    return InkWell(
      onTap: () => BammDetailDialog.show(context, wo),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in visibleColumns) ...[
              SizedBox(
                width: column.width,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapDown: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns, prefillValue: column.textOf(wo)),
                  onLongPressStart: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns, prefillValue: column.textOf(wo)),
                  child: column.buildCell(context, wo),
                ),
              ),
              const SizedBox(width: _columnGap),
            ],
            SizedBox(
              width: _trailingColumnsWidth,
              child: Row(
                children: [
                  if (linkedItems.isNotEmpty)
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
                  const Spacer(),
                  IconButton(
                    tooltip: 'View Work Order Details',
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onPressed: () => BammDetailDialog.show(context, wo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Desktop table: a real header row (sort / right-click filter menu / drag
  /// to reorder / hide) above the data rows, both driven by the same
  /// ordered column list so they always line up.
  Widget _buildDesktopTable(List<BammWorkOrder> orders) {
    final layout = ref.watch(bammProvider).columnLayout;
    final visibleColumns = _visibleColumns(_allColumns(layout), layout);
    final width = _tableWidth(visibleColumns);

    // The 16px inset lives OUTSIDE the horizontal scroller on purpose. [_tableWidth] already
    // accounts for the 12px horizontal padding inside the header/row containers and nothing else,
    // so padding the list as well would leave every row 32px short of the width its children sum
    // to - which is exactly the RenderFlex overflow this used to throw at 1400px.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              _buildTableHeader(visibleColumns),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) => _buildTableRow(orders[idx], visibleColumns),
                ),
              ),
            ],
          ),
        ),
      ),
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
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                      ),
                      if (wo.issueDate != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM d').format(wo.issueDate!),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wo.description,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (wo.workDone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Work done',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(wo.workDone, style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (wo.machine.isNotEmpty || wo.area.isNotEmpty)
                        Expanded(
                          child: Text(
                            [
                              if (wo.machine.isNotEmpty) wo.machine,
                              if (wo.area.isNotEmpty) 'Area: ${wo.area}',
                            ].join(' • '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (wo.responsible.isNotEmpty)
                        Text(
                          'Resp: ${wo.responsible}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      if (wo.requester.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Req: ${wo.requester}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
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
