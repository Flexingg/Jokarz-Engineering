import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/bom_item.dart';
import '../models/project_log.dart';
import '../models/voice_note.dart';
import '../models/filament_profile.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class EngineeringState {
  final List<Project> projects;
  final List<VoiceNote> voiceNotes;
  final List<FilamentProfile> filaments;
  final bool isLoading;
  final String searchQuery;
  final ProjectCategory? selectedCategory;
  final ProjectStatus? selectedStatus;

  const EngineeringState({
    this.projects = const [],
    this.voiceNotes = const [],
    this.filaments = const [],
    this.isLoading = true,
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedStatus,
  });

  List<Project> get filteredProjects {
    return projects.where((p) {
      final matchesSearch = searchQuery.isEmpty ||
          p.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase()));

      final matchesCategory =
          selectedCategory == null || p.category == selectedCategory;
      final matchesStatus =
          selectedStatus == null || p.status == selectedStatus;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  EngineeringState copyWith({
    List<Project>? projects,
    List<VoiceNote>? voiceNotes,
    List<FilamentProfile>? filaments,
    bool? isLoading,
    String? searchQuery,
    ProjectCategory? selectedCategory,
    bool clearCategory = false,
    ProjectStatus? selectedStatus,
    bool clearStatus = false,
  }) {
    return EngineeringState(
      projects: projects ?? this.projects,
      voiceNotes: voiceNotes ?? this.voiceNotes,
      filaments: filaments ?? this.filaments,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
    );
  }
}

class ProjectNotifier extends StateNotifier<EngineeringState> {
  final StorageService _storage;

  ProjectNotifier(this._storage) : super(const EngineeringState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true);
    final data = await _storage.loadData();
    state = state.copyWith(
      projects: data['projects'] as List<Project>,
      voiceNotes: data['voiceNotes'] as List<VoiceNote>,
      filaments: data['filaments'] as List<FilamentProfile>,
      isLoading: false,
    );
  }

  Future<void> _persist() async {
    await _storage.saveData(
      projects: state.projects,
      voiceNotes: state.voiceNotes,
      customFilaments: state.filaments,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void filterCategory(ProjectCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void filterStatus(ProjectStatus? status) {
    if (status == null) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status);
    }
  }

  // --- Project CRUD ---
  Future<void> addProject(Project project) async {
    final updated = [project, ...state.projects];
    state = state.copyWith(projects: updated);
    await _persist();
  }

  Future<void> updateProject(Project project) async {
    final updated = state.projects.map((p) {
      if (p.id == project.id) {
        return project.copyWith(updatedAt: DateTime.now());
      }
      return p;
    }).toList();
    state = state.copyWith(projects: updated);
    await _persist();
  }

  Future<void> deleteProject(String id) async {
    final updated = state.projects.where((p) => p.id != id).toList();
    state = state.copyWith(projects: updated);
    await _persist();
  }

  Project? getProjectById(String id) {
    try {
      return state.projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- BOM Item Management ---
  Future<void> addBOMItem(String projectId, BOMItem item) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedBOM = [...project.bom, item];
    final updatedProject = project.copyWith(bom: updatedBOM);
    await updateProject(updatedProject);
  }

  Future<void> updateBOMItem(String projectId, BOMItem item) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedBOM = project.bom.map((i) => i.id == item.id ? item : i).toList();
    final updatedProject = project.copyWith(bom: updatedBOM);
    await updateProject(updatedProject);
  }

  Future<void> toggleBOMItemPurchased(String projectId, String itemId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedBOM = project.bom.map((i) {
      if (i.id == itemId) {
        return i.copyWith(isPurchased: !i.isPurchased);
      }
      return i;
    }).toList();
    final updatedProject = project.copyWith(bom: updatedBOM);
    await updateProject(updatedProject);
  }

  Future<void> deleteBOMItem(String projectId, String itemId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedBOM = project.bom.where((i) => i.id != itemId).toList();
    final updatedProject = project.copyWith(bom: updatedBOM);
    await updateProject(updatedProject);
  }

  // --- Project Logs ---
  Future<void> addProjectLog(String projectId, ProjectLog log) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedLogs = [log, ...project.logs];
    final updatedProject = project.copyWith(logs: updatedLogs);
    await updateProject(updatedProject);
  }

  Future<void> deleteProjectLog(String projectId, String logId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedLogs = project.logs.where((l) => l.id != logId).toList();
    final updatedProject = project.copyWith(logs: updatedLogs);
    await updateProject(updatedProject);
  }

  // --- Photos ---
  Future<void> addProjectPhoto(String projectId, String photoPath) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedPhotos = [...project.photoPaths, photoPath];
    final updatedProject = project.copyWith(photoPaths: updatedPhotos);
    await updateProject(updatedProject);
  }

  // --- Voice Notes ---
  Future<void> addVoiceNote(VoiceNote note) async {
    final updated = [note, ...state.voiceNotes];
    state = state.copyWith(voiceNotes: updated);

    // If attached to a project, also add as a project log entry
    if (note.projectId != null) {
      final log = ProjectLog(
        title: '🎤 ${note.title}',
        content: note.transcript,
        type: LogType.voice,
        timestamp: note.timestamp,
      );
      await addProjectLog(note.projectId!, log);
    }

    await _persist();
  }

  Future<void> deleteVoiceNote(String id) async {
    final updated = state.voiceNotes.where((n) => n.id != id).toList();
    state = state.copyWith(voiceNotes: updated);
    await _persist();
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, EngineeringState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ProjectNotifier(storage);
});
