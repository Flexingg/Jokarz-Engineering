import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/project.dart';
import '../models/report_config.dart';
import '../providers/project_provider.dart';

/// Flat, export-friendly representations of report rows.
class ReportProject {
  final String title;
  final int priority;
  final String phase;
  final String machine;
  final String nextStep;
  final double cost;
  final String lastAction;
  const ReportProject({
    required this.title,
    required this.priority,
    required this.phase,
    required this.machine,
    required this.nextStep,
    required this.cost,
    required this.lastAction,
  });
}

class ReportOrder {
  final String desc;
  final String po;
  final String pr;
  final double price;
  final String eta;
  final String project;
  final String store;
  const ReportOrder({
    required this.desc,
    required this.po,
    required this.pr,
    required this.price,
    required this.eta,
    required this.project,
    required this.store,
  });
}

class ReportTask {
  final String project;
  final String task;
  const ReportTask({required this.project, required this.task});
}

class ReportNote {
  final String label;
  final String text;
  const ReportNote({required this.label, required this.text});
}

class ReportData {
  final List<ReportProject> projects;
  final List<ReportOrder> orders;
  final List<ReportTask> dueToday;
  final List<ReportNote> notes;
  final List<ReportOrder> stores;
  final List<ReportProject> closed;
  final double totalOpenCost;
  final List<ReportProject> topByCost;
  const ReportData({
    this.projects = const [],
    this.orders = const [],
    this.dueToday = const [],
    this.notes = const [],
    this.stores = const [],
    this.closed = const [],
    this.totalOpenCost = 0,
    this.topByCost = const [],
  });
}

