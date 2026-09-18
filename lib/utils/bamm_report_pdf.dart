/// Renders a printable BAMM work-order report - US Letter, landscape by
/// default (portrait as an option), multi-column cards (never a full-width
/// row), toner-friendly (hairline rules + light zebra tints, no dark/filled
/// boxes), with the sheet-integrity timestamp/template name every page and
/// two toggleable QR codes per card.
library;

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';
import '../models/bamm_models.dart';
import '../models/bamm_report_config.dart';
import '../ui/widgets/bamm_table_columns.dart';

final DateFormat _tsFmt = DateFormat('MMM d, y - h:mm a');

String _groupKeyFor(BammWorkOrder wo, BammReportGroupBy groupBy) {
  switch (groupBy) {
    case BammReportGroupBy.asset:
      return wo.machine.isNotEmpty ? wo.machine : wo.assetId;
    case BammReportGroupBy.area:
      return wo.area;
    case BammReportGroupBy.status:
      return wo.status;
    case BammReportGroupBy.none:
      return '';
  }
}

/// A hand-drawn QR code (via the `qr` package's module matrix, painted
/// directly onto the PDF canvas) - no Flutter-widget QR renderer is needed
/// since this only ever has to exist inside a PDF page.
pw.Widget _qrWidget(String data, {double size = 56}) {
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
            // PDF y grows upward; row 0 must render at the top.
            final y = pdfSize.y - (row + 1) * moduleSize;
            canvas.drawRect(x, y, moduleSize, moduleSize);
          }
        }
      }
      canvas.fillPath();
    },
  );
}

/// An outlined status/step chip - the label text is ALWAYS printed, so
/// meaning never rides on colour alone (hard requirement: greyscale
/// printers, low toner).
pw.Widget _chip(String label, double fontSize) {
  if (label.trim().isEmpty) return pw.SizedBox();
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
    ),
    child: pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _card(
  BammWorkOrder wo,
  BammReportConfig cfg,
  List<BammColumnDef> columns,
  bool zebra, {
  required String Function(BammWorkOrder) webUrlOf,
  required String Function(BammWorkOrder) deepLinkOf,
}) {
  final rows = <pw.Widget>[];
  for (var i = 0; i < columns.length; i++) {
    final col = columns[i];
    final value = col.textOf(wo);
    final isStatusLike = col.key == 'woStatusDescription' || col.key == 'woStepDescription';
    rows.add(
      pw.Container(
        height: cfg.rowHeight,
        alignment: pw.Alignment.centerLeft,
        decoration: i == columns.length - 1
            ? null
            : const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.4))),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 70,
              child: pw.Text(col.header, style: pw.TextStyle(fontSize: cfg.fontSize, color: PdfColors.grey700)),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: isStatusLike
                  ? _chip(value, cfg.fontSize)
                  : pw.Text(value, style: pw.TextStyle(fontSize: cfg.fontSize), maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }

  final qrRow = <pw.Widget>[];
  if (cfg.showDeepLinkQr) {
    qrRow.add(pw.Column(children: [_qrWidget(deepLinkOf(wo)), pw.Text('Open in app', style: const pw.TextStyle(fontSize: 6))]));
  }
  if (cfg.showBammWebQr) {
    qrRow.add(pw.Column(children: [_qrWidget(webUrlOf(wo)), pw.Text('BAMM web', style: const pw.TextStyle(fontSize: 6))]));
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      color: zebra && cfg.zebraStriping ? PdfColors.grey100 : PdfColors.white,
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows)),
        if (qrRow.isNotEmpty) ...[
          pw.SizedBox(width: 6),
          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: qrRow),
        ],
      ],
    ),
  );
}

/// Builds the printable PDF. [webUrlOf]/[deepLinkOf] are injected (rather
/// than reaching into a live `BammService` here) so this stays a pure
/// function of its inputs - easy to test, and keeps "live-only" data
/// fetching entirely the caller's responsibility.
Future<Uint8List> bammReportToPdf(
  List<BammWorkOrder> rows,
  BammReportConfig cfg, {
  required DateTime generatedAt,
  required String Function(BammWorkOrder) webUrlOf,
  required String Function(BammWorkOrder) deepLinkOf,
}) async {
  final doc = pw.Document();
  final allColumns = {for (final c in buildBammColumns()) c.id: c};
  final columns = [for (final id in cfg.columnIds) if (allColumns.containsKey(id)) allColumns[id]!];

  final grouped = <String, List<BammWorkOrder>>{};
  for (final wo in rows) {
    grouped.putIfAbsent(_groupKeyFor(wo, cfg.groupBy), () => []).add(wo);
  }
  final groupKeys = grouped.keys.toList()..sort();

  final pageFormat = cfg.orientation == BammReportOrientation.landscape
      ? PdfPageFormat.letter.landscape
      : PdfPageFormat.letter;

  // `pw.GridView` requires every cell to fit an exact aspect-ratio box and
  // has known pagination trouble in `MultiPage` when a card doesn't fit
  // that box - `pw.Wrap` (also a `SpanningWidget`, so it still paginates
  // across pages) with explicitly-sized cards is the reliable pattern here.
  const margin = 20.0;
  const spacing = 6.0;
  final contentWidth = pageFormat.width - margin * 2;
  final cardWidth = (contentWidth - spacing * (cfg.columnsPerCardRow - 1)) / cfg.columnsPerCardRow;

  final content = <pw.Widget>[];
  var cardIndex = 0;
  for (final key in groupKeys) {
    if (cfg.groupBy != BammReportGroupBy.none) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.75))),
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(key.isEmpty ? '(none)' : key, style: pw.TextStyle(fontSize: cfg.fontSize + 2, fontWeight: pw.FontWeight.bold)),
        ),
      ));
    }
    final cards = <pw.Widget>[];
    for (final wo in grouped[key]!) {
      cards.add(pw.SizedBox(
        width: cardWidth,
        child: _card(wo, cfg, columns, cardIndex.isEven, webUrlOf: webUrlOf, deepLinkOf: deepLinkOf),
      ));
      cardIndex++;
    }
    content.add(pw.Wrap(spacing: spacing, runSpacing: spacing, children: cards));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(cfg.templateName.isEmpty ? 'BAMM Report' : cfg.templateName,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Printed ${_tsFmt.format(generatedAt)}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.75, color: PdfColors.grey700),
        ],
      ),
      build: (ctx) => content,
    ),
  );

  return doc.save();
}
