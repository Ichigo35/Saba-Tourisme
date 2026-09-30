import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../models/dialogue.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';

/// Lecture guidée d'un dialogue simulé : bulles touriste (gauche) / toi
/// (droite), chacune écoutable, pour s'entraîner à l'enchaînement d'une
/// conversation réelle plutôt qu'à une phrase isolée.
class DialogueScreen extends StatelessWidget {
  const DialogueScreen({super.key, required this.dialogue});

  final Dialogue dialogue;

  @override
  Widget build(BuildContext context) {
    final audioService = context.read<AudioService>();
    final repo = ContentRepository.instance;

    return Scaffold(
      appBar: AppBar(title: Text('${dialogue.emoji}  ${dialogue.titleFr}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: dialogue.turns.length,
        itemBuilder: (context, index) {
          final turn = dialogue.turns[index];
          if (turn.speaker == DialogueSpeaker.toi) {
            final phrase = repo.phraseById(turn.phraseId!);
            if (phrase == null) return const SizedBox.shrink();
            return _DialogueBubble(
              alignEnd: true,
              label: '🇱🇦 Toi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phrase.french,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    phrase.lao,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🔤 ${phrase.phoneticLao}',
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              onListen: () => audioService.speak(phrase.french),
            );
          }

          return _DialogueBubble(
            alignEnd: false,
            label: '🇫🇷 Touriste',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turn.textFr!,
                  style: const TextStyle(fontSize: 16, color: AppColors.textDark),
                ),
                if (turn.meaningLao != null) ...[
                  const SizedBox(height: 8),
                  _MeaningReveal(meaningLao: turn.meaningLao!),
                ],
              ],
            ),
            onListen: () => audioService.speak(turn.textFr!),
          );
        },
      ),
    );
  }
}

class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({
    required this.alignEnd,
    required this.label,
    required this.child,
    required this.onListen,
  });

  final bool alignEnd;
  final String label;
  final Widget child;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = alignEnd
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.surface;

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
                  label,
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
                      child,
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: onListen,
                        icon: const Icon(Icons.volume_up),
                        color: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Écouter',
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

/// Traduction lao indicative d'une réplique du touriste, repliée par défaut
/// et toujours accompagnée du rappel qu'elle n'est pas encore validée par un
/// locuteur natif (point 20 du cahier des charges).
class _MeaningReveal extends StatefulWidget {
  const _MeaningReveal({required this.meaningLao});

  final String meaningLao;

  @override
  State<_MeaningReveal> createState() => _MeaningRevealState();
}

class _MeaningRevealState extends State<_MeaningReveal> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!_revealed) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _revealed = true),
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
          widget.meaningLao,
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
