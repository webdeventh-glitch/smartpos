/// Contact: Customer or Supplier
class Contact {
  final int? id;
  final String type; // 'customer' or 'supplier'
  final String name;
  final String? businessName;
  final String phone;
  final String email;
  final String address;
  final double balance; // Receivable for customer, Payable for supplier
  final double creditLimit;
  final double loyaltyPoints;
  final int? customerGroupId;
  final String? customerGroupName;
  final String taxNumber;
  final bool isDefaultWalkIn;

  Contact({
    this.id,
    required this.type,
    required this.name,
    this.businessName,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.balance = 0.0,
    this.creditLimit = 1000.0,
    this.loyaltyPoints = 0.0,
    this.customerGroupId,
    this.customerGroupName,
    this.taxNumber = '',
    this.isDefaultWalkIn = false,
  });

  bool get isCustomer => type == 'customer';
  bool get isSupplier => type == 'supplier';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'name': name,
        'business_name': businessName ?? '',
        'phone': phone,
        'email': email,
        'address': address,
        'balance': balance,
        'credit_limit': creditLimit,
        'loyalty_points': loyaltyPoints,
        'customer_group_id': customerGroupId,
        'tax_number': taxNumber,
        'is_default_walk_in': isDefaultWalkIn ? 1 : 0,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        type: map['type'] as String,
        name: map['name'] as String,
        businessName: map['business_name'] as String?,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        address: map['address'] as String? ?? '',
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 1000.0,
        loyaltyPoints: (map['loyalty_points'] as num?)?.toDouble() ?? 0.0,
        customerGroupId: map['customer_group_id'] as int?,
        customerGroupName: map['customer_group_name'] as String?,
        taxNumber: map['tax_number'] as String? ?? '',
        isDefaultWalkIn: (map['is_default_walk_in'] as int? ?? 0) == 1,
      );
}
