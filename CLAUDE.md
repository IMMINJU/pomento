# Pomento (뽀멘토)

로컬 음원 플레이어. 두 사람이 쓰려고 만든다. 한 명은 Android, 한 명은 iOS.

핵심은 **배속과 피치의 미세 조정**과 **3층으로 쌓는 음향 보정**이다. 배속은
1.0배 근처를 얼마나 곱게 다루느냐가 중요하고, 최고 배속은 중요하지 않다.

## 왜 이렇게 만들었는지

설계 결정 중 되돌리면 안 되는 것들이 있다. 이유를 모르고 고치면 문제가 되살아난다.

### 원본 파일에는 절대 쓰지 않는다

태그와 자켓은 가져오는 시점에 읽어서 앱 DB와 앱 폴더에 복사한다. 이후로는
그 사본만 본다. 애플뮤직 보관함 동기화가 로컬 파일의 자켓과 메타데이터를
애플 카탈로그 것으로 바꿔버리는 문제를 겪은 적이 있어서, 우리가 보여주는
값이 외부 앱의 영향을 받지 않게 했다.

- iOS `Info.plist`에 **`NSAppleMusicUsageDescription`을 넣지 않는다.**
  이 키가 없으면 `MPMediaLibrary` 접근이 시스템 단에서 막힌다. 실수로도
  애플뮤직 보관함을 건드릴 수 없다.
- 자켓 우선순위: 사용자가 지정한 것 → 태그에서 뽑아둔 것 → 폴더의 표지 파일
  → 자동 생성. **온라인 조회는 하지 않는다.**

### 음향은 세 층을 dB 축에서 더한다

| 층 | 내용 | 공유 |
|---|---|---|
| 1. 기기 | 출력 기기 특성 보정. 연결된 기기를 감지해 자동 적용 | 안 함 |
| 2. 환경 | 소음 환경 보정 | 안 함 |
| 3. 취향 | 장르와 취향, 배속 포함 | **함** |

기기 보정을 공유하지 않는 이유가 핵심이다. 두 사람의 이어폰 특성이 서로
달라서, 완성된 EQ 곡선을 통째로 주고받으면 상대 폰에서 어긋난다. 취향 층만
주고받아야 "그가 좋다고 한 게 나한테도 좋게" 들린다.

층을 곱하지 않고 더하기 때문에 19개(기기 7 + 환경 6 + 취향 6)로 200가지가
넘는 조합이 나온다.

지하철 프리셋이 저역을 **깎는** 것도 의도다. 지하철 소음이 저역이라 저역을
더 올리면 소음과 겹쳐 뭉갠다. 소음에 묻히는 건 중역 명료도다.

### 배속에는 두 방식이 있다

- **연동(linked)**: 리샘플링. 속도와 음 높이가 같이 움직인다. 원리상 음질
  손실이 없다. 느리게 하면 소리가 두꺼워져서 리버브와 함께 쓰기 좋다.
- **고정(independent)**: 타임스트레치. 리샘플링이 만든 음 높이 변화를
  피치시프트 필터로 상쇄한다. 1.0에서 멀어질수록 잡음이 생긴다.

피치는 반음이 아니라 **센트** 단위로 다룬다. A=432Hz는 -31.8센트다.

## 구조

```
lib/
  audio/
    audio_engine.dart      SoLoud 감싼 재생기. 필터 체인, 배속, 스트리밍
    platform_decoder.dart  플랫폼 코덱으로 PCM 뽑는 통로
    player_controller.dart 큐, 반복, 셔플, A-B, 곡별 배속 기억
    sleep_timer.dart       정해둔 시간이나 곡 끝에서 멈춘다
    effect_controller.dart 3층 합산, 기기 자동 감지, 선택 저장
    audio_handler.dart     잠금화면·알림 컨트롤(audio_service)
  data/
    db/database.dart       drift 스키마
    models/                eq_curve, preset, tempo, app_settings
    repo/                  library, preset, settings
    spotify/               config, 세션(App Remote + Web API), 곡 매칭
    storage/media_importer.dart  가져오기와 태그 스냅샷
    platform/native_media.dart   MediaStore 스캔, 출력 기기 감지
  presets/builtin_presets.dart   기본 프리셋 19개
  ui/
    home_shell.dart        하단 탭 셸. 탭마다 Navigator를 따로 둔다
    player_screen.dart     로컬 재생 화면
    spotify_player.dart    Spotify가 소리를 낼 때의 화면
    practice_screen.dart   배속·피치·구간반복·점프탐색
    effects_screen.dart    3층 보정. 음향 효과 / 추가 효과 / 공유
    eq_editor_screen.dart  취향 층 곡선 편집
    search_screen.dart     Spotify 검색과 LOCAL 표시
    settings_screen.dart   조작 단위, Spotify 연결
    widgets/stepper_field.dart    라벨+숫자칸+슬라이더+−/+ 한 세트
    widgets/practice_blocks.dart  속도·피치·구간·점프 조각. 두 자리에서 함께 쓴다
    widgets/sound_quick_panel.dart 재생 화면에서 바로 누르는 프리셋
android/
  app/src/main/kotlin/com/pomento/app/
    MainActivity.kt        MethodChannel 3종
    PcmDecoder.kt          MediaCodec 기반 PCM 디코더
  spotify-app-remote/      Spotify App Remote aar을 끼운 서브프로젝트
tool/
  make_icon.py             앱 아이콘 그리기
  install_icons.py         안드로이드·iOS 자리에 굽기
```

