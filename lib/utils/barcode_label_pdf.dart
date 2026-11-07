import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';
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
  final String primaryCode;    // e.g. "PO-9921004" or "PROJ-1042" or "WO-185586"
  final String title;          // e.g. "UHMW Wear Plates" or "Line 2 Infeed Overhaul"
  final String subtitle;       // e.g. "Vendor: McMaster-Carr" or "Machine: Case Packer 1"
  final String? meta1;         // e.g. "PR: PR-48901 • ETA: Nov 12" or "Priority: #1"
  final String? meta2;         // e.g. "Area: Packaging • Status: Open"
  final String scanPayload;    // payload inside the QR / Barcode

  const BarcodeLabelData({
    required this.kind,
    required this.primaryCode,
    required this.title,
    required this.subtitle,
    this.meta1,
    this.meta2,
    required this.scanPayload,
  });
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

/// Generates a single-label sticker or badge PDF (3.5" x 2" / 4" x 2.25")
Future<Uint8List> generateSingleBarcodeLabelPdf(BarcodeLabelData label) async {
  final doc = pw.Document();

  // Standard shipping / crib bin label format (4" x 2.5" landscape)
  const format = PdfPageFormat(4 * PdfPageFormat.inch, 2.5 * PdfPageFormat.inch, marginAll: 8);

  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header brand & Kind
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'JOKARZ ENGINEERING • CRIB & FIELD LABEL',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    child: pw.Text(
                      label.kind.label.toUpperCase(),
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
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

/// Generates a standard multi-label sheet (US Letter 8.5" x 11", 2 columns x 4 rows = 8 labels)
Future<Uint8List> generateMultiLabelSheetPdf(List<BarcodeLabelData> labels) async {
  final doc = pw.Document();
  const format = PdfPageFormat.letter;
  final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '⚙️ JOKARZ ENGINEERING — BARCODE INVENTORY & TRAVELER LABELS',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
            pw.Text('Printed $now', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
      build: (pw.Context context) {
        return [
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: labels.map((label) {
              return pw.Container(
                width: 250,
                height: 140,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          label.kind.label.toUpperCase(),
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                        ),
                        pw.Text(label.primaryCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(label.title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 1),
                    pw.Text(label.subtitle, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700), maxLines: 1),
                    if (label.meta1 != null) pw.Text(label.meta1!, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.blueGrey800)),
                    pw.Spacer(),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              _pdfBarcode128(label.scanPayload, height: 26, width: 140),
                              pw.SizedBox(height: 2),
                              pw.Text(label.scanPayload, style: const pw.TextStyle(fontSize: 7)),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        _pdfQrCode(label.scanPayload, size: 34),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ];
      },
    ),
  );

  return doc.save();
}
