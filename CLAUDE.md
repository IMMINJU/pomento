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
    player_controller.dart 큐, 반복, 셔플, 곡별 배속 기억
    effect_controller.dart 3층 합산, 기기 자동 감지, 선택 저장
    audio_handler.dart     잠금화면·알림 컨트롤(audio_service)
  data/
    db/database.dart       drift 스키마
    models/                eq_curve, preset, tempo
    repo/                  library, preset
    storage/media_importer.dart  가져오기와 태그 스냅샷
    platform/native_media.dart   MediaStore 스캔, 출력 기기 감지
  presets/builtin_presets.dart   기본 프리셋 19개
  ui/                      화면과 위젯. theme.dart에 디자인 토큰
android/app/src/main/kotlin/com/pomento/app/
  MainActivity.kt          MethodChannel 3종
  PcmDecoder.kt            MediaCodec 기반 PCM 디코더
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

- iOS 빌드 검증. 맥이 없어서 Codemagic으로 돌릴 예정
- iOS용 `PcmDecoder` 대응 구현 (AVAudioFile 기반)
- Firestore 프리셋 동기화. 지금은 JSON 복사·붙여넣기
- EQ 그래프에서 직접 밴드 조절 (지금은 보여주기만)
- 아주 긴 음원에서 `maxBufferSizeBytes` 상한이 누적으로 걸리는지 확인
