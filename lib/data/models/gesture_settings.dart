/// 한 번의 쓸기나 두드림에 걸 수 있는 동작.
///
/// Capriccio의 제스쳐 설정에서 고를 수 있는 것과 같다. 다만 가사 토글은
/// 우리에게 가사 화면이 없어서 뺐다.
enum GestureAction {
  none('미설정'),
  playPause('재생 / 일시정지'),
  previous('이전곡 재생'),
  next('다음곡 재생'),
  seekBack1('뒤로 탐색 (설정 1)'),
  seekBack2('뒤로 탐색 (설정 2)'),
  seekForward1('앞으로 탐색 (설정 1)'),
  seekForward2('앞으로 탐색 (설정 2)'),
  volumeUp('음량 높이기'),
  volumeDown('음량 낮추기'),
  speedUp('속도 올리기'),
  speedDown('속도 내리기'),
  pitchUp('피치 올리기'),
  pitchDown('피치 내리기'),
  toggleQueue('지금 재생중인 목록 토글'),
  toggleControls('재생 컨트롤 토글'),
  toggleLoop('A-B 구간반복 토글');

  const GestureAction(this.label);

  final String label;
}

/// 손가락을 붙인 채 끌 때 이어서 바뀌는 값.
///
/// 쓸기와 다르다. 쓸기는 한 번 튕기면 한 번 일어나고, 끌기는 손가락을
/// 움직이는 내내 값이 따라온다.
enum DragAction {
  none('미설정'),
  seek('탐색 조절'),
  volume('음량 조절'),
  speed('속도 조절'),
  pitch('피치 조절');

  const DragAction(this.label);

  final String label;
}

/// 제스쳐 배치 한 벌.
///
/// 기본값은 손이 가는 대로 잡았다. 왼쪽에서 쓸면 이전곡, 위로 쓸면 뒤로,
/// 아래로 쓸면 앞으로. 화면을 필름처럼 잡고 미는 감각이다. Capriccio는
/// 세로가 반대인데, 그쪽이 조그셔틀을 돌리는 감각에 가깝다는 의견을 받아
/// 뒤집었다. 설정에서 되돌릴 수 있다.
///
/// 쓸기를 켜두면 같은 축의 이어 끌기는 동작하지 않는다. 한 손가락으로 두
/// 가지를 같은 방향에 걸면 어느 쪽인지 가릴 수 없다.
class GestureSettings {
  const GestureSettings({
    this.horizontalSwipe = true,
    this.swipeFromLeft = GestureAction.previous,
    this.swipeFromRight = GestureAction.next,
    this.horizontalDrag = DragAction.seek,
    this.verticalSwipe = true,
    this.swipeFromBottom = GestureAction.seekBack1,
    this.swipeFromTop = GestureAction.seekForward1,
    this.verticalDrag = DragAction.none,
    this.verticalDragLeft = DragAction.none,
    this.verticalDragRight = DragAction.volume,
    this.tap = GestureAction.none,
    this.doubleTap = GestureAction.playPause,
    this.doubleTapLeft = GestureAction.seekBack1,
    this.doubleTapRight = GestureAction.seekForward1,
    this.longPress = GestureAction.toggleControls,
  });

  static const GestureSettings defaults = GestureSettings();

  /// 가로로 튕기는 동작을 쓸지.
  final bool horizontalSwipe;

  /// 왼쪽에서 오른쪽으로 튕겼을 때.
  final GestureAction swipeFromLeft;

  /// 오른쪽에서 왼쪽으로 튕겼을 때.
  final GestureAction swipeFromRight;

  /// 가로로 이어 끌 때. 쓸기를 켜두면 쓰지 않는다.
  final DragAction horizontalDrag;

  final bool verticalSwipe;

  /// 아래에서 위로 튕겼을 때.
  final GestureAction swipeFromBottom;

  /// 위에서 아래로 튕겼을 때.
  final GestureAction swipeFromTop;

  final DragAction verticalDrag;

  /// 화면 왼쪽 3분의 1에서 세로로 끌 때.
  final DragAction verticalDragLeft;

  /// 화면 오른쪽 3분의 1에서 세로로 끌 때.
  final DragAction verticalDragRight;

  final GestureAction tap;
  final GestureAction doubleTap;
  final GestureAction doubleTapLeft;
  final GestureAction doubleTapRight;

