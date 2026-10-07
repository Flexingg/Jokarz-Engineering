import '../../models/activity_log.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import 'notifier_core.dart';

/// Orders not attached to a project (PR/PO tracking).
mixin StandaloneOrderOps on EngineeringNotifierCore {
  @override
  Future<void> addStandaloneOrder(StandaloneOrder order) async {
    await logActivity(ActivityType.standaloneOrderAdded, 'Order: ${order.description}');
    final updated = [...state.standaloneOrders, order];
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> updateStandaloneOrder(StandaloneOrder order) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == order.id ? order : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> deleteStandaloneOrder(String id) async {
    final updated = state.standaloneOrders.where((o) => o.id != id).toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> setStandaloneOrderAddToStores(String id, bool value) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == id ? o.copyWith(addToStores: value) : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> markStandaloneOrderStoreRequested(String id) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == id ? o.copyWith(storeRequested: true) : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  Future<void> setStandaloneOrderStoreRequestNumber(String id, String num) async {
    final updated = state.standaloneOrders
        .map((o) =>
            o.id == id
                ? o.copyWith(storeRequestNumber: num.trim(), storeRequested: true)
                : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await persist();
  }

  /// Moves a standalone order into a project's orders list and removes it from standaloneOrders.
  Future<void> linkOrderToProject(String standaloneOrderId, String projectId) async {
    final project = getProjectById(projectId);
    final standalone = state.standaloneOrders
        .where((o) => o.id == standaloneOrderId)
        .firstOrNull;
    if (project == null || standalone == null) return;

    // Convert StandaloneOrder → OrderItem
    final orderItem = OrderItem(
      id: standalone.id,
      pr: standalone.pr,
      po: standalone.po,
      description: standalone.description,
      price: standalone.price,
      eta: standalone.eta,
      delivered: standalone.delivered,
      addToStores: standalone.addToStores,
      storeRequested: standalone.storeRequested,
      storeRequestNumber: standalone.storeRequestNumber,
      vendorId: standalone.vendorId,
      vendorName: standalone.vendorName,
      vendorQuoteNumber: standalone.vendorQuoteNumber,
      trackingUrl: standalone.trackingUrl,
      notes: standalone.notes,
      bammWorkOrders: standalone.bammWorkOrders,
    );

    final updatedOrders = [...project.orders, orderItem];
    final updatedProject = project.copyWith(orders: updatedOrders);
    final remainingStandalone =
        state.standaloneOrders.where((o) => o.id != standaloneOrderId).toList();

    state = state.copyWith(standaloneOrders: remainingStandalone);
    await updateProject(updatedProject);
  }
}
