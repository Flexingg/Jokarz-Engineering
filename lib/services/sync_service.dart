import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/voice_note.dart';
import '../models/standalone_order.dart';
import '../models/inbox_item.dart';
import '../models/vendor.dart';
import '../models/project_template.dart';
import '../providers/project_provider.dart';
import 'app_logger.dart';
import 'auth_service.dart';
import 'sync_merge.dart';

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

  /// Merge conflicts resolved since the app started (an edit made here since
  /// the last sync disagreed with a different cloud edit; see [mergeByUpdatedAt]).
  final int conflictCount;

  /// Human-readable description of the most recent conflict, if any.
  final String? lastConflict;

  const SyncState({
    this.status = SyncStatus.offline,
    this.lastSyncedAt,
    this.errorMessage,
    this.conflictCount = 0,
    this.lastConflict,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? conflictCount,
    String? lastConflict,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      conflictCount: conflictCount ?? this.conflictCount,
      lastConflict: lastConflict ?? this.lastConflict,
    );
  }
}

final syncStatusProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Firestore caps a write batch at 500 operations; stay well under it.
const int _kBatchLimit = 400;

/// Everything the sync layer needs to know about one synced collection
/// (`users/{uid}/<name>`): how to (de)serialize it, read it from local state,
/// merge a cloud snapshot into it, and remove an item that was deleted
/// elsewhere. One generic implementation then serves all six collections.
class _SyncCollection<T> {
  final String name;
  final String label;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final String Function(T) idOf;
  final DateTime Function(T) updatedAtOf;
  final List<T> Function(EngineeringState) items;
  final Future<List<SyncConflict>> Function(
      ProjectNotifier, List<T> remote, DateTime? lastSyncedAt) merge;
  final Future<void> Function(ProjectNotifier, String id) removeLocal;

  /// Projects and notes are what flip the "initial cloud state received" flag
  /// that arms local-change pushing and the Synced status.
  final bool marksInitialSync;

  const _SyncCollection({
    required this.name,
    required this.label,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
    required this.updatedAtOf,
    required this.items,
    required this.merge,
    required this.removeLocal,
    this.marksInitialSync = false,
  });
}

class SyncNotifier extends Notifier<SyncState> {
  Ref get _ref => ref;
  late AuthService _authService;

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription? _authSub;
  final List<StreamSubscription> _collectionSubs = [];
  ProviderSubscription? _localStateSub;
  bool _isProcessingRemoteUpdate = false;
  bool _initialRemoteReceived = false;

