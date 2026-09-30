/// Un item de quiz (voir mode Quiz : français->lao, lao->français, audio, situation).
enum QuizType { frToLao, laoToFr, audio, situation }

class QuizItem {
  final String id;
  final QuizType type;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String? relatedPhraseId;

  const QuizItem({
    required this.id,
    required this.type,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.relatedPhraseId,
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
        id: json['id'] as String,
        type: QuizType.values.firstWhere((t) => t.name == json['type']),
        prompt: json['prompt'] as String,
        choices:
            (json['choices'] as List<dynamic>).map((e) => e as String).toList(),
        correctIndex: json['correctIndex'] as int,
        relatedPhraseId: json['relatedPhraseId'] as String?,
      );
}
