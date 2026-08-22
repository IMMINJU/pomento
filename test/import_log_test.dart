import 'package:flutter_test/flutter_test.dart';
import 'package:pomento/data/models/import_log.dart';

void main() {
  final at = DateTime(2026, 8, 22, 14, 5);

  group('ImportLog 곡 정보 출처', () {
    test('파일 태그에서만 읽었으면 그렇게 적는다', () {
      final log = ImportLog(at: at, added: 5, tagsFromFile: 5);
      expect(log.tagSourceLine, '곡 정보를 모두 파일에서 읽었습니다');
      expect(log.summary, '5곡 추가됨 · 곡 정보를 모두 파일에서 읽었습니다');
    });

    test('음악 앱에서만 읽었으면 그렇게 적는다', () {
      final log = ImportLog(at: at, added: 5, tagsFromLibrary: 5);
      expect(log.tagSourceLine, '곡 정보를 모두 음악 앱에서 읽었습니다');
    });

    test('섞이면 곡 수로 나눠 적는다', () {
      final log =
          ImportLog(at: at, added: 7, tagsFromFile: 4, tagsFromLibrary: 3);
      expect(log.tagSourceLine, '파일에서 4곡, 음악 앱에서 3곡');
    });

    test('셀 것이 없으면 곡 수만 적는다', () {
      final log = ImportLog(at: at, added: 3);
      expect(log.tagSourceLine, '');
      expect(log.summary, '3곡 추가됨');
    });
  });

  group('ImportLog 저장', () {
    test('내보내고 다시 읽으면 같은 값이다', () {
      final log = ImportLog(
        at: at,
        added: 1300,
        tagsFromFile: 1200,
        tagsFromLibrary: 100,
      );
      final back = ImportLog.fromJson(log.toJson());

      expect(back, isNotNull);
      expect(back!.at, at);
      expect(back.added, 1300);
      expect(back.tagsFromFile, 1200);
      expect(back.tagsFromLibrary, 100);
    });

    test('시각을 못 읽으면 기록으로 치지 않는다', () {
      expect(ImportLog.fromJson({'added': 3}), isNull);
      expect(ImportLog.fromJson({'at': '어제', 'added': 3}), isNull);
    });

    test('시각은 월 일 시:분으로 적는다', () {
      expect(ImportLog(at: at, added: 1).whenLabel, '8월 22일 14:05');
    });
  });
}
