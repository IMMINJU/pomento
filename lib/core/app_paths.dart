import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 앱이 소유한 저장 경로.
///
/// 음원과 아트워크를 앱 안에 두는 것이 이 프로젝트의 전제다. 외부 앱(iOS의
/// 음악 앱 등)이 태그나 자켓을 바꿔도 여기 복사해둔 값은 영향을 받지 않는다.
class AppPaths {
  AppPaths._(this.root);

  final Directory root;

  static AppPaths? _instance;
  static AppPaths get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppPaths.init()을 먼저 호출해야 한다');
    }
    return i;
  }

  static Future<AppPaths> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final paths = AppPaths._(dir);
    await paths.media.create(recursive: true);
    await paths.artwork.create(recursive: true);
    await paths.userArtwork.create(recursive: true);
    _instance = paths;
    return paths;
  }

  /// 가져온 음원 원본 (managed 트랙).
  Directory get media => Directory(p.join(root.path, 'media'));

  /// 파일 태그에서 추출해 저장한 자켓.
  Directory get artwork => Directory(p.join(root.path, 'artwork'));

  /// 사용자가 직접 지정한 자켓. 무엇도 이 값을 덮어쓰지 않는다.
  Directory get userArtwork => Directory(p.join(root.path, 'user_artwork'));

  String get dbPath => p.join(root.path, 'player.sqlite');

  String artworkFileFor(String key) => p.join(artwork.path, '$key.jpg');

  String userArtworkFileFor(String key) => p.join(userArtwork.path, '$key.jpg');
}
