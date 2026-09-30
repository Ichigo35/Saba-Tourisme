/// Un mot du dictionnaire français/lao spécialisé tourisme (voir mode Vocabulaire).
class VocabWord {
  final String id;
  final String category;
  final String french;
  final String lao;
  final String phoneticLao;
  final String? audioPath;
  final bool needsReview;

  const VocabWord({
    required this.id,
    required this.category,
    required this.french,
    required this.lao,
    required this.phoneticLao,
    this.audioPath,
    this.needsReview = false,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) => VocabWord(
        id: json['id'] as String,
        category: json['category'] as String,
        french: json['french'] as String,
        lao: json['lao'] as String,
        phoneticLao: json['phoneticLao'] as String,
        audioPath: json['audioPath'] as String?,
        needsReview: json['needsReview'] as bool? ?? false,
      );
}
