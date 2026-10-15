import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../bamm/mutations/model_ops.dart' show propertyValue;
import '../../bamm/schema/lookups.dart';
import '../../models/bamm_models.dart';
import '../../models/order_item.dart';
import '../../models/project.dart';
import '../../models/project_template.dart';
import '../../models/task_item.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/bamm_adapter.dart' show bammActivityLinesFromModel, resolveLookupOption;
import '../../services/bamm_service.dart' show BammAddActivityLineOutcome;
import '../../theme/app_theme.dart';
import 'bamm_asset_tree_picker.dart';
import 'bamm_lookup_picker.dart';

part 'bamm_detail_parts/add_activity_line_sheet.dart';
part 'bamm_detail_parts/bamm_link_sheet.dart';

class BammDetailDialog extends ConsumerStatefulWidget {
  final BammWorkOrder workOrder;
  /// Sheet-integrity warning text (non-null only when a scanned report QR's
  /// embedded hash no longer matches this work order's live data) - see
  /// `bamm_report_integrity.dart`.
  final String? staleWarning;

  /// Render as a side pane (no dialog chrome) instead of an [AlertDialog].
  /// BAMM writes go to the live system, so editing keeps its explicit Save
  /// rather than autosaving.
  final bool embedded;
  final VoidCallback? onClose;

  const BammDetailDialog({
    super.key,
    required this.workOrder,
    this.staleWarning,
    this.embedded = false,
    this.onClose,
  });

  static Future<void> show(BuildContext context, BammWorkOrder workOrder, {String? staleWarning}) {
    return showDialog(
      context: context,
      builder: (ctx) => BammDetailDialog(workOrder: workOrder, staleWarning: staleWarning),
    );
  }

  @override
  ConsumerState<BammDetailDialog> createState() => _BammDetailDialogState();
}

class _BammDetailDialogState extends ConsumerState<BammDetailDialog> {
  late BammWorkOrder _wo;
  bool _isEditing = false;
  late final TextEditingController _descCtrl;
  late final TextEditingController _workDoneCtrl;
  late final TextEditingController _employeesCtrl;
  late final TextEditingController _priorityEmCtrl;
  late final TextEditingController _laborHoursCtrl;
  DateTime? _requiredDate;
  bool _isSaving = false;
  bool _isLoadingDetail = false;

  // API-backed pickers (BammLookupsClient) - never a bundled option list.
  // Seeded from the raw DynamicDTO's id-only properties (see
  // `_optionFromRaw`) until the user opens a picker, which resolves the
  // matching label from whatever BAMM's lookup endpoint actually returns.
  BammAssetSelection? _asset;
  LookupOption? _status;
  LookupOption? _responsible;
  LookupOption? _classification;
  LookupOption? _skill;
  LookupOption? _classificationTable;
  LookupOption? _crewShift;
  LookupOption? _step;
  LookupOption? _maintenanceType;
  LookupOption? _executionMode;