  late final _SyncCollection<Project> _projects = _SyncCollection<Project>(
    name: 'projects',
    label: 'projects',
    fromJson: Project.fromJson,
    toJson: (p) => p.toJson(),
    idOf: (p) => p.id,
    updatedAtOf: (p) => p.updatedAt,
    items: (s) => s.projects,
    merge: (n, r, t) => n.mergeCloudProjects(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.removeProjectLocal(id),
    marksInitialSync: true,
  );
  late final _SyncCollection<VoiceNote> _notes = _SyncCollection<VoiceNote>(
    name: 'voiceNotes',
    label: 'notes',
    fromJson: VoiceNote.fromJson,
    toJson: (n) => n.toJson(),
    idOf: (n) => n.id,
    updatedAtOf: (n) => n.updatedAt,
    items: (s) => s.voiceNotes,
    merge: (n, r, t) => n.mergeCloudNotes(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.removeVoiceNoteLocal(id),
    marksInitialSync: true,
  );
  late final _SyncCollection<StandaloneOrder> _orders =
      _SyncCollection<StandaloneOrder>(
    name: 'standaloneOrders',
    label: 'standalone orders',
    fromJson: StandaloneOrder.fromJson,
    toJson: (o) => o.toJson(),
    idOf: (o) => o.id,
    updatedAtOf: (o) => o.updatedAt,
    items: (s) => s.standaloneOrders,
    merge: (n, r, t) => n.mergeCloudStandaloneOrders(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.deleteStandaloneOrder(id),
  );
  late final _SyncCollection<InboxItem> _inbox = _SyncCollection<InboxItem>(
    name: 'inbox',
    label: 'inbox items',
    fromJson: InboxItem.fromJson,
    toJson: (i) => i.toJson(),
    idOf: (i) => i.id,
    updatedAtOf: (i) => i.updatedAt,
    items: (s) => s.inboxItems,
    merge: (n, r, t) => n.mergeCloudInbox(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.deleteInboxItem(id),
  );
  late final _SyncCollection<Vendor> _vendors = _SyncCollection<Vendor>(
    name: 'vendors',
    label: 'vendors',
    fromJson: Vendor.fromJson,
    toJson: (v) => v.toJson(),
    idOf: (v) => v.id,
    updatedAtOf: (v) => v.updatedAt,
    items: (s) => s.vendors,
    merge: (n, r, t) => n.mergeCloudVendors(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.deleteVendor(id),
  );
  late final _SyncCollection<ProjectTemplate> _templates =
      _SyncCollection<ProjectTemplate>(
    name: 'templates',
    label: 'templates',
    fromJson: ProjectTemplate.fromJson,
    toJson: (t) => t.toJson(),
    idOf: (t) => t.id,
    updatedAtOf: (t) => t.updatedAt,
    items: (s) => s.customTemplates,
    merge: (n, r, t) => n.mergeCloudTemplates(r, lastSyncedAt: t),
    removeLocal: (n, id) => n.deleteCustomTemplate(id),
  );

  List<_SyncCollection<dynamic>> get _all =>
      [_projects, _notes, _orders, _inbox, _vendors, _templates];

  @override
  SyncState build() {
    _authService = ref.watch(authServiceProvider);
    ref.onDispose(() {
      _stopListening();
      _authSub?.cancel();
    });
    _init();
    return const SyncState();
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

  CollectionReference<Map<String, dynamic>>? _col(String uid, String name) =>
      _firestore?.collection('users').doc(uid).collection(name);

  void _startListeningToCloud(String uid) {
    _stopListening();
    if (_firestore == null) return;

    state = state.copyWith(status: SyncStatus.syncing);

    for (final c in _all) {
      _collectionSubs.add(_col(uid, c.name)!.snapshots().listen(
        (snapshot) => _handleSnapshot(c, snapshot),
        onError: (Object e) {
          log.error('sync', 'Firestore ${c.label} sync error', e);
          // Only the projects listener drives the visible error status
          // (matches the previous behaviour); the rest are logged.
          if (identical(c, _projects)) {
            state = state.copyWith(
                status: SyncStatus.error, errorMessage: e.toString());
          }
        },
      ));
    }

    // Push local changes (creates/edits/deletes) to the cloud automatically
    _localStateSub =
        _ref.listen<EngineeringState>(projectProvider, (prev, next) {
      if (_isProcessingRemoteUpdate) return;
      if (!_initialRemoteReceived) return;
      unawaited(_syncChangedEntities(prev, next));
    });
  }

  void _noteConflicts(List<SyncConflict> conflicts) {
    if (conflicts.isEmpty) return;
    state = state.copyWith(
      conflictCount: state.conflictCount + conflicts.length,
      lastConflict: conflicts.last.summary,
    );
  }

  void _handleSnapshot<T>(
      _SyncCollection<T> c, QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final notifier = _ref.read(projectProvider.notifier);

      // 1) Process remote deletions FIRST: an item deleted on another device
      //    arrives as a `removed` doc change. Removing it locally means the
      //    "push local-only" loop below cannot re-upload it (sync resurrection).
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          unawaited(c.removeLocal(notifier, change.doc.id));
        }
      }

      final remote = snapshot.docs.map((d) => c.fromJson(d.data())).toList();
      final hadLocal = c.items(_ref.read(projectProvider)).isNotEmpty;

      if (remote.isNotEmpty) {
        unawaited(c
            .merge(notifier, remote, state.lastSyncedAt)
            .then(_noteConflicts)
            .catchError((Object e, StackTrace s) =>
                log.error('sync', 'Merge of ${c.label} failed', e, s)));
      } else if (hadLocal) {
        // Cloud is empty but we have data: initial cloud push.
        unawaited(pushAllLocalToCloud());
      }

      // Push any local-only items (e.g. created while offline) not on cloud.
      // Items removed above are already gone from local state, so they are
      // correctly excluded here.
      final remoteIds = {for (final r in remote) c.idOf(r)};
      for (final item in c.items(_ref.read(projectProvider))) {
        if (!remoteIds.contains(c.idOf(item))) {
          unawaited(_pushDoc(c, item));
        }
      }

      if (c.marksInitialSync) {
        _initialRemoteReceived = true;
        state = state.copyWith(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
        );
      }
    } catch (e, stack) {
      log.error('sync', 'Error merging remote ${c.label}', e, stack);
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  Future<void> _pushDoc<T>(_SyncCollection<T> c, T item) async {
    final user = _authService.currentUser;
    if (user == null || _firestore == null) return;
    try {
      state = state.copyWith(status: SyncStatus.syncing);
      await _col(user.uid, c.name)!
          .doc(c.idOf(item))
          .set(c.toJson(item), SetOptions(merge: true));
      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e, stack) {
      log.error('sync', 'Error uploading ${c.label}', e, stack);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _deleteDoc(_SyncCollection<dynamic> c, String id) async {
    final user = _authService.currentUser;
    if (user == null || _firestore == null) return;
    try {
      await _col(user.uid, c.name)!.doc(id).delete();
    } catch (e, stack) {
      log.error('sync', 'Error deleting cloud ${c.label}', e, stack);
    }
  }

  // Public push/delete API (used by the UI and the local-change diff).
  Future<void> syncProject(Project project) => _pushDoc(_projects, project);
  Future<void> deleteCloudProject(String id) => _deleteDoc(_projects, id);
  Future<void> syncVoiceNote(VoiceNote note) => _pushDoc(_notes, note);
  Future<void> deleteCloudVoiceNote(String id) => _deleteDoc(_notes, id);
  Future<void> syncStandaloneOrder(StandaloneOrder o) => _pushDoc(_orders, o);
  Future<void> deleteCloudStandaloneOrder(String id) => _deleteDoc(_orders, id);
  Future<void> syncInboxItem(InboxItem i) => _pushDoc(_inbox, i);
  Future<void> deleteCloudInboxItem(String id) => _deleteDoc(_inbox, id);
  Future<void> syncVendor(Vendor v) => _pushDoc(_vendors, v);
  Future<void> deleteCloudVendor(String id) => _deleteDoc(_vendors, id);
  Future<void> syncTemplate(ProjectTemplate t) => _pushDoc(_templates, t);
  Future<void> deleteCloudTemplate(String id) => _deleteDoc(_templates, id);

  /// Deletes a voice/written note from BOTH local state and Firestore so it is
  /// not resurrected by the next cloud snapshot.
  Future<void> deleteVoiceNoteEverywhere(String noteId) async {
    await _ref.read(projectProvider.notifier).deleteVoiceNote(noteId);
    unawaited(deleteCloudVoiceNote(noteId));
  }

  /// Deletes a project from BOTH local state and Firestore.
  Future<void> deleteProjectEverywhere(String projectId) async {
    await _ref.read(projectProvider.notifier).deleteProject(projectId);
    unawaited(deleteCloudProject(projectId));
  }

  /// Push all local entities to cloud, in batches under Firestore's
  /// 500-operation limit (one oversized batch used to fail the whole push).
  Future<void> pushAllLocalToCloud() async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      state = state.copyWith(status: SyncStatus.syncing);
      final localState = _ref.read(projectProvider);

      var batch = firestore.batch();
      var ops = 0;
      Future<void> flush() async {
        if (ops == 0) return;
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }

      Future<void> addAll<T>(_SyncCollection<T> c) async {
        for (final item in c.items(localState)) {
          batch.set(_col(user.uid, c.name)!.doc(c.idOf(item)), c.toJson(item),
              SetOptions(merge: true));
          if (++ops >= _kBatchLimit) await flush();
        }
      }

      await addAll(_projects);
      await addAll(_notes);
      await addAll(_orders);
      await addAll(_inbox);
      await addAll(_vendors);
      await addAll(_templates);
      await flush();

      state = state.copyWith(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e, stack) {
      log.error('sync', 'Error pushing local data to cloud', e, stack);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Diffs previous and next local states and pushes only changes to cloud.
  ///
  /// Edits are detected by `updatedAt` (every model stamps it on copyWith), so
  /// a change to any field syncs - the old per-field comparisons silently
  /// skipped edits such as an order's ETA or notes.
  Future<void> _syncChangedEntities(
      EngineeringState? prev, EngineeringState next) async {
    if (_authService.currentUser == null || _firestore == null) return;

    final futures = <Future<void>>[];

    void diff<T>(_SyncCollection<T> c) {
      final before = <String, T>{
        if (prev != null)
          for (final x in c.items(prev)) c.idOf(x): x,
      };
      final afterIds = <String>{};
      for (final x in c.items(next)) {
        final id = c.idOf(x);
        afterIds.add(id);
        final old = before[id];
        if (old == null || c.updatedAtOf(old) != c.updatedAtOf(x)) {
          futures.add(_pushDoc(c, x));
        }
      }
      for (final id in before.keys) {
        if (!afterIds.contains(id)) futures.add(_deleteDoc(c, id));
      }
    }

    diff(_projects);
    diff(_notes);
    diff(_orders);
    diff(_inbox);
    diff(_vendors);
    diff(_templates);

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void _stopListening() {
    for (final s in _collectionSubs) {
      s.cancel();
    }
    _collectionSubs.clear();
    _localStateSub?.close();
    _localStateSub = null;
  }
}
