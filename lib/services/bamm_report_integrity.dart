/// Sheet integrity: BAMM is live, paper is a snapshot. A printed report's
/// deep-link QR embeds [bammSnapshotHash] for each work order; scanning it
/// later re-fetches the live work order, recomputes the hash, and compares -
/// a mismatch means the work order changed in BAMM since that print run.
library;

import 'dart:convert';
import '../models/bamm_models.dart';

/// The fields that matter for "has this work order changed since it was
/// printed" - deliberately a narrow, named set (not every field on
/// [BammWorkOrder]) so an unrelated display-only change (e.g. `assembly`,
/// which is asset-derived and never edited from this app) doesn't trigger a
/// false "changed" warning.
String _canonicalForHash(BammWorkOrder wo) => jsonEncode({
      'status': wo.status,
      'step': wo.step,
      'description': wo.description,
      'workDone': wo.workDone,
      'responsible': wo.responsible,
      'requiredDate': wo.requiredDate?.toIso8601String(),
      'priority': wo.priority,
    });

/// A short (8 hex char), deterministic fingerprint of the fields that matter
/// for sheet-integrity comparison. Not cryptographic - this only needs to
/// detect accidental drift between a print run and a later scan, not resist
/// tampering.
String bammSnapshotHash(BammWorkOrder wo) {
  final bytes = utf8.encode(_canonicalForHash(wo));
  // FNV-1a 32-bit - simple, dependency-free, stable across platforms.
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// True when [live]'s hash no longer matches [printedHash] - the work order
/// changed in BAMM since the sheet carrying [printedHash] was printed.
bool bammHasChangedSincePrint(BammWorkOrder live, String printedHash) => bammSnapshotHash(live) != printedHash;
