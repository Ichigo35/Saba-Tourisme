import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../models/category.dart';
import '../widgets/phrase_card.dart';

/// Liste des phrases d'une catégorie (point 5 du cahier des charges).
class CategoryPhrasesScreen extends StatelessWidget {
  const CategoryPhrasesScreen({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final phrases = ContentRepository.instance.phrasesForCategory(category.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.emoji}  ${category.nameFr}'),
      ),
      body: phrases.isEmpty
          ? const Center(child: Text('Aucune phrase pour cette catégorie.'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: phrases.length,
              itemBuilder: (context, index) => PhraseCard(phrase: phrases[index]),
            ),
    );
  }
}
