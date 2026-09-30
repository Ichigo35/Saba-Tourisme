import 'package:flutter/material.dart';

import 'dialogues_screen.dart';
import 'home_screen.dart';
import 'lessons_screen.dart';
import 'plus_screen.dart';
import 'vocab_screen.dart';

/// Coquille de navigation racine : barre de navigation en bas plutôt que des
/// icônes d'action entassées dans l'AppBar de l'accueil (5 icônes à la fin
/// de la Phase Assistant IA, point de vigilance noté depuis la Phase 4).
/// Chaque onglet garde son propre `Scaffold`/`AppBar` (imbrication standard
/// en Flutter), donc les écrans existants n'ont pas eu besoin d'être
/// restructurés. `IndexedStack` avec des enfants `const` garde l'état de
/// chaque onglet vivant (position de scroll, filtre sélectionné…) en
/// changeant d'onglet.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    VocabScreen(),
    LessonsScreen(),
    DialoguesScreen(),
    PlusScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vocabulaire',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Leçons',
          ),
          NavigationDestination(
            icon: Icon(Icons.theater_comedy_outlined),
            selectedIcon: Icon(Icons.theater_comedy),
            label: 'Dialogues',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
