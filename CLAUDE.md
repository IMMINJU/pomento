# Pomento (뽀멘토)

로컬 음원 플레이어. 두 사람이 쓰려고 만든다. 한 명은 Android, 한 명은 iOS.

핵심은 **배속과 피치의 미세 조정**과 **3층으로 쌓는 음향 보정**이다. 배속은
1.0배 근처를 얼마나 곱게 다루느냐가 중요하고, 최고 배속은 중요하지 않다.

## 되돌리면 안 되는 것

이유를 모르고 고치면 문제가 되살아난다.

**원본 파일에는 절대 쓰지 않는다.** 태그와 자켓은 가져오는 시점에 읽어서 앱
DB와 앱 폴더에 복사하고, 이후로는 사본만 본다. 애플뮤직 보관함 동기화가 로컬
파일의 자켓과 메타데이터를 애플 카탈로그 것으로 바꿔버린 적이 있다.

- iOS `Info.plist`에 **`NSAppleMusicUsageDescription`을 넣지 않는다.** 이 키가
  없으면 `MPMediaLibrary` 접근이 시스템 단에서 막힌다.
- 자켓 우선순위: 사용자 지정 → 태그에서 뽑아둔 것 → 폴더 표지 → 자동 생성.
  **온라인 조회는 하지 않는다.**
- **자켓 위에는 아무것도 덮지 않는다.** 질감도 색면도 올리지 않는다.

**음향 세 층을 dB 축에서 더한다.** 기기(자동 감지) + 환경 + 취향. **취향 층만
공유한다.** 두 사람의 이어폰 특성이 달라서 완성된 EQ 곡선을 통째로 주고받으면
상대 폰에서 어긋난다. 19개(7+6+6)로 200가지 넘는 조합이 나온다.

구조는 엔진에만 남아 있고 화면에는 안 드러난다. 음향 화면 첫 탭은 취향 프리셋만
이름으로 나열한 평면 목록이다. 기기 보정은 자동으로 붙고 환경 보정은 추가 효과
탭에 있다.

지하철 프리셋이 저역을 **깎는** 것도 의도다. 지하철 소음이 저역이라 저역을 더
올리면 소음과 겹쳐 뭉갠다. 소음에 묻히는 건 중역 명료도다.

**배속 두 방식.** 연동(리샘플링, 속도와 음 높이가 같이 움직임, 음질 손실 없음)과
고정(타임스트레치, 피치시프트로 상쇄, 1.0에서 멀수록 잡음). 피치는 반음이 아니라
**센트** 단위다. A=432Hz는 -31.8센트.

**마지막으로 듣던 자리를 되살리되 소리는 내지 않는다.** 이어폰을 안 꽂은 채 앱을
열었을 때 스피커로 터지는 것을 막는다. 큐는 곡 id만 저장하고, 위치는 5초에 한
번만 쓴다(250ms마다 쓰면 재생 내내 DB에 쓰게 된다). 파일은 재생 버튼을 누를 때
연다.

## 구조

