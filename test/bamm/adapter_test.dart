import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/services/bamm_adapter.dart';

/// A verbatim (trimmed) copy of one row of `~/repos/BAMM/samples/list_row_sample.json`.
const Map<String, dynamic> _listRow = {
  'propertyList': {
    'workOrderId': 700203512,
    'worNoSeq': 'WO-143608.4',
    'functionInfo2': 'Cell 1',
    'functionCode': '700009868',
    'worEstLaborTime': 0.0,
    'worEstNbEmployee': 1,
    'woDescription': 'LR repair request',
    'woStatusDescription': 'Registered',
    'executionModeDescription': 'Down',
    'funCodeLevelNiv3Description': 'Filler A',
    'requesterName': 'Sample, Person',
    'recipientName': '',
    'worNumber3': null,
  }
};

/// A trimmed copy of the properties `~/repos/BAMM/samples/wo_getbyid_response.json`
/// actually carries for a real work order - notably it has no `WOR_NO_SEQ`,
/// `WOR_STATUS_DESC`, `WOR_STEP_DESC`, `functionInfo2`/`regrouping1Description`,
/// or `WOR_EST_LABOR_HOURS` properties at all: those are GetListData-only
/// display columns, absent from the raw DynamicDTO model.
const Map<String, dynamic> _getByIdModel = {
  'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
  'properties': [
    {'name': 'WOR_ID', 'value': '700203549', 'type': 4},
    {'name': 'WOR_NO', 'value': '185610', 'type': 4},
    {'name': 'WOR_DESCR', 'value': 'Test work order', 'type': 9},
    {'name': 'WOR_ISSUE_DATE', 'value': '1789153164263', 'type': 28},
    {'name': 'WOR_REQUI_DATE', 'value': null, 'type': 28},
    {'name': 'FUN_ID', 'value': '700010290', 'type': 4},
    {'name': 'MNT_ID', 'value': '107', 'type': 4},
  ],
  'childSets': <dynamic>[],
};

void main() {
  group('bammWorkOrderFromListRow', () {
    test('maps a GetListData row (propertyList-wrapped) into a BammWorkOrder', () {
      final wo = bammWorkOrderFromListRow(_listRow);

      expect(wo.worId, 700203512);
      expect(wo.worNoSeq, 'WO-143608.4');
      expect(wo.description, 'LR repair request');
      expect(wo.status, 'Registered');
      expect(wo.area, 'Cell 1');
      expect(wo.machine, 'Filler A');
      expect(wo.requester, 'Sample, Person');
      // Absent/empty on this row: responsible, priority.
      expect(wo.responsible, '');
      expect(wo.priority, '');
    });
  });

  group('bammWorkOrderFromModel', () {
    test('maps a real GetById model, including fields the DTO never carries', () {
      final wo = bammWorkOrderFromModel(_getByIdModel);

      expect(wo.worId, 700203549);
      // No WOR_NO_SEQ on the wire - falls back to WOR_NO.
      expect(wo.worNoSeq, '185610');
      expect(wo.description, 'Test work order');
      expect(wo.assetId, '700010290');
      // No WOR_STATUS_DESC/WOR_STEP_DESC on the wire - falls back to defaults.
      expect(wo.status, 'Registered');
      expect(wo.step, 'Normal');
      // No display columns (functionInfo2/regrouping1Description/etc.) on the
      // raw model - area/machine/responsible/requester are genuinely absent.
      expect(wo.area, '');
      expect(wo.machine, '');
      expect(wo.responsible, '');
      expect(wo.requester, '');
      // A null property value must not be misread as a date.
      expect(wo.requiredDate, isNull);
      expect(wo.issueDate, isNotNull);
    });
  });

  group('bammLookupItemsFromOptions', () {
    test('maps LookupOption results (as GetGrouping1 returns) into BammLookupItem', () {
      const options = [
        LookupOption(id: '700000000', label: '100', code: '', inactive: false),
        LookupOption(id: '700000015', label: 'Cell 1', code: '', inactive: false),
      ];

      final items = bammLookupItemsFromOptions(options);

      expect(items, hasLength(2));
      // id must round-trip as an int: callers compare it against int filter ids.
      expect(items[0].id, 700000000);
      expect(items[0].description, '100');
      expect(items[1].id, 700000015);
      expect(items[1].description, 'Cell 1');
    });

    test('falls back to the raw string id when a lookup id is not numeric', () {
      const option = LookupOption(id: 'NOT_NUMERIC', label: 'Odd', code: '', inactive: false);
      final item = bammLookupItemFromOption(option);
      expect(item.id, 'NOT_NUMERIC');
    });
  });
}
