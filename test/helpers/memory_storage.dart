import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

/// A [StorageService] that serves seeded data and never touches disk or
/// `path_provider`, for widget tests.
class MemoryStorage extends StorageService {
  final List<Project> projects;
  final List<StandaloneOrder> orders;
  final List<Vendor> vendors;
  final List<VoiceNote> voiceNotes;
  UiPrefs prefs;

  MemoryStorage({
    this.projects = const [],
    this.orders = const [],
    this.vendors = const [],
    this.voiceNotes = const [],
    this.prefs = const UiPrefs(),
  });

  @override
  Future<Map<String, dynamic>> loadData() async => {
    'projects': [...projects],
    'voiceNotes': [...voiceNotes],
    'filaments': <FilamentProfile>[],
    'standaloneOrders': [...orders],
    'inboxItems': <InboxItem>[],
    'vendors': [...vendors],
    'customTemplates': <ProjectTemplate>[],
    'snoozedProjects': <String, String>{},
  };

  @override
  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
    List<StandaloneOrder> standaloneOrders = const [],
    List<InboxItem> inboxItems = const [],
    List<Vendor> vendors = const [],
    List<ProjectTemplate> customTemplates = const [],
    Map<String, String> snoozedProjects = const {},
  }) async {}

  @override
  Future<List<ActivityLog>> loadActivityLog() async => [];
  @override
  Future<void> saveActivityLog(List<ActivityLog> logs) async {}
  @override
  Future<List<DowntimeEvent>> loadDowntimes() async => [];
  @override
  Future<void> saveDowntimes(List<DowntimeEvent> d) async {}
  @override
  Future<Map<String, String>> loadKeyBindings() async => {};
  @override
  Future<void> saveKeyBindings(Map<String, String> b) async {}
  @override
  Future<UiPrefs> loadUiPrefs() async => prefs;
  @override
  Future<void> saveUiPrefs(UiPrefs p) async => prefs = p;
}
