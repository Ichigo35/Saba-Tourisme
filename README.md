# Sabai Tourisme

Application Android (Flutter) pour les professionnels lao du tourisme (guides,
chauffeurs, accompagnateurs, personnel d'accueil) qui doivent communiquer en
français avec des touristes francophones.

Pour chaque phrase : texte français, traduction lao, transcription phonétique
en alphabet lao (pour aider à prononcer le français), et lecture audio
(synthèse vocale française, normale ou lente). Fonctionne **hors-ligne**.

> ⚠️ **Traductions et phonétique** : tout le contenu lao de cette version est
> marqué `needsReview: true` dans les fichiers de données
> (`assets/data/*.json`) et affiche un badge "à valider" dans l'application.
> Il doit être relu par un locuteur lao natif avant tout déploiement terrain.

## État actuel du projet

- ✅ Socle technique Flutter/Android fonctionnel (voir "Toolchain" ci-dessous)
- ✅ Écran d'accueil avec catégories, recherche, favoris
- ✅ 2 catégories réellement peuplées : **Accueillir un touriste** (accueil,
  aéroport, hôtel) et **Restaurant** — 34 phrases complètes (français / lao /
  phonétique / audio)
- ⏳ À venir (phases suivantes) : catalogue complet (300+ phrases sur toutes
  les catégories), vocabulaire, nombres/heures, mini-leçons, quiz, mode
  "Je dois parler français", mode "Le touriste m'a dit quoi", simulation

## Installer l'APK sur un téléphone Android

1. Récupérer `build/app/outputs/flutter-apk/app-debug.apk` (généré localement,
   pas versionné dans git — voir section compilation ci-dessous).
2. Transférer le fichier `.apk` sur le téléphone (câble USB, ou un service de
   partage de fichiers).
3. Sur le téléphone, autoriser "Installer des applications inconnues" pour
   l'application utilisée pour ouvrir le fichier (Réglages → Sécurité).
4. Ouvrir le fichier `.apk` sur le téléphone et suivre l'installation.

## Compiler le projet

### Prérequis (déjà installés sur cette machine de dev)

- Flutter 3.47.5 (`brew install --cask flutter`)
- Android SDK (plateforme 36, build-tools 28.0.3 et 36.0.0) via
  `~/Library/Android/sdk`
- Java 21 (`brew install --cask temurin` ou `openjdk@21`)

Vérifier l'installation : `flutter doctor`

### Commandes

```bash
flutter pub get                 # installe les dépendances
flutter analyze                 # vérifie le code
flutter test                    # lance les tests
flutter build apk --debug       # APK de test (non optimisé, ~150 Mo)
flutter build apk --release     # APK de production (optimisé, plus léger)
```

L'APK release nécessite une clé de signature (voir
`android/app/build.gradle.kts` — utilise la clé debug par défaut tant
qu'aucune clé de release n'est configurée : suffisant pour tester, **pas**
pour publier sur le Play Store).

## Ajouter ou modifier des phrases

Tout le contenu du catalogue vit dans `assets/data/phrases.json` (pas besoin
de toucher au code Dart). Chaque phrase suit ce format :

```json
{
  "id": "res-011",
  "categoryId": "restaurant",
  "situation": "restaurant",
  "french": "Le plat va arriver bientôt.",
  "lao": "...",
  "phoneticLao": "...",
  "explanation": "Optionnel : quand utiliser cette phrase.",
  "pronunciationTip": "Optionnel : conseil sur un son français difficile.",
  "audioPath": null,
  "difficulty": "debutant",
  "tags": ["restaurant"],
  "needsReview": true
}
```

- `id` doit être unique dans tout le fichier.
- `categoryId` doit correspondre à un `id` de `assets/data/categories.json`.
- Laisser `needsReview: true` tant que la traduction n'a pas été validée par
  un locuteur lao natif.

Après modification, relancer l'app (`flutter run`) — aucune recompilation du
code n'est nécessaire, les JSON sont rechargés au démarrage.

## Ajouter une nouvelle catégorie

Ajouter une entrée dans `assets/data/categories.json` :

```json
{ "id": "shopping", "nameFr": "Shopping", "nameLao": "ຊື້ເຄື່ອງ", "emoji": "🛍️" }
```

La catégorie apparaît automatiquement sur l'écran d'accueil **dès qu'elle a
au moins une phrase** dans `phrases.json` (voir `lib/screens/home_screen.dart`
— la grille est pilotée par les données, jamais de bouton qui mène à un écran
vide).

## Ajouter des audios pré-enregistrés

Le MVP utilise la synthèse vocale (TTS) française embarquée d'Android
(`flutter_tts`, voix fr-FR), qui fonctionne hors-ligne. Pour remplacer le TTS
par un fichier audio pré-enregistré sur une phrase précise :

1. Placer le fichier dans `assets/audio/fr/<id-de-la-phrase>.mp3`.
2. Renseigner `"audioPath": "assets/audio/fr/<id-de-la-phrase>.mp3"` dans
   `phrases.json`.
3. (Phase audio à venir) `AudioService` sera étendu pour lire ce fichier en
   priorité s'il existe, et retomber sur le TTS sinon — l'API des boutons
   (`AudioButtons`) ne changera pas.

## Architecture du code

```
lib/
  main.dart               point d'entrée, injection des services
  models/                 Category, Phrase, VocabWord, Lesson, QuizItem
  data/                   ContentRepository (charge les JSON des assets)
  database/               AppDatabase (SQLite/sqflite : favoris, progression)
  services/               AudioService (TTS), FavoritesService
  screens/                un fichier par écran
  widgets/                composants réutilisables (CategoryCard, PhraseCard…)
  utils/                  thème, constantes
assets/
  data/                   categories.json, phrases.json (contenu éditable)
  fonts/                  NotoSans, NotoSansLao (rendu correct hors-ligne)
  audio/fr/               futurs fichiers audio pré-enregistrés
```

Voir aussi `CLAUDE.md` (racine du dossier utilisateur) section "Projet Sabai
Tourisme" pour les conventions de travail sur ce projet.
