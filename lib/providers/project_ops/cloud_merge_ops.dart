import '../../models/inbox_item.dart';
import '../../models/project.dart';
import '../../models/project_template.dart';
import '../../models/standalone_order.dart';
import '../../models/vendor.dart';
import '../../models/voice_note.dart';
import '../../services/app_logger.dart';
import '../../services/sync_merge.dart';
import 'notifier_core.dart';

/// Cloud snapshot merge handlers (applied by the sync service).
///
/// Every collection is merged last-write-wins on `updatedAt` via
/// [mergeByUpdatedAt]. Each handler returns the conflicts it detected (edits
/// made here since [lastSyncedAt] that disagreed with the cloud) so the sync
/// layer can surface them; they are also written to the diagnostics log.
mixin CloudMergeOps on EngineeringNotifierCore {
  List<SyncConflict> _record(List<SyncConflict> conflicts) {
    for (final c in conflicts) {
      log.warn('sync', 'Merge conflict: ${c.summary}');
    }
    return conflicts;
  }

  Future<List<SyncConflict>> mergeCloudStandaloneOrders(
      List<StandaloneOrder> remoteOrders,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<StandaloneOrder>(
      collection: 'standaloneOrders',
      local: state.standaloneOrders,
      remote: remoteOrders,
      idOf: (o) => o.id,
      updatedAtOf: (o) => o.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(standaloneOrders: out.merged);
    await persist();
    return _record(out.conflicts);
  }

  Future<List<SyncConflict>> mergeCloudInbox(List<InboxItem> remoteItems,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<InboxItem>(
      collection: 'inbox',
      local: state.inboxItems,
      remote: remoteItems,
      idOf: (i) => i.id,
      updatedAtOf: (i) => i.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(inboxItems: out.merged);
    await persist();
    return _record(out.conflicts);
  }

  Future<List<SyncConflict>> mergeCloudVendors(List<Vendor> remoteVendors,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<Vendor>(
      collection: 'vendors',
      local: state.vendors,
      remote: remoteVendors,
      idOf: (v) => v.id,
      updatedAtOf: (v) => v.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(vendors: out.merged);
    await persist();
    return _record(out.conflicts);
  }

  Future<List<SyncConflict>> mergeCloudTemplates(
      List<ProjectTemplate> remoteTemplates,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<ProjectTemplate>(
      collection: 'templates',
      local: state.customTemplates,
      remote: remoteTemplates,
      idOf: (t) => t.id,
      updatedAtOf: (t) => t.updatedAt,
      lastSyncedAt: lastSyncedAt,
      skipRemote: (t) => t.isSystemTemplate,
    );
    state = state.copyWith(customTemplates: out.merged);
    await persist();
    return _record(out.conflicts);
  }

  Future<List<SyncConflict>> mergeCloudProjects(List<Project> remoteProjects,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<Project>(
      collection: 'projects',
      local: state.projects,
      remote: remoteProjects,
      idOf: (p) => p.id,
      updatedAtOf: (p) => p.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(projects: rebalancePriorities(out.merged));
    await persist();
    return _record(out.conflicts);
  }

  Future<List<SyncConflict>> mergeCloudNotes(List<VoiceNote> remoteNotes,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<VoiceNote>(
      collection: 'voiceNotes',
      local: state.voiceNotes,
      remote: remoteNotes,
      idOf: (n) => n.id,
      updatedAtOf: (n) => n.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(voiceNotes: out.merged);
    await persist();
    return _record(out.conflicts);
  }
}
