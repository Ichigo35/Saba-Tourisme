/// Qui parle dans une réplique de simulation de conversation.
enum DialogueSpeaker { touriste, toi }

/// Une réplique d'un dialogue simulé.
///
/// - Pour `toi` : référence une [Phrase] existante du phrasebook
///   (`phraseId`), pour ne jamais dupliquer une traduction/phonétique déjà
///   validée ailleurs.
/// - Pour `touriste` : texte français directement embarqué (`textFr`), avec
///   une traduction lao indicative (`meaningLao`) pour aider le pro à
///   comprendre ce que dit le touriste, pas à le prononcer.
class DialogueTurn {
  final DialogueSpeaker speaker;
  final String? phraseId;
  final String? textFr;
  final String? meaningLao;

  const DialogueTurn({
    required this.speaker,
    this.phraseId,
    this.textFr,
    this.meaningLao,
  });

  factory DialogueTurn.fromJson(Map<String, dynamic> json) => DialogueTurn(
        speaker: DialogueSpeaker.values.firstWhere(
          (s) => s.name == json['speaker'],
        ),
        phraseId: json['phraseId'] as String?,
        textFr: json['textFr'] as String?,
        meaningLao: json['meaningLao'] as String?,
      );
}

/// Un scénario de simulation de conversation (ex : "Accueil à l'aéroport"),
/// lu comme un dialogue en bulles pour s'entraîner à l'enchaînement d'une
/// situation réelle (point 22 du cahier des charges).
class Dialogue {
  final String id;
  final String titleFr;
  final String emoji;
  final String categoryId;
  final List<DialogueTurn> turns;

  const Dialogue({
    required this.id,
    required this.titleFr,
    required this.emoji,
    required this.categoryId,
    required this.turns,
  });

  factory Dialogue.fromJson(Map<String, dynamic> json) => Dialogue(
        id: json['id'] as String,
        titleFr: json['titleFr'] as String,
        emoji: json['emoji'] as String,
        categoryId: json['categoryId'] as String,
        turns: (json['turns'] as List<dynamic>)
            .map((e) => DialogueTurn.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
