import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_config.dart';
import '../providers/project_provider.dart';
import '../services/storage_service.dart';

class ReportSettings {
  final ReportConfig current;
  final Map<String, ReportConfig> templates;
  const ReportSettings({required this.current, this.templates = const {}});
}

final reportSettingsProvider =
    StateNotifierProvider<ReportSettingsNotifier, ReportSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ReportSettingsNotifier(storage);
});

class ReportSettingsNotifier extends StateNotifier<ReportSettings> {
  final StorageService _storage;
  ReportSettingsNotifier(this._storage)
      : super(const ReportSettings(current: ReportConfig())) {
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadReportSettings();
    if (data == null) return;
    final currentRaw = data['current'];
    final templatesRaw = data['templates'];
    final currentCfg = currentRaw is Map<String, dynamic>
        ? ReportConfig.fromJson(currentRaw)
        : const ReportConfig();
    final templates = <String, ReportConfig>{};
    if (templatesRaw is Map<String, dynamic>) {
      templatesRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) templates[k] = ReportConfig.fromJson(v);
      });
    }
    state = ReportSettings(current: currentCfg, templates: templates);
  }

  Future<void> _persist() async {
    await _storage.saveReportSettings({
      'current': state.current.toJson(),
      'templates': state.templates.map((k, v) => MapEntry(k, v.toJson())),
    });
  }

  Future<void> setConfig(ReportConfig cfg) async {
    state = ReportSettings(current: cfg, templates: state.templates);
    await _persist();
  }

  Future<void> saveTemplate(String name, ReportConfig cfg) async {
    final t = Map<String, ReportConfig>.of(state.templates)..[name] = cfg;
    state = ReportSettings(current: state.current, templates: t);
    await _persist();
  }

  Future<void> loadTemplate(String name) async {
    final cfg = state.templates[name];
    if (cfg == null) return;
    state = ReportSettings(current: cfg, templates: state.templates);
    await _persist();
  }

  Future<void> deleteTemplate(String name) async {
    final t = Map<String, ReportConfig>.of(state.templates)..remove(name);
    state = ReportSettings(current: state.current, templates: t);
    await _persist();
  }
}
