/// The six-field write whitelist for BAMM work orders - the only properties
/// this app is ever allowed to send to an *existing* work order. Mirrors
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

/// One of the six BAMM properties this app may ever write to an existing
/// work order. Adding a seventh means adding a case here - and thinking
/// about whether it belongs in a whitelist at all.
enum BammWritableField {
  description('WOR_DESCR'),
  workDone('WOR_TASK'),
  responsible('RCP_ID'),
  requiredDate('WOR_REQUI_DATE'),
  installStart('WOR_PLAN_DATE'),
  installEnd('WOR_END_PLAN_DATE');

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
  /// call at all - not merely before `Save`.
  int get _propertyType {
    switch (this) {
      case BammWritableField.description:
      case BammWritableField.workDone:
        return 9; // text
      case BammWritableField.responsible:
        return 4; // ID / lookup key
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
  /// as calendar dates rather than raw epoch millis.
  String describe() {
    switch (status) {
      case BammFieldReadBackStatus.saved:
        return '${field.bammProperty}: saved';
      case BammFieldReadBackStatus.silentlyDropped:
        return '${field.bammProperty}: silently dropped';
      case BammFieldReadBackStatus.returnedDifferent:
        final shown = field.isDate && returnedValue != null ? epochMsToDate(returnedValue!) : returnedValue;
        return '${field.bammProperty}: BAMM returned $shown';
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
      final status = returned == sent
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
}
