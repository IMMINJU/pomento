/// 마지막으로 가져온 결과.
///
/// 가져오기 직후 스낵바로만 스치고 지나가면, 곡 정보를 어디서 읽었는지
/// 확인하려고 다시 가져와야 한다. iOS는 실기기에서만 확인할 수 있어서 한 번
/// 보는 데 드는 비용이 크다. 설정 > 정보에 남겨둔다.
class ImportLog {
  const ImportLog({
    required this.at,
    required this.added,
    this.tagsFromFile = 0,
    this.tagsFromLibrary = 0,
  });

  final DateTime at;
  final int added;

  /// 곡 정보를 파일에 박힌 태그에서 읽은 곡 수.
  ///
  /// 음악 앱 보관함에서 가져올 때만 센다. 파일에서 직접 가져오면 언제나
  /// 파일 태그라 셀 것이 없다.
  final int tagsFromFile;

  /// 곡 정보를 음악 앱 DB에서 읽은 곡 수. 보관함 동기화가 바꿔놓은 값일 수
  /// 있는 쪽이다.
  final int tagsFromLibrary;

  bool get hasTagSource => tagsFromFile > 0 || tagsFromLibrary > 0;

  /// 곡 정보의 출처. 셀 것이 없으면 빈 문자열.
  String get tagSourceLine {
    if (!hasTagSource) return '';
    if (tagsFromLibrary == 0) return '곡 정보를 모두 파일에서 읽었습니다';
    if (tagsFromFile == 0) return '곡 정보를 모두 음악 앱에서 읽었습니다';
    return '파일에서 $tagsFromFile곡, 음악 앱에서 $tagsFromLibrary곡';
  }

  /// 가져오기 직후 한 줄로 보여줄 말.
  String get summary {
    final base = '$added곡 추가됨';
    final line = tagSourceLine;
    return line.isEmpty ? base : '$base · $line';
  }

  String get whenLabel {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.month}월 ${at.day}일 $hh:$mm';
  }

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'added': added,
        'tagsFromFile': tagsFromFile,
        'tagsFromLibrary': tagsFromLibrary,
      };

  static ImportLog? fromJson(Map<String, Object?> m) {
    final at = DateTime.tryParse(m['at'] as String? ?? '');
    if (at == null) return null;
    return ImportLog(
      at: at,
      added: (m['added'] as num?)?.toInt() ?? 0,
      tagsFromFile: (m['tagsFromFile'] as num?)?.toInt() ?? 0,
      tagsFromLibrary: (m['tagsFromLibrary'] as num?)?.toInt() ?? 0,
    );
  }
}
