import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../router/app_router.dart';

/// Brings parked projects back when their day arrives while the app is open:
/// at the next local midnight, and whenever the app returns to the foreground
/// (a laptop that slept through midnight). Launch and cloud syncs already run
/// the same check inside the project notifier. Shows a toast when something
/// came back.
class ParkScheduler extends ConsumerStatefulWidget {
  final Widget child;

  /// Test seam.
  final DateTime Function() clock;

  const ParkScheduler({
    super.key,
    required this.child,
    this.clock = DateTime.now,
  });

  @override
  ConsumerState<ParkScheduler> createState() => _ParkSchedulerState();
}

class _ParkSchedulerState extends ConsumerState<ParkScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNext();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _timer?.cancel();
    final now = widget.clock();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _timer = Timer(nextMidnight.difference(now), () async {
      await _check();
      if (mounted) _scheduleNext();
    });
  }

  Future<void> _check() async {
    final back = await ref
        .read(projectProvider.notifier)
        .applyDueParks(now: widget.clock());
    if (back.isEmpty || !mounted) return;
    final ctx = appRootContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            back.length == 1
                ? 'Back in the queue: ${back.first}'
                : '${back.length} projects are back in the queue',
          ),
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
      _scheduleNext();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
