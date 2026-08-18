import 'package:flutter_test/flutter_test.dart';
import 'package:pomento/data/spotify/track_match.dart';

void main() {
  group('normalizeTitle', () {
    test('판본 표기가 든 괄호는 지운다', () {
      expect(normalizeTitle('Let Down (Remastered 2016)'), 'let down');
      expect(normalizeTitle('Creep [Explicit]'), 'creep');
    });

    test('판본이 아닌 괄호는 남긴다', () {
      expect(normalizeTitle('Creep (Live)'), 'creep live');
      expect(normalizeTitle('Song (Acoustic)'), 'song acoustic');
    });

    test('하이픈 뒤 판본 표기도 지운다', () {
      expect(normalizeTitle('No Surprises - 2016 Remaster'), 'no surprises');
    });

    test('featuring은 잘라낸다', () {
      expect(normalizeTitle('Track feat. Someone'), 'track');
      expect(normalizeTitle('Track ft Someone'), 'track');
    });

    test('유튜브 꼬리표를 지운다', () {
      expect(normalizeTitle("'The Wolf' [Official Video]"), 'the wolf');
      expect(normalizeTitle('Song (Official Music Video)'), 'song');
      expect(normalizeTitle('Song (Official Audio)'), 'song');
    });

    test('악센트를 벗긴다', () {
      expect(normalizeArtist('SIAMÉS'), 'siames');
      expect(normalizeTitle('Café'), 'cafe');
    });

    test('한글 제목은 그대로 남는다', () {
      expect(normalizeTitle('밤편지'), '밤편지');
    });
  });

  group('normalizeArtist', () {
    test('여러 아티스트 중 첫 사람만 본다', () {
      expect(normalizeArtist('Radiohead, Thom Yorke'), 'radiohead');
      expect(normalizeArtist('A & B'), 'a');
    });

    test('앞의 the는 뗀다', () {
      expect(normalizeArtist('The Beatles'), 'beatles');
    });
  });

  group('bestMatch', () {
    List<MatchKey<String>> keys(List<(String, String)> rows) => [
          for (final r in rows) MatchKey<String>(r.$1, r.$1, r.$2),
        ];

    test('제목과 아티스트가 같으면 강하게 붙는다', () {
      final m = bestMatch(
        keys([('Let Down', 'Radiohead')]),
        title: 'Let Down',
        artist: 'Radiohead',
      );
      expect(m, isNotNull);
      expect(m!.confidence, MatchConfidence.strong);
    });

    test('판본 표기만 다르면 같은 곡으로 본다', () {
      final m = bestMatch(
        keys([('Let Down', 'Radiohead')]),
        title: 'Let Down (Remastered 2016)',
        artist: 'Radiohead',
      );
      expect(m, isNotNull);
      expect(m!.confidence, MatchConfidence.strong);
    });

    test('아티스트가 다르면 제목이 같아도 안 붙는다', () {
      final m = bestMatch(
        keys([('Yesterday', 'Some Cover Band')]),
        title: 'Yesterday',
        artist: 'The Beatles',
      );
      expect(m, isNull);
    });

    test('ISRC가 같으면 제목을 보지 않는다', () {
      final list = [
        MatchKey<String>('a', '전혀 다른 제목', '다른 사람', isrc: 'GBAYE0601498'),
      ];
      final m = bestMatch(
        list,
        title: 'Let Down',
        artist: 'Radiohead',
        isrc: 'GBAYE0601498',
      );
      expect(m, isNotNull);
      expect(m!.confidence, MatchConfidence.exact);
    });

    test('글자가 조금 다르면 느슨한 매칭으로 표시한다', () {
      final m = bestMatch(
        keys([('No Suprises', 'Radiohead')]),
        title: 'No Surprises',
        artist: 'Radiohead',
      );
      expect(m, isNotNull);
      expect(m!.confidence, MatchConfidence.loose);
    });

    test('라이브와 스튜디오 녹음은 가른다', () {
      final m = bestMatch(
        keys([('Creep (Live)', 'Radiohead')]),
        title: 'Creep',
        artist: 'Radiohead',
      );
      expect(m, isNull);
    });

    test('유튜브에서 받은 파일도 같은 곡으로 붙는다', () {
      final m = bestMatch(
        [MatchKey<String>('a', "'The Wolf' [Official Video]", 'SIAMÉS')],
        title: 'The Wolf',
        artist: 'SIAMES',
      );
      expect(m, isNotNull);
      expect(m!.confidence, MatchConfidence.strong);
    });

    test('빈 색인에서는 아무것도 안 나온다', () {
      expect(
        bestMatch(<MatchKey<String>>[], title: 'x', artist: 'y'),
        isNull,
      );
    });
  });
}
