/// The BAMM work-order write sequence:
/// `GetNew -> ValidateSelectedAsset -> Change* -> AddActivityLine -> Save ->
/// read back`, modelled on
/// `~/repos/BAMM/app/bamm/workorders.py::WorkOrderService` and
/// `~/repos/BAMM/docs/04-creating-a-work-order.md` /
/// `05-editing-a-work-order.md`.
///
/// Operates on raw `Map<String, dynamic>` models via `model_ops.dart` - the
/// read-side `DynamicDto` (`dto/dynamic_dto.dart`) is immutable by design and
/// was never meant to carry the write-side normalisation.
library;

import '../bamm_config.dart';
import '../transport/http_transport.dart';
import 'exceptions.dart';
import 'model_ops.dart'; // also re-exports protectedFields, stateNew, ... from dto/dynamic_dto.dart

class BammWorkOrderWriter {
  final BammHttpTransport transport;
  final BammConfig config;

  const BammWorkOrderWriter(this.transport, this.config);

  Map<String, dynamic> _valueObject(dynamic result, String failureMessage) {
    final value = (result is Map) ? result['value'] : null;
    if (value is! Map<String, dynamic>) {
      throw BammModelException(failureMessage);
    }
    return value;
  }

  /// `GET /api/WorkOrder/GetNew` - a blank work-order model.
  Future<Map<String, dynamic>> getNew({Object? assetId, Object? headerId}) async {
    final result = await transport.get(
      '/api/WorkOrder/GetNew',
      params: {
        'spwId': '${config.spwId}',
        'assetId': '${assetId ?? ''}',
        'workOrderHeaderId': '${headerId ?? ''}',
      },
      referer: '/workorder/detail/0',
      operation: 'New work-order model request',
    );
    return _valueObject(result, 'GetNew response has no value object');
  }

  /// `GET /api/WorkOrder/GetById`, plus the WOR_ID sanity check from docs/05:
  /// the retrieved model must actually belong to the id that was asked for.
  Future<Map<String, dynamic>> getById(Object workOrderId) async {
    final result = await transport.get(
      '/api/WorkOrder/GetById',
      params: {'id': '$workOrderId', 'spwId': '${config.spwId}'},
      referer: '/workorder/detail/$workOrderId',
      operation: 'Work-order detail request for $workOrderId',
    );
    final model = _valueObject(result, 'Work-order detail response has no value object');
    final worId = propertyValue(model, 'WOR_ID');
    if (worId != null && worId != workOrderId.toString()) {
      throw BammModelException('Retrieved model belongs to work order $worId, not $workOrderId');
    }
    return model;
  }

  /// Every `Change*`/`Validate*` call returns a replacement model: adopt it.
  /// Falls back to the model that was sent only when the response carries no
  /// usable replacement, exactly as the reference client does.
  Future<Map<String, dynamic>> _change(
    String path,
    Map<String, dynamic> model,
    Map<String, String> params,
    String operation,
  ) async {
    final result = await transport.post(
      path,
      jsonBody: model,
      params: params,
      referer: '/workorder/detail/0',
      contentType: kBammContentTypeDto,
      operation: operation,
    );
    final updated = (result is Map) ? result['value'] : null;
    return updated is Map<String, dynamic> ? updated : model;
  }

  Future<Map<String, dynamic>> validateSelectedAsset(Object assetId, Map<String, dynamic> model) => _change(
        '/api/WorkOrder/ValidateSelectedAsset',
        model,
        {'assetId': '$assetId'},
        'Validate asset $assetId',
      );

  Future<Map<String, dynamic>> changeFunctionCode(
    Object assetId,
    Map<String, dynamic> model, {
    Object? actionId,
    bool applyDefaultModel = true,
  }) =>
      _change(
        '/api/WorkOrder/ChangeFunctionCode',
        model,
        {
          'assetId': '$assetId',
          'actionId': '${actionId ?? ''}',
          'isApplyDefaultModel': applyDefaultModel ? 'true' : 'false',
        },
        'Change function code for asset $assetId',
      );

  Future<Map<String, dynamic>> changeModel(Object modelId, Map<String, dynamic> model) => _change(
        '/api/WorkOrder/ChangeModel',
        model,
        {'modelId': '$modelId'},
        'Change model $modelId',
      );

