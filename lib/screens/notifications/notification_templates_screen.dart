import 'package:flutter/material.dart';
import '../../models/models.dart';

class NotificationTemplatesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const NotificationTemplatesScreen({super.key, required this.settings});

  @override
  State<NotificationTemplatesScreen> createState() => _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState extends State<NotificationTemplatesScreen> {
  final List<Map<String, String>> _templates = [
    {
      'title': 'New Sale / POS Receipt',
      'subject': 'Receipt for invoice {invoice_number}',
      'sms': 'Dear {customer_name}, thank you for shopping at Awesome Shop! Invoice #{invoice_number} total {total_amount}. Paid by {payment_method}.',
      'email': 'Hello {customer_name},\n\nThank you for choosing Awesome Shop. Please find attached your digital invoice copy #{invoice_number}.\nTotal: {total_amount}\n\nHave a great day!',
    },
    {
      'title': 'Payment Reminder',
      'subject': 'Pending payment reminder for {invoice_number}',
      'sms': 'Dear {customer_name}, this is a gentle reminder that your pending balance of {due_amount} for invoice #{invoice_number} is due. Please settle soon.',
      'email': 'Hello {customer_name},\n\nWe would like to remind you that an amount of {due_amount} remains pending on invoice #{invoice_number}.\nKindly contact us for payment.',
    },
    {
      'title': 'Low Stock Alert Notification',
      'subject': 'Alert: Low inventory warning for {product_name}',
      'sms': 'Alert: Stock for {product_name} is currently {current_stock} (Alert threshold: {alert_quantity}). Reorder needed.',
      'email': 'Inventory Alert:\n\nProduct: {product_name}\nSKU: {sku}\nCurrent Stock: {current_stock}\nAlert Limit: {alert_quantity}\nLocation: {location}',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Notification Templates',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text('Configure SMS, Email, and WhatsApp templates sent automatically upon sales or payment alerts.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 20),

            for (final t in _templates) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t['title']!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFEBF3FE), borderRadius: BorderRadius.circular(4)),
                          child: const Text('SMS & Email Active',
                              style: TextStyle(color: Color(0xFF004EEB), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Email Subject: ${t['subject']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text('SMS: "${t['sms']}"', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFF004EEB)),
                        label: const Text('Edit Template', style: TextStyle(color: Color(0xFF004EEB), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Template editor opened.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
