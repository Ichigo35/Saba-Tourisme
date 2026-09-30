import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../models/lesson.dart';
import '../models/quiz_item.dart';
import '../services/lesson_progress_service.dart';
import '../utils/theme.dart';

/// Nombre maximum de questions posées par session de quiz, pour garder
/// une mini-leçon courte même quand la banque de questions est plus grande.
const _maxQuestionsPerSession = 10;

/// Quiz de révision d'une mini-leçon : questions à choix multiple,
/// français -> lao et lao -> français (point 21 du cahier des charges).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizItem> _questions;
  int _index = 0;
  int _score = 0;
  int? _selectedChoice;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    final all = List<QuizItem>.from(
      ContentRepository.instance.quizItemsForLesson(widget.lesson),
    )..shuffle(Random());
    _questions = all.take(_maxQuestionsPerSession).toList();
  }

  void _selectChoice(int choiceIndex) {
    if (_answered) return;
    final question = _questions[_index];
    setState(() {
      _selectedChoice = choiceIndex;
      _answered = true;
      if (choiceIndex == question.correctIndex) _score++;
    });
  }

  Future<void> _next() async {
    if (_index == _questions.length - 1) {
      await context.read<LessonProgressService>().recordResult(
            widget.lesson.id,
            _score,
            _questions.length,
          );
      if (!mounted) return;
      await _showResultDialog();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _selectedChoice = null;
      _answered = false;
    });
  }

  Future<void> _showResultDialog() {
    final total = _questions.length;
    final ratio = total == 0 ? 0.0 : _score / total;
    final message = ratio >= 0.8
        ? 'Excellent ! Cette leçon est bien maîtrisée. 🎉'
        : ratio >= 0.5
            ? 'Pas mal ! Encore un peu de pratique pour tout retenir.'
            : 'On continue de s\'entraîner, ça viendra ! 💪';
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Quiz terminé'),
        content: Text('Score : $_score/$total\n\n$message'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.lesson.emoji}  Quiz')),
        body: const Center(
          child: Text('Aucune question disponible pour cette leçon.'),
        ),
      );
    }

    final question = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lesson.emoji}  Quiz'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / _questions.length,
            backgroundColor: AppColors.background,
            color: AppColors.accent,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_index + 1}/${_questions.length}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                question.type == QuizType.frToLao
                    ? '🇫🇷 Comment le dire en lao ?'
                    : '🇱🇦 Que veut dire cette phrase ?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                question.prompt,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontFamily: question.type == QuizType.laoToFr
                      ? AppFonts.lao
                      : AppFonts.french,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: question.choices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ChoiceButton(
                    text: question.choices[i],
                    isLao: question.type == QuizType.frToLao,
                    state: !_answered
                        ? _ChoiceState.neutral
                        : i == question.correctIndex
                            ? _ChoiceState.correct
                            : i == _selectedChoice
                                ? _ChoiceState.wrong
                                : _ChoiceState.disabled,
                    onTap: () => _selectChoice(i),
                  ),
                ),
              ),
              if (_answered)
                FilledButton(
                  onPressed: _next,
                  child: Text(
                    _index == _questions.length - 1
                        ? 'Voir le résultat'
                        : 'Question suivante',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChoiceState { neutral, correct, wrong, disabled }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.text,
    required this.isLao,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool isLao;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color borderColor;
    switch (state) {
      case _ChoiceState.neutral:
        background = Colors.white;
        borderColor = AppColors.textMuted.withValues(alpha: 0.3);
        break;
      case _ChoiceState.correct:
        background = AppColors.success.withValues(alpha: 0.15);
        borderColor = AppColors.success;
        break;
      case _ChoiceState.wrong:
        background = AppColors.danger.withValues(alpha: 0.15);
        borderColor = AppColors.danger;
        break;
      case _ChoiceState.disabled:
        background = Colors.white;
        borderColor = AppColors.textMuted.withValues(alpha: 0.15);
        break;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state == _ChoiceState.neutral ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: isLao ? AppFonts.lao : AppFonts.french,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (state == _ChoiceState.correct)
                const Icon(Icons.check_circle, color: AppColors.success),
              if (state == _ChoiceState.wrong)
                const Icon(Icons.cancel, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}
