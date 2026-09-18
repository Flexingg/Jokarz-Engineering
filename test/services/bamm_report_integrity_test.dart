// Sheet-integrity hash: proves the fingerprint is stable for identical
// data, changes for each field that actually matters, and does NOT change
// for fields that are out of scope (asset-derived display columns this app
// never edits) - a hash that reacts to everything would false-positive on
// every reprint.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/services/bamm_report_integrity.dart';

BammWorkOrder _wo({
  String status = 'Registered',
  String step = 'Emergency',
  String description = 'Motor replacement',
  String workDone = '',
  String responsible = 'Doe, Jane',
  DateTime? requiredDate,
  String priority = '6',
  String assembly = 'Fill Head 3',
}) =>
    BammWorkOrder(
      worId: 1,
      worNoSeq: '185610',
      status: status,
      step: step,
      description: description,
      workDone: workDone,
      responsible: responsible,
      requiredDate: requiredDate,
      priority: priority,
      assembly: assembly,
    );

void main() {
  group('bammSnapshotHash', () {
    test('identical inputs produce identical hashes', () {
      expect(bammSnapshotHash(_wo()), bammSnapshotHash(_wo()));
    });

    test('changing status changes the hash', () {
      expect(bammSnapshotHash(_wo(status: 'Registered')), isNot(bammSnapshotHash(_wo(status: 'Completed'))));
    });

    test('changing step changes the hash', () {
      expect(bammSnapshotHash(_wo(step: 'Emergency')), isNot(bammSnapshotHash(_wo(step: 'Normal'))));
    });

    test('changing description changes the hash', () {
      expect(bammSnapshotHash(_wo(description: 'A')), isNot(bammSnapshotHash(_wo(description: 'B'))));
    });

    test('changing workDone changes the hash', () {
      expect(bammSnapshotHash(_wo(workDone: '')), isNot(bammSnapshotHash(_wo(workDone: 'Replaced bearing'))));
    });

    test('changing responsible changes the hash', () {
      expect(bammSnapshotHash(_wo(responsible: 'Doe, Jane')), isNot(bammSnapshotHash(_wo(responsible: 'Smith, Bob'))));
    });

    test('changing requiredDate changes the hash', () {
      expect(
        bammSnapshotHash(_wo(requiredDate: DateTime(2026, 1, 1))),
        isNot(bammSnapshotHash(_wo(requiredDate: DateTime(2026, 2, 1)))),
      );
    });

    test('changing priority changes the hash', () {
      expect(bammSnapshotHash(_wo(priority: '6')), isNot(bammSnapshotHash(_wo(priority: '9'))));
    });

    test('changing an out-of-scope field (assembly) does NOT change the hash', () {
      expect(bammSnapshotHash(_wo(assembly: 'Fill Head 3')), bammSnapshotHash(_wo(assembly: 'Fill Head 9')));
    });
  });

  group('bammHasChangedSincePrint', () {
    test('matching hash -> not changed', () {
      final wo = _wo();
      expect(bammHasChangedSincePrint(wo, bammSnapshotHash(wo)), isFalse);
    });

    test('mismatched hash -> changed', () {
      final printed = _wo(status: 'Registered');
      final live = _wo(status: 'Completed');
      expect(bammHasChangedSincePrint(live, bammSnapshotHash(printed)), isTrue);
    });
  });
}