```
lib/
  audio/
    audio_engine.dart      SoLoud 감싼 재생기. 필터 체인, 배속, 스트리밍
    platform_decoder.dart  플랫폼 코덱으로 PCM 뽑는 통로
    player_controller.dart 큐, 반복, 셔플, A-B, 곡별 배속 기억
    sleep_timer.dart / effect_controller.dart / audio_handler.dart
  data/
    db/database.dart       drift 스키마
    models/                eq_curve, preset, tempo, app_settings, gesture_settings
    repo/                  library, preset, settings
    spotify/               config, 세션(App Remote + Web API), 곡 매칭
    storage/media_importer.dart  가져오기와 태그 스냅샷
    platform/native_media.dart   MediaStore 스캔, 출력 기기 감지
  presets/builtin_presets.dart   기본 프리셋 19개
  ui/
    theme.dart             토큰. 종이·잉크·간격·글자
    home_shell.dart        재생 화면 위에 쌓는 셸. 하단 탭바는 없다
    player_screen.dart / spotify_player.dart / practice_screen.dart
    effects_screen.dart / eq_editor_screen.dart / presets_screen.dart
    library_screen.dart / search_screen.dart / settings_screen.dart
    gesture_settings_screen.dart / import_sheet.dart
    widgets/
      paper.dart           미색 종이. 색면 + 얼룩 + 알갱이
      surface.dart         가라앉은 면, 알약, 동그란 버튼, 세그먼트
      ambient_plate.dart   자켓 뒤 등명도 두 색 판, 자켓 액자
      artwork_tone.dart    자켓에서 판 색과 강조색을 뽑는다
      sheet.dart           시트와 대화상자
      jump_button.dart     원형 화살표 안에 초를 적는 버튼
      stepper_field.dart   라벨+숫자칸+슬라이더+−/+ 한 세트
      practice_blocks.dart 속도·피치·구간·점프 조각
      settings_list.dart   설정과 추가 효과가 함께 쓰는 목록 문법
      gesture_layer.dart   설정대로 한 손가락 조작을 받는 층
android/app/src/main/kotlin/com/pomento/app/
  MainActivity.kt          MethodChannel 3종
  PcmDecoder.kt            MediaCodec 기반 PCM 디코더
android/spotify-app-remote/   Spotify App Remote aar 서브프로젝트
tool/
  make_icon.py             앱 아이콘. Newsreader로 찍은 `P.`
  make_paper.py            종이 질감 타일
  install_icons.py         안드로이드·iOS 자리에 굽기
```

## 오디오 엔진

`flutter_soloud`는 **mp3, wav, ogg, flac만** 내장 디코더로 읽는다. AAC가 없어서
m4a가 안 열린다. 그래서 `PlatformDecoder`가 플랫폼 코덱(Android `MediaCodec`)으로
16비트 PCM을 뽑아 `setBufferStream`에 민다. 8초 정도만 앞서 채운다. 7시간짜리를
다 풀면 몇 기가가 된다.

이 경로에서 달라지는 것.

- `BufferingType.released`를 쓰므로 **재생 위치가 항상 0으로 보고된다.** 위치는
  `getStreamTimeConsumed`에 탐색 기준점(`_streamBase`)을 더해 낸다.
- 되감을 수 없으므로 탐색은 디코더를 옮기고 버퍼를 비워 다시 채운다.
- 엔진 루프를 못 쓴다. A-B와 한 곡 반복은 `PlayerController` 타이머가 처리한다.

필터는 전역으로 **한 번만** 붙이고 이후엔 파라미터만 바꾼다. 재생 중에 붙였다
떼면 소리가 튄다. 순서는 피치 → EQ → 리버브 → 에코 → 리미터. 리미터가 맨 끝인
이유는 세 층을 더하면 이득이 +10dB를 넘길 수 있어서다.

값 변경은 대부분 `fade...`로 넘긴다. 배속은 60ms 간격으로 묶는다.

## EQ

`EqPoint`는 두 종류다. `bandwidthOct == 0`은 **곡선 위의 점**(내장 프리셋 19개가
전부 이 방식), `> 0`은 **종 모양 밴드**. 전부 종 모양으로 바꾸면 이미 귀로 맞춰둔
19개의 소리가 다 달라진다. 편집에서 새로 만드는 점만 종 모양(1옥타브)이다.

엔진 밴드 수는 **32**다. 한 칸이 0.29옥타브라 0.5옥타브까지 좁혀도 종 모양이
살아 있다. 10밴드일 때는 한 칸이 0.97옥타브라 좁은 밴드가 이웃으로 번졌다.
SoLoud 상한은 64.

STFT 창이 1024라 44.1kHz에서 해상도가 43Hz다. **100Hz 아래 밴드 몇 개는 같은
빈을 나눠 써서 구분되지 않는다.** 2048로 키우면 지연이 두 배가 된다.

## 화면 배치

Capriccio 6.5.2를 기기에 깔아 화면을 하나씩 찍어 대조했다. App Store 스크린샷은
믿을 것이 못 된다.

