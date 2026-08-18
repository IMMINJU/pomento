import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/tempo.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/practice_blocks.dart';
import 'widgets/screen_header.dart';

/// 재생 화면 위에 쌓는다. 모달로 띄우지 않는 이유는 미니 플레이어와 탭바가
/// 남아 있어야 값을 바꾸면서 소리를 듣고 곡을 넘길 수 있기 때문이다.
void openPracticeScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PracticeScreen()),
  );
}

/// 배속, 피치, 구간 반복, 점프 탐색을 한 곳에 모은 화면.
///
/// 전에는 배속이 1.0이 아닐 때만 진입 배지가 떠서, 기본 상태에서는 배속을
/// 켜러 갈 길이 화면에 없었다. 이제 플레이어 전송 행의 왼쪽 버튼이 항상
/// 이 화면을 연다.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final tempo = state.tempo;
    final isLinked = tempo.mode == TempoMode.linked;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // 유리 뒤에 볼 것이 있어야 블러가 성립한다. 재생 화면과 같은
          // 앨범아트를 깔아 두 화면이 이어져 보이게 한다.
          BlurredBackdrop(
            track: state.current,
            topOverlay: 0.55,
            bottomOverlay: 0.80,
          ),
          SafeArea(
            bottom: false,
            child: Column(
        children: [
          ScreenHeader(
            title: '연습',
            actions: [
              HeaderAction(
                icon: Icons.refresh,
                label: '초기화',
                onTap: () {
                  controller.resetTempo();
                  controller.clearLoop();
                },
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom +
                    shellBottomInset(context, ref) +
                    24,
              ),
              children: [
                Center(
                  child: GlassSegment(
                    labels: [
                      TempoMode.linked.label,
                      TempoMode.independent.label,
                    ],
                    selectedIndex: isLinked ? 0 : 1,
                    onSelect: (i) => controller.setTempoMode(
                      i == 0 ? TempoMode.linked : TempoMode.independent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tempo.mode.hint,
                  textAlign: TextAlign.center,
                  style: AppText.small,
                ),
                const SizedBox(height: 20),

                SpeedBlock(
                  tempo: tempo,
                  settings: settings,
                  controller: controller,
                  onRangeChange: (r) =>
                      ref.read(settingsProvider.notifier).setSpeedRange(r),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 20),

                PitchBlock(
                  tempo: tempo,
                  settings: settings,
                  controller: controller,
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 16),

                const SectionLabel('구간 반복'),
                const SizedBox(height: 10),
                LoopBlock(state: state, controller: controller),
                const SizedBox(height: 20),

                const SectionLabel('점프 탐색'),
                const SizedBox(height: 10),
                JumpRow(settings: settings, controller: controller),
                const SizedBox(height: 20),

                RememberRow(
                  remember: state.rememberTempo,
                  onChanged: controller.setRememberTempo,
                ),
                if (settings.showGestureHint) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '재생 화면에서 두 손가락을 위아래로 끌면 속도, 좌우로 끌면 '
                    '피치가 움직입니다. 두 손가락으로 두 번 두드리면 연동과 고정이 '
                    '바뀝니다.',
                    style: AppText.small,
                  ),
                ],
              ],
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

