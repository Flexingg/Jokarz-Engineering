/// A searchable picker sheet backed by a live BAMM `/api/WorkOrderLookup/*`
/// endpoint - every option comes from [fetch] at call time, never from a
/// bundled/hardcoded list. Mirrors how BAMM's own web UI populates its
/// dropdowns (`~/repos/BAMM/web/static/js/create.js`): filtering is
/// client-side over one fetched page by default, except Responsible, which
/// BAMM itself supports server-side search for - pass [serverSearch] true
/// there and [fetch] is re-invoked (debounced) with the current query
/// instead of filtering locally.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../bamm/schema/lookups.dart';

/// Shows the picker and returns the chosen [LookupOption], or `null` if the
/// user dismissed it without choosing one.
Future<LookupOption?> showBammLookupPicker(
  BuildContext context, {
  required String title,
  required Future<LookupResult> Function(String search) fetch,
  bool serverSearch = false,
}) {
  return showModalBottomSheet<LookupOption>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _BammLookupPickerSheet(title: title, fetch: fetch, serverSearch: serverSearch),
  );
}

class _BammLookupPickerSheet extends StatefulWidget {
  final String title;
  final Future<LookupResult> Function(String search) fetch;
  final bool serverSearch;

  const _BammLookupPickerSheet({required this.title, required this.fetch, required this.serverSearch});

  @override
  State<_BammLookupPickerSheet> createState() => _BammLookupPickerSheetState();
}

class _BammLookupPickerSheetState extends State<_BammLookupPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  LookupResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(query);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (!widget.serverSearch) {
      setState(() {}); // client-side filter reads _searchCtrl.text directly
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(query));
  }

  List<LookupOption> get _visibleOptions {
    final all = _result?.items ?? const [];
    if (widget.serverSearch) return all;
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all
        .where((o) =>
            o.label.toLowerCase().contains(query) ||
            o.code.toLowerCase().contains(query) ||
            o.id.toLowerCase() == query)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final options = _visibleOptions;
    final result = _result;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search...',
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            if (result != null && result.isTruncated)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Showing ${result.items.length} of ${result.total} - refine your search to find more',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(height: 20),
            Expanded(child: _buildBody(options)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<LookupOption> options) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Failed to load options: $_error'));
    if (options.isEmpty) return const Center(child: Text('No matching options'));
    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (ctx, i) {
        final o = options[i];
        return ListTile(
          dense: true,
          title: Text(
            o.label.isNotEmpty ? o.label : 'ID ${o.id}',
            style: TextStyle(decoration: o.inactive ? TextDecoration.lineThrough : null),
          ),
          subtitle: o.code.isNotEmpty ? Text(o.code) : null,
          onTap: () => Navigator.pop(context, o),
        );
      },
    );
  }
}
