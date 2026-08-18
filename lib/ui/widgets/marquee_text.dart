import 'package:flutter/material.dart';

/// 폭을 넘치면 한 방향으로 흘러가는 글자.
///
/// 재생 화면의 곡 제목처럼 끝까지 읽혀야 하는 자리에 쓴다. 말줄임으로
/// 자르면 무슨 곡인지 알 수 없는 제목이 실제로 많다.
///
/// 왼쪽으로만 흐르고 틈을 둔 뒤 같은 글자가 다시 들어온다. 끝에서 되돌아오는
/// 방식도 만들어봤는데, 눈이 방향 바뀌는 지점을 계속 따라가야 해서 읽기가
/// 더 성가시다. 음악 앱들이 한 방향으로 흘리는 이유가 그것이다.
///
/// 처음에는 잠깐 멈춘다. 멈추지 않으면 앞 글자를 읽을 시간이 없다.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 34,
    this.pause = const Duration(milliseconds: 1800),
    this.gap = 56,
  });

  final String text;
  final TextStyle style;

  /// 초당 논리픽셀.
  final double velocity;

  /// 한 바퀴를 시작하기 전에 멈추는 시간.
  final Duration pause;

  /// 글자 끝과 다시 들어오는 글자 사이의 틈.
  final double gap;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// 글자 한 벌의 폭. 0이면 아직 재지 않았다.
  double _textWidth = 0;

  /// 훑을 것이 있는지.
  bool _scrolling = false;

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    // 곡이 바뀌면 처음부터 읽어야 한다
    if (old.text != widget.text || old.style != widget.style) {
      _c.stop();
      _c.value = 0;
      _textWidth = 0;
      _scrolling = false;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _configure(double textWidth, bool scrolling) {
    _textWidth = textWidth;
    _scrolling = scrolling;
    if (!scrolling) {
      _c.stop();
      _c.value = 0;
      return;
    }
    final span = textWidth + widget.gap;
    final travel = (span / widget.velocity * 1000).round();
    _c.duration =
        Duration(milliseconds: widget.pause.inMilliseconds + travel);
    _c.repeat();
  }

  /// 0~1을 왼쪽으로 밀린 거리로 바꾼다. 멈춤 뒤에 한 바퀴.
  double _offsetAt(double t) {
    final total = _c.duration?.inMilliseconds ?? 0;
    if (total == 0) return 0;
    final p = widget.pause.inMilliseconds / total;
    if (t < p) return 0;
    return (_textWidth + widget.gap) * ((t - p) / (1 - p));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final width = painter.width;
        final scrolling = width - box.maxWidth > 0.5;

        // 재는 일은 빌드 중이라 여기서 컨트롤러를 건드리면 안 된다
        if ((_textWidth - width).abs() > 0.5 || _scrolling != scrolling) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _configure(width, scrolling);
          });
        }

        if (!scrolling) {
          return Text(widget.text, maxLines: 1, style: widget.style);
        }

        final one = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );

        return ClipRect(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_offsetAt(_c.value), 0),
              child: child,
            ),
            // 두 벌을 이어 붙인다. 앞 벌이 나가는 동안 뒤 벌이 들어와서
            // 끊기지 않는다
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: width, child: one),
                SizedBox(width: widget.gap),
                SizedBox(width: width, child: one),
              ],
            ),
          ),
        );
      },
    );
  }
}
