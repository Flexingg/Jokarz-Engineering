part of '../bamm_screen.dart';

extension _BammScreenDialogs on _BammScreenState {
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
                            onPressed: () => _openWo(created),
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
}
