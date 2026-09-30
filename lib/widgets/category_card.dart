import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/theme.dart';

/// Grande carte de catégorie pour l'écran d'accueil (point 4 du cahier des
/// charges) : icône, nom lao en premier (public prioritaire), nom français
/// en second.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                category.nameLao,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.lao,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.nameFr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
