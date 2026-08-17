import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'audio/audio_engine.dart';
import 'audio/audio_handler.dart';
import 'core/app_paths.dart';
import 'data/db/database.dart';
import 'data/repo/preset_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppPaths.init();

  final db = AppDatabase();
  await PresetRepository(db).seedBuiltins();

  // 오디오 세션을 음악 재생으로 선언해야 다른 앱과의 포커스 처리가 맞는다.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final handler = await AudioService.init(
    builder: PlayerAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.pomento.app.playback',
      androidNotificationChannelName: '재생',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  await AudioEngine.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioHandlerProvider.overrideWithValue(handler),
      ],
      child: const PlayerApp(),
    ),
  );
}