**하단 탭바를 두지 않는다.** 재생 화면이 곧 첫 화면이고 라이브러리·검색·설정은
그 위에 쌓는다. 한 번 탭 넷으로 만들었다가 걷어냈다. 손이 자주 가는 것이 재생
조작이라 화면 아래쪽을 그쪽에 내준다. 하단은 `[폴더] 이전 재생 다음 [재생목록]`,
상단은 큐 위치·패널 토글·검색·설정.

**앨범아트가 제스쳐를 받는 자리다.** 남는 세로 공간을 전부 자켓에 준다. 컨트롤
패널을 펼치면 자켓이 줄고 패널이 진행바 아래로 들어간다. 전에는 자켓 위에 유리로
얹었는데, 유리를 걷으면 불투명한 카드가 되어 자켓을 덮는다.

**화면 순서를 지킨다.** 상단바 → 앨범아트 → 제목 → 아티스트·앨범 → 진행바 →
(패널) → 전송 행. 제목과 전송을 카드로 묶지 않는다.

**배속 진입점은 조건 없이 항상 보인다.** 전에는 배속이 1.0이 아닐 때만 배지가
떠서 기본 상태에서 배속을 켤 길이 없었다.

**값을 다루는 자리는 모두 같은 모양이다.** `StepperField`가 라벨·숫자칸·슬라이더·
−/+ 를 한 세트로 그린다. **속도 슬라이더에는 폭 전환이 있다**(±8% / ±16% / 넓게).
DJ 피치 페이더가 ±8%인 이유와 같다. 숫자칸과 스테퍼로는 폭 밖으로도 나간다.

**연습 화면의 A와 B는 각각 독립 버튼이다.** 한 버튼을 두 번 눌러 찍으면 지금 어느
쪽 차례인지 화면만 보고 알 수 없다. 패널은 자리가 좁아 한 버튼이라 글자로 적는다.

**점프 버튼에는 알약 배경이 없다.** 원형 화살표가 테두리를 겸하고 그 안에 초를
적는다(애플 팟캐스트 방식). 그냥 빨리감기 아이콘을 쓰면 짧게와 길게 넷이 같은
그림이 된다. 화살표는 흐리게, 숫자는 선명하게.

**값 알약 안은 `아이콘 | 값 | 보조값` 셋으로 나눈다.** 가운데를 비워두면 218px
알약에 68px어치 글자만 든 꼴이 된다.

**미니 플레이어는 화면 폭을 다 쓴다.** 떠 있는 카드가 아니다. 위 가장자리에
진행선, 왼쪽에 44px 섬네일. 바탕은 종이에 자켓 색을 6%만 섞는다. 전에는 86%로
덮었는데 파란 자켓에서 막대 전체가 파랗게 떴다. 무엇이 걸려 있는지는 섬네일과
진행선이 말해준다. 불투명이어야 하고 `SafeArea`로 시스템 바를 피해야 한다.

**연습·음향·EQ는 모달이 아니라 쌓는 화면이다.** 그래야 만지는 동안 소리가 계속
나고 프리셋을 눌러가며 바로 견줄 수 있다. 바텀시트로 덮으면 그 비교가 끊긴다.
미니 플레이어는 위에 무언가 쌓였을 때만 나오고, 몇 겹인지는 `NavigatorObserver`가
세어 `navDepthProvider`에 넣는다. 라우트 전환은 빌드 도중이라 그 값은 다음
프레임에 쓴다. 시트와 대화상자는 세지 않는다.

**제스쳐는 전부 설정에서 바꾼다.** 쓸기와 끌기를 가르는데, 같은 축에 둘 다 걸면
어느 쪽인지 알 수 없으므로 쓸기를 켜두면 그 축의 끌기는 시작하지 않는다. 세로
기본값은 Capriccio와 반대다. 위로 쓸면 뒤로, 아래로 쓸면 앞으로.

**컨트롤 패널은 접힌 상태가 기본이다.** 늘 펼쳐두면 피치와 구간 반복을 스치듯
눌러 잘못 걸린다.

## 디자인