## 오디오 엔진에서 조심할 것

`flutter_soloud`는 **mp3, wav, ogg, flac만** 내장 디코더로 읽는다.
AAC 디코더가 없다. 사람들이 실제로 가진 음원 중 상당수가 m4a라 이대로는
라이브러리가 안 열린다.

그래서 `PlatformDecoder`가 있다. 확장자가 엔진 기본 지원 밖이면 플랫폼
코덱(Android `MediaCodec`)으로 16비트 PCM을 뽑아 `setBufferStream`에
밀어넣는다. 파일을 통째로 풀지 않고 8초 정도만 앞서 채운다. 7시간짜리
음원을 PCM으로 다 풀면 몇 기가가 되기 때문이다.

이 경로에서는 몇 가지가 달라진다.

- `BufferingType.released`를 쓰므로 **재생 위치가 항상 0으로 보고된다.**
  위치는 `getStreamTimeConsumed`에 탐색 기준점(`_streamBase`)을 더해 낸다.
- 되감을 수 없으므로 탐색은 디코더를 옮기고 버퍼를 비워 다시 채운다.
- 엔진의 루프 기능을 못 쓴다. A-B 구간 반복과 한 곡 반복은
  `PlayerController`의 타이머가 직접 처리한다.

필터는 전역으로 **한 번만** 붙이고 이후에는 파라미터만 바꾼다. 재생 중에
필터를 붙였다 떼면 소리가 튄다. 순서는 피치 → EQ → 리버브 → 에코 → 리미터다.
리미터를 맨 끝에 두는 이유는 세 층을 더하면 이득이 +10dB를 넘길 수 있어서다.

값 변경은 대부분 `fade...`로 넘긴다. 다이얼을 계속 돌려도 클릭 잡음이 안
생기게 하려는 것이다. 배속은 60ms 간격으로 묶어서 보낸다.

## 화면 배치

Capriccio 6.5.2의 배치를 기준으로 삼았다. 되돌리면 안 되는 것 몇 가지가 있다.

**플레이어는 탭이지 화면이 아니다.** 하단 탭 넷(플레이어·라이브러리·검색·설정)
중 하나로 상주한다. 배속을 만지러 갔다가 목록으로 돌아오는 일이 잦아서, 열고
닫는 동작이 끼면 그때마다 재생 화면이 사라진다. 탭마다 Navigator를 따로 두어
폴더나 플레이리스트로 들어가도 탭바와 미니 플레이어가 남는다.

**배속 진입점은 조건 없이 항상 보인다.** 전에는 배속이 1.0이 아닐 때만 배지가
떠서, 기본 상태에서 배속을 켤 길이 화면에 없었다. 진행바 아래 스트립과 전송 행
왼쪽 버튼이 항상 연습 시트를 연다.

**값을 다루는 자리는 모두 같은 모양이다.** `StepperField`가 라벨, 숫자칸,
슬라이더, −/+ 를 한 세트로 그린다. 슬라이더로 대충 잡고, 스테퍼로 다듬고,
정확한 값을 알면 숫자칸에 바로 넣는다. 스테퍼 한 번의 폭은 설정에서 정한다.

**속도 슬라이더에는 폭 전환이 있다.** ±8% / ±16% / 넓게. DJ 피치 페이더가
±8%인 이유와 같다. 1.0 근처만 쓰는 사람에게 0.5~2.0 슬라이더를 주면 한 픽셀이
너무 크게 움직인다. 숫자칸과 스테퍼로는 폭 밖으로도 나갈 수 있다.

