import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/voice_note.dart';
import '../providers/project_provider.dart';
import 'auth_service.dart';

enum SyncStatus {
  offline,
  syncing,
  synced,
  error,
}

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.offline,
    this.lastSyncedAt,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SyncNotifier(ref, authService);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  final AuthService _authService;
  
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription? _authSub;
  StreamSubscription? _projectsSub;
  StreamSubscription? _notesSub;
  ProviderSubscription? _localStateSub;
  bool _isProcessingRemoteUpdate = false;
  bool _initialRemoteReceived = false;

  SyncNotifier(this._ref, this._authService) : super(const SyncState()) {
    _init();
  }

  void _init() {
    _authSub = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _startListeningToCloud(user.uid);
      } else {
        _stopListening();
        state = const SyncState(status: SyncStatus.offline);
      }
    });
  }

  void _startListeningToCloud(String uid) {
    _stopListening();
    final firestore = _firestore;
    if (firestore == null) return;

    state = state.copyWith(status: SyncStatus.syncing);

    // Real-time snapshot listener on user's projects collection
    _projectsSub = firestore
        .collection('users')
        .doc(uid)
        .collection('projects')
        .snapshots()
        .listen(
      (snapshot) {
        _handleProjectsSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore projects sync error: $e');
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: e.toString(),
        );
      },
    );

    // Real-time snapshot listener on user's voice notes collection
    _notesSub = firestore
        .collection('users')
        .doc(uid)
        .collection('voiceNotes')
        .snapshots()
        .listen(
      (snapshot) {
        _handleNotesSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore voice notes sync error: $e');
      },
    );

    // Push local changes (creates/edits) to the cloud automatically so edits on
    // one device propagate to others without pressing the manual sync button.
    _localStateSub = _ref.listen<EngineeringState>(projectProvider, (prev, next) {
      if (_isProcessingRemoteUpdate) return;
      if (!_initialRemoteReceived) return;
      unawaited(_syncChangedEntities(prev, next));
    });
  }

  void _handleProjectsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteProjects = snapshot.docs.map((doc) {
        final data = doc.data();
        return Project.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteProjects.isNotEmpty) {
        // Merge cloud with local state
        _ref.read(projectProvider.notifier).mergeCloudProjects(remoteProjects);
      } else if (localState.projects.isNotEmpty) {
        // Initial cloud push if cloud is empty
        pushAllLocalToCloud();
      }

      // Push any local-only projects (e.g. created while offline) not on cloud.
      final remoteProjectIds = {for (final p in remoteProjects) p.id};
      final localAfter = _ref.read(projectProvider);
      for (final p in localAfter.projects) {
        if (!remoteProjectIds.contains(p.id)) {
          syncProject(p);
        }
      }
      _initialRemoteReceived = true;

      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error merging remote projects: $e');
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  void _handleNotesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteNotes = snapshot.docs.map((doc) {
        final data = doc.data();
        return VoiceNote.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteNotes.isNotEmpty) {
        _ref.read(projectProvider.notifier).mergeCloudNotes(remoteNotes);
      } else if (localState.voiceNotes.isNotEmpty) {
        pushAllLocalToCloud();
      }

      // Push any local-only notes (e.g. created while offline) not on cloud.
      final remoteNoteIds = {for (final n in remoteNotes) n.id};
      final localAfter = _ref.read(projectProvider);
      for (final n in localAfter.voiceNotes) {
        if (!remoteNoteIds.contains(n.id)) {
          syncVoiceNote(n);
        }
      }
      _initialRemoteReceived = true;

      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error merging remote notes: $e');
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  /// Push single project to cloud
  Future<void> syncProject(Project project) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      state = state.copyWith(status: SyncStatus.syncing);
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('projects')
          .doc(project.id)
          .set(project.toJson(), SetOptions(merge: true));

      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error uploading project: $e');
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Delete project in cloud
  Future<void> deleteCloudProject(String projectId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('projects')
          .doc(projectId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud project: $e');
    }
  }

  /// Push single voice/written field note to cloud
  Future<void> syncVoiceNote(VoiceNote note) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('voiceNotes')
          .doc(note.id)
          .set(note.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading note: $e');
    }
  }

  /// Delete note in cloud
  Future<void> deleteCloudVoiceNote(String noteId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('voiceNotes')
          .doc(noteId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud note: $e');
    }
  }

  /// Deletes a voice/written note from BOTH local state and Firestore so it is
  /// not resurrected by the next cloud snapshot. Local delete happens first so
  /// the UI updates immediately; the cloud delete is best-effort and never
  /// blocks the caller (the change watcher also handles it automatically).
  Future<void> deleteVoiceNoteEverywhere(String noteId) async {
    await _ref.read(projectProvider.notifier).deleteVoiceNote(noteId);
    unawaited(deleteCloudVoiceNote(noteId));
  }

  /// Deletes a project from BOTH local state and Firestore so it is not
  /// resurrected by the next cloud snapshot. Local delete happens first so the
  /// UI updates immediately; the cloud delete is best-effort and non-blocking.
  Future<void> deleteProjectEverywhere(String projectId) async {
    await _ref.read(projectProvider.notifier).deleteProject(projectId);
    unawaited(deleteCloudProject(projectId));
  }

  /// Push all local projects and notes to cloud
  Future<void> pushAllLocalToCloud() async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      state = state.copyWith(status: SyncStatus.syncing);
      final localState = _ref.read(projectProvider);

      final batch = firestore.batch();
      for (final project in localState.projects) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('projects')
            .doc(project.id);
        batch.set(docRef, project.toJson(), SetOptions(merge: true));
      }

      for (final note in localState.voiceNotes) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('voiceNotes')
            .doc(note.id);
        batch.set(docRef, note.toJson(), SetOptions(merge: true));
      }

      await batch.commit();

      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error pushing local data to cloud: $e');
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Diffs the previous and next local states and pushes only what changed to
  /// the cloud (creates/edits of projects and notes, plus deletes for safety).
  Future<void> _syncChangedEntities(
      EngineeringState? prev, EngineeringState next) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    final prevProjects = {
      for (final p in prev?.projects ?? const <Project>[]) p.id: p,
    };
    final prevNotes = {
      for (final n in prev?.voiceNotes ?? const <VoiceNote>[]) n.id: n,
    };

    final futures = <Future<void>>[];

    // Created or edited projects
    for (final p in next.projects) {
      final old = prevProjects[p.id];
      if (old == null || old.updatedAt != p.updatedAt) {
        futures.add(syncProject(p));
      }
    }
    // Deleted projects
    for (final old in prevProjects.values) {
      if (!next.projects.any((p) => p.id == old.id)) {
        futures.add(deleteCloudProject(old.id));
      }
    }

    // Created or edited notes
    for (final n in next.voiceNotes) {
      final old = prevNotes[n.id];
      if (old == null ||
          old.title != n.title ||
          old.transcript != n.transcript ||
          old.projectId != n.projectId ||
          old.timestamp != n.timestamp) {
        futures.add(syncVoiceNote(n));
      }
    }
    // Deleted notes
    for (final old in prevNotes.values) {
      if (!next.voiceNotes.any((n) => n.id == old.id)) {
        futures.add(deleteCloudVoiceNote(old.id));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void _stopListening() {
    _projectsSub?.cancel();
    _notesSub?.cancel();
    _localStateSub?.close();
    _projectsSub = null;
    _notesSub = null;
    _localStateSub = null;
  }

  @override
  void dispose() {
    _stopListening();
    _authSub?.cancel();
    super.dispose();
  }
}
