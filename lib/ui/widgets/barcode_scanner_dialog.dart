import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/project_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/barcode_label_pdf.dart';
import '../../utils/barcode_utils.dart';
import '../fluid/fluid_dialog.dart';
import 'expressive_badge.dart';

/// Opens the Industrial Barcode & QR Scanner dialog.
/// Supports USB / Bluetooth physical barcode guns (keyboard wedge) and manual keyboard entry.
Future<void> showBarcodeScannerDialog(BuildContext context) {
  return showFluidDialog(
    context: context,
    builder: (ctx) => const BarcodeScannerDialog(),
  );
}

/// Shows a preview modal for a barcode label with 1-click PDF printing / sharing.
Future<void> showBarcodeLabelPreviewDialog(
  BuildContext context,
  BarcodeLabelData labelData,
) {
  return showFluidDialog(
    context: context,
    builder: (ctx) => BarcodeLabelPreviewModal(labelData: labelData),
  );
}

class BarcodeScannerDialog extends ConsumerStatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  ConsumerState<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends ConsumerState<BarcodeScannerDialog> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String _statusMessage = 'Ready. Aim scanner gun or type code.';
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _processScanned(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;

    final state = ref.read(projectProvider);
    final router = appRouter;

    // 1. Detect BAMM Work Order (e.g. "WO:185586" or "WO-185586" or pure 6-digit number)
    final woMatch = RegExp(r'^(?:WO[:\-]?)?(\d{5,7})$', caseSensitive: false).firstMatch(code);
    if (woMatch != null && (code.toUpperCase().contains('WO') || code.length == 6)) {
      final woNum = woMatch.group(1)!;
      Navigator.pop(context);
      router.go('/bamm?wo=$woNum');
      return;
    }

    // 2. Detect Project ID (e.g. "PROJ:id" or "PROJ-1042" or matching project id / priority)
    final projMatch = RegExp(r'^(?:PROJ[:\-]?)?([a-zA-Z0-9\-_]+)$', caseSensitive: false).firstMatch(code);
    if (code.toUpperCase().startsWith('PROJ:') || code.toUpperCase().startsWith('PROJ-')) {
      final idCandidate = code.substring(5).trim();
      final project = state.projects.where((p) => p.id == idCandidate || p.title.toLowerCase() == idCandidate.toLowerCase()).firstOrNull;
      if (project != null) {
        Navigator.pop(context);
        router.push('/projects/${project.id}');
        return;
      }
    }

    // 3. Detect Purchase Order or Requisition (e.g. "PO:9921004" or "PO-9921004" or matching existing PO)
    String cleanPo = code;
    if (code.toUpperCase().startsWith('PO:') || code.toUpperCase().startsWith('PO-')) {
      cleanPo = code.substring(3).trim();
    } else if (code.toUpperCase().startsWith('PR:') || code.toUpperCase().startsWith('PR-')) {
      cleanPo = code.substring(3).trim();
    }

    // Check standalone orders
    final standalone = state.standaloneOrders.where((o) =>
        o.po.toLowerCase() == cleanPo.toLowerCase() ||
        o.pr.toLowerCase() == cleanPo.toLowerCase() ||
        o.id == code).firstOrNull;
    if (standalone != null) {
      Navigator.pop(context);
      router.go('/orders?orderId=${standalone.id}');
      return;
    }

    // Check project-attached orders
    for (final p in state.projects) {
      final ord = p.orders.where((o) =>
          o.po.toLowerCase() == cleanPo.toLowerCase() ||
          o.pr.toLowerCase() == cleanPo.toLowerCase() ||
          o.id == code).firstOrNull;
      if (ord != null) {
        Navigator.pop(context);
        router.push('/projects/${p.id}?tab=orders&orderId=${ord.id}');
        return;
      }
    }

    // Check project by id or title
    final projDirect = state.projects.where((p) => p.id == code || p.title.toLowerCase() == code.toLowerCase()).firstOrNull;
    if (projDirect != null) {
      Navigator.pop(context);
      router.push('/projects/${projDirect.id}');
      return;
    }

    // If not directly matched, check global search
    final hits = state.searchAll(code);
    if (hits.hasMatches) {
      if (hits.orders.isNotEmpty) {
        final firstOrder = hits.orders.first;
        Navigator.pop(context);
        if (firstOrder.project != null) {
          router.push('/projects/${firstOrder.project!.id}?tab=orders&orderId=${firstOrder.id}');
        } else {
          router.go('/orders?orderId=${firstOrder.id}');
        }
        return;
      }
      if (hits.projects.isNotEmpty) {
        Navigator.pop(context);
        router.push('/projects/${hits.projects.first.project.id}');
        return;
      }
    }

    // Not found
    setState(() {
      _statusMessage = 'No matching PO, Project or BAMM WO found for "$code".';
      _statusColor = Colors.redAccent;
      _inputCtrl.clear();
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: colors.primary),
          const SizedBox(width: 8),
          const Text('Scan Barcode / QR Code'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.barcode_reader, size: 28, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hardware Scanner Gun or Keyboard Input',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan any crib bin tag, PO traveler, or enter a BAMM WO #.',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Awaiting Barcode Input...',
                hintText: 'e.g. PO-9921004, PROJ-1042, WO-185586',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => _processScanned(_inputCtrl.text),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: _processScanned,
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor ?? colors.textSecondary,
                fontWeight: _statusColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Open Orders Table', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    Navigator.pop(context);
                    appRouter.go('/orders');
                  },
                ),
                ActionChip(
                  label: const Text('BAMM Work Orders', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    Navigator.pop(context);
                    appRouter.go('/bamm');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class BarcodeLabelPreviewModal extends StatefulWidget {
  final BarcodeLabelData labelData;

  const BarcodeLabelPreviewModal({super.key, required this.labelData});

  @override
  State<BarcodeLabelPreviewModal> createState() => _BarcodeLabelPreviewModalState();
}

class _BarcodeLabelPreviewModalState extends State<BarcodeLabelPreviewModal> {
  bool _isExporting = false;

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await generateSingleBarcodeLabelPdf(widget.labelData);
      final dir = await getTemporaryDirectory();
      final filename = 'label_${widget.labelData.primaryCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Barcode Label: ${widget.labelData.primaryCode}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF label: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final label = widget.labelData;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.print_rounded, color: colors.primary),
          const SizedBox(width: 8),
          const Text('Print Barcode & QR Label'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Realistic physical label card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'JOKARZ ENGINEERING • CRIB & FIELD',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.8,
                        ),
                      ),
                      ExpressiveBadge(
                        label: label.kind.label.toUpperCase(),
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label.subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                    maxLines: 1,
                  ),
                  if (label.meta1 != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      label.meta1!,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Barcode128Widget(
                              data: label.scanPayload,
                              height: 38,
                              barColor: Colors.black,
                              showText: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          QrCodeWidget(data: label.scanPayload, size: 50, color: Colors.black),
                          const SizedBox(height: 2),
                          const Text(
                            'SCAN IN APP',
                            style: TextStyle(fontSize: 6, color: Colors.black54, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Compatible with standard 4"×2.5" thermal crib label printers and US Letter adhesive label sheets.',
              style: TextStyle(fontSize: 10, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _exportPdf,
          icon: _isExporting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print_rounded, size: 16),
          label: const Text('Generate Printable PDF'),
        ),
      ],
    );
  }
}