미색 종이 위에 잉크로 찍은 인쇄물이다. 토큰은 `lib/ui/theme.dart`에 있다.
**글래스모피즘을 걷어냈다.** 되살리려면 아래를 먼저 읽을 것.

**판을 얹지 않고 가라앉힌다.** 테두리 대신 한 단계 어두운 종이(`paperLo`)로
칠한다. 선을 그으면 화면이 칸으로 잘려 보인다. 선을 남긴 자리는 EQ 범례 하나로,
점선·파선·실선이 어느 층인지 보여주는 견본이라 지우면 뜻이 사라진다.

**종이는 세 겹이다**(`PaperBackground`). 색면 셋(따뜻한 미색·찬 회녹색·흙빛,
각 20% 언저리) + 얼룩(460px) + 알갱이(340px). 단색 하나면 균일해서 인쇄물이
아니라 화면으로 보인다. 색면 반지름은 화면보다 커야 그라디언트가 아니라 얼룩으로
읽힌다.

CSS 시안은 `mix-blend-mode: multiply`였다. Flutter에서 blend mode는 `saveLayer`를
불러 보급형 안드로이드에서 프레임을 깎는다. 밝은 바탕 위 곱하기 `B(1-a+ag)`는
검정을 `a(1-g)` 알파로 얹은 것과 결과가 같으므로, 그 값을 알파에 미리 구워
일반 합성으로 그린다. 타일은 `tool/make_paper.py`가 굽고 씨앗이 고정돼 있다.

질감은 내용 **아래**에 깔린다. 알갱이가 제일 진한 자리도 검정 7%라 잉크 위에서는
255단계 중 두 단계도 안 움직이지만, 자켓 위에 얹히면 그건 보인다.

**앰비언트 판은 등명도 두 색이다**(`AmbientPlate`). 자켓 한 장을 뭉개면 색이
하나로 섞여 밝기만 오르내린다. `CoverAnalyzer`가 색상 두 개를 뽑아 **명도를 같게**
맞춘다(L\* 74). 명도가 같으면 경계가 안 생기고 색상만 서로 밀어낸다. 등명도는 두
색이 서로 같으면 되는 것이지 특정 값일 이유가 없다. 종이가 L\* 97이라 58로 잡으면
무겁다. 블러도 마스크도 안 쓴다. 위아래를 종이색으로 덮어 같은 결과를 낸다.

**색이 있으면 재생 중이다.** 강조색은 자켓에서 뽑아 진행선·슬라이더·바뀐 값·지금
걸린 곡에만 쓴다. 목차나 버튼이나 스위치를 강조색으로 칠하면 뜻이 흐려진다.
그래서 Material `Switch`를 안 쓰고 켜짐을 잉크로 채운다. 잉크로 채운 자리는 재생
버튼 하나다. 누를 수 있다는 것도 색이 아니라 밑줄로 말한다.

**글자.** 제목과 숫자는 Newsreader, 본문과 한글은 Pretendard. Newsreader는 가변
폰트라 `fonttools`로 opsz 16에서 잘라 정적 세 벌로 넣었다. 숫자는 고정폭이다.

**아이콘은 `P.` 한 글자다.** LP판·레코드 축·영사기·음표를 다 그려봤는데 축소하면
무엇인지 모르겠거나 다른 앱과 닮았다. 마침표가 붙어 `Po`로도 읽힌다. 그림자와
그라디언트를 넣지 않는다. 글자 위치는 눈금이 아니라 잉크의 실제 경계를 재서
맞춘다. 사이드 베어링 때문에 글자 상자 기준으로 정렬하면 왼쪽으로 치우친다.

## Spotify

카탈로그와 검색은 Spotify에서, 소리는 되도록 내 파일에서. 검색 결과의 내 곡에는
`LOCAL` 표가 붙고 그 곡에서만 배속·피치·구간 반복이 열린다.

**Spotify로 트는 소리에는 우리 처리가 걸리지 않는다.** App Remote는 기기에 깔린
Spotify 앱을 원격 조종하는 방식이라 오디오가 우리 프로세스를 지나지 않는다.
그래서 화면을 `SpotifyPlayerView`로 갈라 두고 무엇이 꺼져 있는지 적어둔다. 구간
반복만 `seekTo`로 흉내 낼 수 있는데 몇백 밀리초 어긋난다.

