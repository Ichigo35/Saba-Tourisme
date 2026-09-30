import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../models/lesson.dart';
import '../services/lesson_progress_service.dart';
import '../utils/theme.dart';
import '../widgets/phrase_card.dart';
import 'quiz_screen.dart';

/// Révision des phrases d'une mini-leçon, puis accès au quiz associé.
class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final repo = ContentRepository.instance;
    final phrases = repo.phrasesForLesson(lesson);
    final progress = context.watch<LessonProgressService>().progressFor(lesson.id);

    return Scaffold(
      appBar: AppBar(title: Text('${lesson.emoji}  ${lesson.titleFr}')),
      body: Column(
        children: [
          if (progress.completed)
            Container(
              width: double.infinity,
              color: AppColors.success.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(12),
              child: Text(
                '✅ Meilleur score : ${progress.bestScore}/${lesson.quizIds.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: phrases.length,
              itemBuilder: (context, index) => PhraseCard(phrase: phrases[index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.quiz),
                  label: Text(
                    progress.completed ? 'Refaire le quiz' : 'Commencer le quiz',
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => QuizScreen(lesson: lesson)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
