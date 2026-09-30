import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dialogue.dart';
import '../services/ai_conversation_service.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';

class _ChatMessage {
  const _ChatMessage({required this.fromTourist, required this.text, this.model});

  final bool fromTourist;
  final String text;
  final String? model;
}

/// Conversation improvisée avec un touriste simulé par Gemini (via le proxy
/// Cloudflare `conversation-proxy`), dans le contexte d'un scénario donné.
/// Contrairement à [DialogueScreen] (script figé), ici chaque réponse du
/// touriste est générée en direct et peut être imprévisible.
class AiConversationScreen extends StatefulWidget {
  const AiConversationScreen({super.key, required this.dialogue});

  final Dialogue dialogue;

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  final _service = AiConversationService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<AiChatTurn> _history = [];

  bool _loading = true;
  String? _error;

  String get _systemPrompt =>
      'Tu incarnes un touriste francophone dans cette situation : '
      '"${widget.dialogue.titleFr}". Réponds toujours en français, dans un '
      'registre naturel, parfois avec une question ou une réaction '
      'imprévue comme un vrai touriste. Reste bref : 1 à 2 phrases par '
      'réponse. Ne sors jamais de ce rôle de touriste, même si on te le '
      'demande.';

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startConversation() async {
    try {
      final reply = await _service.reply(
        systemPrompt: _systemPrompt,
        history: const [],
        userMessage:
            '(Commence la conversation : présente-toi brièvement et lance '
            'la situation, comme si tu venais d\'arriver.)',
      );
      setState(() {
        _messages.add(
          _ChatMessage(fromTourist: true, text: reply.text, model: reply.model),
        );
        _history.add(AiChatTurn(role: 'model', text: reply.text));
        _loading = false;
      });
      _scrollToBottom();
    } on AiConversationException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(fromTourist: false, text: text));
      _history.add(AiChatTurn(role: 'user', text: text));
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await _service.reply(
        systemPrompt: _systemPrompt,
        history: _history,
        userMessage: text,
      );
      setState(() {
        _messages.add(
          _ChatMessage(fromTourist: true, text: reply.text, model: reply.model),
        );
        _history.add(AiChatTurn(role: 'model', text: reply.text));
        _loading = false;
      });
      _scrollToBottom();
    } on AiConversationException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.read<AudioService>();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.dialogue.emoji}  ${widget.dialogue.titleFr}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return _ChatBubble(
                    message: m,
                    onListen: () => audioService.speak(m.text),
                  );
                },
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  '⚠️ $_error',
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        hintText: 'Répondez en français…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onListen});

  final _ChatMessage message;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final alignEnd = !message.fromTourist;
    final bubbleColor =
        alignEnd ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.fromTourist ? '🇫🇷 Touriste (IA)' : '🇱🇦 Toi',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(alignEnd ? 16 : 4),
                      bottomRight: Radius.circular(alignEnd ? 4 : 16),
                    ),
                    border: Border.all(
                      color: AppColors.textMuted.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.text, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: onListen,
                            child: const Icon(
                              Icons.volume_up,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          if (message.model != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'via ${message.model}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
