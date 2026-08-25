import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'calculators/print_estimator_view.dart';
import 'calculators/fastener_chart_view.dart';
import 'calculators/electronics_view.dart';
import 'calculators/unit_converter_view.dart';
import 'calculators/tolerances_view.dart';

class WorkbenchScreen extends StatefulWidget {
  final int initialTabIndex;

  const WorkbenchScreen({super.key, this.initialTabIndex = 0});

  @override
  State<WorkbenchScreen> createState() => _WorkbenchScreenState();
}

class _WorkbenchScreenState extends State<WorkbenchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineering Workbench & Reference',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryCyan,
          tabs: const [
            Tab(icon: Icon(Icons.view_in_ar_rounded), text: '3D Print & Slicer'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Fasteners & Taps'),
            Tab(icon: Icon(Icons.electric_bolt_rounded), text: 'Electronics & Circuits'),
            Tab(icon: Icon(Icons.straighten_rounded), text: 'Unit Converter'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'ISO Fits & Limits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PrintEstimatorView(),
          FastenerChartView(),
          ElectronicsView(),
          UnitConverterView(),
          TolerancesView(),
        ],
      ),
    );
  }
}
