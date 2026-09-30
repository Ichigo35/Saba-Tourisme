import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/category.dart';
import '../models/phrase.dart';
import '../models/vocab_word.dart';

/// Charge le catalogue de contenu (catégories, phrases) depuis les assets
/// JSON embarqués dans l'application. Ce contenu est en lecture seule et
/// fonctionne entièrement hors-ligne : aucune requête réseau.
class ContentRepository {
  ContentRepository._internal();
  static final ContentRepository instance = ContentRepository._internal();

  List<Category> categories = [];
  List<Phrase> phrases = [];
  List<VocabWord> vocabWords = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final categoriesRaw =
        await rootBundle.loadString('assets/data/categories.json');
    final phrasesRaw = await rootBundle.loadString('assets/data/phrases.json');
    final vocabRaw = await rootBundle.loadString('assets/data/vocab.json');

    categories = (jsonDecode(categoriesRaw) as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();

    phrases = (jsonDecode(phrasesRaw) as List<dynamic>)
        .map((e) => Phrase.fromJson(e as Map<String, dynamic>))
        .toList();

    vocabWords = (jsonDecode(vocabRaw) as List<dynamic>)
        .map((e) => VocabWord.fromJson(e as Map<String, dynamic>))
        .toList();

    _loaded = true;
  }

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Phrase> phrasesForCategory(String categoryId) =>
      phrases.where((p) => p.categoryId == categoryId).toList();

  /// Thèmes de vocabulaire disponibles, dans l'ordre d'apparition des mots.
  List<String> get vocabThemes {
    final seen = <String>{};
    for (final v in vocabWords) {
      seen.add(v.category);
    }
    return seen.toList();
  }

  List<VocabWord> vocabForTheme(String theme) =>
      vocabWords.where((v) => v.category == theme).toList();

  Phrase? phraseById(String id) {
    for (final p in phrases) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Recherche libre en français, en lao ou par situation (point 16 du cahier
  /// des charges).
  List<Phrase> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return phrases.where((p) {
      return p.french.toLowerCase().contains(q) ||
          p.lao.contains(query.trim()) ||
          p.situation.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}
