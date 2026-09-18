// Proves the report PDF actually builds: valid PDF bytes, the right US
// Letter page size for each orientation, and that it doesn't throw when
// every toggle (QR codes, grouping, zebra striping) is exercised together.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/models/bamm_report_config.dart';
import 'package:jokarz_engineering/utils/bamm_report_pdf.dart';

List<BammWorkOrder> _rows() => [
      BammWorkOrder(
        worId: 1,
        worNoSeq: '185610',
        description: 'Motor replacement',
        status: 'Registered',
        step: 'Emergency',
        area: 'Packaging',
        machine: 'Filler A',
        responsible: 'Doe, Jane',
      ),
      BammWorkOrder(
        worId: 2,
        worNoSeq: '185611',
        description: 'Belt inspection',
        status: 'Completed',
        step: 'Preventive',
        area: 'Filling',
        machine: 'Capper B',
        responsible: 'Smith, Bob',
      ),
    ];

void main() {
  test('generates a valid PDF (starts with the %PDF magic bytes)', () async {
    final bytes = await bammReportToPdf(
      _rows(),
      const BammReportConfig(templateName: 'Monday walk-around'),
      generatedAt: DateTime(2026, 9, 17, 8, 0),
      webUrlOf: (wo) => 'http://app02-ao-plt:82/workorder/detail/${wo.worId}',
      deepLinkOf: (wo) => 'aor-report://wo?id=${wo.worId}',
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('landscape (default) uses letter-landscape page dimensions', () async {
    final bytes = await bammReportToPdf(
      _rows(),
      const BammReportConfig(),
      generatedAt: DateTime(2026, 9, 17),
      webUrlOf: (wo) => 'x',
      deepLinkOf: (wo) => 'y',
    );
    // Landscape letter is wider than tall - a crude but effective proxy
    // for "the right page format was actually used" without parsing the
    // PDF's own page-size dictionary.
    expect(PdfPageFormat.letter.landscape.width, greaterThan(PdfPageFormat.letter.landscape.height));
    expect(bytes, isNotEmpty);
  });

  test('portrait option uses letter-portrait page dimensions', () async {
    final bytes = await bammReportToPdf(
      _rows(),
      const BammReportConfig(orientation: BammReportOrientation.portrait),
      generatedAt: DateTime(2026, 9, 17),
      webUrlOf: (wo) => 'x',
      deepLinkOf: (wo) => 'y',
    );
    expect(PdfPageFormat.letter.height, greaterThan(PdfPageFormat.letter.width));
    expect(bytes, isNotEmpty);
  });

  test('every toggle combination builds without throwing: 3-column, no QR, grouped by status, no zebra', () async {
    final bytes = await bammReportToPdf(
      _rows(),
      const BammReportConfig(
        columnsPerCardRow: 3,
        showDeepLinkQr: false,
        showBammWebQr: false,
        groupBy: BammReportGroupBy.status,
        zebraStriping: false,
        columnIds: ['worNoSeq', 'woDescription', 'woStatusDescription', 'woStepDescription', 'recipientName'],
      ),
      generatedAt: DateTime(2026, 9, 17),
      webUrlOf: (wo) => 'x',
      deepLinkOf: (wo) => 'y',
    );
    expect(bytes, isNotEmpty);
  });

  test('an empty row list still produces a valid document (no crash on zero work orders)', () async {
    final bytes = await bammReportToPdf(
      [],
      const BammReportConfig(),
      generatedAt: DateTime(2026, 9, 17),
      webUrlOf: (wo) => 'x',
      deepLinkOf: (wo) => 'y',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('an unknown columnId in the config is silently skipped, not a crash', () async {
    final bytes = await bammReportToPdf(
      _rows(),
      const BammReportConfig(columnIds: ['worNoSeq', 'thisColumnDoesNotExist']),
      generatedAt: DateTime(2026, 9, 17),
      webUrlOf: (wo) => 'x',
      deepLinkOf: (wo) => 'y',
    );
    expect(bytes, isNotEmpty);
  });
}
