import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/eq_curve.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/eq_graph.dart';
import 'widgets/glass.dart';
import 'widgets/screen_header.dart';
import 'widgets/stepper_field.dart';

/// 음향 화면 위에 한 겹 더 쌓는다. 뒤로 가면 음향, 닫으면 재생 화면이다.
void openEqEditorScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const EqEditorScreen()),
  );
}

/// 취향 층 곡선을 점 단위로 고친다.
///
/// Capriccio의 Parametric EQ와 같은 배치다. 위에 곡선, 아래에 밴드 번호,
/// 그 아래에 파라미터마다 숫자칸·슬라이더·스테퍼 한 세트.
///
/// 대역폭 항목은 두지 않는다. 우리 모델은 밴드가 아니라 곡선 위의 점이고,
/// 엔진에 넣을 때 고정된 밴드 중심에서 값을 뽑아 쓴다. 대역폭을 받아도
/// 소리에 반영할 자리가 없다.
class EqEditorScreen extends ConsumerStatefulWidget {
  const EqEditorScreen({super.key});

  @override
  ConsumerState<EqEditorScreen> createState() => _EqEditorScreenState();
}

class _EqEditorScreenState extends ConsumerState<EqEditorScreen> {
  int _selected = 0;

  /// 점이 하나도 없는 프리셋에서 시작할 때 깔아주는 기본 다섯 점.
  static const _seed = [
    EqPoint(60, 0),
    EqPoint(250, 0),
    EqPoint(1000, 0),
    EqPoint(4000, 0),
    EqPoint(12000, 0),
  ];

  List<EqPoint> _sorted(EqCurve eq) {
    // const 리스트는 정렬할 수 없다. 항상 새 리스트로 복사한다.
    final pts = eq.points.isEmpty ? [..._seed] : [...eq.points];
    pts.sort((a, b) => a.freq.compareTo(b.freq));
    return pts;
  }

