import 'package:flutter/material.dart';

import '../utils/theme.dart';
import 'assistant_screen.dart';
import 'favorites_screen.dart';

/// Onglet "Plus" : regroupe les fonctionnalités moins consultées au
/// quotidien (Assistant IA, Favoris) qui occupaient auparavant chacune une
/// icône dans l'AppBar de l'accueil — devenu illisible à 5 icônes serrées
/// (point de vigilance noté depuis la Phase 4). Sert aussi de point
/// d'ancrage pour toute future fonctionnalité secondaire, sans reprendre le
/// même problème.
class PlusScreen extends StatelessWidget {
  const PlusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _MenuTile(
            emoji: '🆘',
            title: 'Assistant IA',
            subtitle:
                'Parler français ou comprendre un touriste, en direct',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AssistantScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            emoji: '⭐',
            title: 'Mes phrases favorites',
            subtitle: 'Retrouver les phrases que tu utilises souvent',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
