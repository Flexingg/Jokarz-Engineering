import '../../models/activity_log.dart';
import '../../models/project.dart';
import 'notifier_core.dart';

/// "Park until": move a project to the bottom of the queue for a while (waiting
/// on parts, a downtime window) and have it return to its old rank by itself.
///
/// Rules:
/// * Active ranks stay unique 1..N; parked projects always sit after the
///   unparked ones.
/// * A parked project remembers its rank in `parkRestorePriority`.
/// * On the morning of `parkedUntil` it is reinserted at that rank (clamped to
///   the queue length). [applyDueParks] is idempotent, so it is safe for every
///   device to run it on launch, resume and at midnight.
/// * Manually re-ranking a parked project, or closing it, cancels the park.
mixin ParkingOps on EngineeringNotifierCore {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Active projects ordered the way the queue shows them: unparked by rank,
  /// then parked by rank.
  static List<Project> queueOrder(Iterable<Project> projects) {
    final active = projects.where((p) => !p.isCompletedOrCancelled).toList();
    active.sort((a, b) {
      final pa = a.isParked ? 1 : 0, pb = b.isParked ? 1 : 0;
      return pa != pb ? pa - pb : a.priority.compareTo(b.priority);
    });
    return active;
  }

  /// Renumbers [ordered] 1..N and appends the closed projects unchanged.
  List<Project> renumberQueue(List<Project> ordered, List<Project> closed) => [
    for (var i = 0; i < ordered.length; i++)
      ordered[i].priority == i + 1
          ? ordered[i]
          : ordered[i].copyWith(priority: i + 1),
    ...closed,
  ];

  /// Parks [projectId] until [until] (date only). No-op for closed projects.
  Future<void> parkProject(
    String projectId,
    DateTime until, {
    String reason = '',
  }) async {
    final project = getProjectById(projectId);
    if (project == null || project.isCompletedOrCancelled) return;
    final day = dateOnly(until);
    final restore = project.isParked
        ? (project.parkRestorePriority ?? project.priority)
        : project.priority;

    final closed = state.projects
        .where((p) => p.isCompletedOrCancelled)
        .toList();
    final others = queueOrder(state.projects.where((p) => p.id != projectId));
    final parked = project.copyWith(
      parkedUntil: day,
      parkRestorePriority: restore,
      parkReason: reason.trim(),
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(
      projects: renumberQueue([...others, parked], closed),
    );
    await logActivity(
      ActivityType.projectParked,
      'Parked until ${_fmt(day)}${reason.trim().isEmpty ? '' : ' (${reason.trim()})'}: ${project.title}',
      pid: project.id,
      ptitle: project.title,
    );
    await persist();
  }

  /// Ends the park now and puts the project back at its remembered rank.
  Future<void> unparkProject(String projectId) async {
    final project = getProjectById(projectId);
    if (project == null || !project.isParked) return;
    state = state.copyWith(projects: _reinsert(state.projects, [project]));
    await logActivity(
      ActivityType.projectUnparked,
      'Returned to the queue: ${project.title}',
      pid: project.id,
      ptitle: project.title,
    );
    await persist();
  }

  /// Returns every project whose park date has arrived to its old rank.
  /// Returns the titles that came back (empty when nothing was due).
  @override
  Future<List<String>> applyDueParks({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    final due = state.projects
        .where((p) => p.isParked && !dateOnly(p.parkedUntil!).isAfter(today))
        .toList();
    if (due.isEmpty) return const [];

    state = state.copyWith(projects: _reinsert(state.projects, due));
    for (final p in due) {
      await logActivity(
        ActivityType.projectUnparked,
        'Park ended, back in the queue: ${p.title}',
        pid: p.id,
        ptitle: p.title,
      );
    }
    await persist();
    return [for (final p in due) p.title];
  }

  /// Reinserts [returning] (currently parked) at their remembered ranks.
  /// Lowest remembered rank first, so each lands where it used to be.
  List<Project> _reinsert(List<Project> all, List<Project> returning) {
    final ids = returning.map((p) => p.id).toSet();
    final closed = all.where((p) => p.isCompletedOrCancelled).toList();
    final queue = queueOrder(all.where((p) => !ids.contains(p.id)));
    var unparked = queue.where((p) => !p.isParked).toList();
    final stillParked = queue.where((p) => p.isParked).toList();

    final back = [...returning]
      ..sort(
        (a, b) => (a.parkRestorePriority ?? a.priority).compareTo(
          b.parkRestorePriority ?? b.priority,
        ),
      );
    for (final p in back) {
      final want = p.parkRestorePriority ?? p.priority;
      final index = (want - 1).clamp(0, unparked.length);
      unparked = [...unparked]
        ..insert(index, p.copyWith(clearPark: true, updatedAt: DateTime.now()));
    }
    return renumberQueue([...unparked, ...stillParked], closed);
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
