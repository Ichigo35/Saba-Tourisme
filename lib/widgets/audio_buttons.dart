import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../utils/theme.dart';

/// Boutons ▶️ Écouter / 🐢 Écouter lentement (point 8 du cahier des charges).
class AudioButtons extends StatelessWidget {
  const AudioButtons({
    super.key,
    required this.audioService,
    required this.text,
  });

  final AudioService audioService;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => audioService.speak(text),
            icon: const Icon(Icons.volume_up),
            label: const Text('Écouter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              minimumSize: const Size.fromHeight(48),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => audioService.speakSlowly(text),
            icon: const Text('🐢', style: TextStyle(fontSize: 18)),
            label: const Text('Lentement'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent, width: 1.5),
              minimumSize: const Size.fromHeight(48),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
