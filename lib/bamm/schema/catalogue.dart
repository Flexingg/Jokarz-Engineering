/// Live schema for the BAMM work-order list: column catalogue, filter
/// catalogue, field catalogue, groupings and priority.
///
/// Modelled on `~/repos/BAMM/app/bamm/catalog.py`, but live-only: that Python
/// module reads `samples/grid_fields.json` / `samples/list_filters.json`
/// offline captures with a `TODO(live-catalog)` to fetch live when possible.
/// This port does the live fetch - no bundled-JSON fallback in runtime code.
/// Fixtures are for tests only.
library;

import 'package:xml/xml.dart' as xml;

import '../bamm_config.dart';
import '../dto/dynamic_dto.dart';
import '../src/json_helpers.dart';
import '../transport/http_transport.dart';
import 'lookups.dart';

class BammCatalogueException implements Exception {
  final String message;
  const BammCatalogueException(this.message);

  @override
  String toString() => message;
}

/// One entry from `GetListConfigurationStructure` - a column the work order
/// grid can show.
class ColumnDef {
  final String key;
  final String? header;
  final bool visible;
  final bool hidden;
  final int? dataType;
  final int? format;
  final String? linkURL;
  final String? pinned;
  final int? order;
  final bool isClickable;
  final bool hasValueChanger;

  const ColumnDef({
    required this.key,
    this.header,
    required this.visible,
    required this.hidden,
    this.dataType,
    this.format,
    this.linkURL,
    this.pinned,
    this.order,
    required this.isClickable,
    required this.hasValueChanger,
  });

  factory ColumnDef.fromJson(Map<String, dynamic> json) {
    final key = json['key'] ?? json['name'];
    if (key == null || key.toString().isEmpty) {
      throw const BammCatalogueException('Column entry is missing a key');
    }
    return ColumnDef(
      key: key.toString(),
      header: json['header']?.toString(),
      visible: json['isVisible'] as bool? ?? json['visible'] as bool? ?? true,
      hidden: json['isHidden'] as bool? ?? json['hidden'] as bool? ?? false,
      dataType: asInt(json['fieldDataType'] ?? json['dataType']),
      format: asInt(json['format']),
      linkURL: json['linkURL']?.toString(),
      pinned: json['pinned']?.toString(),
      order: asInt(json['order']),
      isClickable: json['isClickable'] as bool? ?? false,
      hasValueChanger: json['hasValueChanger'] as bool? ?? false,
    );
  }
}

/// One entry from `GetNewFilter` - a field the list screen can filter on.
class FilterFieldDef {
  final String key;
  final String type;
  final String description;

  const FilterFieldDef({required this.key, required this.type, required this.description});
}

class BammCatalogueClient {
  final BammHttpTransport transport;
  final BammConfig config;
  final BammLookupsClient lookups;

  BammCatalogueClient(this.transport, this.config, {BammLookupsClient? lookups})
      : lookups = lookups ?? BammLookupsClient(transport, config);

  /// All grid columns known to BAMM.
  /// `GET/POST /api/dynamicScreen/GetListConfigurationStructure`.
  Future<List<ColumnDef>> columns() async {
    final result = await transport.get(
      '/api/dynamicScreen/GetListConfigurationStructure',
      params: {'programId': '1', 'webGridId': '0'},
      referer: '/',
      operation: 'Column catalogue',
    );
    final value = (result is Map) ? result['value'] : null;
    final available = (value is Map) ? value['availableFields'] : null;
    if (available is! List) {
      throw const BammCatalogueException('Column catalogue response has no availableFields list');
    }
    return available.whereType<Map<String, dynamic>>().map(ColumnDef.fromJson).toList();
  }

  /// All filter fields the list screen offers.
  /// `GET/POST /api/dynamicScreen/GetNewFilter` - the response embeds an XML
  /// document as a string inside the JSON envelope.
  Future<List<FilterFieldDef>> filters() async {
    final result = await transport.get(
      '/api/dynamicScreen/GetNewFilter',
      referer: '/',
      operation: 'Filter catalogue',
    );
    final value = (result is Map) ? result['value'] : null;
    final xmlText = (value is Map) ? value['value']?.toString() : null;
    if (xmlText == null || xmlText.isEmpty) {
      throw const BammCatalogueException('Filter catalogue response has no XML payload');
    }
    return _parseFilterXml(xmlText);
  }

  List<FilterFieldDef> _parseFilterXml(String xmlText) {
    final xml.XmlDocument doc;
    try {
      doc = xml.XmlDocument.parse(xmlText);
    } on xml.XmlException catch (e) {
      throw BammCatalogueException('Filter catalogue XML is malformed: $e');
    }

    String? attrOrChildText(xml.XmlElement el, String attr, String childTag) {
      final attrValue = el.getAttribute(attr);
      if (attrValue != null && attrValue.isNotEmpty) return attrValue;
      final children = el.findElements(childTag);
      if (children.isEmpty) return null;
      final text = children.first.innerText.trim();
      return text.isEmpty ? null : text;
    }

    final out = <FilterFieldDef>[];
    for (final el in doc.findAllElements('Filter')) {
      final key = attrOrChildText(el, 'key', 'Key');
      if (key == null) continue;
      out.add(FilterFieldDef(
        key: key,
        type: attrOrChildText(el, 'type', 'Type') ?? 'Text',
        description: attrOrChildText(el, 'description', 'Description') ?? '',
      ));
    }
    return out;
  }

  /// The live property descriptors of a blank Work Order (210 fields) - a
  /// "field catalogue" fetched fresh via `GetNew` rather than the bundled
  /// `samples/wo_field_catalog.json`.
  Future<List<DynamicDtoProperty>> fieldCatalogue() async {
    final result = await transport.get(
      '/api/WorkOrder/GetNew',
      params: {'spwId': config.spwId.toString(), 'assetId': '', 'workOrderHeaderId': ''},
      referer: '/workorder/detail/0',
      operation: 'Field catalogue',
    );
    final value = (result is Map) ? result['value'] : null;
    if (value is! Map<String, dynamic>) {
      throw const BammCatalogueException('GetNew response has no model');
    }
    return DynamicDto.fromJson(value).properties;
  }

  /// `PRI_ID` options - the priority lookup.
  Future<List<LookupOption>> priority() async => (await lookups.priority()).items;

  /// One grouping slot's options (`WGM_ID`); `type` selects the slot.
  Future<List<LookupOption>> groupings(int type) async => (await lookups.groupings(type)).items;
}
