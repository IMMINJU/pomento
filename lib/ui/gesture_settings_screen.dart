import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/gesture_settings.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/screen_header.dart';
import 'widgets/settings_list.dart';

void openDragGestureScreen(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DragGestureScreen()),
    );

void openTapGestureScreen(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TapGestureScreen()),
    );

/// 끌기와 쓸기에 무엇을 걸지.
///
/// 쓸기를 켜두면 같은 축의 이어 끌기 항목이 흐려진다. 한 손가락으로 두 가지를
/// 같은 방향에 걸면 어느 쪽인지 가릴 수 없어서다.
class DragGestureScreen extends ConsumerWidget {
  const DragGestureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(settingsProvider.select((s) => s.gestures));
    final c = ref.read(settingsProvider.notifier);
    void put(GestureSettings next) => c.setGestures(next);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: '드래그 제스쳐', showBack: true),
            Expanded(
              child: ListView(
                padding:
                    EdgeInsets.only(bottom: shellBottomInset(context, ref) + 24),
                children: [
                  SettingsSection(
                    title: '수평 드래그',
                    children: [
                      SettingsSwitchRow(
                        title: '쓸기 제스쳐 사용',
                        value: g.horizontalSwipe,
                        onChanged: (v) =>
                            put(g.copyWith(horizontalSwipe: v)),
                      ),
                      _ActionRow(
                        title: '왼쪽에서 쓸기',
                        value: g.swipeFromLeft,
                        enabled: g.horizontalSwipe,
                        onPick: (v) => put(g.copyWith(swipeFromLeft: v)),
                      ),
                      _ActionRow(
                        title: '오른쪽에서 쓸기',
                        value: g.swipeFromRight,
                        enabled: g.horizontalSwipe,
                        onPick: (v) => put(g.copyWith(swipeFromRight: v)),
                      ),
                      _DragRow(
                        title: '수평 드래그',
                        value: g.horizontalDrag,
                        enabled: !g.horizontalSwipe,
                        onPick: (v) => put(g.copyWith(horizontalDrag: v)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '수직 드래그',
                    children: [
                      SettingsSwitchRow(
                        title: '쓸기 제스쳐 사용',
                        value: g.verticalSwipe,
                        onChanged: (v) => put(g.copyWith(verticalSwipe: v)),
                      ),
                      _ActionRow(
                        title: '아래쪽에서 쓸기',
                        value: g.swipeFromBottom,
                        enabled: g.verticalSwipe,
                        onPick: (v) => put(g.copyWith(swipeFromBottom: v)),
                      ),
                      _ActionRow(
                        title: '위쪽에서 쓸기',
                        value: g.swipeFromTop,
                        enabled: g.verticalSwipe,
                        onPick: (v) => put(g.copyWith(swipeFromTop: v)),
                      ),
                      _DragRow(
                        title: '수직 드래그',
                        value: g.verticalDrag,
                        enabled: !g.verticalSwipe,
                        onPick: (v) => put(g.copyWith(verticalDrag: v)),
                      ),
                      _DragRow(
                        title: '수직 드래그 (좌측면)',
                        value: g.verticalDragLeft,
                        onPick: (v) => put(g.copyWith(verticalDragLeft: v)),
                      ),
                      _DragRow(
                        title: '수직 드래그 (우측면)',
                        value: g.verticalDragRight,
                        onPick: (v) => put(g.copyWith(verticalDragRight: v)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      '측면은 화면을 가로로 셋으로 나눈 양 끝을 말합니다. '
                      '가운데에서 끌면 측면이 아닌 쪽이 걸립니다.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두드림에 무엇을 걸지.
class TapGestureScreen extends ConsumerWidget {
  const TapGestureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(settingsProvider.select((s) => s.gestures));
    final c = ref.read(settingsProvider.notifier);
    void put(GestureSettings next) => c.setGestures(next);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: '탭 제스쳐', showBack: true),
            Expanded(
              child: ListView(
                padding:
                    EdgeInsets.only(bottom: shellBottomInset(context, ref) + 24),
                children: [
                  SettingsSection(
                    title: '탭',
                    children: [
                      _ActionRow(
                        title: '탭',
                        value: g.tap,
                        onPick: (v) => put(g.copyWith(tap: v)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '더블 탭',
                    children: [
                      _ActionRow(
                        title: '더블 탭',
                        value: g.doubleTap,
                        onPick: (v) => put(g.copyWith(doubleTap: v)),
                      ),
                      _ActionRow(
                        title: '더블 탭 (좌측면)',
                        value: g.doubleTapLeft,
                        onPick: (v) => put(g.copyWith(doubleTapLeft: v)),
                      ),
                      _ActionRow(
                        title: '더블 탭 (우측면)',
                        value: g.doubleTapRight,
                        onPick: (v) => put(g.copyWith(doubleTapRight: v)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '길게 누르기',
                    children: [
                      _ActionRow(
                        title: '길게 누르기',
                        value: g.longPress,
                        onPick: (v) => put(g.copyWith(longPress: v)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      '탭에 무엇을 걸면 화면의 버튼을 누를 때마다 함께 걸릴 수 '
                      '있습니다. 기본값을 미설정으로 둔 이유입니다.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.value,
    required this.onPick,
    this.enabled = true,
  });

  final String title;
  final GestureAction value;
  final ValueChanged<GestureAction> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SettingsRow(
          title: title,
          value: value.label,
          onTap: () async {
            final v = await showChoiceDialog<GestureAction>(
              context: context,
              title: title,
              choices: GestureAction.values,
              selected: value,
              label: (a) => a.label,
            );
            if (v != null) onPick(v);
          },
        ),
      ),
    );
  }
}

class _DragRow extends StatelessWidget {
  const _DragRow({
    required this.title,
    required this.value,
    required this.onPick,
    this.enabled = true,
  });

  final String title;
  final DragAction value;
  final ValueChanged<DragAction> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SettingsRow(
          title: title,
          value: value.label,
          onTap: () async {
            final v = await showChoiceDialog<DragAction>(
              context: context,
              title: title,
              choices: DragAction.values,
              selected: value,
              label: (a) => a.label,
            );
            if (v != null) onPick(v);
          },
        ),
      ),
    );
  }
}
