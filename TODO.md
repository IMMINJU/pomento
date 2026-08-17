# MVP 구현 목록

디자인은 나중에 붙인다. 지금은 기능만.

## A. 골격
- [x] flutter create (com.minju.player)
- [ ] 의존성 추가
- [ ] 폴더 구조 / 앱 진입점 / Riverpod 루트

## B. 데이터
- [ ] Drift 스키마: tracks, playlists, playlist_tracks, presets, track_settings, device_profiles
- [ ] DAO / Repository
- [ ] 앱 저장소 경로 관리 (음원, 아트워크)

## C. 라이브러리
- [ ] 권한 (READ_MEDIA_AUDIO, API 33+)
- [ ] Kotlin MethodChannel: MediaStore 음원 목록 조회
- [ ] 파일 가져오기 (file_picker) → 앱 저장소 복사
- [ ] 태그/아트워크 스냅샷 (audiotags) → DB + artwork/{id}.jpg
- [ ] managed(복사) / linked(참조) 두 방식 지원
- [ ] 자켓 우선순위: 사용자 지정 > 태그 추출 > 폴더 cover.jpg > 자동 생성
- [ ] 사용자 자켓 지정

## D. 오디오 엔진
- [ ] SoLoud 초기화 / 해제
- [ ] 재생, 일시정지, 탐색, 이전, 다음, 큐
- [ ] 반복(없음/전체/한곡), 셔플
- [ ] 배속: 연동(varispeed) / 고정(time-stretch) 두 모드
- [ ] 피치: 센트 단위 미세 조정
- [ ] 값 변경 시 보간(클릭 잡음 방지)
- [ ] 진행률/남은시간 배속 반영
- [ ] audio_service 백그라운드 + 알림 컨트롤
- [ ] A-B 구간 반복

## E. 이펙트
- [ ] 3층 EQ 모델 (device / environment / taste) 합산
- [ ] SoLoud EqualizerSingle 연결
- [ ] 리버브, 에코, 크로스피드
- [ ] Kotlin MethodChannel: 출력 기기 감지 → device 레이어 자동 전환
- [ ] 기본 프리셋 데이터 (기기 7 / 환경 6 / 취향 6)

## F. 프리셋
- [ ] 프리셋 CRUD
- [ ] 곡별 배속/피치 기억
- [ ] JSON export / import (동기화 자리, Firestore는 나중)

## G. 임시 UI
- [ ] 라이브러리 화면
- [ ] 재생 화면
- [ ] 배속/피치 다이얼 (기능만)
- [ ] 이펙트 시트
- [ ] 프리셋 목록
- [ ] 제스처

## H. 빌드
- [ ] release APK
- [ ] 무선 디버깅으로 폰에 설치

## 나중에
- [ ] 디자인 적용 (Figma Make 결과 나오면)
- [ ] Firestore 프리셋 동기화
- [ ] iOS 빌드 검증 (맥 필요)