**A와 B는 각각 독립 버튼이다.** 한 버튼을 두 번 눌러 찍는 방식은 지금 어느
쪽을 찍는 차례인지 화면만 보고 알 수 없다.

**값은 재생 화면에서 바로 바꾼다.** 진행바 아래 칩 네 개(속도·피치·A-B·음향)를
누르면 그 자리에서 컨트롤이 펼쳐진다. 앨범아트가 줄어들 뿐 곡 제목, 진행바,
전송 버튼은 그대로 남는다. 화면을 옮기지 않는 것이 핵심이다. 이 부분은
Capriccio에 없는 우리 것이고, 전체 화면은 "자세히"로 따로 연다.

**연습·음향·EQ는 모달이 아니라 탭 안에 쌓는 화면이다.** 이게 제일 되돌리기
쉬운 곳이라 이유를 적어둔다. Capriccio의 Effects와 Parametric EQ는 전체
화면이고, 그 위에서도 아래쪽에 미니 플레이어와 탭바가 그대로 남는다. 그래서
EQ를 만지는 동안 소리가 계속 나고, 프리셋을 눌러가며 바로 견주고, 다음 곡으로
넘길 수 있다. 바텀시트로 덮으면 그 비교가 끊긴다.

미니 플레이어를 언제 띄울지는 `miniPlayerVisibleProvider`가 정한다. "플레이어
탭이 아닐 때"가 아니라 **"재생 화면 자체를 보고 있지 않을 때"**다. 플레이어
탭에 화면이 쌓였는지는 `NavigatorObserver`가 세어 `playerTabDepthProvider`에
넣는다. 라우트 전환은 빌드 도중에 일어나므로 그 값은 다음 프레임에 쓴다.

머리는 `ScreenHeader`가 그린다. 닫기(X)는 한 단계가 아니라 첫 화면까지
되돌린다. EQ에서 나올 때 음향 화면을 거치지 않고 바로 곡으로 가려는 것이다.

## EQ에서 조심할 것

`EqPoint`에는 두 종류가 있다.

- `bandwidthOct == 0`: **곡선 위의 점.** 점끼리 로그 주파수 축에서 이어 곡선을
  만든다. 내장 프리셋 19개가 전부 이 방식이다.
- `bandwidthOct > 0`: **종 모양 밴드.** 그 주파수를 가운데 둔 봉우리가 곡선
  위에 더해진다. 폭은 옥타브 단위고, 중심에서 폭의 절반만큼 떨어진 자리에서
  이득이 절반이 된다.

두 방식을 함께 두는 이유가 있다. 전부 종 모양으로 바꾸면 이미 귀로 맞춰둔
19개의 소리가 다 달라진다. EQ 편집에서 새로 만드는 점은 종 모양(1옥타브)으로
시작하고, 내장 프리셋의 점은 곡선으로 남는다.

엔진 밴드 수는 **32**다. 한 칸이 0.29옥타브라 대역폭을 0.5옥타브까지 좁혀도
종 모양이 살아 있다. 10밴드였을 때는 한 칸이 0.97옥타브라 좁은 밴드가 이웃
칸으로 번졌다. SoLoud의 상한은 64다.

STFT 창이 1024라 44.1kHz에서 주파수 해상도가 43Hz다. **100Hz 아래 밴드 몇
개는 같은 빈을 나눠 써서 서로 구분되지 않는다.** 저역을 더 잘게 다루려면
창을 2048로 키워야 하는데 지연이 두 배가 된다.

## 디자인

Figma Make로 뽑은 시안을 옮겼다. 토큰은 `lib/ui/theme.dart`에 있고 시안의
`src/tokens.ts` 값과 같다. 시안이 바뀌면 거기만 고치면 된다.

글래스모피즘은 **유리 뒤에 볼 것이 있어야** 성립한다. 배경이 평평한 검정이면
블러가 할 일이 없어서 회색 판으로 보인다. 그래서 재생 화면은 앨범아트를 크게
블러해 깔고, 라이브러리 화면은 미니 플레이어 뒤에 아트를 옅게 깐다.

밝은 앨범아트에서는 흰 글자가 안 읽힌다. `ArtworkTone`이 자켓 평균 밝기를
재서 덮개 농도와 유리 불투명도를 같이 올린다.

`GlassSurface`의 테두리는 표면 전체를 감싸고 그려야 한다. 자식 위젯을 감싸면
안쪽 여백만큼 작은 테두리가 하나 더 생겨서 알약 안에 알약이 든 것처럼 보인다.

한 화면에 유리는 **두 겹까지**. 넘으면 보급형 안드로이드에서 프레임이 떨어진다.

## Spotify

