import 'package:uuid/uuid.dart';

/// A supplier, parts distributor, or fabrication vendor.
class Vendor {
  final String id;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;
  final String type; // vendor type / classification (dropdown, add-new from existing)
  final String accountNumber;
  final String notes;
  final DateTime createdAt;

  Vendor({
    String? id,
    required this.name,
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
    this.type = '',
    this.accountNumber = '',
    this.notes = '',
    DateTime? createdAt,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Vendor copyWith({
    String? name,
    String? contactPerson,
    String? email,
    String? phone,
    String? type,
    String? accountNumber,
    String? notes,
  }) {
    return Vendor(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      accountNumber: accountNumber ?? this.accountNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'type': type,
      'accountNumber': accountNumber,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      contactPerson: json['contactPerson'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      type: json['type'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
