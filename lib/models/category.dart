/// Une grande catégorie de l'écran d'accueil (ex: "Accueillir un touriste").
class Category {
  final String id;
  final String nameFr;
  final String nameLao;
  final String emoji;

  const Category({
    required this.id,
    required this.nameFr,
    required this.nameLao,
    required this.emoji,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        nameFr: json['nameFr'] as String,
        nameLao: json['nameLao'] as String,
        emoji: json['emoji'] as String,
      );
}
