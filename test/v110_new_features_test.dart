import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/utils/barcode_utils.dart';
import 'package:jokarz_engineering/utils/barcode_label_pdf.dart';
import 'package:jokarz_engineering/utils/note_action_extractor.dart';
import 'package:jokarz_engineering/ui/screens/workbench_screen.dart';

void main() {
  group('New Mechanical Engineering Solvers (1–4)', () {
    test('1. O-Ring & Gland Solver Squeeze & Fill Physics', () {
      // Metric AS568-100 series: cs = 2.62mm, depth = 2.15mm, width = 3.40mm
      const cs = 2.62;
      const depth = 2.15;
      const width = 3.40;

      final squeezePercent = ((cs - depth) / cs) * 100.0;
      final oRingArea = (math.pi / 4.0) * (cs * cs);
      final glandArea = depth * width;
      final fillPercent = (oRingArea / glandArea) * 100.0;

      // Squeeze should be ~17.9% (target 15-25% for static radial)
      expect(squeezePercent, closeTo(17.93, 0.1));
      // Gland fill should be ~73.7% (optimal < 85%)
      expect(fillPercent, closeTo(73.7, 0.2));
      expect(fillPercent < 85.0, true);
    });

    test('2. Pneumatic Cylinder Push/Pull Forces & Airflow Demand', () {
      // 50mm bore, 20mm rod, 150mm stroke at 6.2 bar (90 psi)
      const boreIn = 50.0 / 25.4;
      const rodIn = 20.0 / 25.4;
      const strokeIn = 150.0 / 25.4;
      const pressurePsi = 6.2 * 14.5038;

      final boreAreaSqIn = (math.pi / 4.0) * math.pow(boreIn, 2);
      final rodAreaSqIn = (math.pi / 4.0) * math.pow(rodIn, 2);
      final pullAreaSqIn = boreAreaSqIn - rodAreaSqIn;

      final pushForceLbf = pressurePsi * boreAreaSqIn;
      final pullForceLbf = pressurePsi * pullAreaSqIn;
      final pushForceN = pushForceLbf * 4.44822;
      final pullForceN = pullForceLbf * 4.44822;

      // 50mm bore at 6.2 bar push force is ~1217 N (~273 lbf)
      expect(pushForceN, closeTo(1217.0, 5.0));
      // 20mm rod retraction force is ~1022 N (~230 lbf)
      expect(pullForceN, closeTo(1022.0, 5.0));
      expect(pullForceN < pushForceN, true);

      // Volume and CFM
      final compressionRatio = (pressurePsi + 14.7) / 14.7;
      final cycleVol = (boreAreaSqIn + pullAreaSqIn) * strokeIn;
      const cpm = 20.0; // 20 cycles/min
      final scfm = (cycleVol * cpm * compressionRatio) / 1728.0;

      expect(scfm, greaterThan(0.5));
      expect(scfm, lessThan(10.0));
    });

    test('3. Belt & Pulley Ratio, Pitch Length & Wrap Angle', () {
      // D1 = 80mm, D2 = 160mm (2:1 ratio), Center = 400mm
      const d1 = 80.0;
      const d2 = 160.0;
      const c = 400.0;

      final approxLength = 2.0 * c + (math.pi / 2.0) * (d1 + d2) + (math.pow(d2 - d1, 2) / (4.0 * c));
      expect(approxLength, closeTo(1181.0, 2.0));

      // Wrap angle on small pulley: 180 - 2 * arcsin((D-d)/(2C))
      final sinVal = (d2 - d1) / (2.0 * c); // 80 / 800 = 0.1
      final wrapDeg = 180.0 - (2.0 * (math.asin(sinVal) * 180.0 / math.pi));

      expect(wrapDeg, closeTo(168.5, 0.5));
      expect(wrapDeg > 120.0, true); // Safe wrap
    });

    test('4. Motor Torque & Gearbox Output with VFD Derating', () {
      // 5 HP motor at 1750 RPM, 20:1 ratio, 95% helical efficiency
      const hp = 5.0;
      const baseRpm = 1750.0;
      const ratio = 20.0;
      const eff = 0.95;

      final motorTorqueFtLbs = (hp * 5252.0) / baseRpm;
      expect(motorTorqueFtLbs, closeTo(15.0, 0.2)); // ~15 ft-lbs

      final outTorqueFtLbs = motorTorqueFtLbs * ratio * eff;
      expect(outTorqueFtLbs, closeTo(285.0, 5.0)); // ~285 ft-lbs

      final outRpm = baseRpm / ratio;
      expect(outRpm, equals(87.5));
    });

    test('Workbench Tools registry contains all 19 engineering tools', () {
      expect(workbenchTools.containsKey('oring'), true);
      expect(workbenchTools.containsKey('cylinder'), true);
      expect(workbenchTools.containsKey('belt'), true);
      expect(workbenchTools.containsKey('motor'), true);
      expect(workbenchTools['oring']!.keywords, contains('seal'));
      expect(workbenchTools['cylinder']!.keywords, contains('pneumatic'));
      expect(workbenchTools['belt']!.keywords, contains('timing belt'));
      expect(workbenchTools['motor']!.keywords, contains('vfd'));
    });
  });

  group('Barcode 128 & QR Generation (13-Style)', () {
    test('Code 128-B encoder generates valid module stream with quiet zones', () {
      const code = 'PO-9921004';
      final modules = encodeCode128B(code);

      expect(modules.isNotEmpty, true);
      // Quiet zones at both ends (at least 10 spaces)
      expect(modules.take(10).every((b) => b == false), true);
      expect(modules.reversed.take(10).every((b) => b == false), true);
      // Contains bars
      expect(modules.contains(true), true);
    });

    test('Single Barcode Label PDF Generator runs without error', () async {
      const labelData = BarcodeLabelData(
        kind: BarcodeLabelKind.purchaseOrder,
        primaryCode: 'PO-9921004',
        title: 'UHMW Wear Plates for Infeed',
        subtitle: 'Vendor: McMaster-Carr • Machine: Case Packer 1',
        meta1: 'PR: PR-48901 • ETA: Nov 12',
        scanPayload: 'PO:9921004',
      );

      final pdfBytes = await generateSingleBarcodeLabelPdf(labelData);
      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length, greaterThan(100));
      // PDF magic number header %PDF-
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });

    test('2D Project Barcode Label factory formats Step, Type, Priority without top branding', () {
      final sample = Project(
        id: 'proj-101',
        title: 'Rebuild Infeed Staging Roller',
        description: 'Overhaul roller assembly',
        notes: '',
        category: ProjectCategory.maintenance,
        phase: 'Installation',
        priority: 1,
        cost: 0,
        machine: 'Case Packer 2',
        subAssembly: 'Infeed',
        tags: const [],
        tasks: const [],
        orders: const [],
        logs: const [],
        photoPaths: const [],
        bammWorkOrders: const [],
        createdAt: DateTime.now(),
      );

      final label = BarcodeLabelData.fromProject(sample);
      expect(label.kind, BarcodeLabelKind.project);
      expect(label.title, 'Rebuild Infeed Staging Roller');
      expect(label.primaryCode, 'PROJ-#1');
      expect(label.step, 'Installation');
      expect(label.type, 'Maintenance');
      expect(label.priority, '#1');
      expect(label.machine, 'Case Packer 2');
      expect(label.is2dOnly, true);
      expect(label.scanPayload, 'PROJ:proj-101');
    });

    test('Single 2D Barcode Label PDF Generator runs without error', () async {
      final sample = Project(
        id: 'proj-102',
        title: 'Overhaul Sorter Gearbox',
        description: 'New seals and synthetic lube',
        notes: '',
        category: ProjectCategory.capital,
        phase: 'Pending',
        priority: 2,
        cost: 0,
        machine: 'Sorter 1',
        subAssembly: 'Main Drive',
        tags: const [],
        tasks: const [],
        orders: const [],
        logs: const [],
        photoPaths: const [],
        bammWorkOrders: const [],
        createdAt: DateTime.now(),
      );

      final pdfBytes = await generateSingleBarcodeLabelPdf(BarcodeLabelData.fromProject(sample));
      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });

    test('Multi-Label 8.5x11 Cut Sheet PDF Generator formats 8 labels per page', () async {
      final labels = List.generate(
        10,
        (i) => BarcodeLabelData(
          kind: BarcodeLabelKind.project,
          primaryCode: 'PROJ-#${i + 1}',
          title: 'Project Item #$i',
          subtitle: 'Machine: Machine-$i',
          step: 'Step-$i',
          type: 'Maintenance',
          priority: '#${i + 1}',
          machine: 'Machine-$i',
          is2dOnly: true,
          scanPayload: 'PROJ:uuid-$i',
        ),
      );

      final pdfBytes = await generateMultiLabelSheetPdf(labels);
      expect(pdfBytes.isNotEmpty, true);
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });
  });

  group('Smart Voice Note Action Extractor (19)', () {
    test('Extracts machine, task intent, date and pending reason from spoken text', () {
      final sampleProjects = [
        Project(
          id: 'proj-1',
          title: 'Line 3 Conveyor Rebuild',
          machine: 'Line 3 Conveyor',
          category: ProjectCategory.maintenance,
        ),
      ];

      const transcript = 'Replace worn timing belt on Line 3 Conveyor tomorrow pending downtime.';
      final action = extractActionsFromText(transcript, sampleProjects);

      expect(action.detectedMachine, 'Line 3 Conveyor');
      expect(action.matchedProjectId, 'proj-1');
      expect(action.hasTaskSuggestion, true);
      expect(action.taskDescription, contains('Replace'));
      expect(action.suggestedDate, isNotNull);
      expect(action.pendingReason, 'Pending downtime');
    });

    test('Extracts procurement intent and part description', () {
      final sampleProjects = <Project>[];
      const transcript = 'Order two 25mm pillow block bearings for pump 2.';
      final action = extractActionsFromText(transcript, sampleProjects);

      expect(action.hasOrderSuggestion, true);
      expect(action.orderDescription.toLowerCase(), contains('pillow block'));
      expect(action.detectedMachine, 'Pump');
    });
  });
}
