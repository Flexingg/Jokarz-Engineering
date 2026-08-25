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
  bool _isProcessingRemoteUpdate = false;

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

  void _stopListening() {
    _projectsSub?.cancel();
    _notesSub?.cancel();
    _projectsSub = null;
    _notesSub = null;
  }

  @override
  void dispose() {
    _stopListening();
    _authSub?.cancel();
    super.dispose();
  }
}
