import 'package:uuid/uuid.dart';

class OrderItem {
  final String id;
  final String pr; // Purchase Requisition
  final String po; // Purchase Order
  final String description;
  final double price;
  final DateTime? eta;
  final bool delivered;

  OrderItem({
    String? id,
    this.pr = '',
    this.po = '',
    this.description = '',
    this.price = 0.0,
    this.eta,
    this.delivered = false,
  }) : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4();

  OrderItem copyWith({
    String? pr,
    String? po,
    String? description,
    double? price,
    DateTime? eta,
    bool clearEta = false,
    bool? delivered,
  }) {
    return OrderItem(
      id: id,
      pr: pr ?? this.pr,
      po: po ?? this.po,
      description: description ?? this.description,
      price: price ?? this.price,
      eta: clearEta ? null : (eta ?? this.eta),
      delivered: delivered ?? this.delivered,
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
    );
  }
}
