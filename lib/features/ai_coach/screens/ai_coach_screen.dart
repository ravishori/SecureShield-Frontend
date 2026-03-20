import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme.dart';
import '../ai_coach_api.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _api = AiCoachApi();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  String? _sessionId;
  bool _sending = false;

  static const suggestions = [
    'How to spot OTP fraud?',
    'Is this app safe?',
    'What is phishing?',
    'How to report cybercrime?',
    'How to secure my phone?',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(_Message(
      role: 'assistant',
      content: 'Hello! I am SecureShield AI Coach. I can help you stay safe online, identify scams, and protect your digital life. What would you like to know?',
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    final userText = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(_Message(role: 'user', content: userText));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final response = await _api.chat(message: userText, sessionId: _sessionId);
      if (mounted) {
        setState(() {
          _sessionId = response['session_id'] as String?;
          _messages.add(_Message(role: 'assistant', content: response['reply'] as String? ?? ''));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(role: 'assistant', content: 'Sorry, I am unable to respond right now. Please check your connection and try again.'));
          _sending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Suggestions
        if (_messages.length <= 1)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: suggestions.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _send(suggestions[i]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    suggestions[i],
                    style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _sending) {
                return _TypingBubble();
              }
              return _ChatBubble(message: _messages[index]);
            },
          ),
        ),

        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.accent.withOpacity(0.2))),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask about cyber safety...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _send,
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : () => _send(_messageController.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _sending ? AppTheme.textSecondary : AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _sending ? Icons.hourglass_empty : Icons.send,
                      color: AppTheme.background,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.accent.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.accent.withOpacity(0.3)),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? AppTheme.textPrimary : AppTheme.accent,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                color: AppTheme.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Thinking...', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
