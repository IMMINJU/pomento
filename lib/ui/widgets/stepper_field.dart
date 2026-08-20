import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 라벨 + 숫자칸 + 슬라이더 + −/+ 한 세트.
///
/// 이 앱에서 값을 다루는 모든 자리가 같은 모양이어야 한다. 슬라이더로 대충
/// 잡고, 스테퍼로 한 칸씩 다듬고, 정확한 값을 알면 숫자칸에 바로 넣는다.
/// 스테퍼 한 번의 폭은 바깥에서 설정으로 정한다.
class StepperField extends StatefulWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.onCommit,
    this.hardMin,
    this.hardMax,
    this.format,
    this.parse,
    this.suffix,
    this.subLabel,
    this.enabled = true,
    this.centerDetent = false,
    this.detentValue = 0,
    this.decimals = 2,
  });

  final String label;
  final double value;
  final double min;
  final double max;

  /// 스테퍼 한 번의 폭.
  final double step;

  /// 숫자칸으로 직접 칠 때만 허용하는 더 넓은 한계.
  ///
  /// 슬라이더 폭을 ±8%로 좁혀둔 사람도 0.5배를 쳐 넣을 수 있어야 한다.
  /// 비워두면 슬라이더 폭과 같다.
  final double? hardMin;
  final double? hardMax;

  /// 드래그 중. 소리에 바로 반영하되 저장은 하지 않는다.
  final ValueChanged<double> onChanged;

  /// 손을 뗐을 때. 여기서 저장한다.
  final ValueChanged<double> onCommit;

  final String Function(double)? format;
  final double? Function(String)? parse;

  /// 숫자칸 오른쪽에 붙는 단위.
  final String? suffix;

  /// 라벨 아래 한 줄 보조 설명.
  final String? subLabel;

  final bool enabled;

  /// 특정 값 근처에서 걸리게 할지. 배속 1.0과 피치 0에서 쓴다.
  final bool centerDetent;
  final double detentValue;

  final int decimals;

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  Timer? _repeat;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _display(widget.value));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(StepperField old) {
    super.didUpdateWidget(old);
    // 입력 중에는 손대지 않는다. 사용자가 치고 있는 글자를 덮어쓰면 안 된다.
    if (!_focus.hasFocus && widget.value != old.value) {
      _text.text = _display(widget.value);
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  String _display(double v) =>
      widget.format?.call(v) ?? v.toStringAsFixed(widget.decimals);

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _text.selection =
          TextSelection(baseOffset: 0, extentOffset: _text.text.length);
    } else {
      _submit();
    }
  }

  void _submit() {
    final parsed =
        widget.parse?.call(_text.text) ?? double.tryParse(_text.text.trim());
    if (parsed == null) {
      _text.text = _display(widget.value);
      return;
    }
    final clamped = parsed
        .clamp(widget.hardMin ?? widget.min, widget.hardMax ?? widget.max)
        .toDouble();
    _text.text = _display(clamped);
    widget.onCommit(clamped);
  }

  double _snap(double v) => _snapValue(v.clamp(widget.min, widget.max).toDouble());

  double _snapValue(double v) {
    var next = v;
    // 걸림 폭은 스테퍼 폭이 아니라 슬라이더가 훑는 폭에서 뽑는다. 스테퍼를
    // 0.10으로 크게 잡아둔 사람이 슬라이더로 0.95를 못 고르면 안 된다.
    final window = (widget.max - widget.min) * 0.012;
    if (widget.centerDetent && (next - widget.detentValue).abs() < window) {
      next = widget.detentValue;
    }
    // 스테퍼로 움직인 값이 0.7500000000001 같은 꼴로 남지 않게 한다.
    final places = widget.step >= 1 ? 0 : widget.decimals;
    final f = _pow10(places);
    return (next * f).round() / f;
  }

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  void _bump(int direction) {
    // 스테퍼는 슬라이더 폭 밖으로도 나갈 수 있어야 한다. 폭 끝에서 더 눌렀을
    // 때 아무 일도 안 일어나면 고장으로 보인다.
    final lo = widget.hardMin ?? widget.min;
    final hi = widget.hardMax ?? widget.max;
    final raw = (widget.value + widget.step * direction).clamp(lo, hi);
    final next = _snapValue(raw.toDouble());
    if (next == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onCommit(next);
  }

  /// 길게 누르면 계속 움직인다. 배속을 0.05씩 열 번 눌러야 하는 일을 막는다.
  void _startRepeat(int direction) {
    _bump(direction);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 420), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => _bump(direction),
      );
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.35,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label, style: AppText.label),
                      if (widget.subLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(widget.subLabel!, style: AppText.sub),
                      ],
                    ],
                  ),
                ),
                _numberBox(),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.paperLo,
                      thumbColor: AppColors.accent,
                      overlayColor: AppColors.accentTint,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: widget.value.clamp(widget.min, widget.max),
                      min: widget.min,
                      max: widget.max,
                      onChanged: (v) => widget.onChanged(_snap(v)),
                      onChangeEnd: (v) => widget.onCommit(_snap(v)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _stepButton(Icons.remove, -1),
                const SizedBox(width: 8),
                _stepButton(Icons.add, 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberBox() {
    // 테두리 대신 가라앉은 면으로 구분한다
    return Container(
      width: 104,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.paperLo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _focus.unfocus(),
              cursorColor: AppColors.accent,
              style: AppText.num.copyWith(fontSize: 17),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.suffix != null) ...[
            const SizedBox(width: 3),
            Text(widget.suffix!, style: AppText.sub),
          ],
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, int direction) {
    return GestureDetector(
      onTapDown: (_) => _startRepeat(direction),
      onTapUp: (_) => _stopRepeat(),
      onTapCancel: _stopRepeat,
      child: Container(
        width: AppSpace.tap,
        height: AppSpace.tap,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.paperHi,
        ),
        child: Icon(icon, size: 20, color: AppColors.ink1),
      ),
    );
  }
}
