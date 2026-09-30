import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../models/phrase.dart';
import '../widgets/phrase_card.dart';

/// Recherche rapide en français, en lao ou par mot-clé de situation
/// (point 16 du cahier des charges).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Phrase> _results = const [];

  void _onChanged(String query) {
    setState(() {
      _results = ContentRepository.instance.search(query);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Rechercher une phrase')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Ex : toilette, bonjour, ສະບາຍດີ…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _controller.text.isEmpty
                  ? const Center(
                      child: Text('Tapez un mot en français ou en lao.'))
                  : _results.isEmpty
                      ? const Center(child: Text('Aucun résultat.'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) =>
                              PhraseCard(phrase: _results[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
