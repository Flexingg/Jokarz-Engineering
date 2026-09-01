import 'project.dart';
import 'order_item.dart';
import 'standalone_order.dart';
import 'downtime_event.dart';
import 'voice_note.dart';

enum MachineStatus {
  operational,
  inMaintenance,
  breakdown,
}

class MachineOrderEntry {
  final Project? project;
  final OrderItem? order;
  final StandaloneOrder? standaloneOrder;

  const MachineOrderEntry({
    this.project,
    this.order,
    this.standaloneOrder,
  });

  String get description => order?.description ?? standaloneOrder?.description ?? '';
  String get pr => order?.pr ?? standaloneOrder?.pr ?? '';
  String get po => order?.po ?? standaloneOrder?.po ?? '';
  double get price => order?.price ?? standaloneOrder?.price ?? 0.0;
  DateTime? get eta => order?.eta ?? standaloneOrder?.eta;
  bool get delivered => order?.delivered ?? standaloneOrder?.delivered ?? false;
  String get vendorName => order?.vendorName ?? standaloneOrder?.vendorName ?? '';
  String get trackingUrl => order?.trackingUrl ?? standaloneOrder?.trackingUrl ?? '';
}

/// A computed 360° summary of an individual plant machine or production line.
class MachineAsset {
  final String name;
  final List<Project> activeProjects;
  final List<Project> completedProjects;
  final List<MachineOrderEntry> openOrders;
  final List<DowntimeEvent> downtimes;
  final List<VoiceNote> notes;
  final List<String> subAssemblies;

  const MachineAsset({
    required this.name,
    this.activeProjects = const [],
    this.completedProjects = const [],
    this.openOrders = const [],
    this.downtimes = const [],
    this.notes = const [],
    this.subAssemblies = const [],
  });

  int get totalDowntimeEvents => downtimes.length;

  double get totalOpenOrderSpend {
    return openOrders
        .where((o) => !o.delivered)
        .fold(0.0, (prev, o) => prev + o.price);
  }

  MachineStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Check if there is a downtime event scheduled for today
    final hasTodayDowntime = downtimes.any((d) =>
        d.date.year == today.year &&
        d.date.month == today.month &&
        d.date.day == today.day);
    if (hasTodayDowntime) return MachineStatus.breakdown;

    // Check if there are active maintenance/installation projects
    final hasActiveMaintenance = activeProjects.any((p) =>
        p.category == ProjectCategory.maintenance &&
        (p.phase.toLowerCase() == ProjectPhases.installation.toLowerCase() ||
         p.phase.toLowerCase() == ProjectPhases.pending.toLowerCase()));
    if (hasActiveMaintenance) return MachineStatus.inMaintenance;

    return MachineStatus.operational;
  }
}

