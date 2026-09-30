import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_word.dart';
import '../services/audio_service.dart';
import '../utils/theme.dart';

/// Carte compacte d'un mot de vocabulaire : lao en gros, phonétique en
/// dessous, mot français à droite avec un bouton audio rond.
class VocabCard extends StatelessWidget {
  const VocabCard({super.key, required this.word});

  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    final audioService = context.read<AudioService>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.lao,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.phoneticLao,
                    style: const TextStyle(
                      fontFamily: AppFonts.lao,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              word.french,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => audioService.speak(word.french),
              icon: const Icon(Icons.volume_up),
              color: AppColors.primary,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                shape: const CircleBorder(),
              ),
              tooltip: 'Écouter',
            ),
          ],
        ),
      ),
    );
  }
}
