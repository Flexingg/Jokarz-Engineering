import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import 'calculators/simple_calculator_view.dart';
import 'calculators/triangle_solver_view.dart';
import 'calculators/fastener_chart_view.dart';
import 'calculators/torque_chart_view.dart';
import 'calculators/torque_calculator_view.dart';
import 'calculators/heat_shrink_calculator_view.dart';
import 'calculators/oring_calculator_view.dart';
import 'calculators/cylinder_calculator_view.dart';
import 'calculators/belt_calculator_view.dart';
import 'calculators/motor_drivetrain_view.dart';
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
  final List<String> keywords;

  const WorkbenchTool({
    required this.label,
    required this.icon,
    required this.widget,
    this.keywords = const [],
  });
}

/// Registry of all available workbench tools, keyed by id.
const Map<String, WorkbenchTool> workbenchTools = {
  'calculator': WorkbenchTool(
    label: 'Calculator',
    icon: Icons.calculate_outlined,
    widget: SimpleCalculatorView(),
    keywords: ['calc', 'tape', 'math', 'square root', 'memory'],
  ),
  'oring': WorkbenchTool(
    label: 'O-Ring & Gland',
    icon: Icons.radio_button_checked_rounded,
    widget: ORingCalculatorView(),
    keywords: ['seal', 'gland', 'as568', 'hydraulic', 'face seal', 'radial', 'groove', 'squeeze'],
  ),
  'cylinder': WorkbenchTool(
    label: 'Cylinder Sizing',
    icon: Icons.sync_problem_rounded,
    widget: CylinderCalculatorView(),
    keywords: ['pneumatic', 'air', 'hydraulic', 'bore', 'rod', 'thrust', 'force', 'cfm', 'flow'],
  ),
  'belt': WorkbenchTool(
    label: 'Belt & Pulley',
    icon: Icons.all_inclusive_rounded,
    widget: BeltCalculatorView(),
    keywords: ['timing belt', 'v-belt', 'pulley', 'center distance', 'htd', 'gt2', 'ratio', 'wrap'],
  ),
  'motor': WorkbenchTool(
    label: 'Motor & Gearbox',
    icon: Icons.electric_meter_rounded,
    widget: MotorDrivetrainView(),
    keywords: ['hp', 'kw', 'rpm', 'vfd', 'frequency', 'gear ratio', 'reducer', 'torque'],
  ),
  'triangle': WorkbenchTool(
    label: 'Triangle Solver',
    icon: Icons.change_history_rounded,
    widget: TriangleSolverView(),
    keywords: ['trig', 'angle', 'hypotenuse', 'sine', 'cosine'],
  ),
  'tapdrill': WorkbenchTool(
    label: 'Tap & Drill Chart',
    icon: Icons.grid_on_rounded,
    widget: FastenerChartView(),
    keywords: ['thread', 'm50', 'unc', 'unf', 'clearance', 'allen'],
  ),
  'torque_chart': WorkbenchTool(
    label: 'Torque Spec Chart',
    icon: Icons.table_chart_outlined,
    widget: TorqueChartView(),
    keywords: ['bolt', 'grade 8', 'grade 5', '10.9', '12.9', 'ft-lb', 'n-m'],
  ),
  'torque_solver': WorkbenchTool(
    label: 'Torque Solver',
    icon: Icons.fitness_center_rounded,
    widget: TorqueCalculatorView(),
    keywords: ['k factor', 'clamp force', 'preload', 'bolt stress'],
  ),
  'heat_shrink': WorkbenchTool(
    label: 'Heat Shrink Fit',
    icon: Icons.local_fire_department_rounded,
    widget: HeatShrinkCalculatorView(),
    keywords: ['thermal', 'expansion', 'interference', 'temper', 'straw', 'blue oxide'],
  ),
  'translate': WorkbenchTool(
    label: 'Translate (JA → EN)',
    icon: Icons.translate_rounded,
    widget: JapaneseTranslateView(),
    keywords: ['camera', 'japanese', 'kanji', 'machine label'],
  ),
  'converter': WorkbenchTool(
    label: 'Unit Converter',
    icon: Icons.sync_alt_rounded,
    widget: UnitConverterView(),
    keywords: ['convert', 'psi', 'bar', 'metric', 'imperial', 'inch', 'mm'],
  ),
  'tolerances': WorkbenchTool(
    label: 'ISO Tolerances',
    icon: Icons.tune_rounded,
    widget: TolerancesView(),
    keywords: ['h7', 'g6', 'shaft', 'hole', 'fit', 'clearance'],
  ),
  'level': WorkbenchTool(
    label: 'Bubble Level',
    icon: Icons.speed_rounded,
    widget: BubbleLevelView(),
    keywords: ['inclinometer', 'pitch', 'roll', 'plumb', 'leveling'],
  ),
  'sheetmetal': WorkbenchTool(
    label: 'Sheet Metal Gauge',
    icon: Icons.straighten_rounded,
    widget: SheetMetalGaugeView(),
    keywords: ['gauge', 'ga', 'thickness', 'stainless', 'galvanized'],
  ),
  'weld': WorkbenchTool(
    label: 'Welding Symbols',
    icon: Icons.format_shapes_rounded,
    widget: WeldingSymbolsView(),
    keywords: ['fillet', 'groove', 'aws', 'weld arrow'],
  ),
  'pipe': WorkbenchTool(
    label: 'Pipe Sizes',
    icon: Icons.linear_scale_rounded,
    widget: PipeSizesView(),
    keywords: ['npt', 'schedule 40', 'schedule 80', 'nominal pipe'],
  ),
  'bearing': WorkbenchTool(
    label: 'Bearing Lube',
    icon: Icons.opacity_rounded,
    widget: BearingLubeView(),
    keywords: ['grease', 'viscosity', 'ndm', 'relube interval'],
  ),
  'grease': WorkbenchTool(
    label: 'Grease Dictionary',
    icon: Icons.menu_book_rounded,
    widget: GreaseDictionaryView(),
    keywords: ['nlgi', 'polyurea', 'lithium complex', 'compatibility'],
  ),
};

/// User-chosen order of tools on the top bar. Defaults to registry order.
final toolOrderProvider = StateProvider<List<String>>((ref) {
  return workbenchTools.keys.toList();
});

class WorkbenchScreen extends ConsumerWidget {
  final String? initialToolId;
  const WorkbenchScreen({super.key, this.initialToolId});

  void _openReorderSheet(BuildContext context, WidgetRef ref, List<String> order) {
    final working = [...order];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                          leading: Icon(workbenchTools[k]?.icon ?? Icons.build_rounded, color: AppTheme.of(context).primary),
                          title: Text(workbenchTools[k]?.label ?? k),
                          trailing: Icon(Icons.drag_handle_rounded, color: AppTheme.of(context).textSecondary),
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
                          foregroundColor: AppTheme.onColor(AppTheme.of(context).emerald)),
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
    final targetIdx = initialToolId != null ? order.indexOf(initialToolId!) : -1;
    final initialIndex = targetIdx >= 0 ? targetIdx : 0;

    return DefaultTabController(
      key: ValueKey('workbench_tabs_${initialToolId ?? "default"}'),
      initialIndex: initialIndex,
      length: order.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.handyman_rounded, color: AppTheme.of(context).primary),
              const SizedBox(width: 8),
              const Text(
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
                if (workbenchTools.containsKey(k))
                  Tab(icon: Icon(workbenchTools[k]!.icon), text: workbenchTools[k]!.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in order)
              if (workbenchTools.containsKey(k)) workbenchTools[k]!.widget,
          ],
        ),
      ),
    );
  }
}
