import 'package:flutter_test/flutter_test.dart';
import 'package:pomento/audio/platform_decoder.dart';
import 'package:pomento/core/track_source.dart';

void main() {
  group('trackSource', () {
    test('앱이 읽을 수 있는 경로는 파일로 본다', () {
      expect(isFilePath('/var/mobile/Containers/Data/media/a.mp3'), isTrue);
      expect(isLibraryPath('/var/mobile/Containers/Data/media/a.mp3'), isFalse);
    });

    test('보관함 주소는 파일이 아니다', () {
      expect(isLibraryPath('ipod://1234567890'), isTrue);
      expect(isFilePath('ipod://1234567890'), isFalse);
    });

    test('보관함 주소에서 영구 식별자만 떼어낸다', () {
      expect(libraryIdOf('ipod://1234567890'), '1234567890');
      expect(libraryIdOf('/music/a.mp3'), isNull);
    });

    test('식별자로 만든 주소를 다시 풀면 같은 값이다', () {
      expect(libraryPathFor('42'), 'ipod://42');
      expect(libraryIdOf(libraryPathFor('42')), '42');
    });
  });

  group('PlatformDecoder', () {
    test('보관함 곡은 확장자와 무관하게 플랫폼 디코더로 간다', () {
      expect(PlatformDecoder.needsPlatformDecoder('ipod://1'), isTrue);
    });

    test('엔진이 읽는 확장자는 그대로 엔진에 맡긴다', () {
      expect(PlatformDecoder.needsPlatformDecoder('/a/b.mp3'), isFalse);
      expect(PlatformDecoder.needsPlatformDecoder('/a/b.flac'), isFalse);
    });

    test('m4a는 플랫폼 코덱을 거친다', () {
      expect(PlatformDecoder.needsPlatformDecoder('/a/b.m4a'), isTrue);
    });
  });
}
