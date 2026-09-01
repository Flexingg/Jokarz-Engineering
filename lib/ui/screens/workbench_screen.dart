import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import 'calculators/simple_calculator_view.dart';
import 'calculators/triangle_solver_view.dart';
import 'calculators/fastener_chart_view.dart';
import 'calculators/torque_chart_view.dart';
import 'calculators/torque_calculator_view.dart';
import 'calculators/heat_shrink_calculator_view.dart';
import 'calculators/japanese_translate_view.dart';
import 'calculators/unit_converter_view.dart';
import 'calculators/tolerances_view.dart';
import 'calculators/bubble_level_view.dart';
import 'calculators/sheet_metal_gauge_view.dart';
import 'calculators/welding_symbols_view.dart';
import 'calculators/pipe_sizes_view.dart';
import 'calculators/bearing_lube_view.dart';
import 'calculators/grease_dictionary_view.dart';

/// A single tool on the workbench. [widget] must be a const-constructible view.
class WorkbenchTool {
  final String label;
  final IconData icon;
  final Widget widget;
  const WorkbenchTool({
    required this.label,
    required this.icon,
    required this.widget,
  });
}

/// Registry of all available workbench tools, keyed by id.
const Map<String, WorkbenchTool> workbenchTools = {
  'calculator': WorkbenchTool(
      label: 'Calculator', icon: Icons.calculate_outlined, widget: SimpleCalculatorView()),
  'triangle': WorkbenchTool(
      label: 'Triangle Solver', icon: Icons.change_history_rounded, widget: TriangleSolverView()),
  'tapdrill': WorkbenchTool(
      label: 'Tap & Drill Chart', icon: Icons.grid_on_rounded, widget: FastenerChartView()),
  'torque_chart': WorkbenchTool(
      label: 'Torque Spec Chart', icon: Icons.table_chart_outlined, widget: TorqueChartView()),
  'torque_solver': WorkbenchTool(
      label: 'Torque Solver', icon: Icons.fitness_center_rounded, widget: TorqueCalculatorView()),
  'heat_shrink': WorkbenchTool(
      label: 'Heat Shrink Fit', icon: Icons.local_fire_department_rounded, widget: HeatShrinkCalculatorView()),
  'translate': WorkbenchTool(
      label: 'Translate (JA → EN)', icon: Icons.translate_rounded, widget: JapaneseTranslateView()),
  'converter': WorkbenchTool(
      label: 'Unit Converter', icon: Icons.sync_alt_rounded, widget: UnitConverterView()),
  'tolerances': WorkbenchTool(
      label: 'ISO Tolerances', icon: Icons.tune_rounded, widget: TolerancesView()),
  'level': WorkbenchTool(
      label: 'Bubble Level', icon: Icons.speed_rounded, widget: BubbleLevelView()),
  'sheetmetal': WorkbenchTool(
      label: 'Sheet Metal Gauge', icon: Icons.straighten_rounded, widget: SheetMetalGaugeView()),
  'weld': WorkbenchTool(
      label: 'Welding Symbols', icon: Icons.format_shapes_rounded, widget: WeldingSymbolsView()),
  'pipe': WorkbenchTool(
      label: 'Pipe Sizes', icon: Icons.linear_scale_rounded, widget: PipeSizesView()),
  'bearing': WorkbenchTool(
      label: 'Bearing Lube', icon: Icons.opacity_rounded, widget: BearingLubeView()),
  'grease': WorkbenchTool(
      label: 'Grease Dictionary', icon: Icons.menu_book_rounded, widget: GreaseDictionaryView()),
};

/// User-chosen order of tools on the top bar. Defaults to registry order.
final toolOrderProvider = StateProvider<List<String>>((ref) {
  return workbenchTools.keys.toList();
});

class WorkbenchScreen extends ConsumerWidget {
  const WorkbenchScreen({super.key});

  void _openReorderSheet(BuildContext context, WidgetRef ref, List<String> order) {
    final working = [...order];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 14, bottom: 4),
                  child: Text('Arrange Tools',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Text('Drag to change the order of the top bar.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView(
                    onReorderItem: (o, n) {
                      setSheetState(() {
                        final item = working.removeAt(o);
                        working.insert(n, item);
                      });
                    },
                    children: [
                      for (final k in working)
                        ListTile(
                          key: ValueKey(k),
                          leading: Icon(workbenchTools[k]!.icon, color: AppTheme.of(context).primary),
                          title: Text(workbenchTools[k]!.label),
                          trailing: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.of(context).emerald,
                          foregroundColor: Colors.black87),
                      onPressed: () {
                        ref.read(toolOrderProvider.notifier).state = working;
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Order'),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(toolOrderProvider);

    return DefaultTabController(
      length: order.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.handyman_rounded, color: AppTheme.of(context).primary),
              SizedBox(width: 8),
              Text(
                'Tools',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Arrange Tools',
              icon: Icon(Icons.reorder_rounded, color: AppTheme.of(context).primary),
              onPressed: () => _openReorderSheet(context, ref, order),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.of(context).primary,
            tabs: [
              for (final k in order)
                Tab(icon: Icon(workbenchTools[k]!.icon), text: workbenchTools[k]!.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final k in order) workbenchTools[k]!.widget],
        ),
      ),
    );
  }
}
