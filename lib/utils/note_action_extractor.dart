import '../models/project.dart';

class ExtractedNoteAction {
  final bool hasTaskSuggestion;
  final String taskDescription;
  final DateTime? suggestedDate;
  final String? pendingReason;

  final bool hasOrderSuggestion;
  final String orderDescription;

  final String? detectedMachine;
  final String? matchedProjectId;

  const ExtractedNoteAction({
    this.hasTaskSuggestion = false,
    this.taskDescription = '',
    this.suggestedDate,
    this.pendingReason,
    this.hasOrderSuggestion = false,
    this.orderDescription = '',
    this.detectedMachine,
    this.matchedProjectId,
  });

  bool get hasAnySuggestion => hasTaskSuggestion || hasOrderSuggestion || detectedMachine != null;
}

const List<String> _plantMachineKeywords = [
  'conveyor', 'packer', 'case packer', 'capper', 'filler', 'robot', 'press',
  'palletizer', 'wrapper', 'stretch wrapper', 'chiller', 'boiler', 'pump',
  'gearbox', 'motor', 'air compressor', 'stacker', 'drop lifter', 'cartoner',
  'labeler', 'strapping machine', 'agitator', 'centrifuge', 'extruder',
];

const List<String> _procureKeywords = [
  'order', 'buy', 'purchase', 'quote', 'need to order', 'po for', 'reorder', 'source',
];

const List<String> _taskVerbs = [
  'replace', 'fix', 'install', 'inspect', 'clean', 'align', 'adjust',
  'calibrate', 'tighten', 'weld', 'wire', 'service', 'swap', 'grease',
  'lube', 'rebuild', 'troubleshoot', 'check', 'verify',
];

/// Analyzes note text to extract machines, task intents, dates, and order intents.
ExtractedNoteAction extractActionsFromText(String text, List<Project> existingProjects) {
  final clean = text.trim();
  if (clean.isEmpty) return const ExtractedNoteAction();

  final lower = clean.toLowerCase();

  // 1. Detect Machine
  String? matchedMachine;
  String? matchedProjectId;

  // First try exact matches with existing project machine names
  for (final p in existingProjects) {
    if (p.machine.isNotEmpty && lower.contains(p.machine.toLowerCase())) {
      matchedMachine = p.machine;
      matchedProjectId = p.id;
      break;
    }
  }

  // If not matched, scan generic machine keywords
  if (matchedMachine == null) {
    for (final kw in _plantMachineKeywords) {
      if (lower.contains(kw)) {
        // Capitalize words
        matchedMachine = kw.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
        break;
      }
    }
  }

  // 2. Detect Date
  DateTime? detectedDate;
  final now = DateTime.now();

  if (lower.contains('today')) {
    detectedDate = DateTime(now.year, now.month, now.day);
  } else if (lower.contains('tomorrow')) {
    detectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  } else if (lower.contains('monday')) {
    detectedDate = _nextWeekday(DateTime.monday);
  } else if (lower.contains('tuesday')) {
    detectedDate = _nextWeekday(DateTime.tuesday);
  } else if (lower.contains('wednesday')) {
    detectedDate = _nextWeekday(DateTime.wednesday);
  } else if (lower.contains('thursday')) {
    detectedDate = _nextWeekday(DateTime.thursday);
  } else if (lower.contains('friday')) {
    detectedDate = _nextWeekday(DateTime.friday);
  } else if (lower.contains('next week')) {
    detectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  // 3. Detect Pending Reason
  String? pendingReason;
  if (lower.contains('downtime') || lower.contains('shutdown')) {
    pendingReason = 'Pending downtime';
  } else if (lower.contains('parts') || lower.contains('delivery') || lower.contains('shipment')) {
    pendingReason = 'Pending parts';
  } else if (lower.contains('quote') || lower.contains('vendor')) {
    pendingReason = 'Pending vendor quote';
  } else if (lower.contains('email') || lower.contains('approval')) {
    pendingReason = 'Pending email';
  }

  // 4. Detect Procurement Intent
  bool hasOrder = false;
  String orderDesc = '';
  for (final pk in _procureKeywords) {
    final idx = lower.indexOf(pk);
    if (idx != -1) {
      hasOrder = true;
      // Extract from the keyword to the end or punctuation
      final after = clean.substring(idx + pk.length).trim();
      final sentenceEnd = after.indexOf(RegExp(r'[\.\n\r]'));
      orderDesc = (sentenceEnd != -1 ? after.substring(0, sentenceEnd) : after).trim();
      // Remove leading prepositions like "for", "of", "some"
      orderDesc = orderDesc.replaceFirst(RegExp(r'^(?:for|of|some|a|an)\s+', caseSensitive: false), '');
      break;
    }
  }

  // 5. Detect Task Action Intent
  bool hasTask = false;
  String taskDesc = '';
  for (final tv in _taskVerbs) {
    final idx = lower.indexOf(tv);
    if (idx != -1) {
      hasTask = true;
      final after = clean.substring(idx).trim();
      final sentenceEnd = after.indexOf(RegExp(r'[\.\n\r]'));
      taskDesc = (sentenceEnd != -1 ? after.substring(0, sentenceEnd) : after).trim();
      // Capitalize first letter
      if (taskDesc.isNotEmpty) {
        taskDesc = '${taskDesc[0].toUpperCase()}${taskDesc.substring(1)}';
      }
      break;
    }
  }

  // Fallback: if no specific verb found but order intent exists, create task for ordering
  if (!hasTask && clean.length > 5 && clean.length < 120) {
    hasTask = true;
    taskDesc = clean;
  }

  return ExtractedNoteAction(
    hasTaskSuggestion: hasTask && taskDesc.isNotEmpty,
    taskDescription: taskDesc,
    suggestedDate: detectedDate,
    pendingReason: pendingReason,
    hasOrderSuggestion: hasOrder && orderDesc.isNotEmpty,
    orderDescription: orderDesc,
    detectedMachine: matchedMachine,
    matchedProjectId: matchedProjectId,
  );
}

DateTime _nextWeekday(int targetWeekday) {
  final now = DateTime.now();
  int daysToAdd = (targetWeekday - now.weekday) % 7;
  if (daysToAdd <= 0) daysToAdd += 7;
  return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
}
