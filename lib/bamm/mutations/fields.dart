/// The write whitelist for BAMM work orders - the only properties this app
/// is ever allowed to send to an *existing* work order. Mirrors
/// `~/repos/BAMM/app/projects/bamm_sync.py`'s `FIELD_MAP` / `verify_readback`
/// / `summarise_status`.
///
/// The whitelist is enforced **structurally**, not by convention:
/// [BammWritableField] is a closed enum, so there is no string-keyed path
/// from caller input into a Save payload - a non-whitelisted property name
/// cannot be constructed as a [BammFieldEdit] in the first place. This is a
/// deliberate divergence from the Python reference, whose `update_fields`
/// takes an arbitrary `Mapping[str, Any]` of property names and relies on a
/// runtime check (`PROTECTED_FIELDS`) to refuse the wrong ones. Runtime
/// checks can be bypassed by a future caller who skips the check; a closed
/// enum cannot be. For the same reason, `mutations/writer.dart` deliberately
/// does *not* expose a generic "set any property" method - only this typed
/// path may edit an existing work order's content fields.
library;

import 'dates.dart';
import 'exceptions.dart';
import 'model_ops.dart';
import 'writer.dart';

/// One of the BAMM properties this app may ever write to an existing work
/// order. Adding another means adding a case here - and thinking about
/// whether it belongs in a whitelist at all.
enum BammWritableField {
  description('WOR_DESCR'),
  workDone('WOR_TASK'),
  responsible('RCP_ID'),
  requiredDate('WOR_REQUI_DATE'),
  installStart('WOR_PLAN_DATE'),
  installEnd('WOR_END_PLAN_DATE'),
  classification('CTG_ID'),
  skill('SKI_ID'),
  classificationTable('WG6_ID'),
  crewShift('WG7_ID'),
  requiredEmployees('WOR_EST_NB_EMP'),
  step('WSP_ID'),
  maintenanceType('MNT_ID'),
  executionMode('EXM_ID'),
  priorityEm('WOR_NB_3'),
  asset('FUN_ID'),
  estimatedLaborHours('WOR_EST_LABOR_TIME'),
  // `~/repos/BAMM/docs/06-field-reference.md` flags WOS_ID `RO`, and every
  // real `Save` capture in `~/repos/BAMM/captures/*.har` sends it with
  // `state: 1` (unchanged), never `state: 2` - BAMM's own web UI never
  // writes this property directly. Added anyway on explicit instruction,
  // with the closing-status confirmation dialog and verbatim-error surfacing
  // called for in the task brief; the existing read-back verdict (numeric-
  // aware, see WhitelistedFieldWriter._readBackMatches) will honestly report
  // "silently dropped" if BAMM accepts the Save but does not apply the
  // change, exactly as it does for any other field.
  status('WOS_ID');

  final String bammProperty;
  const BammWritableField(this.bammProperty);

  bool get isDate =>
      this == BammWritableField.requiredDate ||
      this == BammWritableField.installStart ||
      this == BammWritableField.installEnd;

  /// The BAMM wire type for this field, known in advance because the
  /// whitelist is closed. Knowing it statically (rather than reading it off
  /// a live model, as the generic Python reference must) is what lets
  /// [WhitelistedFieldWriter.write] validate every value before any network
  /// call at all - not merely before `Save`. Types are taken from
  /// `~/repos/BAMM/docs/06-field-reference.md`'s full property catalogue,
  /// not guessed: `CTG_ID/SKI_ID/WG6_ID/WG7_ID/WOR_EST_NB_EMP/WSP_ID/MNT_ID/
  /// EXM_ID` are all type 4 (lookup id), `WOR_NB_3` is type 15 (decimal).
  int get _propertyType {
    switch (this) {
      case BammWritableField.description:
      case BammWritableField.workDone:
        return 9; // text
      case BammWritableField.responsible:
      case BammWritableField.classification:
      case BammWritableField.skill:
      case BammWritableField.classificationTable:
      case BammWritableField.crewShift:
      case BammWritableField.requiredEmployees:
      case BammWritableField.step:
      case BammWritableField.maintenanceType:
      case BammWritableField.executionMode:
      case BammWritableField.asset:
      case BammWritableField.status:
        return 4; // ID / lookup key
      case BammWritableField.priorityEm:
      case BammWritableField.estimatedLaborHours:
        return 15; // decimal
      case BammWritableField.requiredDate:
      case BammWritableField.installStart:
      case BammWritableField.installEnd:
        return 28; // date
    }
  }
}

/// One field/value pair to send. [value] is raw caller input - a
/// `yyyy-mm-dd` string for date fields, plain text/id otherwise - validated
/// and wire-encoded inside [WhitelistedFieldWriter.write].
class BammFieldEdit {
  final BammWritableField field;
  final String value;
  const BammFieldEdit(this.field, this.value);
}

enum BammFieldReadBackStatus { saved, returnedDifferent, silentlyDropped }

/// What actually happened to one sent field, per the read-back after Save.
class BammFieldReadBack {
  final BammWritableField field;
  final String sentValue;
  final String? returnedValue;
  final BammFieldReadBackStatus status;

  const BammFieldReadBack({
    required this.field,
    required this.sentValue,
    required this.returnedValue,
    required this.status,
  });

