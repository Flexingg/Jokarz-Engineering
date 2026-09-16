/// Raw-map mutation helpers for the Cogep DynamicDTO shape - the write-side
/// counterpart to `dto/dynamic_dto.dart`, which only ever reads.
///
/// `DynamicDto` is immutable by design (see its doc comment: "the write-side
/// normalisation ... belongs to a later mutations batch"), so mutating this
/// shape means operating on the same `Map<String, dynamic>` the wire uses -
/// mirroring `~/repos/BAMM/app/bamm/dto.py`'s free functions on dicts. A
/// class wrapper here would just be another place a value could drift out of
/// sync with what actually gets JSON-encoded and sent.
library;

import 'dart:convert';

import '../dto/dynamic_dto.dart'
    show
        defaultStateForType,
        editablePropertyTypes,
        stateChanged,
        stateNew,
        stateUnchanged;
import 'dates.dart';
import 'exceptions.dart';

// Re-exported so callers of the write-side helpers (writer.dart, fields.dart,
// and their tests) have one import for both the read-side policy constants
// and the write-side mutation functions, instead of reaching into
// dto/dynamic_dto.dart separately for state/type constants.
export '../dto/dynamic_dto.dart'
    show
        defaultStateForType,
        editablePropertyTypes,
        metaPropertyType,
        protectedFields,
        stateChanged,
        stateDeleted,
        stateNew,
        stateUnchanged;

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// A deep copy safe to mutate independently of [source] - used to clone a
/// childSet's `itemPrototype` into a fresh item.
Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

// ---------------------------------------------------------------------------
// Reading (case-insensitive, same as dynamic_dto.dart's read side)
// ---------------------------------------------------------------------------

Map<String, dynamic>? findProperty(Map<String, dynamic> model, String name) {
  final wanted = name.trim().toUpperCase();
  final props = model['properties'];
  if (props is! List) return null;
  for (final p in props) {
    if (p is Map<String, dynamic> && (p['name']?.toString() ?? '').trim().toUpperCase() == wanted) {
      return p;
    }
  }
  return null;
}

String? propertyValue(Map<String, dynamic> model, String name) =>
    findProperty(model, name)?['value']?.toString();

Map<String, dynamic>? findChildSet(Map<String, dynamic> model, String originProperty) {
  final wanted = originProperty.trim().toUpperCase();
  final sets = model['childSets'];
  if (sets is! List) return null;
  for (final cs in sets) {
    if (cs is Map<String, dynamic> && (cs['originProperty']?.toString() ?? '').trim().toUpperCase() == wanted) {
      return cs;
    }
  }
  return null;
}

List<Map<String, dynamic>> childItems(Map<String, dynamic> model, String originProperty) {
  final items = findChildSet(model, originProperty)?['items'];
  if (items is! List) return const [];
  return items.whereType<Map<String, dynamic>>().toList();
}

