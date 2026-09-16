import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/mutations/exceptions.dart';
import 'package:jokarz_engineering/bamm/mutations/model_ops.dart';

Map<String, dynamic> _sampleModel() => {
      'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic, Version=6.9.4.12',
      'guid': 'a-guid',
      'state': 1,
      'properties': [
        {'name': 'WOR_ID', 'type': 3, 'value': '700100', 'state': 1},
        {'name': 'WOR_DESCR', 'type': 9, 'value': 'old description'},
        {'name': 'MultiGrouping1', 'type': 23}, // no explicit state -> defaults to deleted (0)
      ],
      'childSets': [
        {
          'originProperty': 'WO_DETAIL',
          'itemKeyProperty': 'WOD_ID',
          'itemPrototype': {
            'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOD_ID', 'type': 3, 'value': '0'},
              {'name': 'WOD_DESCR', 'type': 9},
            ],
          },
          'items': [],
          'deletedItems': [],
        },
      ],
      'childs': [],
    };

void main() {
  group('findProperty / propertyValue / setProperty', () {
    test('findProperty is case-insensitive', () {
      final model = _sampleModel();
      expect(findProperty(model, 'wor_descr'), isNotNull);
      expect(propertyValue(model, 'WOR_DESCR'), 'old description');
    });

    test('setProperty mutates the value in place and marks it changed', () {
      final model = _sampleModel();
      setProperty(model, 'WOR_DESCR', 'new description');
      expect(propertyValue(model, 'WOR_DESCR'), 'new description');
      expect(findProperty(model, 'WOR_DESCR')!['state'], stateChanged);
    });

    test('setProperty throws for a property that is not on the model', () {
      final model = _sampleModel();
      expect(() => setProperty(model, 'NOT_REAL', 'x'), throwsA(isA<BammModelException>()));
    });
  });

  group('newChildItem', () {
    test('clones the prototype with the key zeroed and marked changed', () {
      final model = _sampleModel();
      final item = newChildItem(model, 'WO_DETAIL');
      expect(item['state'], stateNew);
      expect(item['isNull'], isFalse);
      expect(item['shortTypeName'], 'WO_DETAIL');
      final key = findProperty(item, 'WOD_ID')!;
      expect(key['value'], '0');
      expect(key['state'], stateChanged);
    });

    test('throws for a child set that does not exist', () {
      final model = _sampleModel();
      expect(() => newChildItem(model, 'NOT_A_SET'), throwsA(isA<BammModelException>()));
    });
  });

  group('normalizeModelForSave', () {
    test('a missing property state defaults to unchanged, except type 23 which defaults to deleted', () {
      final normalized = normalizeModelForSave(_sampleModel());
      final props = {for (final p in (normalized['properties'] as List).cast<Map>()) p['name']: p};
      expect(props['WOR_DESCR']!['state'], stateUnchanged);
      expect(props['MultiGrouping1']!['state'], stateDeleted);
    });

    test('does not mutate the original model', () {
      final model = _sampleModel();
      normalizeModelForSave(model);
      expect(findProperty(model, 'WOR_DESCR')!.containsKey('state'), isFalse);
    });

    test('derives shortTypeName from typeName when absent', () {
      final normalized = normalizeModelForSave(_sampleModel());
      expect(normalized['shortTypeName'], 'WORK_ORDER');
    });

    test('echoes childSets with items and an explicit empty deletedItems', () {
      final normalized = normalizeModelForSave(_sampleModel());
      final childSets = normalized['childSets'] as List;
      expect(childSets, hasLength(1));
      expect(childSets.first['originProperty'], 'WO_DETAIL');
      expect(childSets.first['deletedItems'], isEmpty);
    });

    test('throws for a value that is not a BAMM model', () {
      expect(() => normalizeModelForSave({'not': 'a model'}), throwsA(isA<BammModelException>()));
    });
  });

  group('validateShortTypeNames / validateSaveModel', () {
    test('passes for a well-formed model', () {
      expect(() => validateShortTypeNames(normalizeModelForSave(_sampleModel())), returnsNormally);
    });

    test('validateSaveModel throws when WOR_ID is missing', () {
      final model = _sampleModel();
      (model['properties'] as List).removeWhere((p) => p['name'] == 'WOR_ID');
      expect(() => validateSaveModel(model, 700100), throwsA(isA<BammModelException>()));
    });

    test('validateSaveModel throws when the model belongs to a different work order', () {
      final model = _sampleModel();
      expect(() => validateSaveModel(model, 999999), throwsA(isA<BammModelException>()));
    });
  });

  group('changedPropertyNames', () {
    test('reports only properties explicitly marked changed', () {
      final model = _sampleModel();
      setProperty(model, 'WOR_DESCR', 'edited');
      expect(changedPropertyNames(model), ['WOR_DESCR']);
    });
  });

  group('coerceForType', () {
    test('rejects a property type that is not editable', () {
      expect(() => coerceForType(14, '1'), throwsA(isA<BammFieldValidationException>()));
    });

    test('type 9 (text) accepts any non-empty string', () {
      expect(coerceForType(9, 'hello world'), 'hello world');
    });

    test('whole-number types (2/3/4/18) accept an integer and reject a non-numeric string', () {
      for (final type in [2, 3, 4, 18]) {
        expect(coerceForType(type, '42'), '42');
        expect(() => coerceForType(type, 'not-a-number'), throwsA(isA<BammFieldValidationException>()));
      }
    });

    test('boolean types (12/13) normalise common truthy/falsy spellings', () {
      expect(coerceForType(12, 'yes'), 'true');
      expect(coerceForType(12, '0'), 'false');
      expect(coerceForType(13, 'On'), 'true');
    });

    test('decimal type (15) accepts a number and rejects garbage', () {
      expect(coerceForType(15, '12.5'), '12.5');
      expect(() => coerceForType(15, 'abc'), throwsA(isA<BammFieldValidationException>()));
    });

    test('date types (27/28) convert via the same UTC-pinned rules as dates.dart', () {
      expect(coerceForType(28, '2026-01-01'), DateTime.utc(2026, 1, 1).millisecondsSinceEpoch.toString());
      expect(() => coerceForType(27, 'not-a-date'), throwsA(isA<BammFieldValidationException>()));
    });

    test('null or empty input yields null (no value), not an error', () {
      expect(coerceForType(9, null), isNull);
      expect(coerceForType(9, ''), isNull);
      expect(coerceForType(9, '   '), isNull);
    });
  });
}
