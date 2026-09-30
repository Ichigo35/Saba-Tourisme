/// Une phrase utilisable en situation réelle : français, traduction lao,
/// transcription phonétique pédagogique (lao -> prononciation française).
class Phrase {
  final String id;
  final String categoryId;
  final String situation;
  final String french;
  final String lao;
  final String phoneticLao;
  final String? explanation;
  final String? pronunciationTip;
  final String? audioPath;
  final String difficulty;
  final List<String> tags;

  /// true si la traduction ou la phonétique n'a pas encore été validée
  /// par un locuteur lao natif (voir point 20/8/9 du cahier des charges).
  final bool needsReview;

  const Phrase({
    required this.id,
    required this.categoryId,
    required this.situation,
    required this.french,
    required this.lao,
    required this.phoneticLao,
    this.explanation,
    this.pronunciationTip,
    this.audioPath,
    this.difficulty = 'debutant',
    this.tags = const [],
    this.needsReview = false,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        situation: json['situation'] as String? ?? '',
        french: json['french'] as String,
        lao: json['lao'] as String,
        phoneticLao: json['phoneticLao'] as String,
        explanation: json['explanation'] as String?,
        pronunciationTip: json['pronunciationTip'] as String?,
        audioPath: json['audioPath'] as String?,
        difficulty: json['difficulty'] as String? ?? 'debutant',
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
            const [],
        needsReview: json['needsReview'] as bool? ?? false,
      );
}
