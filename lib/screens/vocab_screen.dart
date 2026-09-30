import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../utils/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/vocab_card.dart';

const Map<String, String> _themeLabels = {
  'nombres': '🔢 Nombres',
  'heures': '🕐 Heures',
  'jours': '📅 Jours',
  'lieux': '📍 Lieux',
  'transport': '🚌 Transport',
  'couleurs': '🎨 Couleurs',
};

/// Écran Vocabulaire : mots isolés français/lao classés par thème, utile au
/// quotidien pour un professionnel du tourisme (nombres, heures, lieux...).
class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});

  @override
  State<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends State<VocabScreen> {
  late String _selectedTheme;

  @override
  void initState() {
    super.initState();
    final themes = ContentRepository.instance.vocabThemes;
    _selectedTheme = themes.isNotEmpty ? themes.first : '';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ContentRepository.instance;
    final themes = repo.vocabThemes;
    final words = repo.vocabForTheme(_selectedTheme);

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulaire')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: themes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  final selected = theme == _selectedTheme;
                  return ChoiceChip(
                    label: Text(_themeLabels[theme] ?? theme),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedTheme = theme),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surface,
                    shape: const StadiumBorder(),
                  );
                },
              ),
            ),
            Expanded(
              child: words.isEmpty
                  ? const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Aucun mot dans ce thème',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: words.length,
                      itemBuilder: (context, index) =>
                          VocabCard(word: words[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
