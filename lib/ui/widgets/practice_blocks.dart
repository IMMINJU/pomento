import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../audio/player_controller.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/tempo.dart';
import '../../providers.dart';
import '../theme.dart';
import 'common.dart';
import 'surface.dart';
import 'stepper_field.dart';

/// 배속·피치·구간반복·점프탐색을 그리는 조각들.
///
/// 재생 화면에서 접었다 펴는 패널과, 전체 화면인 연습 화면이 같은 위젯을
/// 쓴다. 두 자리에서 조작이 달라 보이면 어느 쪽이 진짜인지 헷갈린다.
class SpeedBlock extends StatefulWidget {
  const SpeedBlock({
    super.key,
    required this.tempo,
    required this.settings,
    required this.controller,
    required this.onRangeChange,
  });

  final TempoSettings tempo;
  final AppSettings settings;
  final PlayerController controller;
  final ValueChanged<SpeedRange> onRangeChange;

  @override
  State<SpeedBlock> createState() => SpeedBlockState();
}

class SpeedBlockState extends State<SpeedBlock> {
  /// 넛지를 누르기 직전의 속도. 손을 떼면 여기로 돌아온다.
  double? _beforeNudge;

  void _nudgeDown(int direction) {
    final base = widget.tempo.speed;
    _beforeNudge = base;
    final factor = 1 + direction * widget.settings.nudgePercent / 100;
    HapticFeedback.selectionClick();
    widget.controller.setSpeed(base * factor);
  }

  void _nudgeUp() {
    final base = _beforeNudge;
    _beforeNudge = null;
    if (base == null) return;
    widget.controller.setSpeed(base);
  }

  @override
  Widget build(BuildContext context) {
    final speed = widget.tempo.speed;
    final percent = (speed - 1) * 100;
    // 고른 폭 밖으로 값이 나가 있으면 그 값을 담는 가장 좁은 폭으로 보여준다.
    // 슬라이더가 끝에 붙어 움직이지 않는 상태를 없애려는 것이다.
    final chosen = widget.settings.speedRange;
    final range = (speed >= chosen.min && speed <= chosen.max)
        ? chosen
        : SpeedRange.values.firstWhere(
            (r) => speed >= r.min && speed <= r.max,
            orElse: () => SpeedRange.wide,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepperField(
          label: '속도',
          subLabel:
              '${percent >= 0 ? '+' : ''}'
              '${percent.toStringAsFixed(1)}%'
              '${widget.tempo.mode == TempoMode.linked ? ' · '
                        '${widget.tempo.impliedSemitones >= 0 ? '+' : ''}'
                        '${widget.tempo.impliedSemitones.toStringAsFixed(2)} 반음' : ''}',
          value: speed,
          min: range.min,
          max: range.max,
          // 슬라이더 폭을 좁혀도 숫자칸과 스테퍼로는 전 구간을 갈 수 있다.
          hardMin: SpeedRange.wide.min,
          hardMax: SpeedRange.wide.max,
          step: widget.settings.speedStep,
          decimals: 3,
          centerDetent: true,
          detentValue: 1.0,
          suffix: '×',
          onChanged: (v) => widget.controller.setSpeed(v),
          onCommit: (v) => widget.controller.setSpeed(v, commit: true),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final r in SpeedRange.values) ...[
              PaperPill(
                selected: r == range,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                onTap: () => widget.onRangeChange(r),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: r == range ? AppColors.paperHi : AppColors.ink2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            _NudgeButton(
              icon: Icons.fast_rewind,
              onDown: () => _nudgeDown(-1),
              onUp: _nudgeUp,
            ),
            const SizedBox(width: 8),
            _NudgeButton(
              icon: Icons.fast_forward,
              onDown: () => _nudgeDown(1),
              onUp: _nudgeUp,
            ),
          ],
        ),
      ],
    );
  }
}

/// 누르고 있는 동안만 속도를 살짝 밀어주는 버튼.
///
/// 같이 연주하다 반 박 어긋났을 때 배속 값 자체를 바꾸지 않고 위치만 맞춘다.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 44,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.paperLo,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink1),
      ),
    );
  }
}

class PitchBlock extends StatelessWidget {
  const PitchBlock({
    super.key,
    required this.tempo,
    required this.settings,
    required this.controller,
  });

  final TempoSettings tempo;
  final AppSettings settings;
  final PlayerController controller;

  static const _tunings = [
    (label: 'A=432', cents: -31.8),
    (label: '-2반음', cents: -200.0),
    (label: '-1반음', cents: -100.0),
    (label: '0', cents: 0.0),
    (label: '+1반음', cents: 100.0),
    (label: '+2반음', cents: 200.0),
  ];

