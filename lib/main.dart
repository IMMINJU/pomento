import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'audio/audio_engine.dart';
import 'audio/audio_handler.dart';
import 'core/app_paths.dart';
import 'data/db/database.dart';
import 'data/repo/preset_repository.dart';
import 'providers.dart';
import 'ui/theme.dart';

/// 시작 단계를 순서대로 밟는다.
///
/// `runApp` 앞에 await가 다섯 번 있고, 그중 하나만 던져도 화면이 하나도
/// 안 뜬 채로 앱이 죽는다. 기기를 든 사람이 개발자가 아니면 무엇이
/// 잘못됐는지 알 길이 없다. 그래서 단계마다 이름을 달아두고, 실패하면
/// 그 이름과 오류를 화면에 적는다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var step = '앱 폴더';
  try {
    await AppPaths.init();

    step = '데이터베이스';
    final db = AppDatabase();
    await PresetRepository(db).seedBuiltins();

    // 오디오 세션을 음악 재생으로 선언해야 다른 앱과의 포커스 처리가 맞는다.
    step = '오디오 세션';
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    step = '재생 서비스';
    final handler = await AudioService.init(
      builder: PlayerAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pomento.app.playback',
        androidNotificationChannelName: '재생',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    // 엔진이 없으면 소리는 안 나지만 화면은 다 볼 수 있다. iOS에서 처음
    // 도는 참이라 여기서 멈추면 나머지가 멀쩡한지조차 확인할 수 없다.
    // 실패한 이유는 설정 화면에 남겨 둔다.
    step = '오디오 엔진';
    String? engineError;
    try {
      await AudioEngine.instance.init();
    } catch (error) {
      engineError = '$error';
    }

    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioHandlerProvider.overrideWithValue(handler),
          startupWarningProvider.overrideWithValue(engineError),
        ],
        child: const PlayerApp(),
      ),
    );
  } catch (error, stack) {
    runApp(_StartupFailure(step: step, error: '$error', stack: '$stack'));
  }
}

/// 시작에 실패했을 때 대신 뜨는 화면.
///
/// 종이나 폰트를 쓰지 않는다. 그것을 준비하는 단계에서 실패했을 수도
/// 있어서다. 글자는 고를 수 있게 둔다. 기기를 든 사람이 그대로 복사해
/// 보낼 수 있어야 한다.
class _StartupFailure extends StatelessWidget {
  const _StartupFailure({
    required this.step,
    required this.error,
    required this.stack,
  });

  final String step;
  final String error;
  final String stack;

  @override
  Widget build(BuildContext context) {
    final text = '$step 단계에서 실패\n\n$error\n\n$stack';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '시작하지 못했습니다',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '$step 단계',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error\n\n$stack',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: text)),
                    child: const Text('복사'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
