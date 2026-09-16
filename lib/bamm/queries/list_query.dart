/// Building and running a `GetListData` work-order list request.
///
/// Modelled on `~/repos/BAMM/app/bamm/views.py::compile_payload` and
/// `~/repos/BAMM/docs/03-reading-work-orders.md`. The list is a saved view, not
/// a query string: you POST a JSON description of columns/sort/filters and
/// the server resolves and runs it.
library;

import '../bamm_config.dart';
import '../src/json_helpers.dart';
import '../transport/http_transport.dart';

class ListQueryException implements Exception {
  final String message;
  const ListQueryException(this.message);

  @override
  String toString() => message;
}

/// One column in `listFormat.fields`.
class ListColumn {
  final String key;
  final String? header;
  final bool isVisible;
  final int? fieldDataType;
  final int? format;

  const ListColumn({
    required this.key,
    this.header,
    this.isVisible = true,
    this.fieldDataType,
    this.format,
  });

  Map<String, dynamic> toJson() => {
        'name': key,
        'key': key,
        if (header != null) 'header': header,
        'isVisible': isVisible,
        if (fieldDataType != null) 'fieldDataType': fieldDataType,
        if (format != null) 'format': format,
      };
}

/// One entry in `listFormat.orderByFields`.
class ListOrderBy {
  final String name;
  final bool ascending;

  const ListOrderBy(this.name, {this.ascending = true});

  Map<String, dynamic> toJson() => {'name': name, 'ascending': ascending};
}

/// One compiled BAMM list filter block. Build with [ListFilter.byList] (a
/// lookup-backed multi-select, `filterType` 8) or [ListFilter.byText]
/// (free-text contains, `filterType` 1).
class ListFilter {
  final String searchFieldKey;
  final int filterType;
  final String? description;
  final String? sourceUrl;
  final String? categoryDescription;
  final List<Map<String, dynamic>> listValues;
  final List<String> stringValues;
  final String status;
  final bool includeNull;

  const ListFilter._({
    required this.searchFieldKey,
    required this.filterType,
    this.description,
    this.sourceUrl,
    this.categoryDescription,
    this.listValues = const [],
    this.stringValues = const [],
    this.status = 'included',
    this.includeNull = false,
  });

  /// [filterType] defaults to 8 (BAMM's usual lookup-backed multi-select) but
  /// is overridable: the work-order step filter is the one observed case that
  /// travels as filterType 3 instead, even though it is still a list of
  /// lookup-backed options on the wire.
  factory ListFilter.byList({
    required String searchFieldKey,
    required List<Map<String, dynamic>> options,
    String? description,
    String? sourceUrl,
    String? categoryDescription,
    String status = 'included',
    bool includeNull = false,
    int filterType = 8,
  }) =>
      ListFilter._(
        searchFieldKey: searchFieldKey,
        filterType: filterType,
        description: description,
        sourceUrl: sourceUrl,
        categoryDescription: categoryDescription,
        listValues: options,
        status: status,
        includeNull: includeNull,
      );

  factory ListFilter.byText({
    required String searchFieldKey,
    required String value,
    String status = 'included',
  }) =>
      ListFilter._(searchFieldKey: searchFieldKey, filterType: 1, stringValues: [value], status: status);

  Map<String, dynamic> toJson() => {
        'searchFieldKey': searchFieldKey,
        'filterType': filterType,
        if (description != null) 'description': description,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (categoryDescription != null) 'categoryDescription': categoryDescription,
        'values': [
          {
            'status': status,
            'comparisonType': 'contains',
            'includeNull': includeNull,
            'listValues': listValues,
            'stringValues': stringValues,
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      };
}

/// A `GetListData` request body: `{ filters, listFormat, isCountOnly }`.
class ListQueryRequest {
  final List<ListColumn> fields;
  final List<ListOrderBy> orderByFields;
  final List<ListFilter> filters;
  final int topCount;
  final bool isCountOnly;

  const ListQueryRequest({
    required this.fields,
    this.orderByFields = const [],
    this.filters = const [],
    this.topCount = 2000,
    this.isCountOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'filters': filters.map((f) => f.toJson()).toList(),
        'listFormat': {
          'fields': fields.map((f) => f.toJson()).toList(),
          'orderByFields': orderByFields.map((o) => o.toJson()).toList(),
          'topCount': topCount,
        },
        'isCountOnly': isCountOnly,
      };
}

/// Unwrapped rows plus the server-reported total.
class ListQueryResult {
  final List<Map<String, dynamic>> rows;
  final int total;

  const ListQueryResult({required this.rows, required this.total});
}

class BammListQueryClient {
  final BammHttpTransport transport;
  final BammConfig config;

  const BammListQueryClient(this.transport, this.config);

  /// `POST /api/WorkOrderList/GetListData`.
  ///
  /// Every row on the wire is wrapped in `propertyList` - unwrapped here.
  /// Skipping that unwrap is the #1 way this breaks silently: the row count
  /// looks right, but every row appears to have exactly one key.
  Future<ListQueryResult> fetch(ListQueryRequest request) async {
    final result = await transport.post(
      '/api/WorkOrderList/GetListData',
      jsonBody: request.toJson(),
      referer: '/workorder/list/work-order/${config.listScreenId}',
      operation: 'Work order list',
    );

    if (result is! Map) {
      throw const ListQueryException('GetListData response has an unexpected shape');
    }
    final rawRows = result['value'];
    if (rawRows is! List) {
      throw const ListQueryException('GetListData response has no value list');
    }

    final rows = rawRows.map((row) {
      if (row is Map<String, dynamic> && row['propertyList'] is Map<String, dynamic>) {
        return row['propertyList'] as Map<String, dynamic>;
      }
      if (row is Map<String, dynamic>) return row;
      throw const ListQueryException('GetListData row is not an object');
    }).toList();

    final total = asInt(result['total']) ?? rows.length;
    return ListQueryResult(rows: rows, total: total);
  }
}
