/// Spotify 검색 결과와 내 파일이 같은 곡인지 판단한다.
///
/// 같은 녹음인지까지는 알 수 없다. ISRC가 양쪽에 다 있으면 확실하지만,
/// 태그에 ISRC를 넣은 파일은 드물다. 그래서 제목과 아티스트를 다듬어 비교한다.
library;

import 'dart:math' as math;

/// 비교 전에 문자열에서 걷어낼 것들.
///
/// `Let Down (Remastered 2016)`과 `Let Down`을 같은 곡으로 보려면 괄호 안의
/// 판본 표기를 지워야 한다. 다만 `(Live)`는 다른 녹음이라 남긴다.
const _dropInParens = [
  'remaster',
  'remastered',
  'deluxe',
  'bonus track',
  'album version',
  'single version',
  'explicit',
  'clean',
  'mono',
  'stereo',
  'anniversary',
  // 유튜브에서 받은 파일에 흔히 붙는 꼬리표. 파일 제목의 절반이 이것일
  // 때가 있어서 안 지우면 같은 곡을 못 알아본다.
  'official',
  'music video',
  'lyric video',
  'lyrics video',
  'audio',
  'visualizer',
  'hd',
  'hq',
  'm/v',
];

final _parens = RegExp(r'[\(\[][^\)\]]*[\)\]]');

/// 라틴 문자에 붙은 악센트를 벗긴다.
///
/// `SIAMÉS`와 `SIAMES`가 다른 아티스트로 갈린다. 정규화가 글자를 통째로
/// 지워버려서 길이가 달라지고 닮은 정도가 뚝 떨어진다.
const _diacritics = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
  'æ': 'ae',
};

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString();
}

final _featuring = RegExp(
  r'\s+(feat\.?|ft\.?|featuring)\s+.*$',
  caseSensitive: false,
);
final _nonWord = RegExp(r'[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+');

/// 비교용으로 다듬은 문자열.
String normalizeTitle(String raw) {
  var s = _fold(raw.toLowerCase());

  // 괄호 안이 판본 표기면 통째로 지운다. 그 밖의 괄호는 남긴다.
  s = s.replaceAllMapped(_parens, (m) {
    final inner = m.group(0)!.toLowerCase();
    final isEdition = _dropInParens.any(inner.contains);
    return isEdition ? ' ' : m.group(0)!;
  });

  // 하이픈 뒤에 붙는 판본 표기도 같은 취급이다.
  for (final word in _dropInParens) {
    final dash = RegExp('\\s+-\\s+[^-]*$word[^-]*\$', caseSensitive: false);
    s = s.replaceAll(dash, '');
  }

  s = s.replaceAll(_featuring, '');
  s = s.replaceAll(_nonWord, ' ').trim();
  return s;
}

/// 아티스트는 여러 명이 쉼표로 붙는 일이 잦아서 첫 사람만 본다.
String normalizeArtist(String raw) {
  var s = _fold(raw.toLowerCase());
  s = s.split(RegExp(r'[,;&/]|\sfeat\.?\s|\sft\.?\s|\swith\s')).first;
  s = s.replaceAll(_nonWord, ' ').trim();
  // 영어권 밴드 이름 앞의 관사는 있는 쪽과 없는 쪽이 섞인다.
  if (s.startsWith('the ')) s = s.substring(4);
  return s;
}

/// 0~1 사이의 닮은 정도. 편집 거리를 길이로 나눈 값이다.
double similarity(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final distance = _levenshtein(a, b);
  final longest = math.max(a.length, b.length);
  return 1 - distance / longest;
}

int _levenshtein(String a, String b) {
  // 한 줄만 들고 굴린다. 곡 제목 길이에서 전체 행렬을 잡을 이유가 없다.
  var prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = math.min(
        math.min(curr[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev = List<int>.from(curr);
  }
  return prev[b.length];
}

/// 매칭 결과의 확실한 정도.
enum MatchConfidence {
  /// ISRC가 같다. 같은 녹음이다.
  exact,

  /// 제목과 아티스트가 다듬은 뒤 똑같다.
  strong,

  /// 닮았지만 글자가 조금 다르다. 판본이 다를 수 있다.
  loose;

  String get label => switch (this) {
    MatchConfidence.exact => 'LOCAL',
    MatchConfidence.strong => 'LOCAL',
    MatchConfidence.loose => 'LOCAL?',
  };
}

class TrackMatch<T> {
  const TrackMatch(this.track, this.confidence, this.score);

  final T track;
  final MatchConfidence confidence;
  final double score;
}

/// 로컬 곡 하나를 비교용 형태로 미리 다듬어 둔 것.
///
/// 검색할 때마다 수천 곡의 제목을 다시 소문자로 내리고 괄호를 지우면 목록이
/// 버벅인다. 라이브러리를 읽을 때 한 번만 만든다.
class MatchKey<T> {
  MatchKey(this.track, String title, String artist, {this.isrc})
    : title = normalizeTitle(title),
      artist = normalizeArtist(artist);

  final T track;
  final String title;
  final String artist;
  final String? isrc;
}

/// [keys] 중에서 주어진 제목·아티스트에 가장 가까운 것을 찾는다.
///
/// 못 찾으면 null. 아티스트가 다르면 제목이 같아도 버린다. `Yesterday`처럼
/// 흔한 제목에서 엉뚱한 곡이 붙는 것을 막으려는 것이다.
TrackMatch<T>? bestMatch<T>(
  List<MatchKey<T>> keys, {
  required String title,
  required String artist,
  String? isrc,
}) {
  if (keys.isEmpty) return null;

  final wantTitle = normalizeTitle(title);
  final wantArtist = normalizeArtist(artist);

  TrackMatch<T>? best;

  for (final k in keys) {
    if (isrc != null && k.isrc != null && k.isrc == isrc) {
      return TrackMatch(k.track, MatchConfidence.exact, 1);
    }

    final artistScore = similarity(k.artist, wantArtist);
    if (artistScore < 0.75) continue;

    final titleScore = similarity(k.title, wantTitle);
    if (titleScore < 0.80) continue;

    final score = titleScore * 0.65 + artistScore * 0.35;
    final confidence = (titleScore == 1 && artistScore == 1)
        ? MatchConfidence.strong
        : MatchConfidence.loose;

    if (best == null || score > best.score) {
      best = TrackMatch(k.track, confidence, score);
    }
  }

  return best;
}
