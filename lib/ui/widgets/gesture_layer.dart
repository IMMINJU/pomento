import 'package:flutter/material.dart';

import '../../data/models/gesture_settings.dart';

/// 어디에 손가락을 댔는지.
enum GestureZone { left, center, right }

/// 이어 끌기가 진행 중임을 알리는 값.
class DragProgress {
  const DragProgress(this.action, this.delta, this.done);

  final DragAction action;

  /// 끌기를 시작한 자리에서 얼마나 왔는지. 오른쪽과 위쪽이 양수다.
  final double delta;

  final bool done;
}

/// 재생 화면의 한 손가락 조작을 한 곳에서 받는다.
///
/// 쓸기(빠르게 튕기기)와 끌기(붙인 채 움직이기)를 가른다. 같은 축에 둘 다
/// 걸면 어느 쪽인지 알 수 없으므로, 설정에서 쓸기를 켜두면 그 축의 끌기는
/// 아예 시작하지 않는다.
///
/// 두 손가락 동작은 여기서 다루지 않고 바깥의 ScaleGestureRecognizer가 맡는다.
class ConfigurableGestureLayer extends StatefulWidget {
  const ConfigurableGestureLayer({
    super.key,
    required this.settings,
    required this.child,
    required this.onAction,
    required this.onDrag,
  });

  final GestureSettings settings;
  final Widget child;

  /// 쓸기나 두드림 한 번.
  final void Function(GestureAction action) onAction;

  /// 이어 끌기. 손을 뗄 때 done이 참인 값이 한 번 더 온다.
  final void Function(DragProgress progress) onDrag;

  @override
  State<ConfigurableGestureLayer> createState() =>
      _ConfigurableGestureLayerState();
}

class _ConfigurableGestureLayerState extends State<ConfigurableGestureLayer> {
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  GestureZone _zone = GestureZone.center;

  /// 이번 끌기가 어느 축으로 잡혔는지. 한 번 정해지면 손을 뗄 때까지 안 바뀐다.
  Axis? _axis;
  DragAction _dragAction = DragAction.none;

  /// 쓸기로 볼 최소 이동 거리.
  static const double _swipeThreshold = 70;

  GestureZone _zoneOf(double dx, double width) {
    if (dx < width / 3) return GestureZone.left;
    if (dx > width * 2 / 3) return GestureZone.right;
    return GestureZone.center;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final g = widget.settings;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        if (g.tap != GestureAction.none) widget.onAction(g.tap);
      },
      onLongPress: () {
        if (g.longPress != GestureAction.none) widget.onAction(g.longPress);
      },
      onDoubleTapDown: (d) => _zone = _zoneOf(d.localPosition.dx, width),
      onDoubleTap: () {
        final action = switch (_zone) {
          GestureZone.left => g.doubleTapLeft,
          GestureZone.right => g.doubleTapRight,
          GestureZone.center => g.doubleTap,
        };
        if (action != GestureAction.none) widget.onAction(action);
      },
      onPanStart: (d) {
        _start = d.localPosition;
        _last = d.localPosition;
        _axis = null;
        _dragAction = DragAction.none;
        _zone = _zoneOf(d.localPosition.dx, width);
      },
      onPanUpdate: (d) {
        _last = d.localPosition;
        final total = _last - _start;

        // 어느 축인지는 처음 크게 움직인 방향으로 한 번만 정한다.
        if (_axis == null) {
          if (total.distance < 16) return;
          _axis = total.dx.abs() > total.dy.abs() ? Axis.horizontal : Axis.vertical;
          _dragAction = _dragActionFor(_axis!);
        }
        if (_dragAction == DragAction.none) return;

        widget.onDrag(
          DragProgress(
            _dragAction,
            _axis == Axis.horizontal ? total.dx : -total.dy,
            false,
          ),
        );
      },
      onPanEnd: (d) {
        final total = _last - _start;
        final axis = _axis;
        _axis = null;

        if (_dragAction != DragAction.none) {
          widget.onDrag(DragProgress(_dragAction, 0, true));
          _dragAction = DragAction.none;
          return;
        }
        if (axis == null) return;

        // 끌기가 안 걸린 축이면 쓸기로 본다.
        if (axis == Axis.horizontal && g.horizontalSwipe) {
          if (total.dx.abs() < _swipeThreshold) return;
          final action = total.dx > 0 ? g.swipeFromLeft : g.swipeFromRight;
          if (action != GestureAction.none) widget.onAction(action);
        } else if (axis == Axis.vertical && g.verticalSwipe) {
          if (total.dy.abs() < _swipeThreshold) return;
          final action = total.dy < 0 ? g.swipeFromBottom : g.swipeFromTop;
          if (action != GestureAction.none) widget.onAction(action);
        }
      },
      child: widget.child,
    );
  }

  DragAction _dragActionFor(Axis axis) {
    final g = widget.settings;
    if (axis == Axis.horizontal) {
      // 쓸기를 켜뒀으면 가로 끌기는 시작하지 않는다.
      return g.horizontalSwipe ? DragAction.none : g.horizontalDrag;
    }
    final side = switch (_zone) {
      GestureZone.left => g.verticalDragLeft,
      GestureZone.right => g.verticalDragRight,
      GestureZone.center => DragAction.none,
    };
    if (side != DragAction.none) return side;
    return g.verticalSwipe ? DragAction.none : g.verticalDrag;
  }
}
