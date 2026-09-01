import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/voice_note.dart';
import '../models/standalone_order.dart';
import '../models/inbox_item.dart';
import '../models/vendor.dart';
import '../models/project_template.dart';
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
  StreamSubscription? _ordersSub;
  StreamSubscription? _inboxSub;
  StreamSubscription? _vendorsSub;
  StreamSubscription? _templatesSub;
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

    // Real-time snapshot listener on user's standaloneOrders collection
    _ordersSub = firestore
        .collection('users')
        .doc(uid)
        .collection('standaloneOrders')
        .snapshots()
        .listen(
      (snapshot) {
        _handleOrdersSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore standalone orders sync error: $e');
      },
    );

    // Real-time snapshot listener on user's inbox collection
    _inboxSub = firestore
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .snapshots()
        .listen(
      (snapshot) {
        _handleInboxSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore inbox sync error: $e');
      },
    );

    // Real-time snapshot listener on user's vendors collection
    _vendorsSub = firestore
        .collection('users')
        .doc(uid)
        .collection('vendors')
        .snapshots()
        .listen(
      (snapshot) {
        _handleVendorsSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore vendors sync error: $e');
      },
    );

    // Real-time snapshot listener on user's customTemplates collection
    _templatesSub = firestore
        .collection('users')
        .doc(uid)
        .collection('templates')
        .snapshots()
        .listen(
      (snapshot) {
        _handleTemplatesSnapshot(snapshot);
      },
      onError: (e) {
        debugPrint('Firestore templates sync error: $e');
      },
    );

    // Push local changes (creates/edits) to the cloud automatically
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

  void _handleOrdersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        return StandaloneOrder.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteOrders.isNotEmpty) {
        _ref.read(projectProvider.notifier).mergeCloudStandaloneOrders(remoteOrders);
      } else if (localState.standaloneOrders.isNotEmpty) {
        pushAllLocalToCloud();
      }

      final remoteOrderIds = {for (final o in remoteOrders) o.id};
      final localAfter = _ref.read(projectProvider);
      for (final o in localAfter.standaloneOrders) {
        if (!remoteOrderIds.contains(o.id)) {
          syncStandaloneOrder(o);
        }
      }
    } catch (e) {
      debugPrint('Error merging remote standalone orders: $e');
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  void _handleInboxSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteItems = snapshot.docs.map((doc) {
        final data = doc.data();
        return InboxItem.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteItems.isNotEmpty) {
        _ref.read(projectProvider.notifier).mergeCloudInbox(remoteItems);
      } else if (localState.inboxItems.isNotEmpty) {
        pushAllLocalToCloud();
      }

      final remoteItemIds = {for (final i in remoteItems) i.id};
      final localAfter = _ref.read(projectProvider);
      for (final i in localAfter.inboxItems) {
        if (!remoteItemIds.contains(i.id)) {
          syncInboxItem(i);
        }
      }
    } catch (e) {
      debugPrint('Error merging remote inbox items: $e');
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  void _handleVendorsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteVendors = snapshot.docs.map((doc) {
        final data = doc.data();
        return Vendor.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteVendors.isNotEmpty) {
        _ref.read(projectProvider.notifier).mergeCloudVendors(remoteVendors);
      } else if (localState.vendors.isNotEmpty) {
        pushAllLocalToCloud();
      }

      final remoteVendorIds = {for (final v in remoteVendors) v.id};
      final localAfter = _ref.read(projectProvider);
      for (final v in localAfter.vendors) {
        if (!remoteVendorIds.contains(v.id)) {
          syncVendor(v);
        }
      }
    } catch (e) {
      debugPrint('Error merging remote vendors: $e');
    } finally {
      _isProcessingRemoteUpdate = false;
    }
  }

  void _handleTemplatesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      if (_isProcessingRemoteUpdate) return;
      _isProcessingRemoteUpdate = true;

      final remoteTemplates = snapshot.docs.map((doc) {
        final data = doc.data();
        return ProjectTemplate.fromJson(data);
      }).toList();

      final localState = _ref.read(projectProvider);

      if (remoteTemplates.isNotEmpty) {
        _ref.read(projectProvider.notifier).mergeCloudTemplates(remoteTemplates);
      } else if (localState.customTemplates.isNotEmpty) {
        pushAllLocalToCloud();
      }

      final remoteTemplateIds = {for (final t in remoteTemplates) t.id};
      final localAfter = _ref.read(projectProvider);
      for (final t in localAfter.customTemplates) {
        if (!remoteTemplateIds.contains(t.id)) {
          syncTemplate(t);
        }
      }
    } catch (e) {
      debugPrint('Error merging remote templates: $e');
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

  /// Push standalone order to cloud
  Future<void> syncStandaloneOrder(StandaloneOrder order) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('standaloneOrders')
          .doc(order.id)
          .set(order.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading standalone order: $e');
    }
  }

  Future<void> deleteCloudStandaloneOrder(String orderId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('standaloneOrders')
          .doc(orderId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud standalone order: $e');
    }
  }

  /// Push inbox item to cloud
  Future<void> syncInboxItem(InboxItem item) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('inbox')
          .doc(item.id)
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading inbox item: $e');
    }
  }

  Future<void> deleteCloudInboxItem(String itemId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('inbox')
          .doc(itemId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud inbox item: $e');
    }
  }

  /// Push vendor to cloud
  Future<void> syncVendor(Vendor vendor) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('vendors')
          .doc(vendor.id)
          .set(vendor.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading vendor: $e');
    }
  }

  Future<void> deleteCloudVendor(String vendorId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('vendors')
          .doc(vendorId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud vendor: $e');
    }
  }

  /// Push custom template to cloud
  Future<void> syncTemplate(ProjectTemplate template) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('templates')
          .doc(template.id)
          .set(template.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading template: $e');
    }
  }

  Future<void> deleteCloudTemplate(String templateId) async {
    final user = _authService.currentUser;
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('templates')
          .doc(templateId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting cloud template: $e');
    }
  }

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

  /// Push all local entities to cloud
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

      for (final order in localState.standaloneOrders) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('standaloneOrders')
            .doc(order.id);
        batch.set(docRef, order.toJson(), SetOptions(merge: true));
      }

      for (final item in localState.inboxItems) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('inbox')
            .doc(item.id);
        batch.set(docRef, item.toJson(), SetOptions(merge: true));
      }

      for (final vendor in localState.vendors) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('vendors')
            .doc(vendor.id);
        batch.set(docRef, vendor.toJson(), SetOptions(merge: true));
      }

      for (final template in localState.customTemplates) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('templates')
            .doc(template.id);
        batch.set(docRef, template.toJson(), SetOptions(merge: true));
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

  /// Diffs previous and next local states and pushes only changes to cloud.
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
    final prevOrders = {
      for (final o in prev?.standaloneOrders ?? const <StandaloneOrder>[]) o.id: o,
    };
    final prevInbox = {
      for (final i in prev?.inboxItems ?? const <InboxItem>[]) i.id: i,
    };
    final prevVendors = {
      for (final v in prev?.vendors ?? const <Vendor>[]) v.id: v,
    };
    final prevTemplates = {
      for (final t in prev?.customTemplates ?? const <ProjectTemplate>[]) t.id: t,
    };

    final futures = <Future<void>>[];

    // Projects
    for (final p in next.projects) {
      final old = prevProjects[p.id];
      if (old == null || old.updatedAt != p.updatedAt) {
        futures.add(syncProject(p));
      }
    }
    for (final old in prevProjects.values) {
      if (!next.projects.any((p) => p.id == old.id)) {
        futures.add(deleteCloudProject(old.id));
      }
    }

    // Voice Notes
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
    for (final old in prevNotes.values) {
      if (!next.voiceNotes.any((n) => n.id == old.id)) {
        futures.add(deleteCloudVoiceNote(old.id));
      }
    }

    // Standalone Orders
    for (final o in next.standaloneOrders) {
      final old = prevOrders[o.id];
      if (old == null ||
          old.pr != o.pr ||
          old.po != o.po ||
          old.description != o.description ||
          old.price != o.price ||
          old.delivered != o.delivered ||
          old.vendorName != o.vendorName) {
        futures.add(syncStandaloneOrder(o));
      }
    }
    for (final old in prevOrders.values) {
      if (!next.standaloneOrders.any((o) => o.id == old.id)) {
        futures.add(deleteCloudStandaloneOrder(old.id));
      }
    }

    // Inbox Items
    for (final i in next.inboxItems) {
      final old = prevInbox[i.id];
      if (old == null || old.text != i.text || old.isProcessed != i.isProcessed) {
        futures.add(syncInboxItem(i));
      }
    }
    for (final old in prevInbox.values) {
      if (!next.inboxItems.any((i) => i.id == old.id)) {
        futures.add(deleteCloudInboxItem(old.id));
      }
    }

    // Vendors
    for (final v in next.vendors) {
      final old = prevVendors[v.id];
      if (old == null ||
          old.name != v.name ||
          old.email != v.email ||
          old.phone != v.phone) {
        futures.add(syncVendor(v));
      }
    }
    for (final old in prevVendors.values) {
      if (!next.vendors.any((v) => v.id == old.id)) {
        futures.add(deleteCloudVendor(old.id));
      }
    }

    // Templates
    for (final t in next.customTemplates) {
      final old = prevTemplates[t.id];
      if (old == null || old.name != t.name) {
        futures.add(syncTemplate(t));
      }
    }
    for (final old in prevTemplates.values) {
      if (!next.customTemplates.any((t) => t.id == old.id)) {
        futures.add(deleteCloudTemplate(old.id));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void _stopListening() {
    _projectsSub?.cancel();
    _notesSub?.cancel();
    _ordersSub?.cancel();
    _inboxSub?.cancel();
    _vendorsSub?.cancel();
    _templatesSub?.cancel();
    _localStateSub?.close();
    _projectsSub = null;
    _notesSub = null;
    _ordersSub = null;
    _inboxSub = null;
    _vendorsSub = null;
    _templatesSub = null;
    _localStateSub = null;
  }

  @override
  void dispose() {
    _stopListening();
    _authSub?.cancel();
    super.dispose();
  }
}