/// Builds the structured report data from app state according to [cfg].
ReportData buildReportData(EngineeringState state, ReportConfig cfg, DateTime today) {
  final todayDateStr = DateFormat('MM/dd/yyyy').format(today);

  List<ReportProject> projectRows(Iterable<Project> ps) => ps.map((p) {
        final next = p.nextPendingTask;
        final last =
            p.daysSinceLastAction > 0 ? '${p.daysSinceLastAction}d' : 'today';
        return ReportProject(
          title: p.title,
          priority: p.priority,
          phase: p.phase,
          machine: p.machine,
          nextStep: next != null
              ? next.description +
                  (next.pendingReason.isNotEmpty ? ' [${next.pendingReason}]' : '')
              : '—',
          cost: p.totalProjectCost,
          lastAction: last,
        );
      }).toList();

  // Top projects (exclude terminal unless includeCompleted)
  var top = cfg.includeCompleted
      ? state.sortedProjects
      : state.activeProjects;
  switch (cfg.sortBy) {
    case ReportSort.cost:
      top = [...top]..sort((a, b) => b.cost.compareTo(a.cost));
    case ReportSort.nextAction:
      top = [...top]..sort((a, b) {
          final da = a.daysSinceLastAction;
          final db = b.daysSinceLastAction;
          return db.compareTo(da);
        });
    case ReportSort.priority:
      top = [...top]..sort((a, b) => a.priority.compareTo(b.priority));
  }
  final projects = projectRows(top.take(cfg.topProjectsLimit));

  final topByCost = projectRows(
      ([...state.projects]..sort((a, b) => b.totalProjectCost.compareTo(a.totalProjectCost)))
          .take(5));

  // Orders due within lookback window (open orders + standalone)
  final orders = <ReportOrder>[];
  for (final e in state.openOrders) {
    final eta = e.order.eta;
    if (eta == null) continue;
    final days = DateUtils.dateOnly(eta)
        .difference(DateUtils.dateOnly(today))
        .inDays;
    if (days >= 0 && days <= cfg.ordersDueDays) {
      orders.add(ReportOrder(
        desc: e.order.description.isEmpty ? 'Parts / Material Order' : e.order.description,
        po: e.order.po,
        pr: e.order.pr,
        price: e.order.price,
        eta: DateFormat('MMM d').format(eta),
        project: e.project.title,
        store: _storeLabel(e.order.addToStores, e.order.storeRequested, e.order.storeRequestNumber),
      ));
    }
  }
  orders.sort((a, b) => a.eta.compareTo(b.eta));

  // Stores-pending orders (flagged add-to-stores, not fully done)
  final stores = <ReportOrder>[];
  for (final e in state.openOrders) {
    final o = e.order;
    if (!o.addToStores) continue;
    if (o.storeRequestNumber.isNotEmpty) continue; // done
    stores.add(ReportOrder(
      desc: o.description.isEmpty ? 'Parts / Material Order' : o.description,
      po: o.po,
      pr: o.pr,
      price: o.price,
      eta: o.eta != null ? DateFormat('MMM d').format(o.eta!) : 'Unscheduled',
      project: e.project.title,
      store: o.po.isEmpty
          ? 'No PO yet'
          : (o.storeRequested ? 'Requested' : 'Pending request'),
    ));
  }

  // Tasks due today
  final dueToday = <ReportTask>[];
  for (final p in state.projects) {
    for (final t in p.tasks) {
      if (!t.isCompleted && t.scheduledDate != null &&
          DateUtils.isSameDay(t.scheduledDate!, today)) {
        dueToday.add(ReportTask(project: p.title, task: t.description));
      }
    }
  }

  // Notes containing today's date (mm/dd/yyyy)
  final notes = <ReportNote>[];
  for (final n in state.voiceNotes) {
    if (n.title.contains(todayDateStr) || n.transcript.contains(todayDateStr)) {
      notes.add(ReportNote(label: n.title, text: n.transcript));
    }
  }
  for (final p in state.projects) {
    if (p.notes.contains(todayDateStr)) {
      notes.add(ReportNote(label: '${p.title} (notes)', text: p.notes));
    }
  }

  // Recently closed (within notTouchedDays)
  final closed = <ReportProject>[];
  if (cfg.showClosed) {
    for (final p in state.terminalProjects) {
      final ref = p.completedAt ?? p.updatedAt;
      final days = DateUtils.dateOnly(today)
          .difference(DateUtils.dateOnly(ref))
          .inDays;
      if (days <= cfg.notTouchedDays) {
        closed.addAll(projectRows([p]));
      }
    }
    closed.sort((a, b) => a.priority.compareTo(b.priority));
  }

  double totalOpen = 0;
  for (final e in state.openOrders) {
    totalOpen += e.order.price;
  }

  return ReportData(
    projects: projects,
    orders: orders.take(cfg.maxOrders).toList(),
    dueToday: dueToday,
    notes: notes,
    stores: stores.take(cfg.maxOrders).toList(),
    closed: closed,
    totalOpenCost: totalOpen,
    topByCost: topByCost,
  );
}

String _storeLabel(bool addToStores, bool requested, String num) {
  if (!addToStores) return '';
  if (num.isNotEmpty) return 'Stores #$num ✓';
  if (requested) return 'Requested';
  return 'Add to stores';
}

