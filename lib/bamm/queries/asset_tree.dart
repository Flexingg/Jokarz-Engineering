/// One level of the BAMM asset tree.
///
/// Modelled on `~/repos/BAMM/app/bamm/assets.py::AssetTreeService.level`.
/// `GET /api/WorkOrderTreeView/GetAssets?id=X` returns **X's children**, not
/// X itself - verified against every capture BAMM has: ask for node 700012595
/// and get a node with id 700012596; ask for that and get its children.
///
/// This module fetches one level at a time and does not walk/cache the tree -
/// a full recursive walk with a node/depth budget is a caching-layer concern
/// for a later phase.
library;

import '../bamm_config.dart';
import '../transport/http_transport.dart';

class AssetTreeException implements Exception {
  final String message;
  const AssetTreeException(this.message);

  @override
  String toString() => message;
}

class AssetNode {
  final dynamic id;
  final String text;
  final String? typeLetter;
  final bool isDirectory;
  final bool hasChildren;
  final bool isSelectable;
  final bool isRoot;

  /// Raw child references as BAMM sent them: bare ids until fetched with
  /// another [BammAssetTreeClient.level] call for that id. Never resolved
  /// recursively here.
  final List<dynamic> children;

  const AssetNode({
    required this.id,
    required this.text,
    this.typeLetter,
    required this.isDirectory,
    required this.hasChildren,
    required this.isSelectable,
    required this.isRoot,
    required this.children,
  });

  factory AssetNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return AssetNode(
      id: json['id'],
      text: json['text']?.toString() ?? '',
      typeLetter: json['typeLetter']?.toString(),
      isDirectory: json['isDirectory'] as bool? ?? false,
      hasChildren: json['hasChildren'] as bool? ?? false,
      isSelectable: json['isSelectable'] as bool? ?? true,
      isRoot: json['isRoot'] as bool? ?? false,
      children: rawChildren is List ? rawChildren : const [],
    );
  }
}

class BammAssetTreeClient {
  final BammHttpTransport transport;
  final BammConfig config;

  const BammAssetTreeClient(this.transport, this.config);

  /// One level of the tree. `nodeId` of `0` (the default) is the root level;
  /// any other id returns that node's children.
  Future<List<AssetNode>> level({dynamic nodeId = 0, dynamic preselectedId}) async {
    final result = await transport.get(
      '/api/WorkOrderTreeView/GetAssets',
      params: {
        'companiesIds': config.companyId.toString(),
        'preselectedIds': preselectedId?.toString() ?? '',
        'id': (nodeId ?? 0).toString(),
      },
      referer: '/',
      operation: 'Asset tree node $nodeId',
      allowNonJson: true,
    );

    final value = (result is Map) ? result['value'] : null;
    if (value is! List) {
      throw AssetTreeException('Asset tree node $nodeId response has no value list');
    }
    return value.whereType<Map<String, dynamic>>().map(AssetNode.fromJson).toList();
  }
}
