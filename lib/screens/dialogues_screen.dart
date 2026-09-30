import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import 'dialogue_screen.dart';

/// Liste des scénarios de simulation de conversation (point 22 du cahier
/// des charges) : dialogues touriste/toi à suivre pour s'entraîner à
/// l'enchaînement d'une situation réelle.
class DialoguesScreen extends StatelessWidget {
  const DialoguesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dialogues = ContentRepository.instance.dialogues;

    return Scaffold(
      appBar: AppBar(title: const Text('🎭 Simulation de conversation')),
      body: dialogues.isEmpty
          ? const Center(child: Text('Aucun scénario disponible pour le moment.'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: dialogues.length,
              itemBuilder: (context, index) {
                final dialogue = dialogues[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading:
                        Text(dialogue.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      dialogue.titleFr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${dialogue.turns.length} répliques'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DialogueScreen(dialogue: dialogue),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
