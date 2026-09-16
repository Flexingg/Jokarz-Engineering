/// The Cogep DynamicDTO model - the one JSON shape every BAMM Work Order
/// endpoint speaks: an envelope with `properties[]` (the fields) and
/// `childSets[]`/`childs[]` (the child tables/models).
///
/// Modelled on `~/repos/BAMM/app/bamm/dto.py` and `~/repos/BAMM/docs/02-dynamicdto-model.md`.
/// This batch only needs to *read* the shape; the write-side normalisation
/// (`normalize_model_for_save` and friends) belongs to a later mutations batch.
library;

import '../src/json_helpers.dart';

class DynamicDtoException implements Exception {
  final String message;
  const DynamicDtoException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Policy constants (mirrored from dto.py)
// ---------------------------------------------------------------------------

/// Object-level / property-level states.
const int stateDeleted = 0;
const int stateUnchanged = 1;
const int stateChanged = 2;
const int stateNew = 3;

/// Property type that behaves as metadata - its default state is [stateDeleted],
/// not [stateUnchanged] (the derived "MultiGroupingN" display fields).
const int metaPropertyType = 23;

/// Property types the API accepts a write for.
const Set<int> editablePropertyTypes = {2, 3, 4, 9, 12, 13, 15, 18, 21, 27, 28};

/// Fields that identify the record or are server-managed. Never write these.
const Set<String> protectedFields = {
  'WOR_ID',
  'WOR_NO',
  'WOR_MODIF_DATE',
  'WOR_GLOBAL_ID',
  'COM_ID',
  'WOH_ID',
  'CANUSERMODIFY',
  'POOLCONTROL',
  'ISINITIALIZED',
};

int defaultStateForType(int propertyType) =>
    propertyType == metaPropertyType ? stateDeleted : stateUnchanged;

// ---------------------------------------------------------------------------
// properties[]
// ---------------------------------------------------------------------------

/// One scalar field on a DynamicDTO model. `value` always travels as a
/// string on the wire (even booleans and numbers); dates are epoch
/// milliseconds as a string.
class DynamicDtoProperty {
  final String name;
  final int type;
  final String? value;
  final int? state;
  final String? display;
  final bool? isRequired;
  final bool? isReadOnly;
  final bool? isVisible;
  final int? controlType;
  final int? programFieldId;
  final int? length;
  final int? decimalPlaces;

  const DynamicDtoProperty({
    required this.name,
    required this.type,
    this.value,
    this.state,
    this.display,
    this.isRequired,
    this.isReadOnly,
    this.isVisible,
    this.controlType,
    this.programFieldId,
    this.length,
    this.decimalPlaces,
  });

  /// GET responses omit `state` when it is null/default. This is what the
  /// value defaults to in that case - unchanged, except type-23 metadata
  /// properties, which default to deleted.
  int get effectiveState => state ?? defaultStateForType(type);

  /// Parses [value] as an epoch-millisecond date (property type 27/28).
  ///
  /// Returns null only when there genuinely is no value (the field is
  /// null/absent). A present-but-unparseable value throws instead of
  /// silently becoming null - a malformed date must be reported, not guessed.
  DateTime get dateValue => _parseDate(value, name);

  DateTime? get dateValueOrNull => value == null ? null : _parseDate(value, name);

