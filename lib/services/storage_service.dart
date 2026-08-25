import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
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
        final initialData = _generateBlankData();
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
        final initialData = _generateBlankData();
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

      return {
        'projects': projects,
        'voiceNotes': voiceNotes,
        'filaments': FilamentProfile.defaultProfiles,
      };
    } catch (e, stack) {
      debugPrint('Error loading storage data: $e\n$stack');
      final initialData = _generateBlankData();
      return {
        'projects': initialData.projects,
        'voiceNotes': initialData.voiceNotes,
        'filaments': initialData.filaments,
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
  }) async {
    try {
      final file = await _getFile();
      final data = {
        'version': 3,
        'updatedAt': DateTime.now().toIso8601String(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'voiceNotes': voiceNotes.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving storage data: $e');
    }
  }

  ({List<Project> projects, List<VoiceNote> voiceNotes, List<FilamentProfile> filaments}) _generateBlankData() {
    // Blank slate: Starts with 0 demo projects and 0 notes
    return (
      projects: <Project>[],
      voiceNotes: <VoiceNote>[],
      filaments: FilamentProfile.defaultProfiles,
    );
  }
}
