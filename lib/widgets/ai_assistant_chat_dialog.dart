import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantChatDialog extends StatefulWidget {
  final BusinessSettings settings;

  const AiAssistantChatDialog({super.key, required this.settings});

  @override
  State<AiAssistantChatDialog> createState() => _AiAssistantChatDialogState();
}

class _AiAssistantChatDialogState extends State<AiAssistantChatDialog> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Assalam-o-Alaikum! Main Smart POS ka AI Business Assistant hoon. Main aapki store sales, inventory guidance, aur software chalane me mukammal madad kar sakta hoon. Aaj main aapki kya madad karun?',
    }
  ];
  bool _isTyping = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isTyping) return;

    _msgCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await AiAssistantService.chatWithPosHelper(
        question: text,
        settings: widget.settings,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': response});
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text':
                'Maazrat, AI response generate karne me masla pesh aaya: ${e.toString()}',
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Smart POS AI Business Advisor',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          'Powered by Google Gemini / OpenAI • Roman Urdu & English',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Quick Prompt Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.keyboard_outlined, size: 14),
                      label: const Text('Shortcut keys kya hain?',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => _sendMessage(
                          'Smart POS me keyboard shortcut keys kya hain?'),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.trending_up_rounded, size: 14),
                      label: const Text('Sales barhane ka mashwara',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => _sendMessage(
                          'Retail store ki sales aur profit margin barhane ke liye koi 3 tips dein.'),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 14),
                      label: const Text('Draft bill resume kahan se hoga?',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => _sendMessage(
                          'Customer ka draft bill kahan se resume karun?'),
                    ),
                  ],
                ),
              ),
            ),

            // Message Stream
            Expanded(
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF4F46E5)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        msg['text']!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isUser
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF7C3AED))),
                    SizedBox(width: 10),
                    Text('AI is typing response...',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      onSubmitted: _sendMessage,
                      decoration: const InputDecoration(
                        hintText:
                            'Type your question in Roman Urdu or English...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _sendMessage(_msgCtrl.text),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