  static DateTime _parseDate(String? raw, String propertyName) {
    if (raw == null) {
      throw DynamicDtoException('Property $propertyName has no value to parse as a date');
    }
    final ms = int.tryParse(raw);
    if (ms == null) {
      throw DynamicDtoException(
        'Property $propertyName is not a valid epoch-millisecond date: "$raw"',
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  factory DynamicDtoProperty.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    if (rawName == null || rawName.toString().isEmpty) {
      throw const DynamicDtoException('Property has no name');
    }
    return DynamicDtoProperty(
      name: rawName.toString(),
      type: asInt(json['type']) ?? 0,
      value: json['value']?.toString(),
      state: asInt(json['state']),
      display: json['display']?.toString(),
      isRequired: json['isRequired'] as bool?,
      isReadOnly: json['isReadOnly'] as bool?,
      isVisible: json['isVisible'] as bool?,
      controlType: asInt(json['controlType']),
      programFieldId: asInt(json['programFieldId']),
      length: asInt(json['length']),
      decimalPlaces: asInt(json['decimal']),
    );
  }
}

// ---------------------------------------------------------------------------
// childSets[]
// ---------------------------------------------------------------------------

/// One child table (activity lines, parts, files, ...). `items` and
/// `itemPrototype` are themselves full [DynamicDto] models, but - unlike
/// `childs[]` entries - they do NOT require `originProperty`: the real
/// payloads omit it on childSet items and BAMM accepts that.
class DynamicDtoChildSet {
  final String? originProperty;
  final String? itemKeyProperty;
  final DynamicDto? itemPrototype;
  final List<DynamicDto> items;
  final List<DynamicDto> deletedItems;

  const DynamicDtoChildSet({
    this.originProperty,
    this.itemKeyProperty,
    this.itemPrototype,
    required this.items,
    required this.deletedItems,
  });

  factory DynamicDtoChildSet.fromJson(Map<String, dynamic> json) {
    final prototypeJson = json['itemPrototype'];
    return DynamicDtoChildSet(
      originProperty: json['originProperty']?.toString(),
      itemKeyProperty: json['itemKeyProperty']?.toString(),
      itemPrototype: prototypeJson is Map<String, dynamic>
          ? DynamicDto._parse(prototypeJson, requireOriginProperty: false)
          : null,
      items: _parseItems(json['items']),
      deletedItems: _parseItems(json['deletedItems']),
    );
  }

  static List<DynamicDto> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => DynamicDto._parse(e, requireOriginProperty: false))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// The envelope
// ---------------------------------------------------------------------------

class DynamicDto {
  final String? typeName;
  final String? shortTypeName;
  final String? guid;
  final int? state;
  final bool isNull;
  final bool forceEmpty;
  final List<DynamicDtoProperty> properties;
  final List<DynamicDtoChildSet> childSets;
  final List<DynamicDto> childs;
  final List<dynamic> lookupItems;
  final List<dynamic> asyncViews;

  const DynamicDto({
    this.typeName,
    this.shortTypeName,
    this.guid,
    this.state,
    this.isNull = false,
    this.forceEmpty = false,
    required this.properties,
    required this.childSets,
    required this.childs,
    this.lookupItems = const [],
    this.asyncViews = const [],
  });

  /// Parses a top-level DynamicDTO envelope: a `GetNew`/`GetById` `value`, or
  /// a childSet item/prototype. `originProperty` is not required here.
  factory DynamicDto.fromJson(Map<String, dynamic> json) =>
      _parse(json, requireOriginProperty: false);

  /// Parses one entry of a `childs[]` array, where `originProperty` is
  /// mandatory: BAMM names the nested model from it, and a missing value is
  /// what caused real HTTP 599s in production (see docs/02). Rejects the
  /// payload instead of silently continuing without it.
  factory DynamicDto.fromNestedJson(Map<String, dynamic> json) =>
      _parse(json, requireOriginProperty: true);

  static DynamicDto _parse(Map<String, dynamic> json, {required bool requireOriginProperty}) {
    if (requireOriginProperty) {
      final op = json['originProperty'];
      if (op == null || op.toString().isEmpty) {
        throw const DynamicDtoException(
          'Nested model is missing originProperty (mandatory on childs[] entries - '
          'see docs/02-dynamicdto-model.md)',
        );
      }
    }

    final rawProps = json['properties'];
    final properties = rawProps is List
        ? rawProps.whereType<Map<String, dynamic>>().map(DynamicDtoProperty.fromJson).toList()
        : <DynamicDtoProperty>[];

    final rawChildSets = json['childSets'];
    final childSets = rawChildSets is List
        ? rawChildSets.whereType<Map<String, dynamic>>().map(DynamicDtoChildSet.fromJson).toList()
        : <DynamicDtoChildSet>[];

    final rawChilds = json['childs'];
    final childs = rawChilds is List
        ? rawChilds.whereType<Map<String, dynamic>>().map(DynamicDto.fromNestedJson).toList()
        : <DynamicDto>[];

    return DynamicDto(
      typeName: json['typeName']?.toString(),
      shortTypeName: json['shortTypeName']?.toString(),
      guid: json['guid']?.toString(),
      state: asInt(json['state']),
      isNull: json['isNull'] as bool? ?? false,
      forceEmpty: json['forceEmpty'] as bool? ?? false,
      properties: properties,
      childSets: childSets,
      childs: childs,
      lookupItems: (json['lookupItems'] as List?) ?? const [],
      asyncViews: (json['asyncViews'] as List?) ?? const [],
    );
  }

  /// Case-insensitive root-property lookup.
  DynamicDtoProperty? findProperty(String name) {
    final wanted = name.trim().toUpperCase();
    for (final p in properties) {
      if (p.name.trim().toUpperCase() == wanted) return p;
    }
    return null;
  }

  String? propertyValue(String name) => findProperty(name)?.value;

  DynamicDtoChildSet? findChildSet(String originProperty) {
    final wanted = originProperty.trim().toUpperCase();
    for (final cs in childSets) {
      if ((cs.originProperty ?? '').trim().toUpperCase() == wanted) return cs;
    }
    return null;
  }

  /// Derives `WORK_ORDER` from `Cogep.BusinessLogic.WORK_ORDER, Cogep..., Version=...`.
  String resolveShortTypeName() {
    final existing = shortTypeName?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final typeNameValue = typeName?.trim() ?? '';
    if (typeNameValue.isEmpty) {
      throw const DynamicDtoException('BAMM model is missing typeName');
    }
    final className = typeNameValue.split(',').first.trim();
    final short = className.contains('.') ? className.split('.').last.trim() : className;
    if (short.isEmpty) {
      throw DynamicDtoException('Could not derive shortTypeName from "$typeNameValue"');
    }
    return short;
  }
}
