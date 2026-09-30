import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../utils/theme.dart';
import 'ai_conversation_screen.dart';
import 'dialogue_screen.dart';

/// Liste des scénarios de simulation de conversation (point 22 du cahier
/// des charges), avec deux modes pour la même liste de situations :
/// - **Lecture guidée** : script figé, 100% hors-ligne (le contenu de base).
/// - **Improviser avec l'IA** : le touriste est généré en direct par Gemini
///   via le proxy Cloudflare, nécessite Internet.
///
/// Un seul écran avec un sélecteur de mode plutôt que deux entrées séparées
/// depuis l'accueil, pour ne pas surcharger l'AppBar de la page d'accueil.
class DialoguesScreen extends StatefulWidget {
  const DialoguesScreen({super.key});

  @override
  State<DialoguesScreen> createState() => _DialoguesScreenState();
}

enum _Mode { guided, ai }

class _DialoguesScreenState extends State<DialoguesScreen> {
  _Mode _mode = _Mode.guided;

  @override
  Widget build(BuildContext context) {
    final dialogues = ContentRepository.instance.dialogues;

    return Scaffold(
      appBar: AppBar(title: const Text('🎭 Simulation de conversation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                  value: _Mode.guided,
                  label: Text('📖 Lecture guidée'),
                ),
                ButtonSegment(
                  value: _Mode.ai,
                  label: Text('🤖 Improviser avec l\'IA'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          if (_mode == _Mode.ai)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '📶 Ce mode nécessite une connexion Internet : le touriste '
                'est improvisé en direct par une IA, il ne suit pas un '
                'script fixe.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          Expanded(
            child: dialogues.isEmpty
                ? const Center(
                    child: Text('Aucun scénario disponible pour le moment.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: dialogues.length,
                    itemBuilder: (context, index) {
                      final dialogue = dialogues[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Text(
                            dialogue.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            dialogue.titleFr,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _mode == _Mode.guided
                                ? '${dialogue.turns.length} répliques'
                                : 'Improviser avec l\'IA',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _mode == _Mode.guided
                                  ? DialogueScreen(dialogue: dialogue)
                                  : AiConversationScreen(dialogue: dialogue),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
