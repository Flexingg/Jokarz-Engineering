import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class TolerancesView extends StatelessWidget {
  const TolerancesView({super.key});

  static List<Map<String, dynamic>> _fits = [
    {
      'name': 'Loose Running Fit (H11 / c11)',
      'type': 'Clearance',
      'color': AppTheme.of().emerald,
      'app': 'Wide commercial tolerances, thermal expansion clearance, linkages exposed to dirt/grit.',
      'hole': 'H11 (+0.100 to 0.000 mm)',
      'shaft': 'c11 (-0.110 to -0.210 mm)',
    },
    {
      'name': 'Free Running Fit (H9 / d9)',
      'type': 'Clearance',
      'color': AppTheme.of().emerald,
      'app': 'Bearings with high rotational speed, heavy lubricant film, pulleys, 3D printed loose shafts.',
      'hole': 'H9 (+0.052 to 0.000 mm)',
      'shaft': 'd9 (-0.065 to -0.117 mm)',
    },
    {
      'name': 'Close Sliding Fit (H7 / g6)',
      'type': 'Clearance',
      'color': AppTheme.of().emerald,
      'app': 'Sliding spigots, precision guide pins, tool fixtures requiring smooth hand motion without play.',
      'hole': 'H7 (+0.015 to 0.000 mm)',
      'shaft': 'g6 (-0.005 to -0.014 mm)',
    },
    {
      'name': 'Locating Transition Fit (H7 / k6)',
      'type': 'Transition',
      'color': AppTheme.of().amber,
      'app': 'Accurate location with light mallet tap, gears/pulleys keyed to shafts with zero backlash.',
      'hole': 'H7 (+0.015 to 0.000 mm)',
      'shaft': 'k6 (+0.011 to +0.002 mm)',
    },
    {
      'name': 'Light Press / Drive Fit (H7 / p6)',
      'type': 'Interference',
      'color': AppTheme.of().coral,
      'app': 'Permanent press fit, ball bearing outer/inner races, brass bushings into aluminum bores.',
      'hole': 'H7 (+0.015 to 0.000 mm)',
      'shaft': 'p6 (+0.035 to +0.026 mm)',
    },
    {
      'name': 'Heavy Shrink Fit (H7 / u6)',
      'type': 'Interference',
      'color': AppTheme.of().coral,
      'app': 'Assembled with thermal shrink (freezing shaft or torching hub), maximum torque transmission.',
      'hole': 'H7 (+0.015 to 0.000 mm)',
      'shaft': 'u6 (+0.060 to +0.045 mm)',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'ISO Shaft & Hole Fits / Tolerances Guide',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Standard engineering limits & fits for precision machining, 3D print clearances, and bearing bores.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ..._fits.map((fit) {
          final color = fit['color'] as Color;
          return ExpressiveCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fit['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    ExpressiveBadge(
                      label: fit['type'] as String,
                      color: color,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  fit['app'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                  ),
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hole Tolerance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            fit['hole'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shaft Tolerance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            fit['shaft'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
