import 'package:flutter_tts/flutter_tts.dart';

/// Lecture audio des phrases françaises.
///
/// Stratégie (voir point 8 du cahier des charges) : le MVP utilise la
/// synthèse vocale française embarquée d'Android (`flutter_tts`, voix
/// fr-FR), qui fonctionne nativement hors-ligne une fois la voix installée
/// sur l'appareil. L'API de ce service (`speak` / `speakSlowly`) restera
/// identique le jour où des fichiers audio pré-enregistrés
/// (`assets/audio/fr/<id>.mp3`) remplaceront le TTS pour les phrases
/// prioritaires : seule l'implémentation interne changera.
class AudioService {
  AudioService() {
    _tts.setLanguage('fr-FR');
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();

  static const double _normalRate = 0.5;
  static const double _slowRate = 0.28;

  /// [onComplete] est appelé quand la phrase se termine naturellement OU
  /// quand elle est interrompue par [stop] (utile pour un bouton
  /// lecture/stop qui doit remettre son icône à l'état "arrêté" dans les
  /// deux cas).
  Future<void> speak(String text, {void Function()? onComplete}) async {
    _tts.setCompletionHandler(onComplete ?? () {});
    _tts.setCancelHandler(onComplete ?? () {});
    await _tts.setSpeechRate(_normalRate);
    await _tts.speak(text);
  }

  Future<void> speakSlowly(String text, {void Function()? onComplete}) async {
    _tts.setCompletionHandler(onComplete ?? () {});
    _tts.setCancelHandler(onComplete ?? () {});
    await _tts.setSpeechRate(_slowRate);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
