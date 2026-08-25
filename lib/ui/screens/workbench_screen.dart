import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'calculators/simple_calculator_view.dart';
import 'calculators/triangle_solver_view.dart';
import 'calculators/fastener_chart_view.dart';
import 'calculators/torque_chart_view.dart';
import 'calculators/torque_calculator_view.dart';
import 'calculators/heat_shrink_calculator_view.dart';
import 'calculators/unit_converter_view.dart';
import 'calculators/tolerances_view.dart';

class WorkbenchScreen extends StatefulWidget {
  const WorkbenchScreen({super.key});

  @override
  State<WorkbenchScreen> createState() => _WorkbenchScreenState();
}

class _WorkbenchScreenState extends State<WorkbenchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchGoogleTranslateCamera() async {
    // Attempt deep link to Google Translate camera / image translation Japanese -> English
    final uri = Uri.parse('https://translate.google.com/?sl=ja&tl=en&op=images');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Translate')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching translate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.handyman_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text(
              'Mechanical Workbench',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Japanese Google Translate Camera Deeplink Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              onPressed: _launchGoogleTranslateCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text(
                '🇯🇵 Translate (JA ➔ EN)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryCyan,
          tabs: const [
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Calculator'),
            Tab(icon: Icon(Icons.change_history_rounded), text: 'Triangle Solver'),
            Tab(icon: Icon(Icons.grid_on_rounded), text: 'Tap & Drill Chart'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Torque Spec Chart'),
            Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Torque Solver'),
            Tab(icon: Icon(Icons.local_fire_department_rounded), text: 'Heat Shrink Fit'),
            Tab(icon: Icon(Icons.sync_alt_rounded), text: 'Unit Converter'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'ISO Tolerances'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SimpleCalculatorView(),
          TriangleSolverView(),
          FastenerChartView(),
          TorqueChartView(),
          TorqueCalculatorView(),
          HeatShrinkCalculatorView(),
          UnitConverterView(),
          TolerancesView(),
        ],
      ),
    );
  }
}
