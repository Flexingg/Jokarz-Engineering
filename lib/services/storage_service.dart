import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/voice_note.dart';
import '../models/filament_profile.dart';
import '../models/standalone_order.dart';

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
        final initialData = _generateBlankData();
        await saveData(
          projects: initialData.projects,
          voiceNotes: initialData.voiceNotes,
          customFilaments: initialData.filaments,
          standaloneOrders: initialData.standaloneOrders,
        );
        return {
          'projects': initialData.projects,
          'voiceNotes': initialData.voiceNotes,
          'filaments': initialData.filaments,
          'standaloneOrders': initialData.standaloneOrders,
        };
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        final initialData = _generateBlankData();
        return {
          'projects': initialData.projects,
          'voiceNotes': initialData.voiceNotes,
          'filaments': initialData.filaments,
          'standaloneOrders': initialData.standaloneOrders,
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

      final standaloneOrders = (jsonMap['standaloneOrders'] as List<dynamic>?)
              ?.map((e) => StandaloneOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      return {
        'projects': projects,
        'voiceNotes': voiceNotes,
        'filaments': FilamentProfile.defaultProfiles,
        'standaloneOrders': standaloneOrders,
      };
    } catch (e, stack) {
      debugPrint('Error loading storage data: $e\n$stack');
      final initialData = _generateBlankData();
      return {
        'projects': initialData.projects,
        'voiceNotes': initialData.voiceNotes,
        'filaments': initialData.filaments,
        'standaloneOrders': initialData.standaloneOrders,
      };
    }
  }

  Future<void> clearAllData() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
    List<StandaloneOrder> standaloneOrders = const [],
  }) async {
    try {
      final file = await _getFile();
      final data = {
        'version': 4,
        'updatedAt': DateTime.now().toIso8601String(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'voiceNotes': voiceNotes.map((e) => e.toJson()).toList(),
        'standaloneOrders': standaloneOrders.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving storage data: $e');
    }
  }

  ({List<Project> projects, List<VoiceNote> voiceNotes, List<FilamentProfile> filaments, List<StandaloneOrder> standaloneOrders}) _generateBlankData() {
    return (
      projects: <Project>[],
      voiceNotes: <VoiceNote>[],
      filaments: FilamentProfile.defaultProfiles,
      standaloneOrders: <StandaloneOrder>[],
    );
  }
}
