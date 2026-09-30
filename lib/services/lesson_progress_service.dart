import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Progression de l'utilisateur dans une mini-leçon donnée.
class LessonProgress {
  const LessonProgress({required this.completed, required this.bestScore});

  final bool completed;
  final int bestScore;

  static const none = LessonProgress(completed: false, bestScore: 0);
}

/// Gère la progression des mini-leçons et des quiz (📚 Mini-leçons, point 21).
/// Persisté en local via [AppDatabase], notifie l'UI à chaque changement.
class LessonProgressService extends ChangeNotifier {
  LessonProgressService(this._db);

  final AppDatabase _db;
  Map<String, LessonProgress> _progress = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final rows = await _db.getAllLessonProgress();
    _progress = rows.map(
      (id, value) =>
          MapEntry(id, LessonProgress(completed: value.$1, bestScore: value.$2)),
    );
    _loaded = true;
    notifyListeners();
  }

  LessonProgress progressFor(String lessonId) =>
      _progress[lessonId] ?? LessonProgress.none;

  /// Enregistre le résultat d'un quiz : [score] bonnes réponses sur [total].
  Future<void> recordResult(String lessonId, int score, int total) async {
    await _db.saveLessonResult(lessonId, score);
    final previousBest = _progress[lessonId]?.bestScore ?? 0;
    _progress[lessonId] = LessonProgress(
      completed: true,
      bestScore: score > previousBest ? score : previousBest,
    );
    notifyListeners();
  }
}
