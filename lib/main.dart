import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/content_repository.dart';
import 'database/app_database.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/favorites_service.dart';
import 'services/lesson_progress_service.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ContentRepository.instance.load();

  final favoritesService = FavoritesService(AppDatabase.instance);
  await favoritesService.load();

  final lessonProgressService = LessonProgressService(AppDatabase.instance);
  await lessonProgressService.load();

  final audioService = AudioService();

  runApp(SabaiTourismeApp(
    favoritesService: favoritesService,
    lessonProgressService: lessonProgressService,
    audioService: audioService,
  ));
}

class SabaiTourismeApp extends StatelessWidget {
  const SabaiTourismeApp({
    super.key,
    required this.favoritesService,
    required this.lessonProgressService,
    required this.audioService,
  });

  final FavoritesService favoritesService;
  final LessonProgressService lessonProgressService;
  final AudioService audioService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FavoritesService>.value(value: favoritesService),
        ChangeNotifierProvider<LessonProgressService>.value(
          value: lessonProgressService,
        ),
        Provider<AudioService>.value(value: audioService),
      ],
      child: MaterialApp(
        title: 'Sabai Tourisme',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
