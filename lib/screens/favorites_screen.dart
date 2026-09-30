import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../services/favorites_service.dart';
import '../widgets/phrase_card.dart';

/// ⭐ Mes phrases : les phrases que le professionnel utilise souvent
/// (point 15 du cahier des charges).
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesService>();
    final validPhrases = favorites.favoriteIds
        .map((id) => ContentRepository.instance.phraseById(id))
        .where((p) => p != null)
        .map((p) => p!)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('⭐ Mes phrases favorites')),
      body: validPhrases.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune phrase favorite pour l\'instant.\n'
                  'Appuyez sur ⭐ sur une phrase pour la garder ici.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: validPhrases.length,
              itemBuilder: (context, index) =>
                  PhraseCard(phrase: validPhrases[index]),
            ),
    );
  }
}
