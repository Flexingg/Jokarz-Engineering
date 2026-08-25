import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bolt_spec.dart';

// --- Fasteners Filter Provider ---
final fastenerSearchProvider = StateProvider<String>((ref) => '');
final fastenerStandardProvider = StateProvider<FastenerStandard?>((ref) => null);

final filteredFastenersProvider = Provider<List<BoltSpec>>((ref) {
  final search = ref.watch(fastenerSearchProvider).toLowerCase();
  final standard = ref.watch(fastenerStandardProvider);

  return BoltSpec.database.where((b) {
    final matchesSearch = search.isEmpty ||
        b.size.toLowerCase().contains(search) ||
        b.pitchOrTpi.toLowerCase().contains(search) ||
        b.tapDrillFraction.toLowerCase().contains(search) ||
        b.tapDrillMmLabel.toLowerCase().contains(search);
    final matchesStandard = standard == null || b.standard == standard;
    return matchesSearch && matchesStandard;
  }).toList();
});
