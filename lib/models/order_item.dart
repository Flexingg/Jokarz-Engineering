import 'package:uuid/uuid.dart';

class OrderItem {
  final String id;
  final String pr; // Purchase Requisition
  final String po; // Purchase Order
  final String description;
  final double price;
  final DateTime? eta;
  final bool delivered;
  /// Whether this item should be added to the plant storeroom.
  final bool addToStores;
  /// Whether a storeroom request has been made (requires a PO number first).
  final bool storeRequested;
  /// The storeroom request / requisition number.
  final String storeRequestNumber;
  final String? vendorId;
  final String vendorName;
  final String vendorQuoteNumber;
  final String trackingUrl;

  OrderItem({
    String? id,
    this.pr = '',
    this.po = '',
    this.description = '',
    this.price = 0.0,
    this.eta,
    this.delivered = false,
    this.addToStores = false,
    this.storeRequested = false,
    this.storeRequestNumber = '',
    this.vendorId,
    this.vendorName = '',
    this.vendorQuoteNumber = '',
    this.trackingUrl = '',
  }) : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4();

  OrderItem copyWith({
    String? pr,
    String? po,
    String? description,
    double? price,
    DateTime? eta,
    bool clearEta = false,
    bool? delivered,
    bool? addToStores,
    bool? storeRequested,
    String? storeRequestNumber,
    String? vendorId,
    bool clearVendorId = false,
    String? vendorName,
    String? vendorQuoteNumber,
    String? trackingUrl,
  }) {
    return OrderItem(
      id: id,
      pr: pr ?? this.pr,
      po: po ?? this.po,
      description: description ?? this.description,
      price: price ?? this.price,
      eta: clearEta ? null : (eta ?? this.eta),
      delivered: delivered ?? this.delivered,
      addToStores: addToStores ?? this.addToStores,
      storeRequested: storeRequested ?? this.storeRequested,
      storeRequestNumber:
          storeRequestNumber ?? this.storeRequestNumber,
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
      'addToStores': addToStores,
      'storeRequested': storeRequested,
      'storeRequestNumber': storeRequestNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorQuoteNumber': vendorQuoteNumber,
      'trackingUrl': trackingUrl,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String?,
      pr: json['pr'] as String? ?? '',
      po: json['po'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      eta: json['eta'] != null ? DateTime.tryParse(json['eta'] as String) : null,
      delivered: json['delivered'] as bool? ?? false,
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
