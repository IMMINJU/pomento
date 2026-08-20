import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'artwork_tone.dart';
import 'common.dart';
import 'surface.dart';

/// 로컬 재생 화면과 Spotify 재생 화면이 함께 쓰는 조각들.
///
/// 두 화면은 소리를 내는 주체가 다를 뿐 배치가 같다. 같은 모양을 두 벌
/// 들고 있으면 한쪽만 고치는 일이 생긴다. 실제로 점프 버튼과 A-B 알약이
/// 서로 다르게 남아 있었다.

/// 상단 바. 왼쪽 알약만 화면마다 다르고 나머지는 같다.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.leading,
    required this.panelOpen,
    required this.onTogglePanel,
    required this.onSearch,
    required this.onSettings,
    this.trailing = const [],
  });

  /// 큐 위치나 `Spotify` 표. 폭이 화면마다 다르다.
  final Widget leading;

  final bool panelOpen;
  final VoidCallback onTogglePanel;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  /// 검색 왼쪽에 더 붙일 것.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            RoundButton(
              on: panelOpen,
              onTap: onTogglePanel,
              child: Icon(
                Icons.compare_arrows,
                size: 20,
                color: panelOpen ? AppColors.paperHi : AppColors.ink1,
              ),
            ),
            const Spacer(),
            ...trailing,
            RoundButton(
              onTap: onSearch,
              child: const Icon(Icons.search, size: 20, color: AppColors.ink1),
            ),
            const SizedBox(width: 8),
            RoundButton(
              onTap: onSettings,
              child: const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.ink1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 큐 위치 알약. 곡의 진행이 아니라 큐 안에서 몇 번째인지를 밑줄로 그린다.
class QueuePill extends StatelessWidget {
  const QueuePill({super.key, required this.at, required this.total});

  final int at;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 40,
        alignment: Alignment.center,
        color: AppColors.paperLo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('$at / $total', style: AppText.num),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: total == 0 ? 0 : at / total,
                  child: ColoredBox(color: tone.fill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지난 시간과 남은 시간.
///
/// 둘 다 회색이다. 진행 정도는 바로 위 진행바가 말하므로 숫자까지
/// 색을 쓰면 강조가 겹친다.
class TimeRow extends StatelessWidget {
  const TimeRow({super.key, required this.position, required this.total});

  final Duration position;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          formatDuration(position),
          style: AppText.num.copyWith(fontSize: 12, color: AppColors.ink3),
        ),
        const Spacer(),
        Text(
          '-${formatDuration(total - position)}',
          style: AppText.num.copyWith(fontSize: 12, color: AppColors.ink3),
        ),
      ],
    );
  }
}

/// 구간 반복 알약.
///
/// 한 버튼으로 A와 B를 차례로 찍는다. 연습 화면에는 A와 B가 각각 독립
/// 버튼으로 있는데, 여기는 자리가 좁아서 대신 지금 어느 쪽 차례인지를
/// 글자로 적는다.
class AbPill extends StatelessWidget {
  const AbPill({
    super.key,
    required this.loopA,
    required this.loopB,
    required this.onSetA,
    required this.onSetB,
    required this.onClear,
  });

  final Duration? loopA;
  final Duration? loopB;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final on = loopA != null || loopB != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (loopA == null) {
          onSetA();
        } else if (loopB == null) {
          onSetB();
        } else {
          onClear();
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onClear();
      },
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.accentTint : AppColors.paperHi,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          switch ((loopA, loopB)) {
            (null, _) => 'A-B',
            (final a?, null) => 'A ${formatDuration(a)}',
            (final a?, final b?) =>
              '${formatDuration(a)}–${formatDuration(b)}',
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.num.copyWith(
            fontSize: 13,
            color: on ? AppColors.accent : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// `[왼쪽] 이전 재생 다음 [오른쪽]`.
///
/// 화면에서 잉크로 채운 자리는 가운데 재생 버튼 하나다.
class TransportRow extends StatelessWidget {
  const TransportRow({
    super.key,
    required this.playing,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.leading,
    required this.trailing,
  });

  final bool playing;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// 왼쪽 끝. 두 화면 모두 폴더다.
  final Widget leading;

  /// 오른쪽 끝. 로컬은 재생 목록, Spotify는 내 파일로 넘어가기.
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading,
          RoundButton(
            filled: false,
            onTap: onPrevious,
            child: const Icon(Icons.skip_previous,
                size: 28, color: AppColors.ink1),
          ),
          Material(
            color: AppColors.ink1,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggle,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 30,
                  color: AppColors.paperHi,
                ),
              ),
            ),
          ),
          RoundButton(
            filled: false,
            onTap: onNext,
            child:
                const Icon(Icons.skip_next, size: 28, color: AppColors.ink1),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// 켜고 끄는 아이콘. 반복과 셔플이 쓴다.
class ToggleIcon extends StatelessWidget {
  const ToggleIcon({
    super.key,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoundButton(
      filled: false,
      onTap: onTap,
      child: Icon(icon, size: 22, color: on ? AppColors.accent : AppColors.hair),
    );
  }
}

/// 목록을 지금 재생 중인 곡으로 한 번 옮긴다.
///
/// 열자마자 듣던 곡이 보여야 한다. 천 곡 목록에서 맨 위부터 찾을 수는 없다.
/// 매번 옮기면 사용자가 넘겨둔 자리가 계속 되돌아오므로 한 번만 한다.
///
/// 행 높이가 [AppSpace.row]로 고정이라 자리를 곱셈으로 구할 수 있다.
mixin NowPlayingScroll<T extends StatefulWidget> on State<T> {
  final ScrollController nowScroll = ScrollController();
  bool _moved = false;

  @override
  void dispose() {
    nowScroll.dispose();
    super.dispose();
  }

  void moveToNowPlaying(int index) {
    if (_moved || index < 0) return;
    _moved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !nowScroll.hasClients) return;
      final target =
          index * AppSpace.row - MediaQuery.of(context).size.height / 3;
      nowScroll.jumpTo(target.clamp(0.0, nowScroll.position.maxScrollExtent));
    });
  }
}
