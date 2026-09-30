import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de données locale (SQLite via sqflite) pour les données MUTABLES
/// de l'utilisateur : favoris, progression des leçons, scores de quiz.
///
/// Le contenu du catalogue (phrases, vocabulaire, leçons) est en lecture
/// seule et vit dans les assets JSON (voir lib/data/content_repository.dart) :
/// pas besoin de le dupliquer dans une base, ça garde le contenu versionnable
/// et éditable directement dans le repo.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sabai_tourisme.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            phrase_id TEXT PRIMARY KEY,
            added_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE lesson_progress (
            lesson_id TEXT PRIMARY KEY,
            completed INTEGER NOT NULL DEFAULT 0,
            best_score INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<Set<String>> getFavoriteIds() async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['phrase_id']);
    return rows.map((r) => r['phrase_id'] as String).toSet();
  }

  Future<void> addFavorite(String phraseId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'phrase_id': phraseId, 'added_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String phraseId) async {
    final db = await database;
    await db.delete('favorites', where: 'phrase_id = ?', whereArgs: [phraseId]);
  }

  /// Progression de toutes les mini-leçons : lessonId -> (completed, bestScore).
  Future<Map<String, (bool completed, int bestScore)>>
      getAllLessonProgress() async {
    final db = await database;
    final rows = await db.query('lesson_progress');
    return {
      for (final r in rows)
        r['lesson_id'] as String: (
          (r['completed'] as int) == 1,
          r['best_score'] as int,
        ),
    };
  }

  /// Enregistre le résultat d'un quiz de leçon : marque la leçon comme
  /// terminée et conserve le meilleur score obtenu.
  Future<void> saveLessonResult(String lessonId, int score) async {
    final db = await database;
    final existing = await db.query(
      'lesson_progress',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
    final previousBest =
        existing.isEmpty ? 0 : existing.first['best_score'] as int;
    await db.insert(
      'lesson_progress',
      {
        'lesson_id': lessonId,
        'completed': 1,
        'best_score': score > previousBest ? score : previousBest,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