  @override
  Widget build(BuildContext context) {
    final isLinked = tempo.mode == TempoMode.linked;
    final semitones = tempo.pitchCents / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepperField(
          label: '피치',
          subLabel: isLinked
              ? '고정 모드에서 조절할 수 있습니다'
              : '${semitones >= 0 ? '+' : ''}'
                    '${semitones.toStringAsFixed(2)} 반음',
          value: tempo.pitchCents,
          // ±2반음. 피치시프트 필터는 이보다 멀어지면 잡음이 두드러진다.
          min: -200,
          max: 200,
          step: settings.pitchStepCents.toDouble(),
          decimals: 1,
          format: (v) => v.toStringAsFixed(1),
          centerDetent: true,
          suffix: '¢',
          enabled: !isLinked,
          onChanged: (v) => controller.setPitchCents(v),
          onCommit: (v) => controller.setPitchCents(v, commit: true),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: isLinked ? 0.4 : 1,
          // 잠긴 채로 두면 왜 안 되는지 알 길이 없다. 누르면 고정으로 바꾼다
          child: GestureDetector(
            onTap: isLinked
                ? () => controller.setTempoMode(TempoMode.independent)
                : null,
            child: IgnorePointer(
              ignoring: isLinked,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _tunings)
                    PaperPill(
                      selected: (tempo.pitchCents - t.cents).abs() < 0.5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      onTap: () =>
                          controller.setPitchCents(t.cents, commit: true),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: (tempo.pitchCents - t.cents).abs() < 0.5
                              ? AppColors.paperHi
                              : AppColors.ink2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoopBlock extends ConsumerWidget {
  const LoopBlock({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 눈금이 지금 위치를 따라가야 해서 상태를 통째로 본다. 250ms마다
    // 다시 그려지는 것은 이 덩어리뿐이다.
    final state = ref.watch(playerControllerProvider);
    final a = state.loopA;
    final b = state.loopB;
    final total = state.duration;

    return Column(
      children: [
        _LoopTimeline(
          a: a,
          b: b,
          position: state.position,
          duration: total,
          onSeek: (p) => controller.seek(
            Duration(milliseconds: (total.inMilliseconds * p).round()),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LoopButton(
                letter: 'A',
                time: a,
                active: a != null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.setLoopA();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LoopButton(
                letter: 'B',
                time: b,
                active: b != null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.setLoopB();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SmallAction(
                icon: Icons.replay,
                label: '처음으로',
                enabled: a != null,
                onTap: controller.restartLoop,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallAction(
                icon: Icons.close,
                label: '해제',
                enabled: a != null || b != null,
                onTap: controller.clearLoop,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 구간의 위치를 눈으로 확인하는 가는 막대.
///
/// 파형은 그리지 않는다. 플랫폼 디코더로 트는 곡은 파일을 통째로 풀지 않아서
/// 미리 뽑을 수 있는 파형이 없다.
class _LoopTimeline extends StatelessWidget {
  const _LoopTimeline({
    required this.a,
    required this.b,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration? a;
  final Duration? b;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  double _frac(Duration d) {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (d.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSeek((d.localPosition.dx / w).clamp(0.0, 1.0)),
          onHorizontalDragUpdate: (d) =>
              onSeek((d.localPosition.dx / w).clamp(0.0, 1.0)),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.paperLo,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                if (a != null && b != null)
                  Positioned(
                    left: _frac(a!) * w,
                    width: (_frac(b!) - _frac(a!)) * w,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                Positioned(
                  left: (_frac(position) * w - 1).clamp(0.0, w - 2),
                  child: Container(width: 2, height: 16, color: AppColors.ink1),
                ),
                if (a != null) _marker('A', _frac(a!) * w, w),
                if (b != null) _marker('B', _frac(b!) * w, w),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _marker(String letter, double x, double w) {
    return Positioned(
      left: (x - 7).clamp(0.0, w - 14),
      child: Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.paper,
          ),
        ),
      ),
    );
  }
}

class _LoopButton extends StatelessWidget {
  const _LoopButton({
    required this.letter,
    required this.time,
    required this.active,
    required this.onTap,
  });

  final String letter;
  final Duration? time;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.paperLo,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.55)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.accent : AppColors.ink2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              time == null ? '지금 위치 찍기' : formatDuration(time!),
              style: TextStyle(
                fontSize: time == null ? 13 : 16,
                color: time == null ? AppColors.ink3 : AppColors.ink1,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.paperLo,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.ink2),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JumpRow extends StatelessWidget {
  const JumpRow({super.key, required this.settings, required this.controller});

  final AppSettings settings;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final short = settings.seekShortSeconds;
    final long = settings.seekLongSeconds;

    final jumps = [-long, -short, short, long];

    return Row(
      children: [
        for (var i = 0; i < jumps.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.seekBy(Duration(seconds: jumps[i]));
              },
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.paperLo,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      jumps[i] < 0 ? Icons.rotate_left : Icons.rotate_right,
                      size: 15,
                      color: AppColors.ink2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${jumps[i].abs()}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.ink1,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class RememberRow extends StatelessWidget {
  const RememberRow({
    super.key,
    required this.remember,
    required this.onChanged,
  });

  final bool remember;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 14, right: 10),
      decoration: BoxDecoration(
        color: AppColors.paperLo,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_added_outlined,
            size: 17,
            color: AppColors.ink2,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '이 곡의 속도와 피치를 기억',
              style: TextStyle(fontSize: 14, color: AppColors.ink2),
            ),
          ),
          PaperSwitch(value: remember, onChanged: onChanged),
        ],
      ),
    );
  }
}
