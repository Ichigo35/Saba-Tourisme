import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/dialogue.dart';
import '../services/ai_conversation_service.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';

class _ChatMessage {
  _ChatMessage({required this.fromTourist, required this.text, this.model});

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
  final _speech = stt.SpeechToText();
  final List<_ChatMessage> _messages = [];
  final List<AiChatTurn> _history = [];

  // Traductions lao demandées à la volée, indexées par position dans
  // `_messages` (pas stockées sur `_ChatMessage` pour garder ce dernier
  // simple ; conservées ici pour survivre au recyclage des widgets de la
  // ListView pendant le scroll).
  final Map<int, String> _translations = {};
  final Set<int> _translating = {};

  bool _loading = true;
  bool _speechAvailable = false;
  bool _listening = false;
  String? _error;

  // Texte déjà présent dans le champ avant le début de la dictée en cours
  // (dicté ou tapé lors d'un appui précédent sur le micro). Permet de
  // rallumer le micro sans effacer ce qui a déjà été transcrit : chaque
  // nouveau résultat de reconnaissance vient s'ajouter après ce texte plutôt
  // que de le remplacer.
  String _dictationBase = '';

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
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  /// Bascule micro : un appui démarre la dictée, l'appui suivant la termine
  /// (le texte reconnu reste dans le champ, modifiable avant l'envoi).
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      setState(() {
        _error = 'Reconnaissance vocale indisponible sur cet appareil.';
      });
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    _dictationBase = _controller.text.trimRight();
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'fr_FR'),
      onResult: (result) {
        setState(() {
          _controller.text = _dictationBase.isEmpty
              ? result.recognizedWords
              : '$_dictationBase ${result.recognizedWords}';
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        });
      },
    );
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

  Future<void> _translate(int index, String text) async {
    if (_translations.containsKey(index) || _translating.contains(index)) {
      return;
    }
    setState(() => _translating.add(index));
    try {
      final lao = await _service.translateToLao(text);
      if (!mounted) return;
      setState(() {
        _translations[index] = lao;
        _translating.remove(index);
      });
    } on AiConversationException catch (e) {
      if (!mounted) return;
      setState(() {
        _translating.remove(index);
        _error = e.message;
      });
    }
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
                    translation: _translations[index],
                    translating: _translating.contains(index),
                    onTranslate: () => _translate(index, m.text),
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
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'Je vous écoute…'
                            : 'Répondez en français…',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _toggleListening,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    tooltip: _listening
                        ? 'Terminer la dictée'
                        : 'Parler au lieu d\'écrire',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _listening ? AppColors.danger : AppColors.accent,
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
  const _ChatBubble({
    required this.message,
    required this.onListen,
    required this.translation,
    required this.translating,
    required this.onTranslate,
  });

  final _ChatMessage message;
  final VoidCallback onListen;
  final String? translation;
  final bool translating;
  final VoidCallback onTranslate;

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
                      const SizedBox(height: 8),
                      _TranslationReveal(
                        translation: translation,
                        translating: translating,
                        onTranslate: onTranslate,
                      ),
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

/// Traduction lao d'un message du chat (touriste IA ou toi), demandée à la
/// volée au proxy et repliée par défaut — même logique et même rappel
/// "à valider" que `_MeaningReveal` dans `DialogueScreen`, mais ici le texte
/// est généré en direct donc traduit en direct plutôt que lu depuis le
/// contenu figé.
class _TranslationReveal extends StatelessWidget {
  const _TranslationReveal({
    required this.translation,
    required this.translating,
    required this.onTranslate,
  });

  final String? translation;
  final bool translating;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    if (translating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (translation == null) {
      return OutlinedButton.icon(
        onPressed: onTranslate,
        icon: const Icon(Icons.translate, size: 18),
        label: const Text('Voir la traduction'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translation!,
          style: const TextStyle(fontFamily: AppFonts.lao, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          '⚠️ Traduction indicative à valider',
          style: TextStyle(fontSize: 11, color: AppColors.warning),
        ),
      ],
    );
  }
}
