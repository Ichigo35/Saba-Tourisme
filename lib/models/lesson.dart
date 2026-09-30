/// Une mini-leçon du parcours d'apprentissage (voir mode Mini-leçons).
class Lesson {
  final String id;
  final String titleFr;
  final String emoji;
  final int order;
  final List<String> phraseIds;
  final List<String> quizIds;

  const Lesson({
    required this.id,
    required this.titleFr,
    required this.emoji,
    required this.order,
    this.phraseIds = const [],
    this.quizIds = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        titleFr: json['titleFr'] as String,
        emoji: json['emoji'] as String,
        order: json['order'] as int,
        phraseIds: (json['phraseIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        quizIds: (json['quizIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}
