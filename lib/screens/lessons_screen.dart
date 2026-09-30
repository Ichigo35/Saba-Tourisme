import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../models/lesson.dart';
import '../services/lesson_progress_service.dart';
import '../utils/theme.dart';
import '../widgets/empty_state.dart';
import 'lesson_detail_screen.dart';

/// Liste des mini-leçons : une par grande catégorie, avec quiz de révision
/// et progression enregistrée (point 21 du cahier des charges).
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lessons = ContentRepository.instance.lessons;
    final progressService = context.watch<LessonProgressService>();

    return Scaffold(
      appBar: AppBar(title: const Text('📚 Mini-leçons')),
      body: lessons.isEmpty
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: 'Aucune leçon disponible pour le moment',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final progress = progressService.progressFor(lesson.id);
                return _LessonTile(lesson: lesson, progress: progress);
              },
            ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.progress});

  final Lesson lesson;
  final LessonProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = lesson.quizIds.length;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(lesson.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          lesson.titleFr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          progress.completed
              ? 'Meilleur score : ${progress.bestScore}/$total'
              : '${lesson.phraseIds.length} phrases à réviser',
        ),
        trailing: progress.completed
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LessonDetailScreen(lesson: lesson)),
        ),
      ),
    );
  }
}
