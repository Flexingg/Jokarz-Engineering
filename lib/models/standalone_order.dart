import 'package:uuid/uuid.dart';

/// A purchase order that is not (yet) attached to a specific project.
/// The [projectId] field is null when unlinked; set it to attach to a project.
class StandaloneOrder {
  final String id;
  final String pr;
  final String po;
  final String description;
  final double price;
  final DateTime? eta;
  final bool delivered;
  final String notes;
  final String? projectId;
  final DateTime createdAt;
  final bool addToStores;
  final bool storeRequested;
  final String storeRequestNumber;
  final String? vendorId;
  final String vendorName;
  final String vendorQuoteNumber;
  final String trackingUrl;

  StandaloneOrder({
    String? id,
    this.pr = '',
    this.po = '',
    this.description = '',
    this.price = 0.0,
    this.eta,
    this.delivered = false,
    this.notes = '',
    this.projectId,
    DateTime? createdAt,
    this.addToStores = false,
    this.storeRequested = false,
    this.storeRequestNumber = '',
    this.vendorId,
    this.vendorName = '',
    this.vendorQuoteNumber = '',
    this.trackingUrl = '',
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  StandaloneOrder copyWith({
    String? pr,
    String? po,
    String? description,
    double? price,
    DateTime? eta,
    bool clearEta = false,
    bool? delivered,
    String? notes,
    String? projectId,
    bool clearProjectId = false,
    bool? addToStores,
    bool? storeRequested,
    String? storeRequestNumber,
    String? vendorId,
    bool clearVendorId = false,
    String? vendorName,
    String? vendorQuoteNumber,
    String? trackingUrl,
  }) {
    return StandaloneOrder(
      id: id,
      pr: pr ?? this.pr,
      po: po ?? this.po,
      description: description ?? this.description,
      price: price ?? this.price,
      eta: clearEta ? null : (eta ?? this.eta),
      delivered: delivered ?? this.delivered,
      notes: notes ?? this.notes,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      createdAt: createdAt,
      addToStores: addToStores ?? this.addToStores,
      storeRequested: storeRequested ?? this.storeRequested,
      storeRequestNumber: storeRequestNumber ?? this.storeRequestNumber,
      vendorId: clearVendorId ? null : (vendorId ?? this.vendorId),
      vendorName: vendorName ?? this.vendorName,
      vendorQuoteNumber: vendorQuoteNumber ?? this.vendorQuoteNumber,
      trackingUrl: trackingUrl ?? this.trackingUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pr': pr,
      'po': po,
      'description': description,
      'price': price,
      'eta': eta?.toIso8601String(),
      'delivered': delivered,
      'notes': notes,
      'projectId': projectId,
      'createdAt': createdAt.toIso8601String(),
      'addToStores': addToStores,
      'storeRequested': storeRequested,
      'storeRequestNumber': storeRequestNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorQuoteNumber': vendorQuoteNumber,
      'trackingUrl': trackingUrl,
    };
  }

  factory StandaloneOrder.fromJson(Map<String, dynamic> json) {
    return StandaloneOrder(
      id: json['id'] as String?,
      pr: json['pr'] as String? ?? '',
      po: json['po'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      eta: json['eta'] != null ? DateTime.tryParse(json['eta'] as String) : null,
      delivered: json['delivered'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      projectId: json['projectId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      addToStores: json['addToStores'] as bool? ?? false,
      storeRequested: json['storeRequested'] as bool? ?? false,
      storeRequestNumber: json['storeRequestNumber'] as String? ?? '',
      vendorId: json['vendorId'] as String?,
      vendorName: json['vendorName'] as String? ?? '',
      vendorQuoteNumber: json['vendorQuoteNumber'] as String? ?? '',
      trackingUrl: json['trackingUrl'] as String? ?? '',
    );
  }
}
