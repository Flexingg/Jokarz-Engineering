/// Page orientation for a printed BAMM report - landscape first per the
/// brief, portrait as an option.
enum BammReportOrientation {
  landscape,
  portrait;

  static BammReportOrientation fromName(String? name) => BammReportOrientation.values
      .firstWhere((o) => o.name == name, orElse: () => BammReportOrientation.landscape);
}

/// How printed cards are grouped on the page.
enum BammReportGroupBy {
  none,
  asset,
  area,
  status;

  static BammReportGroupBy fromName(String? name) =>
      BammReportGroupBy.values.firstWhere((g) => g.name == name, orElse: () => BammReportGroupBy.none);
}

/// Configuration for a printable BAMM work-order report. `columnIds`
/// references `BammColumnDef.id` from the real table catalogue
/// (`bamm_table_columns.dart`) - this config never re-declares field names.
class BammReportConfig {
  final String templateName;
  final List<String> columnIds;
  final BammReportOrientation orientation;
  /// 2 or 3 - a work order prints as a card, not a full-width row.
  final int columnsPerCardRow;
  /// 6-9pt per the brief.
  final double fontSize;
  final double rowHeight;
  final bool zebraStriping;
  final bool showDeepLinkQr;
  final bool showBammWebQr;
  final BammReportGroupBy groupBy;
  /// References an existing `BammSavedFilter.name` (`BammService.loadSavedFilters`).
  final String? savedFilterName;
  final String? sortField;
  final bool sortAscending;

  const BammReportConfig({
    this.templateName = '',
    this.columnIds = const ['worNoSeq', 'woDescription', 'woStatusDescription', 'woStepDescription'],
    this.orientation = BammReportOrientation.landscape,
    this.columnsPerCardRow = 2,
    this.fontSize = 8,
    this.rowHeight = 14,
    this.zebraStriping = true,
    this.showDeepLinkQr = true,
    this.showBammWebQr = true,
    this.groupBy = BammReportGroupBy.none,
    this.savedFilterName,
    this.sortField,
    this.sortAscending = true,
  });

  BammReportConfig copyWith({
    String? templateName,
    List<String>? columnIds,
    BammReportOrientation? orientation,
    int? columnsPerCardRow,
    double? fontSize,
    double? rowHeight,
    bool? zebraStriping,
    bool? showDeepLinkQr,
    bool? showBammWebQr,
    BammReportGroupBy? groupBy,
    String? savedFilterName,
    bool clearSavedFilterName = false,
    String? sortField,
    bool clearSortField = false,
    bool? sortAscending,
  }) {
    return BammReportConfig(
      templateName: templateName ?? this.templateName,
      columnIds: columnIds ?? this.columnIds,
      orientation: orientation ?? this.orientation,
      columnsPerCardRow: columnsPerCardRow ?? this.columnsPerCardRow,
      fontSize: fontSize ?? this.fontSize,
      rowHeight: rowHeight ?? this.rowHeight,
      zebraStriping: zebraStriping ?? this.zebraStriping,
      showDeepLinkQr: showDeepLinkQr ?? this.showDeepLinkQr,
      showBammWebQr: showBammWebQr ?? this.showBammWebQr,
      groupBy: groupBy ?? this.groupBy,
      savedFilterName: clearSavedFilterName ? null : (savedFilterName ?? this.savedFilterName),
      sortField: clearSortField ? null : (sortField ?? this.sortField),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toJson() => {
        'templateName': templateName,
        'columnIds': columnIds,
        'orientation': orientation.name,
        'columnsPerCardRow': columnsPerCardRow,
        'fontSize': fontSize,
        'rowHeight': rowHeight,
        'zebraStriping': zebraStriping,
        'showDeepLinkQr': showDeepLinkQr,
        'showBammWebQr': showBammWebQr,
        'groupBy': groupBy.name,
        'savedFilterName': savedFilterName,
        'sortField': sortField,
        'sortAscending': sortAscending,
      };

  factory BammReportConfig.fromJson(Map<String, dynamic> json) {
    bool boolOr(dynamic v, bool def) => v is bool ? v : def;
    double doubleOr(dynamic v, double def) => v is num ? v.toDouble() : def;
    int intOr(dynamic v, int def) => v is num ? v.toInt() : def;

    return BammReportConfig(
      templateName: json['templateName'] as String? ?? '',
      columnIds: (json['columnIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['worNoSeq', 'woDescription', 'woStatusDescription', 'woStepDescription'],
      orientation: BammReportOrientation.fromName(json['orientation'] as String?),
      columnsPerCardRow: intOr(json['columnsPerCardRow'], 2),
      fontSize: doubleOr(json['fontSize'], 8),
      rowHeight: doubleOr(json['rowHeight'], 14),
      zebraStriping: boolOr(json['zebraStriping'], true),
      showDeepLinkQr: boolOr(json['showDeepLinkQr'], true),
      showBammWebQr: boolOr(json['showBammWebQr'], true),
      groupBy: BammReportGroupBy.fromName(json['groupBy'] as String?),
      savedFilterName: json['savedFilterName'] as String?,
      sortField: json['sortField'] as String?,
      sortAscending: boolOr(json['sortAscending'], true),
    );
  }
}
