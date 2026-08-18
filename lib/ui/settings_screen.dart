import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../providers.dart';
import 'effects_screen.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

/// 조작 단위를 정하는 화면.
///
/// Capriccio가 탐색 시간, 속도 조절 단위, 피치 조절 단위를 사용자에게 맡기는
/// 것과 같은 자리다. 반음 단위로 옮기는 사람과 A=432Hz를 맞추는 사람이 원하는
/// 스테퍼 폭이 다르다.
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
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            shellBottomInset(context, ref) + 24,
          ),
          children: [
            const Text('설정', style: AppText.display),
            const SizedBox(height: 24),

            const SectionLabel('속도'),
            const SizedBox(height: 10),
            _ChoiceRow<double>(
              label: '스테퍼 한 번',
              value: s.speedStep,
              choices: AppSettings.speedStepChoices,
              format: (v) => v.toStringAsFixed(2),
              onSelect: c.setSpeedStep,
            ),
            const SizedBox(height: 14),
            _ChoiceRow<SpeedRange>(
              label: '슬라이더 폭',
              value: s.speedRange,
              choices: SpeedRange.values,
              format: (r) => r.label,
              onSelect: c.setSpeedRange,
            ),
            const SizedBox(height: 4),
            const Text(
              '폭을 좁히면 1.0 근처를 더 곱게 다룰 수 있습니다. '
              '숫자칸과 −/+ 로는 폭 밖으로도 나갈 수 있습니다.',
              style: AppText.small,
            ),
            const SizedBox(height: 14),
            _ChoiceRow<double>(
              label: '넛지 폭',
              value: s.nudgePercent,
              choices: AppSettings.nudgeChoices,
              format: (v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%',
              onSelect: c.setNudgePercent,
            ),
            const SizedBox(height: 4),
            const Text(
              '누르고 있는 동안만 속도가 밀립니다. 손을 떼면 원래 값으로 '
              '돌아갑니다.',
              style: AppText.small,
            ),

            const SizedBox(height: 28),
            const SectionLabel('피치'),
            const SizedBox(height: 10),
            _ChoiceRow<int>(
              label: '스테퍼 한 번',
              value: s.pitchStepCents,
              choices: AppSettings.pitchStepChoices,
              format: (v) => v == 100 ? '반음' : '$v¢',
              onSelect: c.setPitchStep,
            ),

            const SizedBox(height: 28),
            const SectionLabel('점프 탐색'),
            const SizedBox(height: 10),
            _ChoiceRow<int>(
              label: '짧게',
              value: s.seekShortSeconds,
              choices: AppSettings.seekChoices,
              format: (v) => '$v초',
              onSelect: c.setSeekShort,
            ),
            const SizedBox(height: 14),
            _ChoiceRow<int>(
              label: '길게',
              value: s.seekLongSeconds,
              choices: AppSettings.seekChoices,
              format: (v) => '$v초',
              onSelect: c.setSeekLong,
            ),

            const SizedBox(height: 28),
            const SectionLabel('화면'),
            const SizedBox(height: 10),
            _SwitchRow(
              label: '제스처 안내 보이기',
              sub: '연습 화면 아래에 두 손가락 조작 설명을 둡니다',
              value: s.showGestureHint,
              onChanged: c.setShowGestureHint,
            ),
            const SizedBox(height: 10),
            _SwitchRow(
              label: '화면 꺼짐 방지',
              sub: '앱을 보고 있는 동안 화면이 꺼지지 않습니다',
              value: s.keepScreenOn,
              onChanged: c.setKeepScreenOn,
            ),

            const SizedBox(height: 28),
            const SectionLabel('음향'),
            const SizedBox(height: 10),
            _LinkRow(
              icon: Icons.tune,
              label: '음향 보정 열기',
              sub: '기기 · 환경 · 취향 세 층',
              onTap: () => openEffectsScreen(context),
            ),

            const SizedBox(height: 28),
            const SectionLabel('Spotify'),
            const SizedBox(height: 10),
            const _SpotifyBlock(),
          ],
        ),
      ),
    );
  }
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
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
                    labelStyle: TextStyle(color: AppColors.t3, fontSize: 13),
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
                    style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              s.connected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: s.connected ? AppColors.accent : AppColors.t3,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.error ??
                    (s.connected ? 'Spotify 앱에 연결됨' : '연결되어 있지 않습니다'),
                style: AppText.small,
              ),
            ),
            if (s.connecting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              AccentButton(
                label: s.connected ? '끊기' : '연결',
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                onPressed: s.isConfigured
                    ? (s.connected ? session.disconnect : session.connect)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Spotify로 트는 소리는 Spotify 앱에서 나옵니다. 그 곡에는 배속과 '
          '3층 보정이 걸리지 않습니다. 내가 가진 파일로 틀면 모두 열립니다.',
          style: AppText.small,
        ),
      ],
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.choices,
    required this.format,
    required this.onSelect,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T) format;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: AppColors.t2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ch in choices)
              GlassPill(
                selected: ch == value,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onTap: () => onSelect(ch),
                child: Text(
                  format(ch),
                  style: TextStyle(
                    fontSize: 13,
                    color: ch == value ? AppColors.t1 : AppColors.t2,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 15, color: AppColors.t1)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.small),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.t2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 15, color: AppColors.t1)),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.small),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.t3),
          ],
        ),
      ),
    );
  }
}