  Future<Map<String, dynamic>> changeRecipient(Object recipientId, Map<String, dynamic> model) => _change(
        '/api/WorkOrder/ChangeRecipient',
        model,
        {'recipientId': '$recipientId'},
        'Change recipient $recipientId',
      );

  Future<Map<String, dynamic>> changeMaintenanceType(Object maintenanceTypeId, Map<String, dynamic> model) => _change(
        '/api/WorkOrder/ChangeMaintenanceType',
        model,
        {'maintenanceTypeId': '$maintenanceTypeId'},
        'Change maintenance type $maintenanceTypeId',
      );

  Future<Map<String, dynamic>> changeSkill(Object skillId, Map<String, dynamic> model) => _change(
        '/api/WorkOrder/ChangeSkill',
        model,
        {'skillId': '$skillId'},
        'Change skill $skillId',
      );

  String _nextTempLineId(Map<String, dynamic> model, String keyName) {
    var lowest = 0;
    for (final item in childItems(model, 'WO_DETAIL')) {
      final candidate = int.tryParse(propertyValue(item, keyName) ?? '');
      if (candidate != null && candidate < lowest) lowest = candidate;
    }
    return (lowest - 1).toString();
  }

  /// `POST /api/WorkOrder/AddActivityLine` - asks the server for a fresh
  /// `WO_DETAIL` line, fills it from [fields] (BAMM property names -> raw
  /// values, coerced/validated per-field), appends it to [model] in place,
  /// and returns the appended item.
  Future<Map<String, dynamic>> addActivityLine(
    Map<String, dynamic> model, {
    Map<String, Object?>? fields,
  }) async {
    final result = await transport.post(
      '/api/WorkOrder/AddActivityLine',
      jsonBody: model,
      referer: '/workorder/detail/0',
      contentType: kBammContentTypeDto,
      operation: 'Add activity line',
    );
    var item = (result is Map) ? result['value'] : null;
    if (item is! Map<String, dynamic>) {
      item = newChildItem(model, 'WO_DETAIL');
    }
    item['state'] = stateNew;
    item['isNull'] = false;
    item['forceEmpty'] = false;

    final childSet = findChildSet(model, 'WO_DETAIL');
    if (childSet == null) {
      throw const BammModelException('This work order has no WO_DETAIL child set (activity lines)');
    }
    final keyName = (childSet['itemKeyProperty']?.toString() ?? 'WOD_ID').trim().toUpperCase();
    final keyProp = findProperty(item, keyName);
    if (keyProp != null) {
      keyProp['value'] = _nextTempLineId(model, keyName);
      keyProp['state'] = 2;
    }

    for (final entry in (fields ?? const {}).entries) {
      final value = entry.value;
      if (value == null || value.toString().isEmpty) continue;
      final prop = findProperty(item, entry.key);
      if (prop == null) {
        throw BammModelException('Unknown activity-line field: ${entry.key}');
      }
      prop['value'] = coerceValue(prop, value);
      prop['state'] = 2;
    }

    final items = childSet['items'];
    if (items is List) {
      items.add(item);
    } else {
      childSet['items'] = <dynamic>[item];
    }
    return item;
  }

  /// `GET /api/RecordLocking/Lock` - the pessimistic record lock the fat
  /// client takes before editing (docs/05). Its response is informational
  /// only (`allowNonJson`).
  ///
  /// There is no corresponding "unlock" call: neither the reference client
  /// (`~/repos/BAMM/app/bamm/workorders.py`) nor the mock exposes one - the
  /// lock is released implicitly (by the following Save, or by session
  /// expiry), so this writer does not invent one either.
  ///
  /// `programId`/`tableName` match the fixed defaults in
  /// `~/repos/BAMM/app/config.py::Config` (`BAMM_PROGRAM_ID=1`,
  /// `BAMM_TABLE_NAME=WORK_ORDER`) - every environment observed locks the
  /// same work-order table under the same program id, so these are not
  /// wired into `BammConfig` as another knob to keep in sync.
  Future<void> lockWorkOrder(Object workOrderId) async {
    await transport.get(
      '/api/RecordLocking/Lock',
      params: {
        'programId': '1',
        'tableName': 'WORK_ORDER',
        'recordId': '$workOrderId',
      },
      referer: '/workorder/detail/$workOrderId',
      operation: 'Record lock request for $workOrderId',
      allowNonJson: true,
    );
  }