  /// A human-readable line for a status/report display, with dates rendered
  /// as calendar dates rather than raw epoch millis. Unambiguous about which
  /// outcome happened: `saved` means it landed, `silently dropped` means
  /// BAMM's read-back came back empty, and `returnedDifferent` spells out
  /// both what was sent and what came back instead of leaving the reader to
  /// infer the sent side from context.
  String describe() {
    switch (status) {
      case BammFieldReadBackStatus.saved:
        return '${field.bammProperty}: saved';
      case BammFieldReadBackStatus.silentlyDropped:
        return '${field.bammProperty}: silently dropped';
      case BammFieldReadBackStatus.returnedDifferent:
        final shownSent = field.isDate ? epochMsToDate(sentValue) : sentValue;
        final shownReturned = field.isDate && returnedValue != null ? epochMsToDate(returnedValue!) : returnedValue;
        return '${field.bammProperty}: sent $shownSent but BAMM returned $shownReturned';
    }
  }
}

/// The honest outcome of one whitelisted write. [isSuccess] is true only
/// when every field that was sent came back with the value that was sent -
/// a 200 from BAMM's Save is not, on its own, proof of anything (see the
/// batch brief: a hardcoded `"status": "success"` once coexisted with a
/// read-back saying every field was dropped).
class BammWriteResult {
  final String workOrderId;
  final List<BammFieldReadBack> fields;

  const BammWriteResult({required this.workOrderId, required this.fields});

  bool get isSuccess =>
      fields.isNotEmpty && fields.every((f) => f.status == BammFieldReadBackStatus.saved);

  List<BammFieldReadBack> get dropped =>
      fields.where((f) => f.status == BammFieldReadBackStatus.silentlyDropped).toList();

  List<BammFieldReadBack> get returnedDifferently =>
      fields.where((f) => f.status == BammFieldReadBackStatus.returnedDifferent).toList();

  /// `success`, or `unverified (N dropped, M returned differently)` -
  /// mirrors `~/repos/BAMM/app/projects/bamm_sync.py::summarise_status`.
  String get summary {
    if (fields.isEmpty) return 'unverified';
    if (isSuccess) return 'success';
    final parts = <String>[];
    if (dropped.isNotEmpty) parts.add('${dropped.length} dropped');
    if (returnedDifferently.isNotEmpty) parts.add('${returnedDifferently.length} returned differently');
    return 'unverified (${parts.join(', ')})';
  }
}

/// Writes a subset of the six whitelisted fields to one existing work order:
/// validate -> read -> lock -> save -> read back -> report, per field.
class WhitelistedFieldWriter {
  final BammWorkOrderWriter writer;
  const WhitelistedFieldWriter(this.writer);

  Future<BammWriteResult> write(Object workOrderId, List<BammFieldEdit> edits) async {
    if (edits.isEmpty) {
      throw const BammFieldValidationException('No fields to save');
    }

    // Validate and wire-encode every field before any network call at all
    // (not merely before Save) - see BammWritableField._propertyType.
    final coerced = <BammWritableField, String>{};
    for (final edit in edits) {
      final trimmed = edit.value.trim();
      if (trimmed.isEmpty) continue;
      final value = coerceForType(edit.field._propertyType, trimmed);
      if (value != null) coerced[edit.field] = value;
    }
    if (coerced.isEmpty) {
      throw const BammFieldValidationException('No non-empty fields to save');
    }

    final model = await writer.getById(workOrderId);
    final canModify = propertyValue(model, 'CanUserModify');
    if (canModify != null && canModify.toLowerCase() == 'false') {
      throw const BammModelException('BAMM reports this work order cannot be modified');
    }

    for (final entry in coerced.entries) {
      if (findProperty(model, entry.key.bammProperty) == null) {
        throw BammModelException('Property ${entry.key.bammProperty} was not found on this work order');
      }
      setProperty(model, entry.key.bammProperty, entry.value);
    }

    await writer.lockWorkOrder(workOrderId);
    await writer.save(model, workOrderId);
    final refreshed = await writer.getById(workOrderId);

    final results = <BammFieldReadBack>[];
    for (final entry in coerced.entries) {
      final sent = entry.value;
      final returned = propertyValue(refreshed, entry.key.bammProperty);
      final status = _readBackMatches(entry.key, sent, returned)
          ? BammFieldReadBackStatus.saved
          : ((returned == null || returned.trim().isEmpty)
              ? BammFieldReadBackStatus.silentlyDropped
              : BammFieldReadBackStatus.returnedDifferent);
      results.add(BammFieldReadBack(
        field: entry.key,
        sentValue: sent,
        returnedValue: returned,
        status: status,
      ));
    }
    return BammWriteResult(workOrderId: workOrderId.toString(), fields: results);
  }

  /// Whether BAMM's read-back [returned] value counts as "the same as what
  /// was [sent]" for [field]. A plain string comparison is wrong for
  /// anything BAMM can re-format on the way back: a decimal field like
  /// `WOR_NB_3` (EM Priority) or `WOR_EST_LABOR_TIME` echoes `6` back as
  /// `6.000000000`, and a lookup id field could in principle do the same -
  /// both are numerically identical, and reporting that as "BAMM returned
  /// 6.00000" was a false-positive "field dropped" bug, not a real one. Date
  /// fields (types 27/28) compare as epoch-millisecond integers for the same
  /// reason. Text fields (`WOR_DESCR`/`WOR_TASK`) are compared exactly -
  /// there is no legitimate re-formatting of free text to normalise past.
  bool _readBackMatches(BammWritableField field, String sent, String? returned) {
    if (returned == null) return false;
    if (sent == returned) return true;
    if (field.isDate) {
      final sentMs = int.tryParse(sent);
      final returnedMs = int.tryParse(returned);
      return sentMs != null && returnedMs != null && sentMs == returnedMs;
    }
    if (field._propertyType == 15 || field._propertyType == 4) {
      final sentNum = num.tryParse(sent);
      final returnedNum = num.tryParse(returned);
      return sentNum != null && returnedNum != null && sentNum == returnedNum;
    }
    return false;
  }
}
