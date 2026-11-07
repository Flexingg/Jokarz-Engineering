import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';
import '../models/project.dart';
import 'barcode_utils.dart';

enum BarcodeLabelKind {
  purchaseOrder('Purchase Order'),
  project('Project Traveler'),
  bammWorkOrder('BAMM Work Order');

  final String label;
  const BarcodeLabelKind(this.label);
}

class BarcodeLabelData {
  final BarcodeLabelKind kind;
  final String primaryCode;    // e.g. "PO-9921004" or "PROJ-#1" or "WO-185586"
  final String title;          // e.g. "UHMW Wear Plates" or "Line 2 Infeed Overhaul"
  final String subtitle;       // e.g. "Vendor: McMaster-Carr" or "Machine: Case Packer 1"
  final String? meta1;         // e.g. "PR: PR-48901 • ETA: Nov 12" or "Priority: #1"
  final String? meta2;         // e.g. "Area: Packaging • Status: Open"
  final String scanPayload;    // payload inside the QR / Barcode
  final String? step;          // e.g. "Installation"
  final String? type;          // e.g. "Maintenance", "Capital", "Kaizen"
  final String? priority;      // e.g. "#1"
  final String? machine;       // e.g. "Case Packer 2"
  final bool is2dOnly;         // true for 2D QR code only (no 1D barcode)

  const BarcodeLabelData({
    required this.kind,
    required this.primaryCode,
    required this.title,
    required this.subtitle,
    this.meta1,
    this.meta2,
    required this.scanPayload,
    this.step,
    this.type,
    this.priority,
    this.machine,
    this.is2dOnly = false,
  });

  factory BarcodeLabelData.fromProject(Project project) {
    return BarcodeLabelData(
      kind: BarcodeLabelKind.project,
      primaryCode: 'PROJ-#${project.priority}',
      title: project.title,
      subtitle: project.machine.isNotEmpty ? 'Machine: ${project.machine}' : '',
      step: project.phase,
      type: project.category.label,
      priority: '#${project.priority}',
      machine: project.machine.isNotEmpty ? project.machine : null,
      is2dOnly: true,
      scanPayload: 'PROJ:${project.id}',
    );
  }
}

/// Renders a Code 128 barcode directly onto a PDF canvas.
pw.Widget _pdfBarcode128(String data, {double height = 40, double width = 160}) {
  final modules = encodeCode128B(data);
  if (modules.isEmpty) return pw.SizedBox();

  return pw.CustomPaint(
    size: PdfPoint(width, height),
    painter: (canvas, size) {
      final moduleWidth = size.x / modules.length;
      canvas.setColor(PdfColors.black);

      for (int i = 0; i < modules.length; i++) {
        if (modules[i]) {
          canvas.drawRect(
            i * moduleWidth,
            0,
            moduleWidth + 0.1,
            size.y,
          );
        }
      }
      canvas.fillPath();
    },
  );
}

/// Renders a QR code directly onto a PDF canvas.
pw.Widget _pdfQrCode(String data, {double size = 48}) {
  final qrCode = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
  final qrImage = QrImage(qrCode);
  final moduleCount = qrImage.moduleCount;
  final moduleSize = size / moduleCount;

  return pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, pdfSize) {
      canvas.setColor(PdfColors.black);
      for (var row = 0; row < moduleCount; row++) {
        for (var col = 0; col < moduleCount; col++) {
          if (qrImage.isDark(row, col)) {
            final x = col * moduleSize;
            final y = pdfSize.y - (row + 1) * moduleSize;
            canvas.drawRect(x, y, moduleSize, moduleSize);
          }
        }
      }
      canvas.fillPath();
    },
  );
}

/// Key-value label row for cut sheet label
pw.Widget _pdfField(String key, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 54,
          child: pw.Text(
            '$key:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    ),
  );
}

