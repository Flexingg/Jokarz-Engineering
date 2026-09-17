import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
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
    'funCodeLevelNiv4Description': 'Fill Head 3',
    'requesterName': 'Sample, Person',
    'recipientName': '',
    'worNumber3': null,
  }
};

/// A trimmed copy of the properties `~/repos/BAMM/samples/wo_getbyid_response.json`
/// actually carries for a real work order - notably it has no `WOR_NO_SEQ`,
/// `WOR_STATUS_DESC`, `WOR_STEP_DESC`, `functionInfo2`/`regrouping1Description`,
/// or `WOR_EST_LABOR_HOURS` properties at all: those are GetListData-only
/// display columns, absent from the raw DynamicDTO model. It DOES carry the
/// enumerated `WOS_ID`/`WSP_ID` ids (8 = Registered, 3 = Emergency per
/// `~/repos/BAMM/docs/06-field-reference.md`) and the raw `WOR_NB_3` decimal.
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
    {'name': 'WOS_ID', 'value': '8', 'type': 4},
    {'name': 'WSP_ID', 'value': '3', 'type': 4},
    {'name': 'WOR_NB_3', 'value': '6.0000000', 'type': 15},
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
      expect(wo.assembly, 'Fill Head 3');
      expect(wo.requester, 'Sample, Person');
      // Absent/empty on this row: responsible, priority.
      expect(wo.responsible, '');
      expect(wo.priority, '');
    });

    test('prefers funCodeLevelNiv1Description ("1st level - description", the real Area) over the older fallbacks', () {
      final row = {
        'propertyList': {
          ..._listRow['propertyList'] as Map<String, dynamic>,
          'funCodeLevelNiv1Description': 'North Wing',
        },
      };
      final wo = bammWorkOrderFromListRow(row);
      expect(wo.area, 'North Wing', reason: 'funCodeLevelNiv1Description must win over functionInfo2');
    });

    test('falls back to functionInfo2 when funCodeLevelNiv1Description is absent', () {
      // _listRow carries no funCodeLevelNiv1Description - proves the old
      // source still works so nothing that works today breaks.
      final wo = bammWorkOrderFromListRow(_listRow);
      expect(wo.area, 'Cell 1');
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
      // No WOR_STATUS_DESC/WOR_STEP_DESC on the wire - the enumerated ids
      // (WOS_ID/WSP_ID) are captured, but the label is left BLANK rather
      // than a plausible-looking hardcoded default ("Registered"/"Normal")
      // - resolving the real label needs a live lookup, which this pure
      // mapping factory has no access to (see resolveWorkOrderLabels below).
      expect(wo.statusId, 8);
      expect(wo.status, '');
      expect(wo.stepId, 3);
      expect(wo.step, '');
      // BAMM sends decimals as "6.0000000" - trimmed for display.
      expect(wo.priority, '6');
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

    test('prefers funCodeLevelNiv1Description over regrouping1Description for area when a model somehow carries both', () {
      // Neither property is ever actually present on a real GetById
      // response (see the doc comment on `_getByIdModel` above) - this is a
      // pure priority-ordering proof of `BammWorkOrder.fromDynamicDto`, not a
      // claim about what BAMM sends.
      final model = {
        'properties': [
          ...(_getByIdModel['properties'] as List<dynamic>),
          {'name': 'funCodeLevelNiv1Description', 'value': 'North Wing', 'type': 9},
          {'name': 'regrouping1Description', 'value': 'Old Area Name', 'type': 9},
        ],
        'childSets': <dynamic>[],
      };
      final wo = bammWorkOrderFromModel(model);
      expect(wo.area, 'North Wing');
    });

    test('falls back to regrouping1Description when funCodeLevelNiv1Description is absent', () {
      final model = {
        'properties': [
          ...(_getByIdModel['properties'] as List<dynamic>),
          {'name': 'regrouping1Description', 'value': 'Old Area Name', 'type': 9},
        ],
        'childSets': <dynamic>[],
      };
      final wo = bammWorkOrderFromModel(model);
      expect(wo.area, 'Old Area Name');
    });
  });

  group('resolveWorkOrderLabels', () {
    test('resolves status/step labels from live lookup ids, not a hardcoded guess', () {
      final wo = bammWorkOrderFromModel(_getByIdModel); // statusId 8, stepId 3
      final resolved = resolveWorkOrderLabels(
        wo,
        statusLookups: const [
          BammLookupItem(id: 1, description: 'In preparation'),
          BammLookupItem(id: 8, description: 'Registered'),
        ],
        stepLookups: const [
          BammLookupItem(id: 3, description: 'Emergency'),
          BammLookupItem(id: 5, description: 'Planned Work'),
        ],
      );

      expect(resolved.status, 'Registered');
      expect(resolved.step, 'Emergency');
      // The ids themselves are untouched by resolution.
      expect(resolved.statusId, 8);
      expect(resolved.stepId, 3);
    });

    test('falls back to showing the raw id - not a wrong label - when the lookup has no match', () {
      final wo = bammWorkOrderFromModel(_getByIdModel);
      final resolved = resolveWorkOrderLabels(wo, statusLookups: const [], stepLookups: const []);

      expect(resolved.status, '8');
      expect(resolved.step, '3');
    });

    test('blank when there is no id at all', () {
      final wo = BammWorkOrder(worId: 1, worNoSeq: '1', description: '');
      final resolved = resolveWorkOrderLabels(wo, statusLookups: const [], stepLookups: const []);

      expect(resolved.status, '');
      expect(resolved.step, '');
    });
  });

  group('BammWorkOrder.mergeDetail', () {
    // The exact regression the user hit: opening/editing a work order wrote
    // a GetById-derived model straight over the list row, destroying the
    // list-only display columns (formatted WO#, area, machine, responsible,
    // requester) that GetById structurally cannot carry.
    final listRow = BammWorkOrder(
      worId: 700203512,
      worNoSeq: 'WO-143608.4',
      description: 'LR repair request',
      status: 'Registered',
      statusId: 8,
      step: 'Emergency',
      stepId: 3,
      area: 'Cell 1',
      machine: 'Filler A',
      assembly: 'Fill Head 3',
      responsible: 'Doe, Jane',
      requester: 'Sample, Person',
      priority: '6',
      executionMode: 'Down',
    );

    test('keeps list-only display fields and patches through what the detail genuinely carries', () {
      final rawDetail = resolveWorkOrderLabels(
        bammWorkOrderFromModel(_getByIdModel).copyWith(worId: listRow.worId, description: 'LR repair request (edited)'),
        statusLookups: const [BammLookupItem(id: 8, description: 'Registered')],
        stepLookups: const [BammLookupItem(id: 3, description: 'Emergency')],
      );

      final merged = listRow.mergeDetail(rawDetail);

      // List-only fields survive - GetById never carried them, so the merge
      // must not blank them out.
      expect(merged.worNoSeq, 'WO-143608.4', reason: 'must not fall back to the bare WOR_NO');
      expect(merged.area, 'Cell 1');
      expect(merged.machine, 'Filler A');
      expect(merged.assembly, 'Fill Head 3');
      expect(merged.responsible, 'Doe, Jane');
      expect(merged.requester, 'Sample, Person');
      expect(merged.executionMode, 'Down');
      // Genuinely-carried detail fields patch through.
      expect(merged.description, 'LR repair request (edited)');
      expect(merged.status, 'Registered');
      expect(merged.step, 'Emergency');
      expect(merged.priority, '6');
    });

    test('tapping a row after an edit does not change its status/step/number/priority', () {
      // Simulates re-opening the same row: the detail fetch this time
      // resolves to blank labels (e.g. lookups not yet loaded) - the merge
      // must still not regress what the row already correctly showed.
      final unresolvedDetail = BammWorkOrder(
        worId: listRow.worId,
        worNoSeq: '143608', // GetById's bare WOR_NO, no "WO-x.y" form
        description: listRow.description,
        status: '',
        statusId: null,
        step: '',
        stepId: null,
        priority: '',
      );

      final merged = listRow.mergeDetail(unresolvedDetail);

      expect(merged.worNoSeq, listRow.worNoSeq);
      expect(merged.status, listRow.status);
      expect(merged.step, listRow.step);
      expect(merged.priority, listRow.priority);
    });
  });

  group('resolveLookupOption', () {
    const options = [
      LookupOption(id: '4123', label: 'Electrical', code: '', inactive: false),
      LookupOption(id: '9', label: 'Millwright', code: 'MW', inactive: false),
    ];

    test('resolves a raw id against the live options list into its real label', () {
      final resolved = resolveLookupOption('4123', options);
      expect(resolved?.label, 'Electrical');
    });

    test('falls back to an id-labelled placeholder - never a wrong label - when nothing matches', () {
      final resolved = resolveLookupOption('700000007', options);
      expect(resolved?.id, '700000007');
      expect(resolved?.label, 'id 700000007');
    });

    test('null/empty/"0" all mean "not set"', () {
      expect(resolveLookupOption(null, options), isNull);
      expect(resolveLookupOption('', options), isNull);
      expect(resolveLookupOption('0', options), isNull);
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
