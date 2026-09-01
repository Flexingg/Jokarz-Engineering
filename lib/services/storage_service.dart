import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/voice_note.dart';
import '../models/filament_profile.dart';
import '../models/standalone_order.dart';
import '../models/activity_log.dart';
import '../models/downtime_event.dart';
import '../models/inbox_item.dart';
import '../models/vendor.dart';
import '../models/project_template.dart';

class StorageService {
  static const String _downtimesFile = 'jokarz_downtimes.json';
  static const String _dataFile = 'jokarz_engineering_data.json';

  /// Writes content atomically: write to a temp file in the same directory,
  /// then rename over the target. Prevents a crash mid-write from leaving a
  /// truncated/corrupt data file (the previous in-place writeAsString truncates
  /// the live file before writing, so an interruption destroyed everything).
  Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

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
          inboxItems: initialData.inboxItems,
          vendors: initialData.vendors,
          customTemplates: initialData.customTemplates,
          snoozedProjects: initialData.snoozedProjects,
        );
        return {
          'projects': initialData.projects,
          'voiceNotes': initialData.voiceNotes,
          'filaments': initialData.filaments,
          'standaloneOrders': initialData.standaloneOrders,
          'inboxItems': initialData.inboxItems,
          'vendors': initialData.vendors,
          'customTemplates': initialData.customTemplates,
          'snoozedProjects': initialData.snoozedProjects,
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
          'inboxItems': initialData.inboxItems,
          'vendors': initialData.vendors,
          'customTemplates': initialData.customTemplates,
          'snoozedProjects': initialData.snoozedProjects,
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

      final inboxItems = (jsonMap['inboxItems'] as List<dynamic>?)
              ?.map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      final vendors = (jsonMap['vendors'] as List<dynamic>?)
              ?.map((e) => Vendor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      final customTemplates = (jsonMap['customTemplates'] as List<dynamic>?)
              ?.map((e) => ProjectTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      final snoozedProjects = (jsonMap['snoozedProjects'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          <String, String>{};

      return {
        'projects': projects,
        'voiceNotes': voiceNotes,
        'filaments': FilamentProfile.defaultProfiles,
        'standaloneOrders': standaloneOrders,
        'inboxItems': inboxItems,
        'vendors': vendors,
        'customTemplates': customTemplates,
        'snoozedProjects': snoozedProjects,
      };
    } catch (e, stack) {
      debugPrint('Error loading storage data: $e\n$stack');
      final initialData = _generateBlankData();
      return {
        'projects': initialData.projects,
        'voiceNotes': initialData.voiceNotes,
        'filaments': initialData.filaments,
        'standaloneOrders': initialData.standaloneOrders,
        'inboxItems': initialData.inboxItems,
        'vendors': initialData.vendors,
        'customTemplates': initialData.customTemplates,
        'snoozedProjects': initialData.snoozedProjects,
      };
    }
  }

  Future<void> clearAllData() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- Key Bindings ---
  static const String _bindingsFile = 'jokarz_keybindings.json';

  Future<File> _getBindingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_bindingsFile');
  }

  Future<Map<String, String>> loadKeyBindings() async {
    try {
      final file = await _getBindingsFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return jsonMap.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('Error loading keybindings: $e');
      return {};
    }
  }

  Future<void> saveKeyBindings(Map<String, String> bindings) async {
    try {
      final file = await _getBindingsFile();
      await _atomicWrite(file, jsonEncode(bindings));
    } catch (e) {
      debugPrint('Error saving keybindings: $e');
    }
  }

  // --- Report Settings ---
  static const String _reportFile = 'jokarz_report_config.json';

  Future<File> _getReportFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_reportFile');
  }

  Future<Map<String, dynamic>?> loadReportSettings() async {
    try {
      final file = await _getReportFile();
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReportSettings(Map<String, dynamic> data) async {
    try {
      final file = await _getReportFile();
      await _atomicWrite(file, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving report settings: $e');
    }
  }

  // --- Activity Log ---
  static const String _activityFile = 'jokarz_activity_log.json';

  Future<File> _getActivityFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_activityFile');
  }

  Future<File> _getDowntimesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_downtimesFile');
  }

  Future<List<ActivityLog>> loadActivityLog() async {
    try {
      final file = await _getActivityFile();
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveActivityLog(List<ActivityLog> logs) async {
    try {
      final file = await _getActivityFile();
      await _atomicWrite(
          file, jsonEncode(logs.map((l) => l.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving activity log: $e');
    }
  }

  Future<List<DowntimeEvent>> loadDowntimes() async {
    try {
      final file = await _getDowntimesFile();
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) => DowntimeEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDowntimes(List<DowntimeEvent> downtimes) async {
    try {
      final file = await _getDowntimesFile();
      await _atomicWrite(
          file, jsonEncode(downtimes.map((l) => l.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving downtimes: $e');
    }
  }

  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
    List<StandaloneOrder> standaloneOrders = const [],
    List<InboxItem> inboxItems = const [],
    List<Vendor> vendors = const [],
    List<ProjectTemplate> customTemplates = const [],
    Map<String, String> snoozedProjects = const {},
  }) async {
    try {
      final file = await _getFile();
      final data = {
        'version': 5,
        'updatedAt': DateTime.now().toIso8601String(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'voiceNotes': voiceNotes.map((e) => e.toJson()).toList(),
        'standaloneOrders': standaloneOrders.map((e) => e.toJson()).toList(),
        'inboxItems': inboxItems.map((e) => e.toJson()).toList(),
        'vendors': vendors.map((e) => e.toJson()).toList(),
        'customTemplates': customTemplates.map((e) => e.toJson()).toList(),
        'snoozedProjects': snoozedProjects,
      };
      await _atomicWrite(file, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving storage data: $e');
    }
  }

  ({
    List<Project> projects,
    List<VoiceNote> voiceNotes,
    List<FilamentProfile> filaments,
    List<StandaloneOrder> standaloneOrders,
    List<InboxItem> inboxItems,
    List<Vendor> vendors,
    List<ProjectTemplate> customTemplates,
    Map<String, String> snoozedProjects,
  }) _generateBlankData() {
    return (
      projects: <Project>[],
      voiceNotes: <VoiceNote>[],
      filaments: FilamentProfile.defaultProfiles,
      standaloneOrders: <StandaloneOrder>[],
      inboxItems: <InboxItem>[],
      vendors: <Vendor>[],
      customTemplates: <ProjectTemplate>[],
      snoozedProjects: <String, String>{},
    );
  }
}

