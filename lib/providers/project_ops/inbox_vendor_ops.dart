import '../../models/activity_log.dart';
import '../../models/downtime_event.dart';
import '../../models/inbox_item.dart';
import '../../models/standalone_order.dart';
import '../../models/task_item.dart';
import '../../models/vendor.dart';
import '../../models/voice_note.dart';
import 'notifier_core.dart';

/// Quick-capture inbox, triage and the vendor directory.
mixin InboxVendorOps on EngineeringNotifierCore {
  Future<void> addInboxItem(InboxItem item) async {
    final updated = [item, ...state.inboxItems];
    state = state.copyWith(inboxItems: updated);
    await logActivity(ActivityType.noteAdded, 'Quick dump: ${item.text}');
    await persist();
  }

  Future<void> updateInboxItem(InboxItem item) async {
    final updated = state.inboxItems.map((i) => i.id == item.id ? item : i).toList();
    state = state.copyWith(inboxItems: updated);
    await persist();
  }

  Future<void> deleteInboxItem(String id) async {
    final updated = state.inboxItems.where((i) => i.id != id).toList();
    state = state.copyWith(inboxItems: updated);
    await persist();
  }

  Future<void> dismissInboxItem(String id) async {
    final updated = state.inboxItems.map((i) {
      if (i.id == id) return i.copyWith(isProcessed: true);
      return i;
    }).toList();
    state = state.copyWith(inboxItems: updated);
    await persist();
  }

  /// Triage an inbox item directly into a task on an existing project.
  Future<void> triageToTask(String inboxId, String projectId, {DateTime? scheduledDate}) async {
    final inboxItem = state.inboxItems.where((i) => i.id == inboxId).firstOrNull;
    if (inboxItem == null) return;

    final task = TaskItem(
      description: inboxItem.text,
      scheduledDate: scheduledDate,
    );
    await addTask(projectId, task);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a new standalone purchase order.
  Future<void> triageToOrder(String inboxId, StandaloneOrder order) async {
    await addStandaloneOrder(order);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a machine downtime event.
  Future<void> triageToDowntime(String inboxId, DowntimeEvent downtime) async {
    await addDowntime(downtime);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a field note.
  Future<void> triageToNote(String inboxId, VoiceNote note) async {
    await addVoiceNote(note);
    await dismissInboxItem(inboxId);
  }

  Future<void> addVendor(Vendor vendor) async {
    final updated = [...state.vendors, vendor];
    state = state.copyWith(vendors: updated);
    await persist();
  }

  Future<void> updateVendor(Vendor vendor) async {
    final updated = state.vendors.map((v) => v.id == vendor.id ? vendor : v).toList();
    state = state.copyWith(vendors: updated);
    await persist();
  }

  Future<void> deleteVendor(String id) async {
    final updated = state.vendors.where((v) => v.id != id).toList();
    state = state.copyWith(vendors: updated);
    await persist();
  }
}