/// Derives `WORK_ORDER` from `Cogep.BusinessLogic.WORK_ORDER, Cogep..., Version=...`.
String shortTypeNameOf(Map<String, dynamic> node) {
  final existing = (node['shortTypeName']?.toString() ?? '').trim();
  if (existing.isNotEmpty) return existing;
  final typeName = (node['typeName']?.toString() ?? '').trim();
  if (typeName.isEmpty) {
    throw const BammModelException('BAMM model is missing typeName');
  }
  final className = typeName.split(',').first.trim();
  final short = className.contains('.') ? className.split('.').last.trim() : className;
  if (short.isEmpty) {
    throw BammModelException('Could not derive shortTypeName from "$typeName"');
  }
  return short;
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/// Sets a root property's value in place and flags it changed for the
/// server. Throws [BammModelException] if [name] is not on this model - a
/// mismatch between what the caller expects and what BAMM actually sent,
/// discovered only after a read.
Map<String, dynamic> setProperty(
  Map<String, dynamic> model,
  String name,
  String? value, {
  bool markChanged = true,
}) {
  final prop = findProperty(model, name);
  if (prop == null) {
    throw BammModelException('Property "$name" is not on this model');
  }
  prop['value'] = value;
  if (markChanged) prop['state'] = stateChanged;
  return prop;
}

/// Clones a child set's `itemPrototype` into a ready-to-fill new item, with
/// its key property zeroed and marked changed (the server assigns the real
/// id on save).
Map<String, dynamic> newChildItem(Map<String, dynamic> model, String originProperty) {
  final childSet = findChildSet(model, originProperty);
  if (childSet == null) {
    throw BammModelException('No child set "$originProperty" on this model');
  }
  final prototype = childSet['itemPrototype'];
  if (prototype is! Map<String, dynamic>) {
    throw BammModelException('Child set "$originProperty" has no usable itemPrototype');
  }
  final item = deepCopyMap(prototype);
  item['state'] ??= stateNew;
  item['isNull'] ??= false;
  item['forceEmpty'] ??= false;
  item['shortTypeName'] ??= shortTypeNameOf(item);

  final keyName = (childSet['itemKeyProperty']?.toString() ?? '').trim().toUpperCase();
  final keyProp = findProperty(item, keyName);
  if (keyProp != null) {
    keyProp['value'] = '0';
    keyProp['state'] = stateChanged;
  }
  return item;
}

Map<String, dynamic> _normalizePropertyForSave(Map<String, dynamic> prop) {
  final name = prop['name'];
  if (name == null || name.toString().isEmpty) {
    throw const BammModelException('Property has no name');
  }
  final type = _asInt(prop['type'], 0);
  return {
    'name': name.toString(),
    'type': type,
    'value': prop['value'],
    'state': _asInt(prop['state'], defaultStateForType(type)),
  };
}

/// `normalize_model_for_save` for a nested model (childSet item or `childs[]`
/// entry): `originProperty` and nested `childs`/`childSets` are carried
/// through unconditionally, with no fallback to a sibling's value. Dropping
/// `originProperty` on a `childs[]` entry is what produced real HTTP 599s in
/// the Python reference (see docs/02) - it is preserved here whenever present,
/// exactly as the reference does, even though it is optional on childSet items.
Map<String, dynamic> normalizeRecursive(Map<String, dynamic> node) {
  final out = <String, dynamic>{
    'typeName': node['typeName'],
    'shortTypeName': shortTypeNameOf(node),
    'state': _asInt(node['state'], stateChanged),
    'isNull': node['isNull'] == true,
    'forceEmpty': node['forceEmpty'] == true,
    'properties': (node['properties'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_normalizePropertyForSave)
        .toList(),
  };
  if (node['guid'] != null) out['guid'] = node['guid'];
  if (node['originProperty'] != null) out['originProperty'] = node['originProperty'];
  out['childSets'] = (node['childSets'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((cs) => {
            'originProperty': cs['originProperty'],
            'itemKeyProperty': cs['itemKeyProperty'],
            'items': (cs['items'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(normalizeRecursive)
                .toList(),
            'deletedItems': (cs['deletedItems'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(normalizeRecursive)
                .toList(),
          })
      .toList();
  out['childs'] =
      (node['childs'] as List? ?? const []).whereType<Map<String, dynamic>>().map(normalizeRecursive).toList();
  return out;
}

/// Converts a `GetById`/`GetNew` model into the compact shape
/// `/WorkOrder/Save` wants. Deliberately returns a *copy*: [model] is left
/// untouched.
Map<String, dynamic> normalizeModelForSave(Map<String, dynamic> model) {
  final typeName = model['typeName'];
  final props = model['properties'];
  if (typeName == null || props is! List) {
    throw const BammModelException('Value is not a BAMM model');
  }
  final out = <String, dynamic>{
    'typeName': typeName,
    'shortTypeName': shortTypeNameOf(model),
    'state': _asInt(model['state'], stateChanged),
    'isNull': model['isNull'] == true,
    'forceEmpty': model['forceEmpty'] == true,
    'properties': props.whereType<Map<String, dynamic>>().map(_normalizePropertyForSave).toList(),
  };
  if (model['guid'] != null) out['guid'] = model['guid'];

  final childSetsOut = <Map<String, dynamic>>[];
  final childSets = model['childSets'];
  if (childSets is List) {
    for (final cs in childSets) {
      if (cs is! Map<String, dynamic>) continue;
      final entry = <String, dynamic>{
        'originProperty': cs['originProperty'],
        'itemKeyProperty': cs['itemKeyProperty'],
        'items': (cs['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(normalizeRecursive)
            .toList(),
        'deletedItems': (cs['deletedItems'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(normalizeRecursive)
            .toList(),
      };
      final prototype = cs['itemPrototype'];
      if (prototype is Map<String, dynamic>) {
        entry['itemPrototype'] = {
          'typeName': prototype['typeName'],
          'properties': (prototype['properties'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(_normalizePropertyForSave)
              .toList(),
        };
      }
      childSetsOut.add(entry);
    }
  }
  out['childSets'] = childSetsOut;
  out['childs'] =
      (model['childs'] as List? ?? const []).whereType<Map<String, dynamic>>().map(normalizeRecursive).toList();
  return out;
}

/// Every object in the payload must have a resolvable `shortTypeName` - BAMM
/// rejects unknown type names. Throws (via [shortTypeNameOf]) at the first
/// object that has neither `shortTypeName` nor a parseable `typeName`.
void validateShortTypeNames(Map<String, dynamic> model) {
  shortTypeNameOf(model);
  for (final cs in (model['childSets'] as List? ?? const [])) {
    if (cs is! Map<String, dynamic>) continue;
    for (final item in (cs['items'] as List? ?? const [])) {
      if (item is Map<String, dynamic>) validateShortTypeNames(item);
    }
  }
  for (final child in (model['childs'] as List? ?? const [])) {
    if (child is Map<String, dynamic>) validateShortTypeNames(child);
  }
}

/// Sanity-checks a model before it goes to `/WorkOrder/Save`.
void validateSaveModel(Map<String, dynamic> model, Object workOrderId) {
  final worId = propertyValue(model, 'WOR_ID');
  if (worId == null) {
    throw const BammModelException('Model has no WOR_ID property');
  }
  if (worId != workOrderId.toString()) {
    throw BammModelException('Model belongs to work order $worId, not $workOrderId');
  }
  final props = model['properties'];
  if (props is! List || props.isEmpty) {
    throw const BammModelException('Model has no properties');
  }
}

/// Names of root properties the payload marks as changed (`state !=
/// unchanged`). Handy when a Save fails, and used by tests to prove the
/// six-field whitelist never marks anything else changed.
List<String> changedPropertyNames(Map<String, dynamic> model) {
  final props = model['properties'];
  if (props is! List) return const [];
  return props
      .whereType<Map<String, dynamic>>()
      .where((p) => _asInt(p['state'], stateUnchanged) != stateUnchanged)
      .map((p) => p['name'].toString())
      .toList();
}

/// Validates/coerces user input to the wire string for a property of
/// [propertyType]. Throws [BammFieldValidationException] - an input error,
/// never a transport one - so callers can validate before any network call
/// happens (see `mutations/writer.dart` and `mutations/fields.dart`).
///
/// Mirrors `~/repos/BAMM/app/bamm/dto.py::coerce_value`, with one
/// intentional gap: decimal values (type 15) round-trip through Dart's
/// `num`, not an arbitrary-precision decimal, so a value like `"12.50"` may
/// come back as `"12.5"`. None of the six whitelisted fields are type 15, so
/// this batch does not need exact decimal fidelity; a later batch touching
/// activity-line hours should revisit it if that matters.
String? coerceForType(int propertyType, Object? submitted) {
  if (!editablePropertyTypes.contains(propertyType)) {
    throw BammFieldValidationException('Property type $propertyType is not editable');
  }
  if (submitted == null) return null;
  final text = submitted.toString().trim();
  if (text.isEmpty) return null;

  if (propertyType == 12 || propertyType == 13) {
    return ['1', 'true', 'yes', 'y', 'on'].contains(text.toLowerCase()) ? 'true' : 'false';
  }
  if (propertyType == 2 || propertyType == 3 || propertyType == 4 || propertyType == 18) {
    final n = int.tryParse(text);
    if (n == null) {
      throw BammFieldValidationException('Expected a whole number, got "$submitted"');
    }
    return n.toString();
  }
  if (propertyType == 15) {
    final n = num.tryParse(text);
    if (n == null) {
      throw BammFieldValidationException('Expected a number, got "$submitted"');
    }
    return n.toString();
  }
  if (propertyType == 27 || propertyType == 28) {
    return dateToEpochMs(text);
  }
  return text;
}

/// [coerceForType] for a live property map (as returned by [findProperty]).
String? coerceValue(Map<String, dynamic> prop, Object? submitted) =>
    coerceForType(_asInt(prop['type'], 0), submitted);