  void _write(List<EqPoint> points) {
    ref
        .read(effectControllerProvider.notifier)
        .setTasteCurve(EqCurve(points));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(effectControllerProvider);
    final taste = state.tastePreset;

    if (taste == null) {
      return const SizedBox.shrink();
    }

    final points = _sorted(taste.eq);
    final index = _selected.clamp(0, points.length - 1);
    final point = points[index];

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          BlurredBackdrop(
            track: ref.watch(playerControllerProvider).current,
            topOverlay: 0.55,
            bottomOverlay: 0.80,
          ),
          SafeArea(
            bottom: false,
            child: Column(
        children: [
          ScreenHeader(
            title: 'EQ 편집',
            subtitle: taste.name,
            showBack: true,
            actions: [
              HeaderAction(
                icon: Icons.horizontal_rule,
                label: '평탄하게',
                onTap: () {
                  _write(const []);
                  setState(() => _selected = 0);
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
                Container(
                  height: 190,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: EqGraph(
                    device: state.deviceEnabled ? state.devicePreset?.eq : null,
                    environment: state.environmentPreset?.eq,
                    taste: EqCurve(points),
                    height: 146,
                  ),
                ),
                const SizedBox(height: 16),

                _BandTabs(
                  points: points,
                  selected: index,
                  onSelect: (i) => setState(() => _selected = i),
                  onAdd: points.length >= 12
                      ? null
                      : () {
                          final added = _newPoint(points);
                          final next = [...points, added]
                            ..sort((a, b) => a.freq.compareTo(b.freq));
                          _write(next);
                          setState(() => _selected =
                              next.indexWhere((p) => p.freq == added.freq));
                        },
                  onRemove: points.length <= 2
                      ? null
                      : () {
                          final next = [...points]..removeAt(index);
                          _write(next);
                          setState(() => _selected =
                              math.max(0, index - 1));
                        },
                ),
                const SizedBox(height: 18),

                StepperField(
                  label: '중심 주파수',
                  value: point.freq,
                  min: 20,
                  max: 20000,
                  step: _freqStep(point.freq),
                  decimals: 0,
                  suffix: 'Hz',
                  format: (v) => v.round().toString(),
                  onChanged: (v) => _setFreq(points, index, v),
                  onCommit: (v) => _setFreq(points, index, v),
                ),
                const SizedBox(height: 6),
                _FreqPresets(
                  onPick: (f) => _setFreq(points, index, f),
                ),
                const SizedBox(height: 20),

                StepperField(
                  label: '대역폭',
                  subLabel: point.isBell
                      ? '중심에서 ${(point.bandwidthOct / 2).toStringAsFixed(2)}'
                          '옥타브 떨어진 자리에서 절반이 됩니다'
                      : '0이면 옆 점과 이어지는 곡선이 됩니다',
                  value: point.bandwidthOct,
                  min: 0,
                  max: 4,
                  step: 0.1,
                  decimals: 1,
                  suffix: 'oct',
                  onChanged: (v) => _setBandwidth(points, index, v),
                  onCommit: (v) => _setBandwidth(points, index, v),
                ),
                const SizedBox(height: 20),

                StepperField(
                  label: '이득',
                  subLabel: '세 층을 더한 값이 리미터로 들어갑니다',
                  value: point.gainDb,
                  min: -12,
                  max: 12,
                  step: 0.5,
                  decimals: 1,
                  centerDetent: true,
                  suffix: 'dB',
                  onChanged: (v) => _setGain(points, index, v),
                  onCommit: (v) => _setGain(points, index, v),
                ),
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

  /// 주파수 스테퍼는 로그 축에서 움직여야 한다. 60Hz에서 100Hz씩 뛰면
  /// 저역을 못 다루고, 12kHz에서 10Hz씩 움직이면 끝이 없다.
  double _freqStep(double f) {
    if (f < 100) return 5;
    if (f < 1000) return 25;
    if (f < 5000) return 100;
    return 500;
  }

  EqPoint _newPoint(List<EqPoint> points) {
    // 가장 넓게 벌어진 두 점 사이의 로그 중간에 넣는다.
    var bestGap = 0.0;
    var at = 1000.0;
    for (var i = 0; i < points.length - 1; i++) {
      final la = math.log(points[i].freq);
      final lb = math.log(points[i + 1].freq);
      if (lb - la > bestGap) {
        bestGap = lb - la;
        at = math.exp((la + lb) / 2);
      }
    }
    return EqPoint(at.roundToDouble(), 0, bandwidthOct: 1.0);
  }

  void _setBandwidth(List<EqPoint> points, int index, double bw) {
    final next = [...points];
    next[index] = next[index].copyWith(bandwidthOct: bw);
    _write(next);
  }

  void _setFreq(List<EqPoint> points, int index, double freq) {
    final next = [...points];
    next[index] = next[index].copyWith(freq: freq.roundToDouble());
    next.sort((a, b) => a.freq.compareTo(b.freq));
    _write(next);
    // 정렬 때문에 순번이 바뀔 수 있다. 고르고 있던 점을 계속 따라간다.
    final moved = next.indexWhere(
      (p) => p.freq == freq.roundToDouble(),
    );
    if (moved >= 0 && moved != index) setState(() => _selected = moved);
  }

  void _setGain(List<EqPoint> points, int index, double gain) {
    final next = [...points];
    next[index] = next[index].copyWith(gainDb: gain);
    _write(next);
  }
}

class _BandTabs extends StatelessWidget {
  const _BandTabs({
    required this.points,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  final List<EqPoint> points;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final on = i == selected;
                final touched = points[i].gainDb.abs() > 0.05;
                final bell = points[i].isBell;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.accent.withValues(alpha: 0.18)
                          : AppColors.glass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                touched ? FontWeight.w700 : FontWeight.w400,
                            color: on
                                ? AppColors.accent
                                : (touched ? AppColors.t1 : AppColors.t3),
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        // 종 모양 밴드와 곡선 위의 점을 한눈에 가른다.
                        Container(
                          width: bell ? 10 : 6,
                          height: 2,
                          margin: const EdgeInsets.only(top: 2),
                          color: bell
                              ? (on ? AppColors.accent : AppColors.t2)
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _MiniButton(icon: Icons.remove, onTap: onRemove),
        const SizedBox(width: 6),
        _MiniButton(icon: Icons.add, onTap: onAdd),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.3 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glass,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(icon, size: 18, color: AppColors.t1),
        ),
      ),
    );
  }
}

class _FreqPresets extends StatelessWidget {
  const _FreqPresets({required this.onPick});

  final ValueChanged<double> onPick;

  static const _points = [60.0, 150.0, 400.0, 1000.0, 3000.0, 8000.0, 14000.0];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in _points)
          GlassPill(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            onTap: () => onPick(f),
            child: Text(
              f >= 1000
                  ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
                  : '${f.round()}',
              style: const TextStyle(fontSize: 11, color: AppColors.t2),
            ),
          ),
      ],
    );
  }
}
