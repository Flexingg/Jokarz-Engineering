import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/task_item.dart';
import '../models/order_item.dart';
import '../models/project_log.dart';
import '../models/voice_note.dart';
import '../models/filament_profile.dart';

class StorageService {
  static const String _dataFile = 'jokarz_engineering_data.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_dataFile');
  }

  Future<Map<String, dynamic>> loadData() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        final initialData = _generateSeedData();
        await saveData(
          projects: initialData.projects,
          voiceNotes: initialData.voiceNotes,
          customFilaments: initialData.filaments,
        );
        return {
          'projects': initialData.projects,
          'voiceNotes': initialData.voiceNotes,
          'filaments': initialData.filaments,
        };
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        final initialData = _generateSeedData();
        return {
          'projects': initialData.projects,
          'voiceNotes': initialData.voiceNotes,
          'filaments': initialData.filaments,
        };
      }

      final jsonMap = jsonDecode(content) as Map<String, dynamic>;

      final projects = (jsonMap['projects'] as List<dynamic>?)
              ?.map((e) => Project.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      final voiceNotes = (jsonMap['voiceNotes'] as List<dynamic>?)
              ?.map((e) => VoiceNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      final filaments = (jsonMap['filaments'] as List<dynamic>?)
              ?.map((e) => FilamentProfile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          FilamentProfile.defaultProfiles;

      return {
        'projects': projects,
        'voiceNotes': voiceNotes,
        'filaments': filaments,
      };
    } catch (e, stack) {
      debugPrint('Error loading storage data: $e\n$stack');
      final initialData = _generateSeedData();
      return {
        'projects': initialData.projects,
        'voiceNotes': initialData.voiceNotes,
        'filaments': initialData.filaments,
      };
    }
  }

  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
  }) async {
    try {
      final file = await _getFile();
      final data = {
        'version': 2,
        'updatedAt': DateTime.now().toIso8601String(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'voiceNotes': voiceNotes.map((e) => e.toJson()).toList(),
        'filaments': customFilaments.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving storage data: $e');
    }
  }

  ({List<Project> projects, List<VoiceNote> voiceNotes, List<FilamentProfile> filaments}) _generateSeedData() {
    final p1Id = 'proj-mfg-1';
    final p2Id = 'proj-mfg-2';
    final p3Id = 'proj-mfg-3';
    final p4Id = 'proj-mfg-4';

    final t1Id = 'task-101';
    final t2Id = 'task-102';
    final t3Id = 'task-103';

    final projects = [
      Project(
        id: p1Id,
        title: 'Line 1 Filler Infeed Starwheel Jamming',
        description: 'Address frequent bottle jamming and bottle tip-overs on the high-speed infeed transition starwheel. Machine custom UHMW wear plates and upgrade main bearings.',
        category: ProjectCategory.maintenance,
        phase: ProjectPhases.installation,
        priority: 1,
        cost: 1250.0,
        machine: 'Line 1 High-Speed Filler',
        subAssembly: 'Infeed Timing Starwheel',
        nextPendingTaskId: t1Id,
        tags: ['Line 1', '621', 'Filler', 'Starwheel', 'Shutdown'],
        tasks: [
          TaskItem(
            id: t1Id,
            description: 'Machine replacement UHMW starwheel guide plates in machine shop',
            scheduledDate: DateTime.now().add(const Duration(days: 1)),
            pendingReason: 'Pending mill downtime',
            isCompleted: false,
          ),
          TaskItem(
            id: t2Id,
            description: 'Replace 6205 sealed ball bearings on starwheel drive shaft',
            isCompleted: true,
          ),
          TaskItem(
            id: t3Id,
            description: 'Re-align bottle timing screw with proximity sensor trigger',
            pendingReason: 'Pending line clearance',
            isCompleted: false,
          ),
        ],
        orders: [
          OrderItem(
            pr: 'PR-48901',
            po: 'PO-9921004',
            description: 'UHMW 1/2" Sheet 24x48 White Virgin',
            price: 184.50,
            delivered: true,
          ),
          OrderItem(
            pr: 'PR-48922',
            po: 'PO-9921088',
            description: 'SKF 6205-2RSH Deep Groove Bearings (x4)',
            price: 78.20,
            eta: DateTime.now().add(const Duration(days: 2)),
            delivered: false,
          ),
        ],
        logs: [
          ProjectLog(
            title: 'Worn starwheel pocket inspection',
            content: 'Found 0.080" excessive play on pocket #3 causing bottle tilt at 450 bpm.',
            type: LogType.inspection,
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      ),
      Project(
        id: p2Id,
        title: 'Cell 621 Robot End-Effector Quick-Change Kaizen',
        description: 'Implement toolless quick-change pneumatic gripper assembly on ABB robot to reduce line changeover downtime from 45 minutes to 4 minutes.',
        category: ProjectCategory.kaizen,
        phase: ProjectPhases.validation,
        priority: 2,
        cost: 3400.0,
        machine: 'Cell 621 ABB Robot',
        subAssembly: 'Pneumatic Gripper Tooling',
        tags: ['621', 'Kaizen', 'Robotics', 'Pneumatics', 'QuickChange'],
        tasks: [
          TaskItem(
            description: 'Design 6061 aluminum mounting adapter plate in Inventor CAD',
            isCompleted: true,
          ),
          TaskItem(
            description: 'Wire safety interlock 24V PNP inductive sensor to robot controller',
            scheduledDate: DateTime.now().add(const Duration(days: 1)),
            pendingReason: 'Pending electrician review',
            isCompleted: false,
          ),
          TaskItem(
            description: 'Run 100-cycle dry run repeatability test with payload',
            scheduledDate: DateTime.now().add(const Duration(days: 3)),
            pendingReason: 'Pending shift downtime',
            isCompleted: false,
          ),
        ],
        orders: [
          OrderItem(
            pr: 'PR-50112',
            po: 'PO-9922415',
            description: 'Schunk Quick-Change Robotic Tool Changer Module QC-040',
            price: 2850.00,
            eta: DateTime.now().add(const Duration(days: 4)),
            delivered: false,
          ),
          OrderItem(
            pr: 'PR-50118',
            po: 'PO-9922430',
            description: 'SMC 8mm Quick Exhaust Valves & Push-in Fittings',
            price: 145.00,
            delivered: true,
          ),
        ],
        logs: [
          ProjectLog(
            title: 'Adapter plate machined and anodized',
            content: 'Fits robot wrist bolt circle precisely with 0.001" locating dowel pin fit.',
            type: LogType.update,
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      ),
      Project(
        id: p3Id,
        title: 'Packaging Gantry Overhead Servo Overhaul',
        description: 'Upgrade obsolete pneumatic pusher cylinder on Case Packer 4 with high-speed linear belt-drive servo actuator for smooth deceleration.',
        category: ProjectCategory.capital,
        phase: ProjectPhases.idea,
        priority: 3,
        cost: 18500.0,
        machine: 'Packaging Gantry 4',
        subAssembly: 'Z-Axis Linear Actuator',
        tags: ['100', 'Packaging', 'Servo', 'Capital', 'Actuator'],
        tasks: [
          TaskItem(
            description: 'Obtain vendor quotes and torque calculations from Festo and Rockwell',
            pendingReason: 'Pending vendor email quote',
            isCompleted: false,
          ),
          TaskItem(
            description: 'Submit Capital Expenditure (CapEx) approval form to plant management',
            isCompleted: false,
          ),
        ],
        orders: [],
      ),
      Project(
        id: p4Id,
        title: 'Stamping Press 2 Hydraulic Seal Kit Rebuild',
        description: 'Replaced leaking rod seals and piston wipers on main 50-ton hydraulic clamp manifold block.',
        category: ProjectCategory.maintenance,
        phase: ProjectPhases.complete,
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
        priority: 1,
        cost: 620.0,
        machine: 'Stamping Press 2',
        subAssembly: 'Hydraulic Manifold Block',
        tags: ['Hydraulics', 'Stamping', 'Seals', 'Maintenance', 'Shutdown'],
        tasks: [
          TaskItem(
            description: 'Lockout/tagout press and bleed accumulator pressure to 0 psi',
            isCompleted: true,
          ),
          TaskItem(
            description: 'Replace polyurethane rod seals and O-rings with viton backup rings',
            isCompleted: true,
          ),
          TaskItem(
            description: 'Pressure test clamp cylinder at 2500 psi for 30 minutes',
            isCompleted: true,
          ),
        ],
        orders: [
          OrderItem(
            pr: 'PR-47800',
            po: 'PO-9918820',
            description: 'Parker Cylinder 3.25" Bore Seal Overhaul Kit',
            price: 310.00,
            delivered: true,
          ),
        ],
      ),
    ];

    final voiceNotes = [
      VoiceNote(
        title: 'Line 1 Starwheel Measurement',
        transcript: 'Measured bottle pocket clearance on the infeed starwheel. Bore is 6.10mm on guide pins, but the wear plate has 2mm grooving from glass bottle friction.',
        durationSeconds: 16,
        projectId: p1Id,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      VoiceNote(
        title: 'Cell 621 Robot Sensor Wiring',
        transcript: 'Need to make sure electrician uses shielded 4-conductor M8 sensor cable to prevent electrical noise from the robot servo drives.',
        durationSeconds: 19,
        projectId: p2Id,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    return (
      projects: projects,
      voiceNotes: voiceNotes,
      filaments: FilamentProfile.defaultProfiles,
    );
  }
}
