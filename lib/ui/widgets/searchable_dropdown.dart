import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Sentinel returned by the sheet's "Clear" action to signal a null selection.
class _ClearAction {
  const _ClearAction();
}
const _clearAction = _ClearAction();

/// A dropdown that opens a filterable picker: tap the field, a sheet opens with
/// a text field so you can type to filter results down (item 12), then pick.
class SearchableDropdownFormField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final Widget? prefixIcon;
  final bool allowClear;

  const SearchableDropdownFormField({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.labelText,
    this.prefixIcon,
    this.allowClear = true,
  });

  Future<void> _open(BuildContext context) async {
    if (items.isEmpty) return;
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _SearchableSheet<T>(
        items: items,
        labelOf: labelOf,
        current: value,
        allowClear: allowClear,
      ),
    );
    if (result == _clearAction) {
      onChanged(null);
      return;
    }
    if (result != null) onChanged(result as T);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = value == null ? null : labelOf(value as T);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: prefixIcon,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text ?? 'Select…',
                style: TextStyle(
                  fontSize: 14,
                  color: text == null
                      ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                      : (isDark ? Colors.white : Colors.black87),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SearchableSheet<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelOf;
  final T? current;
  final bool allowClear;

  const _SearchableSheet({
    required this.items,
    required this.labelOf,
    this.current,
    this.allowClear = true,
  });

  @override
  State<_SearchableSheet<T>> createState() => _SearchableSheetState<T>();
}

class _SearchableSheetState<T> extends State<_SearchableSheet<T>> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => widget.labelOf(i).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Type to filter…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matches'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final isCurrent = item == widget.current;
                        return ListTile(
                          dense: true,
                          title: Text(widget.labelOf(item),
                              style: TextStyle(
                                  fontWeight:
                                      isCurrent ? FontWeight.bold : FontWeight.normal)),
                          trailing:
                              isCurrent ? const Icon(Icons.check, color: AppTheme.accentEmerald) : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
            if (widget.allowClear)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(_clearAction),
                    child: Text('Clear',
                        style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
