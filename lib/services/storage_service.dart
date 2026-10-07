import 'dart:convert';
import 'dart:io';
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
import '../models/time_block.dart';
import '../models/slip_log_entry.dart';
import '../models/ui_prefs.dart';
import 'app_logger.dart';

class StorageService {
  /// [docsDir] overrides where data files live (tests point this at a temp dir).
  StorageService({Future<Directory> Function()? docsDir})
      : _docsDirOverride = docsDir;

  final Future<Directory> Function()? _docsDirOverride;
  Future<Directory> _docs() => (_docsDirOverride ?? getApplicationDocumentsDirectory)();

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
    final dir = await _docs();
    return File('${dir.path}/$_dataFile');
  }

  Map<String, dynamic> _blankDataMap() {
    final d = _generateBlankData();
    return {
      'projects': d.projects,
      'voiceNotes': d.voiceNotes,
      'filaments': d.filaments,
      'standaloneOrders': d.standaloneOrders,
      'inboxItems': d.inboxItems,
      'vendors': d.vendors,
      'customTemplates': d.customTemplates,
      'snoozedProjects': d.snoozedProjects,
    };
  }

  /// Parses the main data document. Throws on malformed content so callers can
  /// fall back to the last-good backup instead of silently starting blank.
  Map<String, dynamic> parseData(String content) {
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;

    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (jsonMap[key] as List<dynamic>?)
            ?.map((e) => f(e as Map<String, dynamic>))
            .toList() ??
        <T>[];

    return {
      'projects': list('projects', Project.fromJson),
      'voiceNotes': list('voiceNotes', VoiceNote.fromJson),
      'filaments': FilamentProfile.defaultProfiles,
      'standaloneOrders': list('standaloneOrders', StandaloneOrder.fromJson),
      'inboxItems': list('inboxItems', InboxItem.fromJson),
      'vendors': list('vendors', Vendor.fromJson),
      'customTemplates': list('customTemplates', ProjectTemplate.fromJson),
      'snoozedProjects': (jsonMap['snoozedProjects'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          <String, String>{},
    };
  }

  Future<Map<String, dynamic>> loadData() async {
    File? file;
    try {
      file = await _getFile();
      if (!await file.exists()) {
        final blank = _blankDataMap();
        await saveData(
          projects: blank['projects'] as List<Project>,
          voiceNotes: blank['voiceNotes'] as List<VoiceNote>,
          customFilaments: blank['filaments'] as List<FilamentProfile>,
        );
        return blank;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) return _blankDataMap();
      return parseData(content);
    } catch (e, stack) {
      log.error('storage', 'Main data file failed to load', e, stack);
      return _recoverFromCorruption(file);
    }
  }

  /// The live data file could not be parsed. Never fall through to a blank
  /// state without first preserving the bad file (the next save would
  /// otherwise overwrite the user's only copy) and trying the last-good
  /// `.bak` written before every save.
  Future<Map<String, dynamic>> _recoverFromCorruption(File? file) async {
    if (file == null) return _blankDataMap();
    try {
      if (await file.exists()) {
        final quarantine = File(
            '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
        await file.rename(quarantine.path);
        log.warn('storage', 'Quarantined unreadable data file',
            quarantine.path);
      }
      final bak = File('${file.path}.bak');
      if (await bak.exists()) {
        final restored = parseData(await bak.readAsString());
        await bak.copy(file.path);
        log.warn('storage', 'Restored data from last-good backup');
        return restored;
      }
    } catch (e, stack) {
      log.error('storage', 'Backup recovery failed', e, stack);
    }
    return _blankDataMap();
  }

  Future<void> clearAllData() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- UI preferences (theme, accent, motion, rail, dashboard layout) ---
  static const String _uiPrefsFile = 'jokarz_ui_prefs.json';

  Future<UiPrefs> loadUiPrefs() async {
    try {
      final file = File('${(await _docs()).path}/$_uiPrefsFile');
      if (!await file.exists()) return const UiPrefs();
      final text = await file.readAsString();
      if (text.trim().isEmpty) return const UiPrefs();
      return UiPrefs.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (e) {
      log.warn('storage', 'Could not read UI prefs; using defaults', e);
      return const UiPrefs();
    }
  }

  Future<void> saveUiPrefs(UiPrefs prefs) async {
    try {
      final file = File('${(await _docs()).path}/$_uiPrefsFile');
      await _atomicWrite(file, jsonEncode(prefs.toJson()));
    } catch (e) {
      log.warn('storage', 'Could not save UI prefs', e);
    }
  }

  // --- Key Bindings ---
  static const String _bindingsFile = 'jokarz_keybindings.json';

  Future<File> _getBindingsFile() async {
    final dir = await _docs();
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
      log.error('storage', 'Error loading keybindings', e);
      return {};
    }
  }

  Future<void> saveKeyBindings(Map<String, String> bindings) async {
    try {
      final file = await _getBindingsFile();
      await _atomicWrite(file, jsonEncode(bindings));
    } catch (e) {
      log.error('storage', 'Error saving keybindings', e);
    }
  }

  // --- Report Settings ---
  static const String _reportFile = 'jokarz_report_config.json';

  Future<File> _getReportFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_reportFile');
  }

  Future<Map<String, dynamic>?> loadReportSettings() async {
    try {
      final file = await _getReportFile();
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      log.warn('storage', 'Failed to read file; using defaults', e);
      return null;
    }
  }

  Future<void> saveReportSettings(Map<String, dynamic> data) async {
    try {
      final file = await _getReportFile();
      await _atomicWrite(file, jsonEncode(data));
    } catch (e) {
      log.error('storage', 'Error saving report settings', e);
    }
  }

  // --- BAMM report templates ---
  static const String _bammReportFile = 'jokarz_bamm_report_templates.json';

  Future<File> _getBammReportFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_bammReportFile');
  }

  Future<Map<String, dynamic>?> loadBammReportTemplates() async {
    try {
      final file = await _getBammReportFile();
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      log.warn('storage', 'Failed to read file; using defaults', e);
      return null;
    }
  }

  Future<void> saveBammReportTemplates(Map<String, dynamic> data) async {
    try {
      final file = await _getBammReportFile();
      await _atomicWrite(file, jsonEncode(data));
    } catch (e) {
      log.error('storage', 'Error saving BAMM report templates', e);
    }
  }

  // --- Activity Log ---
  static const String _activityFile = 'jokarz_activity_log.json';

  Future<File> _getActivityFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_activityFile');
  }

  Future<File> _getDowntimesFile() async {
    final dir = await _docs();
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
    } catch (e) {
      log.warn('storage', 'Failed to read file; using defaults', e);
      return [];
    }
  }

  Future<void> saveActivityLog(List<ActivityLog> logs) async {
    try {
      final file = await _getActivityFile();
      await _atomicWrite(
          file, jsonEncode(logs.map((l) => l.toJson()).toList()));
    } catch (e) {
      log.error('storage', 'Error saving activity log', e);
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
    } catch (e) {
      log.warn('storage', 'Failed to read file; using defaults', e);
      return [];
    }
  }

  Future<void> saveDowntimes(List<DowntimeEvent> downtimes) async {
    try {
      final file = await _getDowntimesFile();
      await _atomicWrite(
          file, jsonEncode(downtimes.map((l) => l.toJson()).toList()));
    } catch (e) {
      log.error('storage', 'Error saving downtimes', e);
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
      // Keep the previous good copy so a bad write/parse can be rolled back.
      if (await file.exists()) {
        try {
          await file.copy('${file.path}.bak');
        } catch (e) {
          log.warn('storage', 'Could not refresh .bak', e);
        }
      }
      await _atomicWrite(file, jsonEncode(data));
    } catch (e, stack) {
      log.error('storage', 'Error saving storage data', e, stack);
    }
  }

  // --- Time blocking (personal planning data - never sent to BAMM) ---
  static const String _timeBlocksFile = 'jokarz_time_blocks.json';
  static const String _slipLogFile = 'jokarz_slip_log.json';
  static const String _scheduleSettingsFile = 'jokarz_schedule_settings.json';

  Future<File> _getTimeBlocksFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_timeBlocksFile');
  }

  Future<File> _getSlipLogFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_slipLogFile');
  }

  Future<File> _getScheduleSettingsFile() async {
    final dir = await _docs();
    return File('${dir.path}/$_scheduleSettingsFile');
  }

  Future<List<TimeBlock>> loadTimeBlocks() async {
    try {
      final file = await _getTimeBlocksFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list.map((e) => TimeBlock.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log.error('storage', 'Error loading time blocks', e);
      return [];
    }
  }

  Future<void> saveTimeBlocks(List<TimeBlock> blocks) async {
    try {
      final file = await _getTimeBlocksFile();
      await _atomicWrite(file, jsonEncode(blocks.map((b) => b.toJson()).toList()));
    } catch (e) {
      log.error('storage', 'Error saving time blocks', e);
    }
  }

  Future<List<SlipLogEntry>> loadSlipLog() async {
    try {
      final file = await _getSlipLogFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list.map((e) => SlipLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log.error('storage', 'Error loading slip log', e);
      return [];
    }
  }

  Future<void> saveSlipLog(List<SlipLogEntry> entries) async {
    try {
      final file = await _getSlipLogFile();
      await _atomicWrite(file, jsonEncode(entries.map((e) => e.toJson()).toList()));
    } catch (e) {
      log.error('storage', 'Error saving slip log', e);
    }
  }

  /// Just `{"cascadeEnabled": bool}` today - a small, standalone file (like
  /// `_reportFile`/`_bindingsFile`) rather than folded into the main data
  /// file, so a corrupt/missing settings file can never affect projects.
  Future<bool> loadCascadeEnabled() async {
    try {
      final file = await _getScheduleSettingsFile();
      if (!await file.exists()) return true;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return true;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['cascadeEnabled'] as bool? ?? true;
    } catch (e) {
      log.warn('storage', 'Failed to read file; using defaults', e);
      return true;
    }
  }

  Future<void> saveCascadeEnabled(bool enabled) async {
    try {
      final file = await _getScheduleSettingsFile();
      await _atomicWrite(file, jsonEncode({'cascadeEnabled': enabled}));
    } catch (e) {
      log.error('storage', 'Error saving schedule settings', e);
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

