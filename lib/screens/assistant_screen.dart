import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/content_repository.dart';
import '../models/phrase.dart';
import '../services/ai_conversation_service.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';
import '../widgets/audio_buttons.dart';
import '../widgets/phrase_card.dart';

enum _Mode { speak, understand }

/// Deux outils d'urgence IA pour le pro lao en situation réelle avec un
/// touriste, réunis dans un seul écran (comme [DialoguesScreen] réunit
/// lecture guidée et IA) pour ne pas ajouter une icône de plus par mode dans
/// l'AppBar de l'accueil :
/// - **🆘 Parler français** : le pro décrit ce qu'il veut dire, l'IA lui
///   donne la phrase française à prononcer (+ phonétique lao).
/// - **🧠 Le touriste a dit quoi** : le pro rapporte ce que le touriste a dit
///   en français, l'IA en explique le sens en lao.
///
/// Les deux nécessitent Internet (même proxy Cloudflare que la Conversation
/// IA). [IndexedStack] garde l'état des deux panneaux vivant quand on
/// bascule de l'un à l'autre (pas de perte du texte en cours de saisie).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  _Mode _mode = _Mode.speak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🆘 Assistant IA')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                  value: _Mode.speak,
                  label: Text('🆘 Parler français'),
                ),
                ButtonSegment(
                  value: _Mode.understand,
                  label: Text('🧠 Le touriste a dit quoi'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '📶 Ces outils nécessitent une connexion Internet (réponse '
              'générée en direct par une IA).',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode == _Mode.speak ? 0 : 1,
              children: const [
                _SpeakFrenchPanel(),
                _UnderstandTouristPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode "🆘 Parler français" : le pro décrit ce qu'il veut dire (situation,
/// idée approximative), l'IA formule la phrase française à prononcer avec sa
/// phonétique en écriture lao. Recherche aussi le phrasebook existant en
/// local (gratuit, hors-ligne) avant de proposer d'appeler l'IA.
class _SpeakFrenchPanel extends StatefulWidget {
  const _SpeakFrenchPanel();

  @override
  State<_SpeakFrenchPanel> createState() => _SpeakFrenchPanelState();
}

class _SpeakFrenchPanelState extends State<_SpeakFrenchPanel> {
  final _service = AiConversationService();
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();

  List<Phrase> _localMatches = const [];
  bool _speechAvailable = false;
  bool _listening = false;
  bool _loading = false;
  String? _error;
  ComposedPhrase? _result;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
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
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'fr_FR'),
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
          _onQueryChanged(_controller.text);
        });
      },
    );
  }

  void _onQueryChanged(String query) {
    setState(() {
      _localMatches = ContentRepository.instance.search(query);
    });
  }

  Future<void> _askAi() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.composePhrase(text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on AiConversationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.read<AudioService>();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Décris ce que tu veux dire (en français, même approximatif) : '
          'l\'IA te donne la phrase française correcte à prononcer.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: _listening
                      ? 'Je vous écoute…'
                      : 'Ex : dire au touriste que le bus part à 8h…',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _toggleListening,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              tooltip:
                  _listening ? 'Terminer la dictée' : 'Parler au lieu d\'écrire',
              style: IconButton.styleFrom(
                backgroundColor: _listening ? AppColors.danger : AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _askAi,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Formulation en cours…' : 'Demander à l\'IA'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            '⚠️ $_error',
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _ComposedPhraseCard(result: _result!, audioService: audioService),
        ],
        if (_localMatches.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            '📖 Phrases déjà dans le phrasebook (hors-ligne)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          ..._localMatches.take(3).map((p) => PhraseCard(phrase: p)),
        ],
      ],
    );
  }
}

class _ComposedPhraseCard extends StatelessWidget {
  const _ComposedPhraseCard({required this.result, required this.audioService});

  final ComposedPhrase result;
  final AudioService audioService;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🇫🇷 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    result.french,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔤 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    result.phonetic,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🇱🇦 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    result.meaning,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⚠️ Généré à la volée par l\'IA, à valider par un locuteur lao',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 14),
            AudioButtons(audioService: audioService, text: result.french),
            const SizedBox(height: 4),
            Text(
              'via ${result.model}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode "🧠 Le touriste a dit quoi" : le pro rapporte ce que le touriste a dit
/// en français (tapé ou dicté au micro), l'IA en donne le sens en lao —
/// réutilise le mode `translate` du proxy déjà utilisé pour la relecture des
/// bulles de la Conversation IA.
class _UnderstandTouristPanel extends StatefulWidget {
  const _UnderstandTouristPanel();

  @override
  State<_UnderstandTouristPanel> createState() =>
      _UnderstandTouristPanelState();
}

class _UnderstandTouristPanelState extends State<_UnderstandTouristPanel> {
  final _service = AiConversationService();
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();

  bool _speechAvailable = false;
  bool _listening = false;
  bool _loading = false;
  String? _error;
  String? _meaning;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
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
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'fr_FR'),
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        });
      },
    );
  }

  Future<void> _understand() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _meaning = null;
    });
    try {
      final meaning = await _service.translateToLao(text);
      if (!mounted) return;
      setState(() {
        _meaning = meaning;
        _loading = false;
      });
    } on AiConversationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Tape ou dicte ce que le touriste vient de dire en français : '
          'l\'IA t\'explique le sens en lao.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: _listening
                      ? 'Je vous écoute…'
                      : 'Ce que le touriste a dit en français…',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _toggleListening,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              tooltip:
                  _listening ? 'Terminer la dictée' : 'Parler au lieu d\'écrire',
              style: IconButton.styleFrom(
                backgroundColor: _listening ? AppColors.danger : AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _understand,
          icon: const Icon(Icons.translate),
          label: Text(_loading ? 'Traduction en cours…' : 'Comprendre'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            '⚠️ $_error',
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        if (_meaning != null) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _meaning!,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 19,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '⚠️ Traduction indicative à valider',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
