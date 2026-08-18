import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../providers.dart';
import 'effects_screen.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/settings_list.dart';

/// 설정.
///
/// Capriccio의 설정처럼 섹션과 목록으로만 짠다. 왼쪽에 항목 이름, 오른쪽에
/// 지금 값, 누르면 목록 대화상자가 뜬다. 알약이나 슬라이더를 쓰지 않으므로
/// 항목이 늘어도 화면이 흐트러지지 않는다.
///
/// 재생 컨트롤 항목 이름은 그쪽 것을 그대로 쓴다. 탐색 시간 1, 탐색 시간 2,
/// 속도 조절 단위, 피치 조절 단위. 기본값도 5초, 10초, 0.05x로 같다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: shellBottomInset(context, ref) + 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('설정', style: AppText.display),
            ),

            SettingsSection(
              title: '재생 컨트롤',
              children: [
                SettingsRow(
                  title: '탐색 시간 1',
                  value: '${s.seekShortSeconds}초',
                  onTap: () async {
                    final v = await showChoiceDialog<int>(
                      context: context,
                      title: '탐색 시간 1',
                      choices: AppSettings.seekChoices,
                      selected: s.seekShortSeconds,
                      label: (v) => '$v초',
                    );
                    if (v != null) c.setSeekShort(v);
                  },
                ),
                SettingsRow(
                  title: '탐색 시간 2',
                  value: '${s.seekLongSeconds}초',
                  onTap: () async {
                    final v = await showChoiceDialog<int>(
                      context: context,
                      title: '탐색 시간 2',
                      choices: AppSettings.seekChoices,
                      selected: s.seekLongSeconds,
                      label: (v) => '$v초',
                    );
                    if (v != null) c.setSeekLong(v);
                  },
                ),
                SettingsRow(
                  title: '속도 조절 단위',
                  value: '${s.speedStep.toStringAsFixed(2)}x',
                  onTap: () async {
                    final v = await showChoiceDialog<double>(
                      context: context,
                      title: '속도 조절 단위',
                      choices: AppSettings.speedStepChoices,
                      selected: s.speedStep,
                      label: (v) => '${v.toStringAsFixed(2)}x',
                    );
                    if (v != null) c.setSpeedStep(v);
                  },
                ),
                SettingsRow(
                  title: '피치 조절 단위',
                  value: _pitchLabel(s.pitchStepCents),
                  description: '센트로도 고를 수 있습니다. 100센트가 한 반음입니다',
                  onTap: () async {
                    final v = await showChoiceDialog<int>(
                      context: context,
                      title: '피치 조절 단위',
                      choices: AppSettings.pitchStepChoices,
                      selected: s.pitchStepCents,
                      label: _pitchLabel,
                    );
                    if (v != null) c.setPitchStep(v);
                  },
                ),
                SettingsRow(
                  title: '속도 슬라이더 폭',
                  value: s.speedRange.label,
                  description: '폭을 좁히면 1.0배 근처를 더 곱게 다룰 수 있습니다',
                  onTap: () async {
                    final v = await showChoiceDialog<SpeedRange>(
                      context: context,
                      title: '속도 슬라이더 폭',
                      choices: SpeedRange.values,
                      selected: s.speedRange,
                      label: (v) => v.label,
                    );
                    if (v != null) c.setSpeedRange(v);
                  },
                ),
                SettingsRow(
                  title: '넛지 폭',
                  value: _percent(s.nudgePercent),
                  description: '누르고 있는 동안만 속도가 밀립니다',
                  onTap: () async {
                    final v = await showChoiceDialog<double>(
                      context: context,
                      title: '넛지 폭',
                      choices: AppSettings.nudgeChoices,
                      selected: s.nudgePercent,
                      label: _percent,
                    );
                    if (v != null) c.setNudgePercent(v);
                  },
                ),
              ],
            ),

            SettingsSection(
              title: '제스쳐와 화면',
              children: [
                SettingsSwitchRow(
                  title: '제스쳐 안내 보이기',
                  description: '연습 화면 아래에 두 손가락 조작 설명을 둡니다',
                  value: s.showGestureHint,
                  onChanged: c.setShowGestureHint,
                ),
                SettingsSwitchRow(
                  title: '화면 꺼짐 방지',
                  description: '앱을 보고 있는 동안 화면이 꺼지지 않습니다',
                  value: s.keepScreenOn,
                  onChanged: c.setKeepScreenOn,
                ),
              ],
            ),

            SettingsSection(
              title: '음향',
              children: [
                SettingsLinkRow(
                  title: '음향 효과',
                  description: '기기 보정, 환경 보정, 취향 프리셋',
                  onTap: () => openEffectsScreen(context),
                ),
              ],
            ),

            const SettingsSection(
              title: 'Spotify',
              children: [_SpotifyBlock()],
            ),
          ],
        ),
      ),
    );
  }

  static String _pitchLabel(int cents) => switch (cents) {
        100 => '1 반음',
        50 => '반 반음',
        _ => '$cents센트',
      };

  static String _percent(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';
}

/// Spotify 연결.
///
/// Client ID는 개발자 대시보드에서 앱을 만들면 나온다. Redirect URI로
/// `pomento://auth`를, Android 패키지명으로 `com.pomento.app`과 키스토어
/// SHA-1을 그 대시보드에 같이 등록해야 연결이 붙는다.
class _SpotifyBlock extends ConsumerStatefulWidget {
  const _SpotifyBlock();

  @override
  ConsumerState<_SpotifyBlock> createState() => _SpotifyBlockState();
}

class _SpotifyBlockState extends ConsumerState<_SpotifyBlock> {
  final _text = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(spotifySessionProvider);
    final session = ref.read(spotifySessionProvider.notifier);

    // 저장된 값이 늦게 올라온다. 한 번만 칸에 채워 넣는다.
    if (!_seeded && s.clientId.isNotEmpty) {
      _text.text = s.clientId;
      _seeded = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  style: AppText.body,
                  cursorColor: AppColors.accent,
                  onSubmitted: session.setClientId,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    labelText: 'Client ID',
                    labelStyle: TextStyle(color: AppColors.t3, fontSize: 14),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  session.setClientId(_text.text);
                  FocusScope.of(context).unfocus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('저장했습니다')),
                  );
                },
                child: const Text('저장',
                    style: TextStyle(fontSize: 16, color: AppColors.accent)),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: !s.isConfigured || s.connecting
              ? null
              : (s.connected ? session.disconnect : session.connect),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.connected ? '연결 끊기' : '연결',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.t1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.error ??
                            (s.connected
                                ? 'Spotify 앱에 연결됨'
                                : 'Spotify로 트는 소리에는 배속과 음향 보정이 걸리지 않습니다'),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (s.connecting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else
                  Icon(
                    s.connected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: s.connected ? AppColors.accent : AppColors.t3,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
