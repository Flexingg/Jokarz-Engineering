import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final GlobalKey _reportKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReport() async {
    setState(() => _isSharing = true);
    try {
      final boundary =
          _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/jokarz_report_$dateStr.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Jokarz Engineering Daily Report - $dateStr',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final today = DateTime.now();
    final weekEnd = today.add(const Duration(days: 7));
    final dateFormat = DateFormat('MMM d, y');
    final dateShort = DateFormat('MMM d');

    final activeProjects = state.activeProjects;
    final openOrders = state.openOrders;
    final standaloneOrders =
        state.standaloneOrders.where((o) => !o.delivered).toList();

    final tasksDueThisWeek = <Map<String, dynamic>>[];
    for (final p in activeProjects) {
      for (final t in p.tasks) {
        if (!t.isCompleted &&
            t.scheduledDate != null &&
            !t.scheduledDate!.isBefore(today) &&
            t.scheduledDate!.isBefore(weekEnd)) {
          tasksDueThisWeek.add({'project': p, 'task': t});
        }
      }
    }
    tasksDueThisWeek.sort((a, b) =>
        (a['task'].scheduledDate as DateTime)
            .compareTo(b['task'].scheduledDate as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          _isSharing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.share_rounded,
                      color: AppTheme.primaryCyan),
                  tooltip: 'Share / Print',
                  onPressed: _shareReport,
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(
            key: _reportKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportHeader(date: dateFormat.format(today)),
                    const SizedBox(height: 24),

                    // Active Projects
                    _ReportSection(
                      title: '1. Active Projects by Priority',
                      tagText: 'PROJ',
                      child: activeProjects.isEmpty
                          ? const Text('No active projects.',
                              style: TextStyle(color: Colors.grey, fontSize: 13))
                          : Table(
                              border: TableBorder.all(
                                  color: const Color(0xFFBDBDBD), width: 0.5),
                              columnWidths: const {
                                0: FixedColumnWidth(36),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(2),
                                4: FlexColumnWidth(2),
                              },
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(
                                      color: Color(0xFFF5F5F5)),
                                  children: [
                                    _TH('#'),
                                    _TH('Project'),
                                    _TH('Phase'),
                                    _TH('Machine'),
                                    _TH('Next Task'),
                                  ],
                                ),
                                ...activeProjects.map((p) {
                                  final nextTask = p.nextPendingTask;
                                  return TableRow(children: [
                                    _TD('${p.priority}', center: true),
                                    _TD(p.title, bold: true),
                                    _TD(p.phase),
                                    _TD(
                                        p.machine.isEmpty ? '-' : p.machine),
                                    _TD(
                                        nextTask?.description ?? '-',
                                        maxLines: 2),
                                  ]);
                                }),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Open Orders
                    _ReportSection(
                      title: '2. Open Purchase Orders',
                      tagText: 'PO',
                      child: (openOrders.isEmpty && standaloneOrders.isEmpty)
                          ? const Text('No open orders.',
                              style: TextStyle(color: Colors.grey, fontSize: 13))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (openOrders.isNotEmpty)
                                  Table(
                                    border: TableBorder.all(
                                        color: const Color(0xFFBDBDBD),
                                        width: 0.5),
                                    columnWidths: const {
                                      0: FlexColumnWidth(3),
                                      1: FlexColumnWidth(1.5),
                                      2: FlexColumnWidth(1.5),
                                      3: FlexColumnWidth(1.5),
                                      4: FlexColumnWidth(2),
                                    },
                                    children: [
                                      const TableRow(
                                        decoration: BoxDecoration(
                                            color: Color(0xFFF5F5F5)),
                                        children: [
                                          _TH('Description'),
                                          _TH('PR'),
                                          _TH('PO'),
                                          _TH('ETA'),
                                          _TH('Project'),
                                        ],
                                      ),
                                      ...openOrders.map((e) => TableRow(children: [
                                        _TD(e.order.description.isEmpty
                                            ? '-'
                                            : e.order.description,
                                            maxLines: 2),
                                        _TD(e.order.pr.isEmpty ? '-' : e.order.pr),
                                        _TD(e.order.po.isEmpty ? '-' : e.order.po),
                                        _TD(e.order.eta != null
                                            ? dateShort.format(e.order.eta!)
                                            : '-'),
                                        _TD(e.project.title, maxLines: 2),
                                      ])),
                                    ],
                                  ),
                                if (standaloneOrders.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Unlinked Orders:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  ...standaloneOrders.map((o) {
                                    final parts = <String>[
                                      '\u2022 ${o.description.isEmpty ? "(no description)" : o.description}',
                                      if (o.pr.isNotEmpty) 'PR: ${o.pr}',
                                      if (o.po.isNotEmpty) 'PO: ${o.po}',
                                      if (o.eta != null)
                                        'ETA: ${dateShort.format(o.eta!)}',
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(parts.join('  '),
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    );
                                  }),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Tasks Due This Week
                    _ReportSection(
                      title: '3. Tasks Due This Week',
                      tagText: 'CAL',
                      child: tasksDueThisWeek.isEmpty
                          ? const Text('No tasks scheduled this week.',
                              style: TextStyle(color: Colors.grey, fontSize: 13))
                          : Table(
                              border: TableBorder.all(
                                  color: const Color(0xFFBDBDBD), width: 0.5),
                              columnWidths: const {
                                0: FixedColumnWidth(70),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(2),
                              },
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(
                                      color: Color(0xFFF5F5F5)),
                                  children: [
                                    _TH('Date'),
                                    _TH('Task'),
                                    _TH('Project'),
                                  ],
                                ),
                                ...tasksDueThisWeek.map((e) {
                                  final task = e['task'];
                                  final project = e['project'] as Project;
                                  return TableRow(children: [
                                    _TD(dateShort
                                        .format(task.scheduledDate as DateTime)),
                                    _TD(task.description as String,
                                        maxLines: 2),
                                    _TD(project.title, maxLines: 2),
                                  ]);
                                }),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jokarz Engineering',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          'Generated: ${DateFormat('MMM d, y HH:mm').format(today)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareReport,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_rounded),
            label: const Text('Share / Print Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  final String date;
  const _ReportHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('JOKARZ ENGINEERING',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text('Daily Walk-Around Report \u2014 $date',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(height: 3, color: Colors.black87),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String tagText;
  final Widget child;
  const _ReportSection(
      {required this.title, required this.tagText, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4)),
            child: Text(tagText,
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
        ]),
        const SizedBox(height: 2),
        Container(height: 1, color: const Color(0xFFBDBDBD)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.black)),
    );
  }
}

class _TD extends StatelessWidget {
  final String text;
  final bool bold;
  final bool center;
  final int maxLines;
  const _TD(this.text,
      {this.bold = false, this.center = false, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
            color: Colors.black),
      ),
    );
  }
}
