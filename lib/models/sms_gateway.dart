/// SMS Gateway Configuration (Zong, Ufone, Jazz, Generic REST, Twilio)
class SmsGateway {
  final int? id;
  final String name;
  final String provider; // 'zong', 'ufone', 'jazz', 'telenor', 'sendpk', 'generic_http', 'twilio'
  final String apiUrl;
  final String apiKey;
  final String apiSecret;
  final String senderId; // Mask or sender phone
  final String httpMethod; // 'GET' or 'POST'
  final String payloadFormat;
  final bool isActive;
  final String createdAt;

  SmsGateway({
    this.id,
    required this.name,
    required this.provider,
    required this.apiUrl,
    this.apiKey = '',
    this.apiSecret = '',
    this.senderId = 'SMARTPOS',
    this.httpMethod = 'POST',
    this.payloadFormat = '',
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'provider': provider,
        'api_url': apiUrl,
        'api_key': apiKey,
        'api_secret': apiSecret,
        'sender_id': senderId,
        'http_method': httpMethod,
        'payload_format': payloadFormat,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory SmsGateway.fromMap(Map<String, dynamic> map) => SmsGateway(
        id: map['id'] as int?,
        name: map['name'] as String? ?? 'Custom SMS Gateway',
        provider: map['provider'] as String? ?? 'generic_http',
        apiUrl: map['api_url'] as String? ?? '',
        apiKey: map['api_key'] as String? ?? '',
        apiSecret: map['api_secret'] as String? ?? '',
        senderId: map['sender_id'] as String? ?? 'SMARTPOS',
        httpMethod: map['http_method'] as String? ?? 'POST',
        payloadFormat: map['payload_format'] as String? ?? '',
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  SmsGateway copyWith({
    int? id,
    String? name,
    String? provider,
    String? apiUrl,
    String? apiKey,
    String? apiSecret,
    String? senderId,
    String? httpMethod,
    String? payloadFormat,
    bool? isActive,
    String? createdAt,
  }) {
    return SmsGateway(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      senderId: senderId ?? this.senderId,
      httpMethod: httpMethod ?? this.httpMethod,
      payloadFormat: payloadFormat ?? this.payloadFormat,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
