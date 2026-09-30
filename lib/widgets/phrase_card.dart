import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/phrase.dart';
import '../services/audio_service.dart';
import '../services/favorites_service.dart';
import '../utils/theme.dart';
import 'audio_buttons.dart';

/// Carte d'une phrase : français, lao, phonétique, audio, favoris
/// (point 5 du cahier des charges).
class PhraseCard extends StatelessWidget {
  const PhraseCard({super.key, required this.phrase});

  final Phrase phrase;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesService>();
    final audioService = context.read<AudioService>();
    final isFavorite = favorites.isFavorite(phrase.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🇫🇷 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    phrase.french,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => favorites.toggle(phrase.id),
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: AppColors.accent,
                  ),
                  tooltip: 'Ajouter aux favoris',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🇱🇦 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    phrase.lao,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 19,
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
                    phrase.phoneticLao,
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
            if (phrase.needsReview) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '⚠️ Traduction à valider par un locuteur lao',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            ],
            if (phrase.pronunciationTip != null) ...[
              const SizedBox(height: 10),
              Text(
                '💡 ${phrase.pronunciationTip}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (phrase.explanation != null) ...[
              const SizedBox(height: 6),
              Text(
                phrase.explanation!,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 14),
            AudioButtons(audioService: audioService, text: phrase.french),
          ],
        ),
      ),
    );
  }
}
