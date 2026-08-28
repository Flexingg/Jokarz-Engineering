import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/utils/text_utils.dart';

void main() {
  group('titleCase', () {
    test('capitalizes each word and lowercases the rest', () {
      expect(titleCase('line 4 filler jamming'), 'Line 4 Filler Jamming');
      expect(titleCase('  hello   world '), 'Hello World');
      expect(titleCase(''), '');
      expect(titleCase('   '), '');
    });

    test('splitMachines splits on / and ,', () {
      expect(splitMachines('621 / Packer A, Mill 3'), ['621', 'Packer A', 'Mill 3']);
      expect(splitMachines('621'), ['621']);
      expect(splitMachines(''), isEmpty);
      expect(splitMachines('   '), isEmpty);
    });

    test('decodeUnicodeEscapes decodes literal \\uXXXX sequences', () {
      expect(decodeUnicodeEscapes(r'\u201cHello\u201d'), '\u201cHello\u201d');
      expect(decodeUnicodeEscapes('plain text'), 'plain text');
      expect(decodeUnicodeEscapes(''), '');
      expect(decodeUnicodeEscapes('a\\u2019s'), "a\u2019s");
    });
  });

  group('EngineeringState.searchAll', () {
    final project = Project(
      id: 'p1',
      title: 'Line 4 Filler Infeed Jamming',
      machine: 'Line 4 / Filler',
      subAssembly: 'Infeed Starwheel',
      description: 'UHMW guide plates wearing',
      tags: ['starwheel', 'shutdown'],
      notes: 'Check plate clearances at 2mm.',
    );

    final state = EngineeringState(
      projects: [project],
      voiceNotes: [
        VoiceNote(
          title: 'Bearing clearance observation',
          transcript: 'Rear shaft bearing has 0.25mm play on Line 4.',
          durationSeconds: 0,
          projectId: 'p1',
        ),
      ],
      standaloneOrders: [
        StandaloneOrder(
          description: 'SKF 6205 bearings',
          po: 'PO-9921004',
          pr: 'PR-48901',
          price: 120.0,
        ),
      ],
    );

    test('returns empty for empty or whitespace query', () {
      expect(state.searchAll('').isEmpty, isTrue);
      expect(state.searchAll('   ').isEmpty, isTrue);
    });

    test('matches project by title (case-insensitive)', () {
      final r = state.searchAll('filler');
      expect(r.projects.length, 1);
      expect(r.projects.first.project.id, 'p1');
    });

    test('tokenized: all tokens must match', () {
      final r = state.searchAll('line 4 jamming');
      expect(r.projects.length, 1);
      expect(state.searchAll('line 4 nope').projects, isEmpty);
    });

    test('matches project by machine or tag', () {
      expect(state.searchAll('starwheel').projects.length, 1);
      expect(state.searchAll('shutdown').projects.length, 1);
    });

    test('project note is searchable', () {
      final r = state.searchAll('clearances');
      expect(r.notes.any((n) => n.isProjectNote && n.projectId == 'p1'), isTrue);
    });

    test('voice note matches transcript and carries project title', () {
      final r = state.searchAll('0.25mm');
      final hit = r.notes.firstWhere((n) => !n.isProjectNote);
      expect(hit.content, contains('0.25mm'));
      expect(hit.projectTitle, 'Line 4 Filler Infeed Jamming');
    });

    test('attached order matches description and carries project title', () {
      // Add an order to the project and rebuild state.
      final p2 = project.copyWith(
        orders: [
          OrderItem(
            id: 'o1',
            pr: 'PR-48901',
            po: 'PO-1002',
            description: 'UHMW 1/2 inch sheet',
            price: 184.5,
          ),
        ],
      );
      final s2 = state.copyWith(projects: [p2]);
      final r = s2.searchAll('UHMW');
      expect(r.orders.length, greaterThan(0));
      final hit = r.orders.first;
      expect(hit.projectTitle, 'Line 4 Filler Infeed Jamming');
    });

    test('standalone order matches and is marked unlinked', () {
      final r = state.searchAll('6205');
      final hit = r.orders.firstWhere((o) => o.isStandalone);
      expect(hit.description, 'SKF 6205 bearings');
      expect(hit.projectTitle, 'Unlinked');
      expect(hit.project, isNull);
    });

    test('standalone order matches by PO', () {
      final r = state.searchAll('PO-9921004');
      expect(r.orders.any((o) => o.isStandalone), isTrue);
    });

    test('availableSubAssembliesFor drills down by machine', () {
      final s = EngineeringState(projects: [
        Project(id: 'a', title: 'A', machine: '621', subAssembly: 'Spindle'),
        Project(
            id: 'b', title: 'B', machine: '621 / Packer A', subAssembly: 'Packer Guides'),
        Project(id: 'c', title: 'C', machine: 'Line 3', subAssembly: 'Starwheel'),
      ]);
      expect(s.availableSubAssembliesFor('621').toSet(),
          {'Spindle', 'Packer Guides'});
      expect(s.availableSubAssembliesFor('Packer A').toSet(),
          {'Packer Guides'});
      expect(s.availableSubAssembliesFor('').length, 3);
    });

    test('search matches tasks inside projects', () {
      final s = EngineeringState(projects: [
        Project(id: 't1', title: 'Line 1 Filler', tasks: [
          TaskItem(description: 'Replace starwheel bearing', pendingReason: ''),
        ]),
      ]);
      final r = s.searchAll('bearing');
      expect(r.tasks.length, 1);
      expect(r.tasks.first.task.description, 'Replace starwheel bearing');
      expect(r.tasks.first.project.id, 't1');
      expect(s.searchAll('nomatch').tasks, isEmpty);
    });
  });
}
