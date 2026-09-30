import 'dart:convert';

import 'package:http/http.dart' as http;

/// Un tour de dialogue envoyé au proxy IA : `user` = le pro (toi),
/// `model` = le touriste simulé par Gemini.
class AiChatTurn {
  const AiChatTurn({required this.role, required this.text});

  final String role;
  final String text;
}

class AiReply {
  const AiReply({required this.text, required this.model});

  final String text;
  final String model;
}

class AiConversationException implements Exception {
  AiConversationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Appelle le proxy Cloudflare `conversation-proxy` (voir
/// `cloudflare/conversation-proxy/` à la racine du repo) pour simuler un
/// touriste francophone qui improvise, via Gemini.
///
/// La clé API Gemini ne vit JAMAIS dans l'app : elle est un secret côté
/// Worker. Le secret partagé ci-dessous n'est pas une vraie authentification
/// (il finit dans l'APK compilé, donc extractible) — il sert seulement à
/// dissuader un usage occasionnel de l'URL du Worker par quelqu'un d'autre.
/// La vraie protection, c'est que la clé Gemini elle-même reste hors de
/// portée du client.
///
/// Sa valeur n'est volontairement PAS écrite en dur ici (elle ne doit pas
/// atterrir dans l'historique git, même si sa valeur de sécurité est
/// limitée) : elle est injectée à la compilation avec
/// `--dart-define=SABAI_APP_SHARED_SECRET=<valeur>` (valeur réelle dans la
/// mémoire du projet, jamais dans ce repo).
class AiConversationService {
  static const _endpoint =
      'https://sabai-tourisme-conversation-proxy.ichigo35.workers.dev';
  static const _appSecret =
      String.fromEnvironment('SABAI_APP_SHARED_SECRET');

  Future<AiReply> reply({
    required String systemPrompt,
    required List<AiChatTurn> history,
    required String userMessage,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': _appSecret,
            },
            body: jsonEncode({
              'systemPrompt': systemPrompt,
              'history':
                  history.map((t) => {'role': t.role, 'text': t.text}).toList(),
              'userMessage': userMessage,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw AiConversationException(
        'Impossible de contacter le service. Vérifiez votre connexion Internet.',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiConversationException('Réponse invalide du service.');
    }

    if (response.statusCode != 200) {
      throw AiConversationException(
        data['error'] as String? ?? 'Erreur inconnue du service.',
      );
    }
    return AiReply(
      text: data['reply'] as String,
      model: data['model'] as String? ?? '?',
    );
  }

  /// Traduit une phrase française en lao via le même proxy (mode
  /// `translate`), pour relire une réplique (celle du touriste IA ou la
  /// tienne) et vérifier qu'elle veut bien dire ce qui était voulu — même
  /// principe que la traduction repliée de la lecture guidée, mais générée à
  /// la volée puisque le texte n'existe pas dans le contenu figé.
  Future<String> translateToLao(String text) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': _appSecret,
            },
            body: jsonEncode({'mode': 'translate', 'text': text}),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw AiConversationException(
        'Impossible de contacter le service. Vérifiez votre connexion Internet.',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiConversationException('Réponse invalide du service.');
    }

    if (response.statusCode != 200) {
      throw AiConversationException(
        data['error'] as String? ?? 'Erreur inconnue du service.',
      );
    }
    return data['translation'] as String;
  }

  /// Mode "🆘 Je dois parler français" : à partir d'une description
  /// approximative de ce que le pro veut dire (mode `compose` du proxy),
  /// obtient la phrase française à prononcer, sa phonétique en écriture lao
  /// et sa traduction lao.
  Future<ComposedPhrase> composePhrase(String situation) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': _appSecret,
            },
            body: jsonEncode({'mode': 'compose', 'text': situation}),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw AiConversationException(
        'Impossible de contacter le service. Vérifiez votre connexion Internet.',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiConversationException('Réponse invalide du service.');
    }

    if (response.statusCode != 200) {
      throw AiConversationException(
        data['error'] as String? ?? 'Erreur inconnue du service.',
      );
    }
    return ComposedPhrase(
      french: data['french'] as String,
      phonetic: data['phonetic'] as String,
      meaning: data['meaning'] as String,
      model: data['model'] as String? ?? '?',
    );
  }
}

/// Résultat du mode "🆘 Je dois parler français" : phrase française générée
/// par l'IA à partir d'une situation décrite par le pro, avec sa phonétique
/// en écriture lao et sa traduction — toujours à considérer comme
/// `needsReview` (générée à la volée, jamais relue par un locuteur natif).
class ComposedPhrase {
  const ComposedPhrase({
    required this.french,
    required this.phonetic,
    required this.meaning,
    required this.model,
  });

  final String french;
  final String phonetic;
  final String meaning;
  final String model;
}