  /// 길게 누르기. Capriccio에는 없는 자리다. 재생 컨트롤을 늘 펼쳐두면
  /// 피치와 구간 반복을 잘못 건드린다는 의견을 받아 넣었다.
  final GestureAction longPress;

  GestureSettings copyWith({
    bool? horizontalSwipe,
    GestureAction? swipeFromLeft,
    GestureAction? swipeFromRight,
    DragAction? horizontalDrag,
    bool? verticalSwipe,
    GestureAction? swipeFromBottom,
    GestureAction? swipeFromTop,
    DragAction? verticalDrag,
    DragAction? verticalDragLeft,
    DragAction? verticalDragRight,
    GestureAction? tap,
    GestureAction? doubleTap,
    GestureAction? doubleTapLeft,
    GestureAction? doubleTapRight,
    GestureAction? longPress,
  }) =>
      GestureSettings(
        horizontalSwipe: horizontalSwipe ?? this.horizontalSwipe,
        swipeFromLeft: swipeFromLeft ?? this.swipeFromLeft,
        swipeFromRight: swipeFromRight ?? this.swipeFromRight,
        horizontalDrag: horizontalDrag ?? this.horizontalDrag,
        verticalSwipe: verticalSwipe ?? this.verticalSwipe,
        swipeFromBottom: swipeFromBottom ?? this.swipeFromBottom,
        swipeFromTop: swipeFromTop ?? this.swipeFromTop,
        verticalDrag: verticalDrag ?? this.verticalDrag,
        verticalDragLeft: verticalDragLeft ?? this.verticalDragLeft,
        verticalDragRight: verticalDragRight ?? this.verticalDragRight,
        tap: tap ?? this.tap,
        doubleTap: doubleTap ?? this.doubleTap,
        doubleTapLeft: doubleTapLeft ?? this.doubleTapLeft,
        doubleTapRight: doubleTapRight ?? this.doubleTapRight,
        longPress: longPress ?? this.longPress,
      );

  Map<String, dynamic> toJson() => {
        'horizontalSwipe': horizontalSwipe,
        'swipeFromLeft': swipeFromLeft.name,
        'swipeFromRight': swipeFromRight.name,
        'horizontalDrag': horizontalDrag.name,
        'verticalSwipe': verticalSwipe,
        'swipeFromBottom': swipeFromBottom.name,
        'swipeFromTop': swipeFromTop.name,
        'verticalDrag': verticalDrag.name,
        'verticalDragLeft': verticalDragLeft.name,
        'verticalDragRight': verticalDragRight.name,
        'tap': tap.name,
        'doubleTap': doubleTap.name,
        'doubleTapLeft': doubleTapLeft.name,
        'doubleTapRight': doubleTapRight.name,
        'longPress': longPress.name,
      };

  factory GestureSettings.fromJson(Map<String, dynamic> j) {
    GestureAction act(String key, GestureAction fallback) =>
        GestureAction.values.firstWhere(
          (a) => a.name == j[key],
          orElse: () => fallback,
        );
    DragAction drag(String key, DragAction fallback) =>
        DragAction.values.firstWhere(
          (a) => a.name == j[key],
          orElse: () => fallback,
        );

    const d = GestureSettings.defaults;
    return GestureSettings(
      horizontalSwipe: j['horizontalSwipe'] as bool? ?? d.horizontalSwipe,
      swipeFromLeft: act('swipeFromLeft', d.swipeFromLeft),
      swipeFromRight: act('swipeFromRight', d.swipeFromRight),
      horizontalDrag: drag('horizontalDrag', d.horizontalDrag),
      verticalSwipe: j['verticalSwipe'] as bool? ?? d.verticalSwipe,
      swipeFromBottom: act('swipeFromBottom', d.swipeFromBottom),
      swipeFromTop: act('swipeFromTop', d.swipeFromTop),
      verticalDrag: drag('verticalDrag', d.verticalDrag),
      verticalDragLeft: drag('verticalDragLeft', d.verticalDragLeft),
      verticalDragRight: drag('verticalDragRight', d.verticalDragRight),
      tap: act('tap', d.tap),
      doubleTap: act('doubleTap', d.doubleTap),
      doubleTapLeft: act('doubleTapLeft', d.doubleTapLeft),
      doubleTapRight: act('doubleTapRight', d.doubleTapRight),
      longPress: act('longPress', d.longPress),
    );
  }
}
