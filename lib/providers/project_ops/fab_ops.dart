import '../../models/fab_job.dart';
import '../../services/app_logger.dart';
import '../../services/sync_merge.dart';
import 'notifier_core.dart';

/// The fabricators' list: jobs handed to fabricators, from a project task or
/// typed in directly.
mixin FabOps on EngineeringNotifierCore {
  Future<void> addFabJob(FabJob job) async {
    state = state.copyWith(fabJobs: [job, ...state.fabJobs]);
    await persistFabJobs();
  }

  Future<void> updateFabJob(FabJob job) async {
    state = state.copyWith(
      fabJobs: state.fabJobs.map((j) => j.id == job.id ? job : j).toList(),
    );
    await persistFabJobs();
  }

  Future<void> deleteFabJob(String id) => removeFabJobLocal(id);

  /// Also what the sync layer calls when another device deleted the job.
  Future<void> removeFabJobLocal(String id) async {
    state = state.copyWith(
      fabJobs: state.fabJobs.where((j) => j.id != id).toList(),
    );
    await persistFabJobs();
  }

  FabJob? fabJobForTask(String taskId) =>
      state.fabJobs.where((j) => j.taskId == taskId).firstOrNull;

  /// Puts a project task on the fab list (once; asking again returns the job
  /// that is already there). Null when the task no longer exists.
  Future<FabJob?> addTaskToFabList(String projectId, String taskId) async {
    final existing = fabJobForTask(taskId);
    if (existing != null) return existing;
    final project = getProjectById(projectId);
    final task = project?.tasks.where((t) => t.id == taskId).firstOrNull;
    if (project == null || task == null) return null;
    final job = FabJob(
      title: task.description,
      dueDate: task.scheduledDate,
      notes: task.pendingReason,
      projectId: projectId,
      taskId: taskId,
    );
    await addFabJob(job);
    return job;
  }

  Future<List<SyncConflict>> mergeCloudFabJobs(List<FabJob> remote,
      {DateTime? lastSyncedAt}) async {
    final out = mergeByUpdatedAt<FabJob>(
      collection: 'fabJobs',
      local: state.fabJobs,
      remote: remote,
      idOf: (j) => j.id,
      updatedAtOf: (j) => j.updatedAt,
      lastSyncedAt: lastSyncedAt,
    );
    state = state.copyWith(fabJobs: out.merged);
    await persistFabJobs();
    for (final c in out.conflicts) {
      log.warn('sync', 'Merge conflict: ${c.summary}');
    }
    return out.conflicts;
  }
}
