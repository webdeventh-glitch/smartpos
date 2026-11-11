/// Business Location (Branch / Warehouse) in Smart POS
class BusinessLocation {
  final int? id;
  final String name;
  final String locationId;
  final String landmark;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final String mobile;
  final String email;
  final String invoiceScheme;
  final bool isActive;

  BusinessLocation({
    this.id,
    required this.name,
    this.locationId = 'BL0001',
    this.landmark = '',
    this.city = 'Lahore',
    this.state = 'Punjab',
    this.country = 'Pakistan',
    this.zipCode = '54000',
    this.mobile = '+92 300 0000000',
    this.email = 'branch@smartpos.com',
    this.invoiceScheme = 'INV-',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'location_id': locationId,
        'landmark': landmark,
        'city': city,
        'state': state,
        'country': country,
        'zip_code': zipCode,
        'mobile': mobile,
        'email': email,
        'invoice_scheme': invoiceScheme,
        'is_active': isActive ? 1 : 0,
      };

  factory BusinessLocation.fromMap(Map<String, dynamic> map) =>
      BusinessLocation(
        id: map['id'] as int?,
        name: map['name'] as String,
        locationId: map['location_id'] as String? ?? 'BL0001',
        landmark: map['landmark'] as String? ?? '',
        city: map['city'] as String? ?? '',
        state: map['state'] as String? ?? '',
        country: map['country'] as String? ?? '',
        zipCode: map['zip_code'] as String? ?? '',
        mobile: map['mobile'] as String? ?? '',
        email: map['email'] as String? ?? '',
        invoiceScheme: map['invoice_scheme'] as String? ?? 'INV-',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  BusinessLocation copyWith({
    int? id,
    String? name,
    String? locationId,
    String? landmark,
    String? city,
    String? state,
    String? country,
    String? zipCode,
    String? mobile,
    String? email,
    String? invoiceScheme,
    bool? isActive,
  }) {
    return BusinessLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      locationId: locationId ?? this.locationId,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      invoiceScheme: invoiceScheme ?? this.invoiceScheme,
      isActive: isActive ?? this.isActive,
    );
  }
}
