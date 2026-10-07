import '../../models/inbox_item.dart';
import '../../models/project.dart';
import '../../models/project_template.dart';
import '../../models/standalone_order.dart';
import '../../models/vendor.dart';
import '../../models/voice_note.dart';
import 'notifier_core.dart';

/// Cloud snapshot merge handlers (applied by the sync service).
mixin CloudMergeOps on EngineeringNotifierCore {
  Future<void> mergeCloudStandaloneOrders(List<StandaloneOrder> remoteOrders) async {
    final localMap = {for (var o in state.standaloneOrders) o.id: o};
    for (final remote in remoteOrders) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(standaloneOrders: localMap.values.toList());
    await persist();
  }

  Future<void> mergeCloudInbox(List<InboxItem> remoteItems) async {
    final localMap = {for (var i in state.inboxItems) i.id: i};
    for (final remote in remoteItems) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(inboxItems: localMap.values.toList());
    await persist();
  }

  Future<void> mergeCloudVendors(List<Vendor> remoteVendors) async {
    final localMap = {for (var v in state.vendors) v.id: v};
    for (final remote in remoteVendors) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(vendors: localMap.values.toList());
    await persist();
  }

  Future<void> mergeCloudTemplates(List<ProjectTemplate> remoteTemplates) async {
    final localMap = {for (var t in state.customTemplates) t.id: t};
    for (final remote in remoteTemplates) {
      if (!remote.isSystemTemplate) {
        localMap[remote.id] = remote;
      }
    }
    state = state.copyWith(customTemplates: localMap.values.toList());
    await persist();
  }

  Future<void> mergeCloudProjects(List<Project> remoteProjects) async {
    final localMap = {for (var p in state.projects) p.id: p};
    for (final remote in remoteProjects) {
      final local = localMap[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        localMap[remote.id] = remote;
      }
    }
    state = state.copyWith(
      projects: rebalancePriorities(localMap.values.toList()),
    );
    await persist();
  }

  Future<void> mergeCloudNotes(List<VoiceNote> remoteNotes) async {
    final localMap = {for (var n in state.voiceNotes) n.id: n};
    for (final remote in remoteNotes) {
      final local = localMap[remote.id];
      // Keep the newer edit (last-write-wins by updatedAt). This prevents a
      // stale device's older copy from clobbering newer local edits.
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        localMap[remote.id] = remote;
      }
    }
    state = state.copyWith(
      voiceNotes: localMap.values.toList(),
    );
    await persist();
  }
}
