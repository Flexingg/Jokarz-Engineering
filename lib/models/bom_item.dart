import 'package:uuid/uuid.dart';

enum BOMCategory {
  fastener('Fasteners & Hardware'),
  filament('Filament & Resin'),
  electronic('Electronics & PCB'),
  rawMaterial('Raw Stock & Metals'),
  tool('Tooling & Bits'),
  pneumatics('Pneumatics & Hydraulics'),
  other('General Component');

  final String label;
  const BOMCategory(this.label);
}

class BOMItem {
  final String id;
  final String name;
  final String partNumber;
  final String supplier;
  final double unitCost;
  final int quantity;
  final String linkUrl;
  final bool isPurchased;
  final BOMCategory category;

  BOMItem({
    String? id,
    required this.name,
    this.partNumber = '',
    this.supplier = '',
    this.unitCost = 0.0,
    this.quantity = 1,
    this.linkUrl = '',
    this.isPurchased = false,
    this.category = BOMCategory.other,
  }) : id = id ?? const Uuid().v4();

  double get totalCost => unitCost * quantity;

  BOMItem copyWith({
    String? name,
    String? partNumber,
    String? supplier,
    double? unitCost,
    int? quantity,
    String? linkUrl,
    bool? isPurchased,
    BOMCategory? category,
  }) {
    return BOMItem(
      id: id,
      name: name ?? this.name,
      partNumber: partNumber ?? this.partNumber,
      supplier: supplier ?? this.supplier,
      unitCost: unitCost ?? this.unitCost,
      quantity: quantity ?? this.quantity,
      linkUrl: linkUrl ?? this.linkUrl,
      isPurchased: isPurchased ?? this.isPurchased,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'partNumber': partNumber,
      'supplier': supplier,
      'unitCost': unitCost,
      'quantity': quantity,
      'linkUrl': linkUrl,
      'isPurchased': isPurchased,
      'category': category.name,
    };
  }

  factory BOMItem.fromJson(Map<String, dynamic> json) {
    return BOMItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled Part',
      partNumber: json['partNumber'] as String? ?? '',
      supplier: json['supplier'] as String? ?? '',
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      linkUrl: json['linkUrl'] as String? ?? '',
      isPurchased: json['isPurchased'] as bool? ?? false,
      category: BOMCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => BOMCategory.other,
      ),
    );
  }
}