Client Secret은 앱에 넣지 않는다. APK를 뜯으면 나온다.

**설정.** [개발자 대시보드](https://developer.spotify.com/dashboard)에서 앱 생성 →
Redirect URI `pomento://auth` → Android 패키지명 `com.pomento.app`과 디버그·릴리스
SHA-1 등록 → iOS Bundle ID 등록 → **앱 소유자 계정에 Premium**(2026년 2월부터
Development Mode 필수 조건). Client ID는 `--dart-define=SPOTIFY_CLIENT_ID=...`나
설정 화면에서 넣고, 기기에 저장한 값이 빌드에 박은 값보다 우선한다.

**Web API 제약**(2026년 2월 개편 이후). 앱당 사용자 5명, 개발자당 Client ID 25개.
`/search`는 최대 10개. 배치 조회와 아티스트 top-tracks 제거(인기곡은
`search?q=artist:...`로 대신). 사용자 `product` 필드 제거라 상대 Premium 여부를
알 수 없다.

**iOS.** `spotify_sdk`의 podspec이 `prepare_command`로 `spotify/ios-sdk`를 `v3.0.0`
태그에 클론해 xcframework만 남긴다. `pod install` 시점 네트워크 작업이라 맥에서만
확인된다. 태그가 사라지면 iOS 빌드가 통째로 깨진다. `ios/Podfile`에 최소 버전을
13.0으로 못 박고 `post_install`에서 모든 pod을 같은 값으로 올린다.
`SystemNavigator.pop`은 안드로이드에서만 돈다.

**App Remote.** Maven에 없어서 `android/spotify-app-remote/`에 aar을 직접 넣고
`settings.gradle.kts`에서 `include(":spotify-app-remote")`로 끼운다.
`dart run spotify_sdk:android_setup`은 Groovy gradle을 전제해서 안 돈다.

## 개발

```bash
flutter pub get
dart run build_runner build          # drift 코드 생성
flutter analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk

python tool/make_icon.py && python tool/install_icons.py   # 아이콘
python tool/make_paper.py                                  # 종이 질감
```

`flutter_launcher_icons`는 쓰지 않는다. 다른 의존성과 물려서 0.9.3으로 내려앉는다.

`compileSdk`는 `android/build.gradle.kts`에서 하위 프로젝트까지 37로 맞춘다.
`permission_handler`가 37을 요구하는데 `audiotags`는 31에 묶여 있어서다. 이 블록은
`evaluationDependsOn`보다 **먼저** 와야 한다.

## 글쓰기

한국어 주석과 문서는 담백하게. em dash를 쓰지 않고, 과장된 동사와 감정 라벨을
쓰지 않으며, 비유로 설명을 대체하지 않는다. 소제목은 그 단계에서 밝혀진 사실을
적는다.

## 아직 안 한 것

- Smart Lists, 라디오, 곡 식별, 가사, 비주얼라이저
- 클라우드(Box·Dropbox·OneDrive)와 네트워크(FTP·WebDAV) 파일
- iOS 빌드 검증. 맥이 없어서 Codemagic `ios-compile`로 돌릴 예정
- **iOS에서 m4a가 안 열린다.** `com.pomento.app/decoder` 채널이 안드로이드에만
  있다. iOS에서는 `MissingPluginException`을 잡아 엔진 기본 경로로 넘어가는데
  AAC 디코더가 없어 그 곡은 재생에 실패한다. 크래시는 안 나고 다음 곡으로
  넘어간다. AVAudioFile 기반 Swift 구현이 필요하다
- iOS에서 Spotify SDK 확인
- Firestore 프리셋 동기화. 지금은 JSON 복사·붙여넣기
- 태그에서 ISRC 읽기. 지금은 제목·아티스트로만 맞춘다
- 아주 긴 음원에서 `maxBufferSizeBytes` 상한이 누적으로 걸리는지 확인
- 다크모드