  @override
  void initState() {
    super.initState();
    _wo = widget.workOrder;
    _descCtrl = TextEditingController(text: _wo.description);
    _workDoneCtrl = TextEditingController(text: _wo.workDone);
    _requiredDate = _wo.requiredDate;
    _employeesCtrl = TextEditingController(text: _wo.requiredEmployees?.toString() ?? '');
    _priorityEmCtrl = TextEditingController();
    _laborHoursCtrl = TextEditingController(text: _wo.laborHours?.toString() ?? '');
    _resetPickersFromRawDto();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFullDetail();
    });
  }

  /// One raw property value from the last `GetById` model as a placeholder
  /// [LookupOption] - id only, no label, until a picker resolves it against
  /// the live lookup list. `null`/`"0"` means "not set".
  LookupOption? _optionFromRaw(String propertyName) {
    final raw = _wo.rawDto;
    if (raw == null) return null;
    final id = propertyValue(raw, propertyName)?.trim();
    if (id == null || id.isEmpty || id == '0') return null;
    return LookupOption(id: id, label: '', code: '', inactive: false);
  }

  void _resetPickersFromRawDto() {
    final rawAssetId = _wo.rawDto != null ? propertyValue(_wo.rawDto!, 'FUN_ID')?.trim() : null;
    _asset = (rawAssetId == null || rawAssetId.isEmpty || rawAssetId == '0')
        ? null
        : BammAssetSelection(id: rawAssetId, path: [if (_wo.machine.isNotEmpty) _wo.machine else 'ID $rawAssetId']);
    _status = _optionFromRaw('WOS_ID');
    _responsible = _optionFromRaw('RCP_ID');
    _classification = _optionFromRaw('CTG_ID');
    _skill = _optionFromRaw('SKI_ID');
    _classificationTable = _optionFromRaw('WG6_ID');
    _crewShift = _optionFromRaw('WG7_ID');
    _step = _optionFromRaw('WSP_ID');
    _maintenanceType = _optionFromRaw('MNT_ID');
    _executionMode = _optionFromRaw('EXM_ID');
    _priorityEmCtrl.text = _wo.rawDto != null ? (propertyValue(_wo.rawDto!, 'WOR_NB_3') ?? '') : '';
    _laborHoursCtrl.text = _wo.laborHours?.toString() ?? '';
  }

  /// Resolves every id-only picker field's real label against the live
  /// lookup lists (the same `BammLookupsClient` endpoints the pickers
  /// themselves call) - the fix for the dialog showing raw ids where a label
  /// was actually resolvable. Runs after every raw-dto refresh (initial
  /// fetch, save, add-activity-line); a failure here must not crash the
  /// dialog - the id-only placeholder from [_resetPickersFromRawDto] (shown
  /// via `_buildPickerRow`'s own "ID x" fallback) stays in place until it
  /// succeeds.
  Future<void> _resolveLookupLabels() async {
    final raw = _wo.rawDto;
    if (raw == null) return;
    final lookups = ref.read(bammServiceProvider).lookups;
    try {
      final results = await Future.wait([
        lookups.status(),
        lookups.responsible(),
        lookups.categories(),
        lookups.skills(),
        lookups.classificationTables(),
        lookups.crewShifts(),
        lookups.steps(),
        lookups.maintenanceTypes(),
        lookups.executionModes(),
      ]);
      if (!mounted || _wo.rawDto != raw) return;
      setState(() {
        _status = resolveLookupOption(propertyValue(raw, 'WOS_ID'), results[0].items) ?? _status;
        _responsible = resolveLookupOption(propertyValue(raw, 'RCP_ID'), results[1].items) ?? _responsible;
        _classification = resolveLookupOption(propertyValue(raw, 'CTG_ID'), results[2].items) ?? _classification;
        _skill = resolveLookupOption(propertyValue(raw, 'SKI_ID'), results[3].items) ?? _skill;
        _classificationTable = resolveLookupOption(propertyValue(raw, 'WG6_ID'), results[4].items) ?? _classificationTable;
        _crewShift = resolveLookupOption(propertyValue(raw, 'WG7_ID'), results[5].items) ?? _crewShift;
        _step = resolveLookupOption(propertyValue(raw, 'WSP_ID'), results[6].items) ?? _step;
        _maintenanceType = resolveLookupOption(propertyValue(raw, 'MNT_ID'), results[7].items) ?? _maintenanceType;
        _executionMode = resolveLookupOption(propertyValue(raw, 'EXM_ID'), results[8].items) ?? _executionMode;
      });
    } catch (_) {
      // Leave the id-only placeholders in place - a resolution failure must
      // never crash the dialog or show a wrong label.
    }
  }

  Future<void> _fetchFullDetail() async {
    if (_wo.worId <= 0) return;
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await ref.read(bammProvider.notifier).fetchWorkOrderDetail(_wo.worId);
      if (detail != null && mounted) {
        setState(() {
          _wo = detail;
          _descCtrl.text = detail.description;
          _workDoneCtrl.text = detail.workDone;
          _requiredDate = detail.requiredDate;
          _employeesCtrl.text = detail.requiredEmployees?.toString() ?? '';
          _resetPickersFromRawDto();
          _isLoadingDetail = false;
        });
        unawaited(_resolveLookupLabels());
      } else if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _workDoneCtrl.dispose();
    _employeesCtrl.dispose();
    _priorityEmCtrl.dispose();
    _laborHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final employees = int.tryParse(_employeesCtrl.text.trim());
      final priorityEm = double.tryParse(_priorityEmCtrl.text.trim());
      final laborHours = double.tryParse(_laborHoursCtrl.text.trim());
      final outcome = await ref.read(bammProvider.notifier).updateWorkOrder(
        worId: _wo.worId,
        description: _descCtrl.text.trim(),
        workDone: _workDoneCtrl.text.trim(),
        responsible: _responsible?.id,
        requiredDate: _requiredDate,
        classificationId: _classification?.id,
        skillId: _skill?.id,
        classificationTableId: _classificationTable?.id,
        crewShiftId: _crewShift?.id,
        requiredEmployees: employees,
        stepId: _step?.id,
        maintenanceTypeId: _maintenanceType?.id,
        executionModeId: _executionMode?.id,
        priorityEm: priorityEm,
        assetId: _asset?.id,
        estimatedLaborHours: laborHours,
        statusId: _status?.id,
      );
      setState(() {
        _wo = outcome.workOrder;
        _descCtrl.text = outcome.workOrder.description;
        _workDoneCtrl.text = outcome.workOrder.workDone;
        _requiredDate = outcome.workOrder.requiredDate;
        _employeesCtrl.text = outcome.workOrder.requiredEmployees?.toString() ?? '';
        _laborHoursCtrl.text = outcome.workOrder.laborHours?.toString() ?? '';
        _resetPickersFromRawDto();
        _isEditing = false;
        _isSaving = false;
      });
      unawaited(_resolveLookupLabels());
      if (mounted) {
        final result = outcome.writeResult;
        final verdict = result.fields.map((f) => f.describe()).join('\n');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess ? 'Saved to BAMM:\n$verdict' : 'BAMM save incomplete:\n$verdict',
            ),
            backgroundColor: result.isSuccess ? null : Theme.of(context).colorScheme.errorContainer,
            duration: Duration(seconds: result.isSuccess ? 4 : 8),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update BAMM: $e')),
        );
      }
    }
  }

  void _showAssignToItemModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _BammLinkSheet(
        workOrder: _wo,
        onLinked: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(projectProvider);
    final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(_wo.worNoSeq);

    final titleRow = Row(
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
          Expanded(
            child: Text(
              'BAMM Work Order #${_wo.worNoSeq}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: _isEditing ? 'Cancel Editing' : 'Edit Work Order',
            icon: Icon(_isEditing ? Icons.close : Icons.edit_rounded, size: 20),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      );
    final bodyColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.staleWarning != null) ...[
                Container(
                  key: const Key('bamm_stale_warning'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade700, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.staleWarning!,
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Status & Step Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _wo.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _wo.statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _wo.status,
                      style: TextStyle(color: _wo.statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _wo.stepColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _wo.stepColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _wo.step,
                      style: TextStyle(color: _wo.stepColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_wo.priority.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Priority: ${_wo.priority}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isEditing) ...[
                // Edit Form - only fields BAMM will actually accept
                // (BammWritableField) get an input; everything else is
                // read-only here too, so nothing is ever shown as editable
                // without a way to save it.
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Work Order Description *',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workDoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Work Done',
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                _buildPickerRow(
                  label: 'Status',
                  current: _status,
                  onTap: _pickStatus,
                ),
                const SizedBox(height: 12),
                _buildPickerRow(
                  label: 'Responsible',
                  current: _responsible,
                  onTap: () => _pickLookup(
                    title: 'Responsible',
                    serverSearch: true,
                    fetch: (query) => ref.read(bammServiceProvider).lookups.responsible(search: query),
                    onSelected: (o) => _responsible = o,
                  ),
                ),
                const SizedBox(height: 12),
                // API-backed pickers - each option list comes from BAMM at
                // pick time (BammLookupsClient), never a bundled array.
                _buildPickerRow(
                  label: 'Classification',
                  current: _classification,
                  onTap: () => _pickLookup(
                    title: 'Classification',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.categories(),
                    onSelected: (o) => _classification = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Required skill',
                  current: _skill,
                  onTap: () => _pickLookup(
                    title: 'Required skill',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.skills(),
                    onSelected: (o) => _skill = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Classification table',
                  current: _classificationTable,
                  onTap: () => _pickLookup(
                    title: 'Classification table',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.classificationTables(),
                    onSelected: (o) => _classificationTable = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Crew / Shift',
                  current: _crewShift,
                  onTap: () => _pickLookup(
                    title: 'Crew / Shift',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.crewShifts(),
                    onSelected: (o) => _crewShift = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Step',
                  current: _step,
                  onTap: () => _pickLookup(
                    title: 'Step',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.steps(),
                    onSelected: (o) => _step = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Maintenance type',
                  current: _maintenanceType,
                  onTap: () => _pickLookup(
                    title: 'Maintenance type',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.maintenanceTypes(),
                    onSelected: (o) => _maintenanceType = o,
                  ),
                ),
                _buildPickerRow(
                  label: 'Machine status',
                  current: _executionMode,
                  onTap: () => _pickLookup(
                    title: 'Machine status',
                    fetch: (_) => ref.read(bammServiceProvider).lookups.executionModes(),
                    onSelected: (o) => _executionMode = o,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerRow(
                        label: 'Machine',
                        current: _asset == null ? null : LookupOption(id: _asset!.id, label: _asset!.displayPath, code: '', inactive: false),
                        onTap: () async {
                          final selection = await showBammAssetTreePicker(context, client: ref.read(bammServiceProvider).assetTree);
                          if (selection != null && mounted) setState(() => _asset = selection);
                        },
                      ),
                    ),
                    if (_asset != null)
                      IconButton(
                        tooltip: 'Clear machine selection (does not remove it from BAMM until you pick a new one and save)',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _asset = null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _employeesCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Required employees', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _priorityEmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                        decoration: const InputDecoration(labelText: 'EM Priority (0-25)', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _laborHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                  decoration: const InputDecoration(labelText: 'Estimated labour hours', isDense: true),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not editable from this app yet',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow('Area', _wo.area.isNotEmpty ? _wo.area : 'Unspecified'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, size: 20),
                  title: Text(
                    _requiredDate != null ? DateFormat('yyyy-MM-dd').format(_requiredDate!) : 'No target date',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text('Target Required Date', style: TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requiredDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _requiredDate = picked);
                      }
                    },
                    child: const Text('Change Date'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save to BAMM'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                ),
              ] else ...[
                // View Mode
                if (_isLoadingDetail)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                Text(
                  _wo.description,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (_wo.workDone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.of(context).primary),
                            const SizedBox(width: 6),
                            Text(
                              'Work Done / Activity Log',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.of(context).primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _wo.workDone,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoRow('Machine / Area', '${_wo.machine.isNotEmpty ? _wo.machine : 'None'} (${_wo.area.isNotEmpty ? _wo.area : 'Unspecified'})'),
                _buildInfoRow('Responsible', _wo.responsible.isNotEmpty ? _wo.responsible : 'Unassigned'),
                _buildInfoRow('Requester', _wo.requester.isNotEmpty ? _wo.requester : 'None'),
                if (_wo.issueDate != null)
                  _buildInfoRow('Registered Date', DateFormat('MMM d, y').format(_wo.issueDate!)),
                if (_wo.requiredDate != null)
                  _buildInfoRow('Target Date', DateFormat('MMM d, y').format(_wo.requiredDate!)),
                if (_wo.laborHours != null)
                  _buildInfoRow('Est. Labor Hours', '${_wo.laborHours} hrs'),
              ],

              const Divider(height: 28),

              // Activity lines (WO_DETAIL) - display + add only, no edit/delete
              // of existing lines (see the batch brief).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text('Activity Lines:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _wo.worId > 0 ? _showAddActivityLineSheet : null,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Line', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_activityLines.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Text('No activity lines yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else
                ..._activityLines.map((line) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.checklist_rounded, size: 18),
                        title: Text(
                          line.description.isNotEmpty ? line.description : 'Activity ${line.activityId} / ${line.subActivityId}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Activity ${line.activityId} - Sub-activity ${line.subActivityId}'
                          '${line.hours != null ? ' - ${line.hours}h' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )),

              const Divider(height: 28),

              // Linked Items in AOR Engineering
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Linked in AOR Engineering:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showAssignToItemModal,
                    icon: const Icon(Icons.add_link_rounded, size: 16),
                    label: const Text('Link Item', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (linkedItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Not linked to any projects, tasks, or orders yet. Tap "Link Item" above to connect it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                ...linkedItems.map((item) {
                  final type = item['type'] as String;
                  IconData icon;
                  String label;

                  if (type == 'project') {
                    icon = Icons.assignment_rounded;
                    label = 'Project: ${item['title']}';
                  } else if (type == 'task') {
                    icon = Icons.task_alt_rounded;
                    label = 'Task: ${item['title']} (${item['projectTitle']})';
                  } else if (type == 'order') {
                    icon = Icons.local_shipping_rounded;
                    label = 'Order: ${item['title']} (${item['projectTitle']})';
                  } else {
                    icon = Icons.receipt_long_rounded;
                    label = 'Standalone Order: ${item['title']}';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(icon, color: AppTheme.of(context).primary, size: 18),
                      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
                      onTap: () {
                        if (!widget.embedded) Navigator.pop(context);
                        if (type == 'project' || type == 'task' || type == 'order') {
                          final pId = item['projectId'] as String;
                          context.push('/projects/$pId');
                        } else {
                          context.push('/orders');
                        }
                      },
                    ),
                  );
                }),
            ],
          );

    if (widget.embedded) {
      final colors = AppTheme.of(context);
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
                child: Row(
                  children: [
                    Expanded(child: titleRow),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: bodyColumn,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: titleRow,
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(child: bodyColumn),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<BammActivityLine> get _activityLines =>
      _wo.rawDto != null ? bammActivityLinesFromModel(_wo.rawDto!) : const [];

  Future<void> _showAddActivityLineSheet() async {
    final outcome = await showModalBottomSheet<BammAddActivityLineOutcome>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _AddActivityLineSheet(workOrder: _wo),
    );
    if (outcome != null && mounted) {
      setState(() {
        _wo = outcome.workOrder;
        _resetPickersFromRawDto();
      });
      unawaited(_resolveLookupLabels());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.added
              ? 'Activity line added'
              : 'BAMM did not add the line - nothing changed'),
          backgroundColor: outcome.added ? null : Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  Future<void> _pickLookup({
    required String title,
    required Future<LookupResult> Function(String search) fetch,
    required ValueChanged<LookupOption> onSelected,
    bool serverSearch = false,
  }) async {
    final selected = await showBammLookupPicker(context, title: title, fetch: fetch, serverSearch: serverSearch);
    if (selected != null && mounted) setState(() => onSelected(selected));
  }

  /// Status ids (`WOS_ID`) that end a work order's workflow - confirmed
  /// against `~/repos/BAMM/docs/11-field-inventory.md`'s enumerated values
  /// (Completed `3`, Cancelled `4`, Closed `6`). Picking one of these is not
  /// accepted until the user explicitly confirms it in [_pickStatus], since
  /// closing/completing/cancelling a work order affects plant workflow.
  static const Set<String> _closingStatusIds = {'3', '4', '6'};

  Future<void> _pickStatus() async {
    final selected = await showBammLookupPicker(
      context,
      title: 'Status',
      fetch: (_) => ref.read(bammServiceProvider).lookups.status(),
    );
    if (selected == null || !mounted) return;

    if (_closingStatusIds.contains(selected.id)) {
      final label = selected.label.isNotEmpty ? selected.label : 'ID ${selected.id}';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm status change'),
          content: Text(
            'Setting status to "$label" closes this work order and affects plant workflow. '
            'This cannot be easily undone from this app. Are you sure?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (confirmed != true) return; // not sent - the picker selection is simply discarded
    }
    if (mounted) setState(() => _status = selected);
  }

  Widget _buildPickerRow({required String label, required LookupOption? current, VoidCallback? onTap}) {
    final display = current == null
        ? 'Not set'
        : (current.label.isNotEmpty ? current.label : 'ID ${current.id}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          TextButton(onPressed: onTap, child: const Text('Change', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

