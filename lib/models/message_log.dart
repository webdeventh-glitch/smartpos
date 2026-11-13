/// Outgoing Message Log (SMS & WhatsApp delivery tracking)
class MessageLog {
  final int? id;
  final String recipientName;
  final String phoneNumber;
  final String channel; // 'sms' or 'whatsapp'
  final String messageBody;
  final String status; // 'sent', 'failed', 'delivered'
  final String gatewayName;
  final String errorDetails;
  final String createdAt;

  MessageLog({
    this.id,
    this.recipientName = 'Customer',
    required this.phoneNumber,
    this.channel = 'sms',
    required this.messageBody,
    this.status = 'sent',
    this.gatewayName = '',
    this.errorDetails = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'recipient_name': recipientName,
        'phone_number': phoneNumber,
        'channel': channel,
        'message_body': messageBody,
        'status': status,
        'gateway_name': gatewayName,
        'error_details': errorDetails,
        'created_at': createdAt,
      };

  factory MessageLog.fromMap(Map<String, dynamic> map) => MessageLog(
        id: map['id'] as int?,
        recipientName: map['recipient_name'] as String? ?? 'Customer',
        phoneNumber: map['phone_number'] as String? ?? '',
        channel: map['channel'] as String? ?? 'sms',
        messageBody: map['message_body'] as String? ?? '',
        status: map['status'] as String? ?? 'sent',
        gatewayName: map['gateway_name'] as String? ?? '',
        errorDetails: map['error_details'] as String? ?? '',
        createdAt:
            map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );
}