/// Standard 2D equipment / traveler cut label (3.7" × 2.3", dashed cut lines)
/// Displays ONLY: Project Title & ID, Step, Type, Priority, Machine, and 2D QR Code.
/// No "Crib and Field", "Jokarz Engineering", or 1D barcode clutter.
pw.Widget _build2dCutLabel(BarcodeLabelData label, {double width = 268, double height = 160}) {
  final step = label.step ?? (label.meta1 != null && label.meta1!.isNotEmpty ? label.meta1! : label.subtitle);
  final type = label.type ?? label.kind.label;
  final priority = label.priority ?? label.primaryCode;

  return pw.Container(
    width: width,
    height: height,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.black, width: 1.2, style: pw.BorderStyle.dashed),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Project Title and ID
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    label.title,
                    style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    label.primaryCode,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text('✂', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Divider(color: PdfColors.grey400, thickness: 0.75),
        pw.SizedBox(height: 5),

        // Key Details (Step, Type, Priority, Machine) on left, 2D QR Code on right
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfField('STEP', step),
                    _pdfField('TYPE', type),
                    _pdfField('PRIORITY', priority),
                    if (label.machine != null && label.machine!.isNotEmpty)
                      _pdfField('MACHINE', label.machine!),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _pdfQrCode(label.scanPayload, size: 66),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'SCAN IN APP',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Generates a single-label sticker or badge PDF (4" x 2.5" landscape)
Future<Uint8List> generateSingleBarcodeLabelPdf(BarcodeLabelData label) async {
  final doc = pw.Document();
  const format = PdfPageFormat(4 * PdfPageFormat.inch, 2.5 * PdfPageFormat.inch, marginAll: 8);

  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (pw.Context context) {
        if (label.is2dOnly || label.kind == BarcodeLabelKind.project) {
          return _build2dCutLabel(
            label,
            width: 4 * PdfPageFormat.inch - 16,
            height: 2.5 * PdfPageFormat.inch - 16,
          );
        }

        // Standard 1D/2D label without obsolete brand header
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    label.primaryCode,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    child: pw.Text(
                      label.kind.label.toUpperCase(),
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // Title & Subtitle
              pw.Text(
                label.title,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
              pw.Text(
                label.subtitle,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                maxLines: 1,
              ),
              if (label.meta1 != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  label.meta1!,
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
              ],
              pw.Spacer(),

              // Barcode and QR side-by-side
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _pdfBarcode128(label.scanPayload, height: 32, width: 170),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          label.primaryCode,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    children: [
                      _pdfQrCode(label.scanPayload, size: 44),
                      pw.SizedBox(height: 2),
                      pw.Text('SCAN IN APP', style: const pw.TextStyle(fontSize: 5)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

/// Generates an 8.5" x 11" US Letter multi-label sheet with cut lines (2 columns x 4 rows = 8 labels/sheet)
/// Specially designed for workshop scissors/paper-cutter trimming into good-sized barcode labels.
Future<Uint8List> generateMultiLabelSheetPdf(List<BarcodeLabelData> labels) async {
  final doc = pw.Document();
  const format = PdfPageFormat.letter; // 612 x 792 pt
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  const int perPage = 8;
  for (var i = 0; i < labels.length; i += perPage) {
    final pageLabels = labels.sublist(i, (i + perPage > labels.length) ? labels.length : i + perPage);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sheet Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PROJECT 2D BARCODE LABELS (8.5" × 11" CUT SHEET)',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Text('8 Labels / Sheet • Printed $now', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '✂ Cut along dashed borders into 3.7" × 2.3" equipment & traveler barcode labels',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 10),

              // 2 columns x 4 rows grid
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: pageLabels.map((lbl) {
                    if (lbl.is2dOnly || lbl.kind == BarcodeLabelKind.project) {
                      return _build2dCutLabel(lbl, width: 268, height: 160);
                    }
                    // For general labels on 8.5x11
                    return _build2dCutLabel(lbl, width: 268, height: 160);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  return doc.save();
}