카탈로그와 검색은 Spotify에서 가져오고, 소리는 되도록 내 파일에서 낸다.
검색 결과에서 내가 가진 곡에는 `LOCAL` 표가 붙고, 그 곡에서만 배속·피치·
구간 반복이 열린다.

**Spotify로 트는 소리에는 우리 처리가 걸리지 않는다.** App Remote는 기기에
깔린 Spotify 앱을 원격 조종하는 방식이라 오디오가 우리 프로세스를 지나지
않는다. 배속, 피치, 3층 보정, 리미터가 전부 무관하다. 그래서 화면을 아예
`SpotifyPlayerView`로 갈라 두고 무엇이 꺼져 있는지 적어둔다. 구간 반복만
`seekTo`로 흉내 낼 수 있는데, 상태 이벤트가 일정한 간격으로 오지 않아서
몇백 밀리초 어긋난다.

Client Secret은 앱에 넣지 않는다. APK를 뜯으면 나온다. 토큰은 SDK가 받아온다.

### 설정에 필요한 것

1. [개발자 대시보드](https://developer.spotify.com/dashboard)에서 앱 생성
2. Redirect URI에 `pomento://auth`
3. Android 패키지명 `com.pomento.app`과 디버그·릴리스 키스토어 SHA-1 등록
4. iOS Bundle ID 등록
5. **앱 소유자 계정에 Premium.** 2026년 2월부터 Development Mode의 필수 조건이다

Client ID는 `--dart-define=SPOTIFY_CLIENT_ID=...`로 넣거나 설정 화면에서
붙여 넣는다. 기기에 저장한 값이 빌드에 박은 값보다 우선한다.

### Web API 제약

2026년 2월 Development Mode 개편 이후다.

- 앱당 사용자 5명, 개발자당 Client ID 25개(2026년 7월 완화)
- `/search`는 한 번에 최대 10개. 기본값은 5
- 배치 조회(`GET /tracks`, `/albums`, `/artists`)와 아티스트 top-tracks 제거.
  아티스트의 인기곡 목록은 `search?q=artist:...`로 대신한다
- 사용자 `product` 필드 제거. API로 상대의 Premium 여부를 알 수 없다
- Extended quota는 250k MAU 조직 요건이라 해당 없다

### App Remote 붙이는 법

Spotify는 이 라이브러리를 Maven에 올리지 않는다. `android/spotify-app-remote/`
에 GitHub 릴리스의 aar을 직접 넣고 `settings.gradle.kts`에서
`include(":spotify-app-remote")`로 끼운다. `dart run spotify_sdk:android_setup`
스크립트도 있지만 Groovy gradle 파일을 전제해서 이 프로젝트에서는 안 돈다.

## 개발

```bash
flutter pub get
dart run build_runner build          # drift 코드 생성
flutter analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

아이콘을 고쳤다면:

```bash
python tool/make_icon.py
python tool/install_icons.py
```

`flutter_launcher_icons`는 쓰지 않는다. 이 프로젝트의 다른 의존성과 물려서
0.9.3으로 내려앉는다.

`compileSdk`는 `android/build.gradle.kts`에서 하위 프로젝트까지 37로 맞춘다.
`permission_handler`가 37을 요구하는데 `audiotags`는 31에 묶여 있어서다.
이 블록은 `evaluationDependsOn`보다 **먼저** 와야 한다.

## 글쓰기

한국어 주석과 문서는 담백하게 쓴다. em dash를 쓰지 않고, 과장된 동사와
감정 라벨을 쓰지 않으며, 비유로 설명을 대체하지 않는다. 소제목은 그 단계에서
밝혀진 사실을 적는다.

## 아직 안 한 것

- Smart Lists(최다 재생·최근 재생), 라디오, 곡 식별, 가사, 비주얼라이저
- 클라우드(Box·Dropbox·OneDrive)와 네트워크(FTP·WebDAV) 파일
- iOS 빌드 검증. 맥이 없어서 Codemagic으로 돌릴 예정
- iOS용 `PcmDecoder` 대응 구현 (AVAudioFile 기반)
- iOS에서 Spotify SDK 확인. podspec의 `prepare_command`가 xcframework를
  받는데 `pod install`이 맥에서만 돈다
- Firestore 프리셋 동기화. 지금은 JSON 복사·붙여넣기
- 태그에서 ISRC 읽기. 지금은 Spotify 쪽에만 있어서 제목·아티스트로만 맞춘다
- 아주 긴 음원에서 `maxBufferSizeBytes` 상한이 누적으로 걸리는지 확인
