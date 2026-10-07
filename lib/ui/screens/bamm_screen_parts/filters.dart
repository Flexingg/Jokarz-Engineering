part of '../bamm_screen.dart';

extension _BammScreenFilters on _BammScreenState {
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

  Widget _buildFilterControlsRow(BammState bammState, bool isDesktop, int displayedCount) {
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
                    onChanged: (val) => _rebuild(() => _localSearchQuery = val),
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
                                _rebuild(() => _localSearchQuery = '');
                                ref.read(bammProvider.notifier).setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildLocalSearchToggle(),
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
                  '$displayedCount orders',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => _rebuild(() => _localSearchQuery = val),
                        onSubmitted: (val) => ref.read(bammProvider.notifier).setSearchQuery(val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search BAMM work orders...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildLocalSearchToggle(),
                  ],
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

  /// Toggles local "search everything already loaded" mode (item 4): OFF by
  /// default, filters the rows already in memory - all fields, including
  /// hidden columns - as the user types, with no new API request. Leaves the
  /// existing server-side search (submit-to-query) untouched either way.
  Widget _buildLocalSearchToggle() {
    return Tooltip(
      message: _localSearchOn
          ? 'Searching all loaded fields locally (no new request). Tap to search BAMM again on submit.'
          : 'Search all fields of already-loaded rows as you type, with no new request',
      child: FilterChip(
        key: const Key('bamm_local_search_toggle'),
        label: const Text('All fields', style: TextStyle(fontSize: 11)),
        avatar: Icon(Icons.travel_explore_rounded, size: 16, color: _localSearchOn ? null : Colors.grey),
        selected: _localSearchOn,
        onSelected: (val) => _rebuild(() => _localSearchOn = val),
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
    if (c.assembly != null && c.assembly!.isNotEmpty) {
      chips.add(Chip(
        label: Text('Assembly: ${c.assembly}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setAssemblyFilter(null),
      ));
    }
    if (c.level2 != null && c.level2!.isNotEmpty) {
      chips.add(Chip(
        label: Text('Level 2: ${c.level2}', style: const TextStyle(fontSize: 11)),
        onDeleted: () => ref.read(bammProvider.notifier).setLevel2Filter(null),
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
}
