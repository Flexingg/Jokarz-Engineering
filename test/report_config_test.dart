import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/report_config.dart';

void main() {
  test('ReportConfig defaults', () {
    const c = ReportConfig();
    expect(c.showPriority, isTrue);
    expect(c.ordersDueDays, 5);
    expect(c.topProjectsLimit, 10);
    expect(c.sortBy, ReportSort.priority);
    expect(c.includeCompleted, isFalse);
  });

  test('ReportConfig JSON round-trip', () {
    const c = ReportConfig(
      showNotes: false,
      showCost: true,
      ordersDueDays: 3,
      topProjectsLimit: 7,
      sortBy: ReportSort.cost,
      groupByMachine: true,
      includeCompleted: true,
    );
    final restored = ReportConfig.fromJson(c.toJson());
    expect(restored.showNotes, isFalse);
    expect(restored.showCost, isTrue);
    expect(restored.ordersDueDays, 3);
    expect(restored.topProjectsLimit, 7);
    expect(restored.sortBy, ReportSort.cost);
    expect(restored.groupByMachine, isTrue);
    expect(restored.includeCompleted, isTrue);
  });

  test('ReportConfig copyWith updates fields', () {
    const c = ReportConfig();
    final c2 = c.copyWith(showPriority: false, maxOrders: 3);
    expect(c2.showPriority, isFalse);
    expect(c2.maxOrders, 3);
    expect(c2.showOrders, isTrue);
  });
}
