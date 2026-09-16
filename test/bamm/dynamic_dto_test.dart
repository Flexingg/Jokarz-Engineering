import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/dto/dynamic_dto.dart';

/// Loads a fixture that is a trimmed, otherwise-verbatim excerpt of the real
/// `~/repos/BAMM/samples/wo_getnew_response.json` capture.
Map<String, dynamic> _loadFixture(String name) {
  final file = File('test/bamm/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('DynamicDto.fromJson (real captured shape)', () {
    late Map<String, dynamic> fixture;
    late DynamicDto dto;

    setUp(() {
      fixture = _loadFixture('wo_getnew_excerpt.json');
      dto = DynamicDto.fromJson(fixture);
    });

    test('parses the envelope', () {
      expect(dto.typeName, contains('WORK_ORDER'));
      expect(dto.state, 3);
      expect(dto.guid, isNotNull);
      expect(dto.properties, hasLength(12));
    });

    test('resolveShortTypeName derives WORK_ORDER from typeName', () {
      expect(dto.resolveShortTypeName(), 'WORK_ORDER');
    });

    test('findProperty is case-insensitive and returns the raw string value', () {
      final prop = dto.findProperty('wor_id');
      expect(prop, isNotNull);
      expect(prop!.value, '0');
      expect(dto.propertyValue('WOR_ID'), '0');
    });

    test('a property with no value on the wire has a null value, not a guessed default', () {
      final prop = dto.findProperty('InterventionComment');
      expect(prop, isNotNull);
      expect(prop!.value, isNull);
    });

    test('a childSet item does NOT require originProperty', () {
      final childSet = dto.findChildSet('WO_DETAIL');
      expect(childSet, isNotNull);
      expect(childSet!.itemKeyProperty, 'WOD_ID');
      // The itemPrototype is itself a DynamicDto, parsed without complaint
      // even though it carries no originProperty.
      expect(childSet.itemPrototype, isNotNull);
      expect(childSet.itemPrototype!.properties, isNotEmpty);
    });

    test('an unknown property/child set lookup returns null, not a throw', () {
      expect(dto.findProperty('NOT_A_REAL_FIELD'), isNull);
      expect(dto.findChildSet('NOT_A_REAL_CHILD_SET'), isNull);
    });
  });

  group('date coercion (epoch-millisecond strings)', () {
    test('a real captured date value parses to the correct DateTime', () {
      final dto = DynamicDto.fromJson(_loadFixture('wo_getnew_excerpt.json'));
      final prop = dto.findProperty('WOR_MODIF_DATE')!;
      expect(prop.value, '1789125335852');
      final parsed = prop.dateValue;
      expect(parsed, DateTime.fromMillisecondsSinceEpoch(1789125335852));
    });

    test('a missing value has no date - dateValueOrNull returns null', () {
      final dto = DynamicDto.fromJson(_loadFixture('wo_getnew_excerpt.json'));
      final prop = dto.findProperty('WOR_PLAN_DATE')!;
      expect(prop.value, isNull);
      expect(prop.dateValueOrNull, isNull);
    });

    test('dateValue on a property with no value throws instead of returning null', () {
      final dto = DynamicDto.fromJson(_loadFixture('wo_getnew_excerpt.json'));
      final prop = dto.findProperty('WOR_PLAN_DATE')!;
      expect(() => prop.dateValue, throwsA(isA<DynamicDtoException>()));
    });

    test('a malformed date string throws rather than silently becoming null', () {
      final malformed = DynamicDtoProperty.fromJson({
        'name': 'WOR_REQUI_DATE',
        'type': 28,
        'value': 'not-a-timestamp',
      });
      expect(() => malformed.dateValue, throwsA(isA<DynamicDtoException>()));
      expect(() => malformed.dateValueOrNull, throwsA(isA<DynamicDtoException>()));
    });
  });

  group('originProperty is mandatory on childs[] entries but not on childSet items', () {
    test('a childs[] entry missing originProperty is rejected', () {
      final payload = {
        'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
        'state': 2,
        'properties': <Map<String, dynamic>>[],
        'childSets': <Map<String, dynamic>>[],
        'childs': [
          {
            // Missing originProperty - this is exactly what produced a
            // "Value cannot be null. Parameter name: name" HTTP 599 live.
            'typeName': 'Cogep.BusinessLogic.WORK_ORDER_HEADER, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOH_ID', 'type': 3, 'value': '700195851'},
            ],
          }
        ],
      };

      expect(
        () => DynamicDto.fromJson(payload),
        throwsA(isA<DynamicDtoException>()),
      );
    });

    test('a childs[] entry WITH originProperty parses fine', () {
      final payload = {
        'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
        'state': 2,
        'properties': <Map<String, dynamic>>[],
        'childSets': <Map<String, dynamic>>[],
        'childs': [
          {
            'originProperty': 'WORK_ORDER_HEADER',
            'typeName': 'Cogep.BusinessLogic.WORK_ORDER_HEADER, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOH_ID', 'type': 3, 'value': '700195851'},
            ],
          }
        ],
      };

      final dto = DynamicDto.fromJson(payload);
      expect(dto.childs, hasLength(1));
      expect(dto.childs.first.propertyValue('WOH_ID'), '700195851');
    });

    test('a childSet item missing originProperty parses fine (real payloads omit it)', () {
      final payload = {
        'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
        'state': 2,
        'properties': <Map<String, dynamic>>[],
        'childs': <Map<String, dynamic>>[],
        'childSets': [
          {
            'originProperty': 'WO_DETAIL',
            'itemKeyProperty': 'WOD_ID',
            'items': [
              {
                // No originProperty on the item itself - matches the real
                // wire shape; must not be rejected.
                'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
                'properties': [
                  {'name': 'WOD_ID', 'type': 3, 'value': '5001'},
                ],
              }
            ],
            'deletedItems': <Map<String, dynamic>>[],
          }
        ],
      };

      final dto = DynamicDto.fromJson(payload);
      final childSet = dto.findChildSet('WO_DETAIL')!;
      expect(childSet.items, hasLength(1));
      expect(childSet.items.first.propertyValue('WOD_ID'), '5001');
    });
  });

  group('DynamicDtoProperty.fromJson', () {
    test('a property with no name is rejected', () {
      expect(
        () => DynamicDtoProperty.fromJson({'type': 9, 'value': 'x'}),
        throwsA(isA<DynamicDtoException>()),
      );
    });

    test('effectiveState defaults to unchanged, except type-23 metadata which defaults to deleted', () {
      final ordinary = DynamicDtoProperty.fromJson({'name': 'WOR_DESCR', 'type': 9, 'value': 'x'});
      expect(ordinary.state, isNull);
      expect(ordinary.effectiveState, stateUnchanged);

      final metadata = DynamicDtoProperty.fromJson({'name': 'ActivityLineMetadata', 'type': 23});
      expect(metadata.state, isNull);
      expect(metadata.effectiveState, stateDeleted);

      final explicit = DynamicDtoProperty.fromJson({'name': 'WOR_DESCR', 'type': 9, 'value': 'x', 'state': 2});
      expect(explicit.effectiveState, stateChanged);
    });
  });

  group('resolveShortTypeName', () {
    test('prefers an explicit shortTypeName when present', () {
      final dto = DynamicDto.fromJson({
        'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
        'shortTypeName': 'WORK_ORDER',
        'properties': <Map<String, dynamic>>[],
        'childSets': <Map<String, dynamic>>[],
        'childs': <Map<String, dynamic>>[],
      });
      expect(dto.resolveShortTypeName(), 'WORK_ORDER');
    });

    test('throws when neither shortTypeName nor typeName is present', () {
      final dto = DynamicDto.fromJson({
        'properties': <Map<String, dynamic>>[],
        'childSets': <Map<String, dynamic>>[],
        'childs': <Map<String, dynamic>>[],
      });
      expect(() => dto.resolveShortTypeName(), throwsA(isA<DynamicDtoException>()));
    });
  });
}
