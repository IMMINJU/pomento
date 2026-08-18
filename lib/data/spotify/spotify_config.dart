/// Spotify 개발자 대시보드에서 받은 값.
///
/// Client ID는 빌드할 때 `--dart-define=SPOTIFY_CLIENT_ID=...`로 넣거나,
/// 설정 화면에서 붙여 넣어 기기에 저장할 수 있다. 둘 다 있으면 기기에 저장한
/// 값을 쓴다. 앱을 다시 빌드하지 않고 값을 바꿀 수 있어야 해서다.
///
/// Client Secret은 쓰지 않는다. 앱에 넣으면 APK를 뜯어 꺼낼 수 있다.
/// 인증은 Spotify SDK가 대신 받아온다.
class SpotifyConfig {
  const SpotifyConfig({required this.clientId});

  /// 우리 앱의 Client ID.
  ///
  /// Client ID는 비밀이 아니다. 어느 앱이든 클라이언트에 실려 나가고,
  /// Spotify 문서도 그렇게 쓴다. 비밀인 것은 Client Secret 쪽이고 그건
  /// 넣지 않는다. 저장소가 비공개이기도 하다.
  ///
  /// Development Mode라 대시보드의 User Management에 올라간 계정만 로그인할
  /// 수 있다. 값이 새어 나가도 남이 쓸 수 없다.
  static const String bakedClientId = '2276e411ef2140c3bb49e7ed60de222a';

  /// 빌드할 때 다른 값을 쓰고 싶으면 --dart-define으로 덮는다.
  static const String buildTimeClientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: bakedClientId,
  );

  /// Spotify 대시보드의 Redirect URI에 이 값을 그대로 등록해야 한다.
  /// android/app/build.gradle.kts의 manifestPlaceholders와 짝이 맞아야 한다.
  static const String redirectUrl = 'pomento://auth';

  /// 필요한 권한.
  ///
  /// `app-remote-control`은 Spotify 앱을 조종하는 데, 나머지는 지금 무엇이
  /// 재생 중인지 읽는 데 쓴다. 라이브러리를 고치는 권한은 넣지 않는다.
  static const String scope =
      'app-remote-control,user-read-currently-playing,user-read-playback-state';

  final String clientId;

  bool get isConfigured => clientId.trim().isNotEmpty;
}
