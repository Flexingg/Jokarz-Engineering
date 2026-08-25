import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/bom_item.dart';
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
        'version': 1,
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

  String exportBOMToCSV(Project project) {
    final buffer = StringBuffer();
    buffer.writeln('Part Name,Category,Part Number,Supplier,Quantity,Unit Cost (USD),Total Cost (USD),Purchased');
    for (final item in project.bom) {
      buffer.writeln(
        '"${item.name}","${item.category.label}","${item.partNumber}","${item.supplier}",${item.quantity},${item.unitCost.toStringAsFixed(2)},${item.totalCost.toStringAsFixed(2)},${item.isPurchased ? "YES" : "NO"}',
      );
    }
    buffer.writeln('');
    buffer.writeln('TOTAL ESTIMATED BOM COST,,,,,,${project.totalBOMCost.toStringAsFixed(2)},');
    return buffer.toString();
  }

  ({List<Project> projects, List<VoiceNote> voiceNotes, List<FilamentProfile> filaments}) _generateSeedData() {
    final p1Id = 'proj-seed-1';
    final p2Id = 'proj-seed-2';
    final p3Id = 'proj-seed-3';

    final projects = [
      Project(
        id: p1Id,
        title: 'Jokarz Fastener Grid & Sorting System',
        description: 'Modular interlocking grid storage for M2-M6 socket head cap screws, hex nuts, and heat-set inserts with chamfered bin lip designs.',
        category: ProjectCategory.threeDPrinting,
        status: ProjectStatus.production,
        priority: ProjectPriority.high,
        budget: 45.0,
        tags: ['Gridfinity', '3D Print', 'PETG', 'Workshop Organization'],
        estimatedPrintHours: 18.5,
        estimatedFilamentGrams: 420.0,
        bom: [
          BOMItem(name: 'Black PETG Filament (1kg)', category: BOMCategory.filament, supplier: 'Polymaker', unitCost: 22.0, quantity: 1, isPurchased: true),
          BOMItem(name: '6x2mm Neodymium Magnets (100pk)', category: BOMCategory.fastener, supplier: 'Amazon', unitCost: 12.50, quantity: 1, isPurchased: true),
          BOMItem(name: 'M3 Brass Heat-Set Inserts (50pk)', category: BOMCategory.fastener, supplier: 'CNC Kitchen', unitCost: 8.99, quantity: 1, isPurchased: true),
        ],
        logs: [
          ProjectLog(
            title: 'Initial CAD bin prototypes completed',
            content: 'Modeled 1x1, 1x2, and 2x2 modular bins with 0.4mm tolerance fit. Stackable lip verified.',
            type: LogType.milestone,
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
          ),
          ProjectLog(
            title: 'Filament shrinkage & magnet press fit test',
            content: 'Dialed in magnet pocket bore to 6.10mm. Magnets press fit snugly without glue.',
            type: LogType.inspection,
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      ),
      Project(
        id: p2Id,
        title: 'ESP32 Workshop Environmental & Power Node',
        description: 'Multi-sensor wireless telemetry node monitoring workshop temperature, humidity, particulate dust (PM2.5), and 12V tool battery rail voltage with MQTT / WebSocket reporting.',
        category: ProjectCategory.electronics,
        status: ProjectStatus.prototyping,
        priority: ProjectPriority.critical,
        budget: 65.0,
        tags: ['ESP32', 'Sensors', 'BME280', 'PCB', 'Home Assistant'],
        estimatedPrintHours: 4.2,
        estimatedFilamentGrams: 85.0,
        bom: [
          BOMItem(name: 'ESP32-S3 Dev Board', category: BOMCategory.electronic, supplier: 'DigiKey', unitCost: 6.50, quantity: 2, isPurchased: true),
          BOMItem(name: 'BME280 Temperature/Humidity/Pressure Sensor', category: BOMCategory.electronic, supplier: 'Adafruit', unitCost: 14.95, quantity: 1, isPurchased: true),
          BOMItem(name: 'PMS5003 Laser Dust Sensor', category: BOMCategory.electronic, supplier: 'Amazon', unitCost: 24.0, quantity: 1, isPurchased: false),
          BOMItem(name: 'Buck Converter Module 24V->5V', category: BOMCategory.electronic, supplier: 'Pololu', unitCost: 7.20, quantity: 1, isPurchased: true),
          BOMItem(name: 'M2.5 x 6mm Standoffs (Pack)', category: BOMCategory.fastener, supplier: 'McMaster-Carr', unitCost: 6.50, quantity: 1, isPurchased: true),
        ],
        logs: [
          ProjectLog(
            title: 'Breadboard wiring verified',
            content: 'I2C communication established at 400kHz. BME280 sending clean telemetry to local broker.',
            type: LogType.update,
            timestamp: DateTime.now().subtract(const Duration(days: 4)),
          ),
        ],
      ),
      Project(
        id: p3Id,
        title: 'Precision Quick-Change Lathe Toolpost Height Gauge',
        description: 'Machined aluminum reference fixture with digital dial indicator for rapid on-center lathe tooling setup.',
        category: ProjectCategory.mechanical,
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        budget: 35.0,
        tags: ['Machining', 'Lathe', 'Metrology', '6061-T6'],
        bom: [
          BOMItem(name: '6061-T6 Aluminum Bar 1" x 2" x 6"', category: BOMCategory.rawMaterial, supplier: 'Midwest Steel', unitCost: 14.50, quantity: 1, isPurchased: false),
          BOMItem(name: 'Digital Dial Indicator 0.0005" Res', category: BOMCategory.tool, supplier: 'Shars Tool', unitCost: 28.0, quantity: 1, isPurchased: false),
          BOMItem(name: '1/4"-20 Brass Tipped Thumbscrew', category: BOMCategory.fastener, supplier: 'McMaster-Carr', unitCost: 4.80, quantity: 2, isPurchased: false),
        ],
        logs: [
          ProjectLog(
            title: 'Tolerance and clearance specs drafted',
            content: 'Establishing base parallelism to within 0.0005 inches. V-groove angle chosen at 90 degrees.',
            type: LogType.update,
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      ),
    ];

    final voiceNotes = [
      VoiceNote(
        title: 'Filament Drying & Speed Note',
        transcript: 'Remember to dry the CF-PETG at 65C for 6 hours prior to printing the structural brackets to prevent layer delamination.',
        durationSeconds: 14,
        projectId: p1Id,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      VoiceNote(
        title: 'Sensor I2C Pullup Check',
        transcript: 'Added 4.7k ohm pullup resistors on SDA and SCL lines for the ESP32 breadboard rig to stabilize noise from the dust sensor fan motor.',
        durationSeconds: 22,
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
