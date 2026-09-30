import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Gère les phrases favorites de l'utilisateur (⭐ Mes phrases, point 15).
/// Persisté en local via [AppDatabase], notifie l'UI à chaque changement.
class FavoritesService extends ChangeNotifier {
  FavoritesService(this._db);

  final AppDatabase _db;
  Set<String> _favoriteIds = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get favoriteIds => _favoriteIds;

  Future<void> load() async {
    if (_loaded) return;
    _favoriteIds = await _db.getFavoriteIds();
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(String phraseId) => _favoriteIds.contains(phraseId);

  Future<void> toggle(String phraseId) async {
    if (_favoriteIds.contains(phraseId)) {
      _favoriteIds.remove(phraseId);
      await _db.removeFavorite(phraseId);
    } else {
      _favoriteIds.add(phraseId);
      await _db.addFavorite(phraseId);
    }
    notifyListeners();
  }
}
