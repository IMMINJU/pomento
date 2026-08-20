import '../db/database.dart';

/// 곡 안의 자리표.
///
/// 이름이 없다. [position]이 이름 자리를 대신하고, 값이 걸린 마크만 값을
/// 같이 적는다. 듣다가 찍는 순간 이름을 물으면 그 대목을 놓친다.
class Mark {
  const Mark({
    required this.id,
    required this.trackId,
    required this.position,
    this.end,
    this.speed,
    this.pitchCents,
  });

  factory Mark.fromRow(MarkRow r) => Mark(
        id: r.id,
        trackId: r.trackId,
        position: Duration(milliseconds: r.positionMs),
        end: r.endMs == null ? null : Duration(milliseconds: r.endMs!),
        speed: r.speed,
        pitchCents: r.pitchCents,
      );

  final int id;
  final int trackId;

  /// 점 마크의 자리. 구간 마크에서는 시작이다.
  final Duration position;

  /// 구간 마크의 끝. 점 마크는 null이다.
  final Duration? end;

  /// 이 자리에서 갈아끼울 값. 둘 다 null이면 위치만 표시한다.
  final double? speed;
  final double? pitchCents;

  bool get isLoop => end != null;

  /// 값이 걸려 있는지. 칩에 값을 적을지 여부가 이것으로 갈린다.
  bool get hasValue => speed != null || pitchCents != null;

  Duration get endOrPosition => end ?? position;

  Mark copyWith({
    Duration? position,
    Duration? end,
    bool clearEnd = false,
    double? speed,
    bool clearSpeed = false,
    double? pitchCents,
    bool clearPitch = false,
  }) =>
      Mark(
        id: id,
        trackId: trackId,
        position: position ?? this.position,
        end: clearEnd ? null : (end ?? this.end),
        speed: clearSpeed ? null : (speed ?? this.speed),
        pitchCents: clearPitch ? null : (pitchCents ?? this.pitchCents),
      );

  @override
  bool operator ==(Object other) =>
      other is Mark &&
      other.id == id &&
      other.trackId == trackId &&
      other.position == position &&
      other.end == end &&
      other.speed == speed &&
      other.pitchCents == pitchCents;

  @override
  int get hashCode =>
      Object.hash(id, trackId, position, end, speed, pitchCents);
}