  /// Everything `POST /WorkOrder/Save` will send, normalised and validated,
  /// without sending it - so a bad model shape surfaces before the network
  /// call, not as a 599 from BAMM.
  Map<String, dynamic> buildSaveBody(Map<String, dynamic> model, Object workOrderId) {
    final saveModel = normalizeModelForSave(model);
    validateShortTypeNames(saveModel);
    validateSaveModel(saveModel, workOrderId);
    return saveModel;
  }

  /// `POST /api/WorkOrder/Save`. Note the non-JSON content type
  /// (`application/cogep.dynamicdtoV1+json`) - this is the trap the
  /// reference docs call out; a plain JSON POST here gets a 599.
  Future<Map<String, dynamic>> save(Map<String, dynamic> model, Object workOrderId) async {
    final body = buildSaveBody(model, workOrderId);
    final result = await transport.post(
      '/api/WorkOrder/Save',
      jsonBody: body,
      params: {'duplicateQuestionSettingsJson': ''},
      referer: '/workorder/detail/$workOrderId',
      contentType: kBammContentTypeDto,
      operation: 'Work-order save request for $workOrderId',
      allowNonJson: true,
    );
    final value = (result is Map) ? result['value'] : null;
    if (value is Map<String, dynamic>) return value;
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  /// Creates a work order: `GetNew -> [ValidateSelectedAsset ->
  /// ChangeFunctionCode] -> apply fields -> AddActivityLine(s) -> Save ->
  /// read back`. Mirrors
  /// `~/repos/BAMM/app/bamm/workorders.py::WorkOrderService.create_work_order`
  /// (without groupings/model/skill/maintenance-type/recipient selection,
  /// which are not needed by anything in this codebase yet - call
  /// [changeModel]/[changeSkill]/[changeMaintenanceType]/[changeRecipient]
  /// directly on the model between [getNew] and this method's field
  /// application if a future caller needs them).
  ///
  /// Creation takes no record lock: there is nothing to lock until BAMM
  /// assigns an id, and the reference client does not lock here either -
  /// only edits to an *existing* work order do (see `fields.dart`).
  ///
  /// [fields] are BAMM property names -> raw values; unlike the six-field
  /// whitelist in `fields.dart`, creation legitimately needs to set many
  /// properties (asset, priority, category, ...), so this stays a generic,
  /// protected-fields-only guard - exactly what the Python reference does.
  Future<Map<String, dynamic>> createWorkOrder({
    required Map<String, Object?> fields,
    Object? assetId,
    bool applyDefaultModel = true,
    List<Map<String, Object?>> activityLines = const [],
  }) async {
    final description = (fields['WOR_DESCR']?.toString() ?? '').trim();
    if (description.isEmpty) {
      throw const BammFieldValidationException('WOR_DESCR (description) is required');
    }

    var model = await getNew(assetId: assetId);

    if (assetId != null) {
      model = await validateSelectedAsset(assetId, model);
      model = await changeFunctionCode(assetId, model, applyDefaultModel: applyDefaultModel);
    }

    if (assetId != null && findProperty(model, 'FUN_ID') != null) {
      setProperty(model, 'FUN_ID', '$assetId');
    }
    final unknown = <String>[];
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null || value.toString().isEmpty) continue;
      if (protectedFields.contains(entry.key.toUpperCase())) {
        unknown.add(entry.key);
        continue;
      }
      final prop = findProperty(model, entry.key);
      if (prop == null) {
        unknown.add(entry.key);
        continue;
      }
      setProperty(model, entry.key, coerceValue(prop, value));
    }
    if (unknown.isNotEmpty) {
      throw BammModelException('Unknown or protected field(s): ${(unknown..sort()).join(', ')}');
    }

    final added = <Map<String, dynamic>>[];
    for (final line in activityLines) {
      added.add(await addActivityLine(model, fields: line));
    }

    model['state'] = stateNew;
    model['isNull'] = false;
    model['forceEmpty'] = false;

    final saveResult = await save(model, propertyValue(model, 'WOR_ID') ?? '0');
    final newId = propertyValue(saveResult, 'WOR_ID');
    Map<String, dynamic>? created;
    if (newId != null && newId != '0') {
      created = await getById(newId);
    }
    return {
      'workOrderId': newId,
      'workOrderNumber': propertyValue(saveResult, 'WOR_NO'),
      'activityLines': added.length,
      'saveResult': saveResult,
      'model': created,
    };
  }
}
