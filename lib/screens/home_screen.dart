import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../widgets/category_card.dart';
import 'category_phrases_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'vocab_screen.dart';

/// Écran d'accueil : grandes catégories, recherche et accès aux favoris
/// (point 4 du cahier des charges).
///
/// La grille est pilotée par les données : seules les catégories qui
/// possèdent déjà des phrases s'affichent, pour ne jamais proposer de
/// bouton qui mène à un écran vide.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ContentRepository.instance;
    final categories = repo.categories
        .where((c) => repo.phrasesForCategory(c.id).isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabai Tourisme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Vocabulaire',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VocabScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Mes phrases favorites',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchEntry(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return CategoryCard(
                      category: category,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CategoryPhrasesScreen(category: category),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (categories.length < repo.categories.length)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'D\'autres catégories arrivent bientôt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.black54),
              SizedBox(width: 12),
              Text(
                'Rechercher une phrase…',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
