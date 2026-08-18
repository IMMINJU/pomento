import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_sdk/models/player_state.dart' as sdk;
import 'package:spotify_sdk/spotify_sdk.dart';

import 'spotify_config.dart';
import 'spotify_track.dart';

/// Spotify 앱에서 나오는 소리의 상태.
///
/// 우리 엔진을 지나지 않는다. 그래서 배속, 피치, 3층 보정이 이 소리에는
/// 걸리지 않는다. 화면에서도 그렇게 보여야 한다.
class SpotifyState {
  const SpotifyState({
    this.clientId = '',
    this.connected = false,
    this.connecting = false,
    this.token,
    this.error,
    this.trackName,
    this.artistName,
    this.trackUri,
    this.imageId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.paused = true,
    this.loopA,
    this.loopB,
  });

  final String clientId;
  final bool connected;
  final bool connecting;
  final String? token;
  final String? error;

  final String? trackName;
  final String? artistName;
  final String? trackUri;
  final String? imageId;
  final Duration position;
  final Duration duration;
  final bool paused;

  /// Spotify에서도 구간 반복은 된다. 끝점을 지나면 시작점으로 seek한다.
  /// 이벤트가 일정한 간격으로 오지 않아서 몇백 밀리초 어긋난다.
  final Duration? loopA;
  final Duration? loopB;

  bool get isConfigured => clientId.trim().isNotEmpty;
  bool get hasTrack => trackUri != null && trackUri!.isNotEmpty;

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  SpotifyState copyWith({
    String? clientId,
    bool? connected,
    bool? connecting,
    String? token,
    String? error,
    bool clearError = false,
    String? trackName,
    String? artistName,
    String? trackUri,
    String? imageId,
    Duration? position,
    Duration? duration,
    bool? paused,
    Duration? loopA,
    Duration? loopB,
    bool clearLoop = false,
  }) =>
      SpotifyState(
        clientId: clientId ?? this.clientId,
        connected: connected ?? this.connected,
        connecting: connecting ?? this.connecting,
        token: token ?? this.token,
        error: clearError ? null : (error ?? this.error),
        trackName: trackName ?? this.trackName,
        artistName: artistName ?? this.artistName,
        trackUri: trackUri ?? this.trackUri,
        imageId: imageId ?? this.imageId,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        paused: paused ?? this.paused,
        loopA: clearLoop ? null : (loopA ?? this.loopA),
        loopB: clearLoop ? null : (loopB ?? this.loopB),
      );
}

/// Spotify 검색과 재생을 맡는다.
///
/// 검색은 Web API로, 재생은 App Remote로 한다. App Remote는 기기에 깔린
/// Spotify 앱을 원격 조종하는 방식이라 우리 앱이 소리를 직접 만들지 않는다.
class SpotifySession extends StateNotifier<SpotifyState> {
  SpotifySession() : super(const SpotifyState()) {
    _loadClientId();
  }

  static const _kClientId = 'spotify.clientId';
  static const _search = 'https://api.spotify.com/v1/search';

  SharedPreferences? _prefs;
  StreamSubscription<sdk.PlayerState>? _playerSub;
  Timer? _ticker;

