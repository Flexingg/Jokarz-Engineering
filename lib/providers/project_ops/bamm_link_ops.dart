import 'notifier_core.dart';

/// Linking projects, tasks and orders to BAMM work orders.
mixin BammLinkOps on EngineeringNotifierCore {
  Future<void> assignBammToProject(String projectId, String bammWo) async {
    final cleanWo = bammWo.trim();
    if (cleanWo.isEmpty) return;
    final project = getProjectById(projectId);
    if (project == null) return;
    if (project.bammWorkOrders.contains(cleanWo)) return;
    final updated = project.copyWith(bammWorkOrders: [...project.bammWorkOrders, cleanWo]);
    await updateProject(updated);
  }

  Future<void> removeBammFromProject(String projectId, String bammWo) async {
    final cleanWo = bammWo.trim();
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedList = project.bammWorkOrders.where((w) => w != cleanWo).toList();
    final updated = project.copyWith(bammWorkOrders: updatedList);
    await updateProject(updated);
  }

  Future<void> setProjectBammWorkOrders(String projectId, List<String> bammWos) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final updated = project.copyWith(bammWorkOrders: bammWos.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList());
    await updateProject(updated);
  }

  Future<void> assignBammToTask(String projectId, String taskId, String bammWo) async {
    final cleanWo = bammWo.trim();
    if (cleanWo.isEmpty) return;
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedTasks = project.tasks.map((t) {
      if (t.id == taskId && !t.bammWorkOrders.contains(cleanWo)) {
        return t.copyWith(bammWorkOrders: [...t.bammWorkOrders, cleanWo]);
      }
      return t;
    }).toList();
    await updateProject(project.copyWith(tasks: updatedTasks));
  }

  Future<void> removeBammFromTask(String projectId, String taskId, String bammWo) async {
    final cleanWo = bammWo.trim();
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedTasks = project.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(bammWorkOrders: t.bammWorkOrders.where((w) => w != cleanWo).toList());
      }
      return t;
    }).toList();
    await updateProject(project.copyWith(tasks: updatedTasks));
  }

  Future<void> assignBammToOrder(String projectId, String orderId, String bammWo) async {
    final cleanWo = bammWo.trim();
    if (cleanWo.isEmpty) return;
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId && !o.bammWorkOrders.contains(cleanWo)) {
        return o.copyWith(bammWorkOrders: [...o.bammWorkOrders, cleanWo]);
      }
      return o;
    }).toList();
    await updateProject(project.copyWith(orders: updatedOrders));
  }

  Future<void> removeBammFromOrder(String projectId, String orderId, String bammWo) async {
    final cleanWo = bammWo.trim();
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(bammWorkOrders: o.bammWorkOrders.where((w) => w != cleanWo).toList());
      }
      return o;
    }).toList();
    await updateProject(project.copyWith(orders: updatedOrders));
  }

  Future<void> assignBammToStandaloneOrder(String orderId, String bammWo) async {
    final cleanWo = bammWo.trim();
    if (cleanWo.isEmpty) return;
    final updated = state.standaloneOrders.map((o) {
      if (o.id == orderId && !o.bammWorkOrders.contains(cleanWo)) {
        return o.copyWith(bammWorkOrders: [...o.bammWorkOrders, cleanWo]);
      }
      return o;
    }).toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> removeBammFromStandaloneOrder(String orderId, String bammWo) async {
    final cleanWo = bammWo.trim();
    final updated = state.standaloneOrders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(bammWorkOrders: o.bammWorkOrders.where((w) => w != cleanWo).toList());
      }
      return o;
    }).toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  /// Finds all projects, tasks, and orders linked to a given BAMM Work Order #.
  List<Map<String, dynamic>> findItemsLinkedToBamm(String bammWo) {
    final clean = bammWo.trim().toLowerCase();
    final results = <Map<String, dynamic>>[];

    for (final p in state.projects) {
      if (p.bammWorkOrders.any((w) => w.toLowerCase() == clean)) {
        results.add({
          'type': 'project',
          'id': p.id,
          'title': p.title,
          'projectId': p.id,
        });
      }
      for (final t in p.tasks) {
        if (t.bammWorkOrders.any((w) => w.toLowerCase() == clean)) {
          results.add({
            'type': 'task',
            'id': t.id,
            'title': t.description,
            'projectId': p.id,
            'projectTitle': p.title,
          });
        }
      }
      for (final o in p.orders) {
        if (o.bammWorkOrders.any((w) => w.toLowerCase() == clean)) {
          results.add({
            'type': 'order',
            'id': o.id,
            'title': o.description.isNotEmpty ? o.description : (o.po.isNotEmpty ? o.po : o.pr),
            'projectId': p.id,
            'projectTitle': p.title,
          });
        }
      }
    }

    for (final so in state.standaloneOrders) {
      if (so.bammWorkOrders.any((w) => w.toLowerCase() == clean)) {
        results.add({
          'type': 'standalone_order',
          'id': so.id,
          'title': so.description.isNotEmpty ? so.description : (so.po.isNotEmpty ? so.po : so.pr),
        });
      }
    }

    return results;
  }
}
