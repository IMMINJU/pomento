/// 트랙의 `filePath`가 무엇을 가리키는지 가른다.
///
/// 대부분의 트랙은 앱이 읽을 수 있는 절대 경로다. iOS에서 음악 앱 보관함의
/// 곡을 참조로 들여오면 그 자리에 `ipod://<persistentID>`가 들어간다. 파일이
/// 아니므로 `File(...).existsSync()`로 확인하면 전부 없는 것으로 나온다.
library;

/// 음악 앱 보관함의 곡을 가리키는 주소의 머리.
///
/// `assetURL`을 그대로 저장하지 않는다. 재동기화 후 무효가 될 수 있어서
/// 영구 식별자만 남기고 재생 시점에 다시 푼다.
const String kLibraryScheme = 'ipod://';

/// 음악 앱 보관함의 곡인가.
bool isLibraryPath(String path) => path.startsWith(kLibraryScheme);

/// 파일 시스템에서 직접 열 수 있는 경로인가.
bool isFilePath(String path) => !isLibraryPath(path);

/// 보관함 주소에서 영구 식별자만 떼어낸다. 보관함 주소가 아니면 null.
String? libraryIdOf(String path) =>
    isLibraryPath(path) ? path.substring(kLibraryScheme.length) : null;

/// 영구 식별자로 보관함 주소를 만든다.
String libraryPathFor(String persistentId) => '$kLibraryScheme$persistentId';