  Future<void> _loadClientId() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    if (!mounted) return;
    // 기기에 저장한 값이 빌드에 박아 넣은 값보다 우선한다.
    final saved = p.getString(_kClientId);
    state = state.copyWith(
      clientId: (saved != null && saved.trim().isNotEmpty)
          ? saved.trim()
          : SpotifyConfig.buildTimeClientId,
    );
  }

  void setClientId(String value) {
    final v = value.trim();
    state = state.copyWith(clientId: v, clearError: true);
    _prefs?.setString(_kClientId, v);
  }

  // ── 연결 ───────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (!state.isConfigured) {
      state = state.copyWith(error: 'Client ID를 먼저 넣으세요');
      return;
    }
    if (state.connecting) return;
    state = state.copyWith(connecting: true, clearError: true);

    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: state.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
        scope: SpotifyConfig.scope,
      );
      final ok = await SpotifySdk.connectToSpotifyRemote(
        clientId: state.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
        scope: SpotifyConfig.scope,
        accessToken: token,
      );
      if (!mounted) return;
      state = state.copyWith(
        connected: ok,
        connecting: false,
        token: token,
        clearError: true,
      );
      if (ok) _listen();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        connecting: false,
        connected: false,
        error: _readable(e),
      );
    }
  }

  Future<void> disconnect() async {
    _playerSub?.cancel();
    _playerSub = null;
    _stopTicker();
    try {
      await SpotifySdk.disconnect();
    } catch (_) {
      // 이미 끊겨 있으면 그만이다.
    }
    if (!mounted) return;
    state = const SpotifyState().copyWith(clientId: state.clientId);
  }

  void _listen() {
    _playerSub?.cancel();
    _playerSub = SpotifySdk.subscribePlayerState().listen(
      (s) {
        if (!mounted) return;
        final t = s.track;
        state = state.copyWith(
          trackName: t?.name ?? '',
          artistName: t?.artist.name ?? '',
          trackUri: t?.uri ?? '',
          imageId: t?.imageUri.raw,
          duration: Duration(milliseconds: t?.duration ?? 0),
          position: Duration(milliseconds: s.playbackPosition),
          paused: s.isPaused,
        );
        if (s.isPaused) {
          _stopTicker();
        } else {
          _startTicker();
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        state = state.copyWith(error: _readable(e));
      },
    );
    _startTicker();
  }

  /// 진행 위치를 스스로 굴린다.
  ///
  /// App Remote는 재생 위치가 바뀔 때마다 이벤트를 주지 않는다. 곡이
  /// 바뀌거나 일시정지될 때만 온다. 그사이는 우리가 시간을 더해 채운다.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || state.paused) return;
      var next = state.position + const Duration(milliseconds: 500);

      final a = state.loopA;
      final b = state.loopB;
      if (a != null && b != null && next >= b) {
        seek(a);
        return;
      }

      if (state.duration > Duration.zero && next > state.duration) {
        next = state.duration;
      }
      state = state.copyWith(position: next);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ── 재생 ───────────────────────────────────────────────────────────

  Future<void> play(String spotifyUri) async {
    try {
      if (!state.connected) await connect();
      if (!state.connected) return;
      await SpotifySdk.play(spotifyUri: spotifyUri);
      if (!mounted) return;
      state = state.copyWith(clearLoop: true, clearError: true);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: _readable(e));
    }
  }

  Future<void> togglePlay() async {
    try {
      if (state.paused) {
        await SpotifySdk.resume();
      } else {
        await SpotifySdk.pause();
      }
    } catch (e) {
      if (mounted) state = state.copyWith(error: _readable(e));
    }
  }

  Future<void> next() => _guard(SpotifySdk.skipNext);
  Future<void> previous() => _guard(SpotifySdk.skipPrevious);

  Future<void> seek(Duration at) async {
    // 낙관적으로 먼저 반영한다. 이벤트를 기다리면 막대가 늦게 움직인다.
    if (mounted) state = state.copyWith(position: at);
    await _guard(
      () => SpotifySdk.seekTo(positionedMilliseconds: at.inMilliseconds),
    );
  }

  Future<void> seekBy(Duration delta) => seek(state.position + delta);

  void setLoopA([Duration? at]) {
    final a = at ?? state.position;
    final b = state.loopB;
    if (b != null && a >= b) {
      state = state.copyWith(clearLoop: true).copyWith(loopA: a);
    } else {
      state = state.copyWith(loopA: a);
    }
  }

  void setLoopB([Duration? at]) {
    final b = at ?? state.position;
    final a = state.loopA;
    if (a == null) {
      state = state.copyWith(loopA: Duration.zero, loopB: b);
    } else if (b > a) {
      state = state.copyWith(loopB: b);
    }
  }

  void clearLoop() => state = state.copyWith(clearLoop: true);

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (mounted) state = state.copyWith(error: _readable(e));
    }
  }

  // ── 검색 ───────────────────────────────────────────────────────────

  /// 트랙을 찾는다.
  ///
  /// 2026년 2월부터 Development Mode 앱의 `/search`는 한 번에 최대 10개까지만
  /// 준다. 더 보려면 [offset]으로 넘긴다.
  Future<List<SpotifyTrack>> searchTracks(
    String query, {
    int offset = 0,
  }) async {
    if (query.trim().isEmpty) return const [];
    var token = state.token;
    if (token == null) {
      await connect();
      token = state.token;
      if (token == null) return const [];
    }

    Future<http.Response> call(String t) => http.get(
          Uri.parse(_search).replace(queryParameters: {
            'q': query.trim(),
            'type': 'track',
            'limit': '10',
            'offset': '$offset',
          }),
          headers: {'Authorization': 'Bearer $t'},
        );

    var res = await call(token);
    if (res.statusCode == 401) {
      // 토큰이 만료됐다. 한 번만 다시 받아 본다.
      await connect();
      final fresh = state.token;
      if (fresh == null) return const [];
      res = await call(fresh);
    }

    if (res.statusCode != 200) {
      if (mounted) {
        state = state.copyWith(
          error: '검색에 실패했습니다 (${res.statusCode})',
        );
      }
      return const [];
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = ((body['tracks'] as Map?)?['items'] as List?) ?? const [];
    return items
        .map((e) => SpotifyTrack.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('CouldNotFindSpotifyApp') || s.contains('NotInstalled')) {
      return '기기에 Spotify 앱이 없습니다';
    }
    if (s.contains('UserNotAuthorizedException') || s.contains('AUTHENTICATION')) {
      return 'Spotify 로그인이 필요합니다';
    }
    if (s.contains('NotLoggedIn')) return 'Spotify 앱에 로그인하세요';
    if (kDebugMode) return s;
    return 'Spotify에 연결하지 못했습니다';
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _stopTicker();
    super.dispose();
  }
}