/// Renders the report as a plain-text document.
String reportToText(ReportData d, ReportConfig cfg, DateTime today) {
  const hr = '============================================================';
  final b = StringBuffer();
  b.writeln('Daily Report — ${DateFormat('MM/dd/yyyy').format(today)}');
  b.writeln(hr);

  if (cfg.showPriority) {
    b.writeln('\nTOP PROJECTS & NEXT STEPS');
    for (final p in d.projects) {
      b.writeln('  #${p.priority} ${p.title} [${p.phase}]');
      if (p.machine.isNotEmpty) b.writeln('     Machine: ${p.machine}');
      b.writeln('     Next: ${p.nextStep}');
    }
  }

  if (cfg.showOrders) {
    b.writeln('\nORDERS DUE (NEXT ${cfg.ordersDueDays} DAYS)');
    if (d.orders.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final o in d.orders) {
        b.writeln('  ${o.eta} | ${o.project} | PO ${o.po.isEmpty ? '—' : o.po} | \$${o.price.toStringAsFixed(2)} | ${o.desc}');
      }
    }
  }

  if (cfg.showStores) {
    b.writeln('\nSTORES REQUESTS PENDING');
    if (d.stores.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final o in d.stores) {
        b.writeln('  ${o.project} | ${o.desc} | ${o.store}');
      }
    }
  }

  if (cfg.showDueToday) {
    b.writeln('\nDUE / HAPPENING TODAY');
    if (d.dueToday.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final t in d.dueToday) {
        b.writeln('  ${t.project}: ${t.task}');
      }
    }
  }

  if (cfg.showNotes) {
    b.writeln('\nNOTES (TODAY ${DateFormat('MM/dd/yyyy').format(today)})');
    if (d.notes.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final n in d.notes) {
        b.writeln('  • ${n.label}: ${n.text}');
      }
    }
  }

  if (cfg.showCost) {
    b.writeln('\nCOST SUMMARY');
    b.writeln('  Total Open PO Spend: \$${d.totalOpenCost.toStringAsFixed(2)}');
    if (d.topByCost.isNotEmpty) {
      b.writeln('  Top projects by cost:');
      for (final p in d.topByCost) {
        b.writeln('    ${p.title} — \$${p.cost.toStringAsFixed(2)}');
      }
    }
  }

  if (cfg.showClosed) {
    b.writeln('\nRECENTLY CLOSED');
    if (d.closed.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final p in d.closed) {
        b.writeln('  #${p.priority} ${p.title} [${p.phase}]');
      }
    }
  }
  return b.toString();
}

/// Renders the report as CSV (a flat table with a section column).
String reportToCsv(ReportData d, ReportConfig cfg, DateTime today) {
  final b = StringBuffer();
  b.writeln('Section,Project/Title,Detail,PO/PR,Price,ETA,Extra');
  void row(String sec, String proj, String detail, String po, String price, String eta, String extra) {
    b.writeln('"$sec","${_csv(proj)}","${_csv(detail)}","${_csv(po)}","${_csv(price)}","${_csv(eta)}","${_csv(extra)}"');
  }
  if (cfg.showPriority) {
    for (final p in d.projects) {
      row('Priority', p.title, 'Phase: ${p.phase} • Next: ${p.nextStep}', '', '\$${p.cost.toStringAsFixed(2)}', '', p.machine);
    }
  }
  if (cfg.showOrders) {
    for (final o in d.orders) {
      row('Order Due', o.project, o.desc, 'PO ${o.po} PR ${o.pr}', '\$${o.price.toStringAsFixed(2)}', o.eta, o.store);
    }
  }
  if (cfg.showStores) {
    for (final o in d.stores) {
      row('Stores', o.project, o.desc, 'PO ${o.po}', '\$${o.price.toStringAsFixed(2)}', o.eta, o.store);
    }
  }
  if (cfg.showDueToday) {
    for (final t in d.dueToday) {
      row('Due Today', t.project, t.task, '', '', '', '');
    }
  }
  if (cfg.showNotes) {
    for (final n in d.notes) {
      row('Note', n.label, n.text, '', '', '', '');
    }
  }
  if (cfg.showCost) {
    row('Cost', 'Total Open PO', '', '', '\$${d.totalOpenCost.toStringAsFixed(2)}', '', '');
    for (final p in d.topByCost) {
      row('Cost', p.title, '', '', '\$${p.cost.toStringAsFixed(2)}', '', '');
    }
  }
  if (cfg.showClosed) {
    for (final p in d.closed) {
      row('Closed', p.title, 'Phase: ${p.phase}', '', '', '', '');
    }
  }
  return b.toString();
}

String _csv(String s) => s.replaceAll('"', '""');

/// Renders the report as a PDF document.
Future<Uint8List> reportToPdf(ReportData d, ReportConfig cfg, DateTime today) async {
  final doc = pw.Document();
  final text = reportToText(d, cfg, today);
  const hr = '============================================================';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Text('Jokarz Engineering — Daily Report',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(DateFormat('MM/dd/yyyy h:mm a').format(today),
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        for (final line in text.split('\n'))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(line == hr ? '' : line,
                style: const pw.TextStyle(fontSize: 9)),
          ),
      ],
    ),
  );
  return doc.save();
}
