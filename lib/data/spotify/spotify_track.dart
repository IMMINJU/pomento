/// Spotify 검색 결과 한 줄.
///
/// 우리 DB의 Track과 섞이지 않게 따로 둔다. 이건 카탈로그에서 읽어온 정보일
/// 뿐이고, 실제로 소리를 내는 것은 로컬 파일이거나 Spotify 앱이다.
class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.artworkUrl,
    this.isrc,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artworkUrl;

  /// 국제 표준 녹음 코드. 있으면 제목 비교보다 정확하게 같은 녹음을 가른다.
  final String? isrc;

  /// Spotify 앱을 여는 주소. 앱이 없으면 브라우저로 넘어간다.
  String get appUri => 'spotify:track:$id';
  String get webUrl => 'https://open.spotify.com/track/$id';

  Duration get duration => Duration(milliseconds: durationMs);

  factory SpotifyTrack.fromJson(Map<String, dynamic> j) {
    final artists = (j['artists'] as List?) ?? const [];
    final album = (j['album'] as Map?)?.cast<String, dynamic>();
    final images = (album?['images'] as List?) ?? const [];
    // 이미지는 큰 것부터 온다. 목록에 쓸 것이라 가장 작은 것을 고른다.
    final art = images.isEmpty
        ? null
        : (images.last as Map)['url'] as String?;

    return SpotifyTrack(
      id: j['id'] as String? ?? '',
      title: j['name'] as String? ?? '',
      artist: artists.isEmpty
          ? ''
          : artists
              .map((a) => (a as Map)['name'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .join(', '),
      album: album?['name'] as String? ?? '',
      durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
      artworkUrl: art,
      isrc: ((j['external_ids'] as Map?)?['isrc']) as String?,
    );
  }
}
