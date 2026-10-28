import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';

class PaymentReminderDialog extends StatefulWidget {
  final Contact contact;
  final BusinessSettings settings;
  final double? specificDue;
  final String? invoiceNo;

  const PaymentReminderDialog({
    super.key,
    required this.contact,
    required this.settings,
    this.specificDue,
    this.invoiceNo,
  });

  @override
  State<PaymentReminderDialog> createState() => _PaymentReminderDialogState();
}

class _PaymentReminderDialogState extends State<PaymentReminderDialog> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _messageCtrl;
  String _selectedTemplate = 'friendly'; // 'friendly', 'urgent', 'detailed'

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.contact.phone);
    _messageCtrl = TextEditingController();
    _updateMessageText();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _formatInternationalPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '').trim();
    if (clean.startsWith('03') && clean.length == 11) {
      clean = '92${clean.substring(1)}';
    } else if (clean.startsWith('00')) {
      clean = clean.substring(2);
    }
    return clean;
  }

  void _updateMessageText() {
    final cur = widget.settings.currencySymbol;
    final due = widget.specificDue ?? widget.contact.balance;
    final bName = widget.settings.businessName.isNotEmpty ? widget.settings.businessName : 'Our Store';
    final cName = widget.contact.name;

    String msg = '';
    if (_selectedTemplate == 'friendly') {
      msg = '''Assalam-o-Alaikum *$cName*,
This is a gentle payment reminder from *$bName*.
Your current outstanding ledger balance is *$cur${due.toStringAsFixed(2)}*${widget.invoiceNo != null ? " against Invoice #${widget.invoiceNo}" : ""}.

Kindly arrange the payment at your earliest convenience.
For online bank transfer details or queries, please reply to this message.

Thank you for your continuous support!
*$bName*''';
    } else if (_selectedTemplate == 'urgent') {
      msg = '''*URGENT PAYMENT REMINDER*
Dear *$cName*,
This is an urgent reminder regarding your pending overdue balance of *$cur${due.toStringAsFixed(2)}* with *$bName*.

Your account balance has exceeded the credit term limits. Please settle the due balance immediately to avoid disruption to your account credit facility.

Contact us immediately for settlement.
*$bName*''';
    } else {
      msg = '''*ACCOUNT STATEMENT & DUE SUMMARY*
Client: *$cName*
Store: *$bName*
Total Outstanding Due: *$cur${due.toStringAsFixed(2)}*
Credit Limit: $cur${widget.contact.creditLimit.toStringAsFixed(2)}

Please review your ledger and clear the pending dues.
Thank you!''';
    }

    _messageCtrl.text = msg;
  }

  void _sendViaWhatsApp() {
    final phone = _formatInternationalPhone(_phoneCtrl.text);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number!'), backgroundColor: Colors.red),
      );
      return;
    }

    final text = Uri.encodeComponent(_messageCtrl.text.trim());
    final url = 'https://wa.me/$phone?text=$text';

    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}

    Clipboard.setData(ClipboardData(text: _messageCtrl.text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening WhatsApp... Message also copied to clipboard!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _sendViaSms() {
    final phone = _formatInternationalPhone(_phoneCtrl.text);
    final text = Uri.encodeComponent(_messageCtrl.text.trim());
    final url = 'sms:$phone?body=$text';

    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}

    Clipboard.setData(ClipboardData(text: _messageCtrl.text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS ready! Message copied to clipboard.'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _messageCtrl.text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment reminder message copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final due = widget.specificDue ?? widget.contact.balance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send Payment Reminder (WhatsApp & SMS)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Customer: ${widget.contact.name}  •  Due: $cur${due.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Body
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone input
                  const Text('Customer Mobile / WhatsApp Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      hintText: 'e.g. 03001234567 or +923001234567',
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Template selector chips
                  const Text('Reminder Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _templateChip('friendly', 'Friendly Reminder', Icons.sentiment_satisfied_alt_rounded),
                      const SizedBox(width: 8),
                      _templateChip('urgent', 'Urgent / Overdue', Icons.warning_amber_rounded, isUrgent: true),
                      const SizedBox(width: 8),
                      _templateChip('detailed', 'Khata Statement', Icons.receipt_long_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Message textarea
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Message Preview & Customization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: _copyToClipboard,
                        child: const Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5)),
                            SizedBox(width: 4),
                            Text('Copy Text', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 7,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Action Buttons Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sms_rounded, size: 16),
                    label: const Text('Send SMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _sendViaSms,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                    label: const Text('Send via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _sendViaWhatsApp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateChip(String id, String label, IconData icon, {bool isUrgent = false}) {
    final isSelected = _selectedTemplate == id;
    final color = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => _selectedTemplate = id);
        _updateMessageText();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : (isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B))),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
