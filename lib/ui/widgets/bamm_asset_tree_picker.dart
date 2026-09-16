/// The 5-level cascading machine/asset picker, replacing the free-text
/// machine field. Modelled on `~/repos/BAMM/web/static/js/create.js`
/// (`LEVELS = 5`) and `~/repos/BAMM/app/bamm/assets.py`: one level is
/// fetched lazily per expansion via [BammAssetTreeClient.level] - `?id=X`
/// returns X's *children*, never X itself - and a node with
/// `isSelectable == false` is a folder, not a pickable asset.
///
/// There is no full-tree walk here (that would need `TREE_MAX_DEPTH`/
/// `TREE_MAX_NODES` from the reference); instead a session-wide fetched-node
/// budget ([_nodeBudget]) is enforced across whatever levels this picker
/// instance actually opens, and exceeding it is surfaced in the sheet rather
/// than silently refusing to expand further.
library;

import 'package:flutter/material.dart';

import '../../bamm/queries/asset_tree.dart';

/// The result of a completed pick: the chosen asset's id and its label path
/// from whatever ancestor levels this picker actually visited (BAMM's tree
/// API has no parent lookup, so a result reached via the flat search box has
/// a path of just its own label - see [_AssetTreePickerSheetState._searchResults]).
class BammAssetSelection {
  final String id;
  final List<String> path;
  const BammAssetSelection({required this.id, required this.path});

  String get displayPath => path.join(' > ');
}

Future<BammAssetSelection?> showBammAssetTreePicker(
  BuildContext context, {
  required BammAssetTreeClient client,
}) {
  return showModalBottomSheet<BammAssetSelection>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _AssetTreePickerSheet(client: client),
  );
}

class _AssetTreePickerSheet extends StatefulWidget {
  final BammAssetTreeClient client;
  const _AssetTreePickerSheet({required this.client});

  @override
  State<_AssetTreePickerSheet> createState() => _AssetTreePickerSheetState();
}

class _AssetTreePickerSheetState extends State<_AssetTreePickerSheet> {
  static const int levelCount = 5;
  static const int _nodeBudget = 4000;
  static const int _searchResultCap = 60;

  final List<List<AssetNode>> _levelNodes = List.generate(levelCount, (_) => <AssetNode>[]);
  final List<AssetNode?> _levelSelection = List.generate(levelCount, (_) => null);
  final List<bool> _levelLoading = List.generate(levelCount, (_) => false);
  final List<Object?> _levelError = List.generate(levelCount, (_) => null);
  int _nodesFetched = 0;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLevel(0, nodeId: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _budgetExceeded => _nodesFetched > _nodeBudget;

  Future<void> _loadLevel(int level, {required dynamic nodeId}) async {
    setState(() {
      _levelLoading[level] = true;
      _levelError[level] = null;
    });
    try {
      final nodes = await widget.client.level(nodeId: nodeId);
      _nodesFetched += nodes.length;
      if (!mounted) return;
      setState(() {
        _levelNodes[level] = nodes;
        _levelLoading[level] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _levelError[level] = e;
        _levelLoading[level] = false;
      });
    }
  }

  void _selectNode(int level, AssetNode node) {
    setState(() {
      _levelSelection[level] = node;
      for (var l = level + 1; l < levelCount; l++) {
        _levelSelection[l] = null;
        _levelNodes[l] = const [];
        _levelError[l] = null;
      }
    });
    if (node.hasChildren && level + 1 < levelCount && !_budgetExceeded) {
      _loadLevel(level + 1, nodeId: node.id);
    }
  }

  AssetNode? get _deepestSelectable {
    for (var l = levelCount - 1; l >= 0; l--) {
      final sel = _levelSelection[l];
      if (sel != null && sel.isSelectable) return sel;
    }
    return null;
  }

  List<String> get _pathLabels =>
      _levelSelection.where((n) => n != null).map((n) => n!.text).toList(growable: false);

  /// Prefix-scored search over every node loaded into any level so far - not
  /// a server call, matching the reference's client-side "cached tree"
  /// search. A purely numeric query also matches by id.
  List<AssetNode> _searchResults(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final all = _levelNodes.expand((l) => l).toList();
    final byId = all.where((n) => n.id.toString() == q).toList();
    final byLabel = all.where((n) => n.text.toLowerCase().contains(q)).toList()
      ..sort((a, b) {
        final aStarts = a.text.toLowerCase().startsWith(q) ? 0 : 1;
        final bStarts = b.text.toLowerCase().startsWith(q) ? 0 : 1;
        if (aStarts != bStarts) return aStarts.compareTo(bStarts);
        return a.text.compareTo(b.text);
      });
    final merged = <AssetNode>[...byId, ...byLabel.where((n) => !byId.contains(n))];
    return merged.take(_searchResultCap).toList();
  }

  void _confirm(BammAssetSelection selection) => Navigator.pop(context, selection);

  @override
  Widget build(BuildContext context) {
    final searching = _searchCtrl.text.trim().isNotEmpty;
    final deepest = _deepestSelectable;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Select machine / asset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search already-loaded assets, or an id...',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_budgetExceeded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Loaded $_nodesFetched nodes (budget $_nodeBudget) - narrow your search instead of expanding further branches',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(height: 20),
            Expanded(
              child: searching
                  ? _buildSearchResults(scrollCtrl, _searchResults(_searchCtrl.text))
                  : _buildLevels(scrollCtrl),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    deepest != null
                        ? 'Selected: ${_pathLabels.join(' > ')}'
                        : 'No selectable asset chosen yet',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: deepest == null
                      ? null
                      : () => _confirm(BammAssetSelection(id: deepest.id.toString(), path: _pathLabels)),
                  child: const Text('Use this asset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ScrollController scrollCtrl, List<AssetNode> results) {
    if (results.isEmpty) {
      return const Center(child: Text('No matches in the levels loaded so far'));
    }
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final node = results[i];
        return ListTile(
          dense: true,
          leading: Icon(node.isDirectory ? Icons.folder_outlined : Icons.precision_manufacturing_outlined, size: 18),
          title: Text(node.text),
          subtitle: Text(node.isSelectable ? 'id ${node.id}' : 'Not selectable (folder)'),
          enabled: node.isSelectable,
          onTap: node.isSelectable ? () => _confirm(BammAssetSelection(id: node.id.toString(), path: [node.text])) : null,
        );
      },
    );
  }

  Widget _buildLevels(ScrollController scrollCtrl) {
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: levelCount,
      itemBuilder: (ctx, level) {
        // Progressive reveal: level N only shows once level N-1 has a
        // selection with children (or is level 0, always shown).
        if (level > 0 && _levelSelection[level - 1] == null) return const SizedBox.shrink();
        if (level > 0 && !_levelSelection[level - 1]!.hasChildren) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level ${level + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              if (_levelLoading[level])
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
              else if (_levelError[level] != null)
                Text('Failed to load: ${_levelError[level]}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _levelNodes[level].map((node) {
                    final isSelected = identical(_levelSelection[level], node);
                    return ChoiceChip(
                      label: Text(node.text, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(
                        node.isDirectory ? Icons.folder_outlined : Icons.precision_manufacturing_outlined,
                        size: 14,
                      ),
                      selected: isSelected,
                      onSelected: (_) => _selectNode(level, node),
                      backgroundColor: node.isSelectable ? null : Colors.grey.withValues(alpha: 0.15),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
