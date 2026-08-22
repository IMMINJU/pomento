
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/track_source.dart';

/// 열려 있는 플랫폼 디코더 하나.
class DecoderHandle {
  const DecoderHandle({
    required this.id,
    required this.sampleRate,
    required this.channels,
    required this.duration,
  });

  final int id;
  final int sampleRate;
  final int channels;
  final Duration duration;
}

class DecoderChunk {
  const DecoderChunk(this.data, this.finished);

  final Uint8List data;
  final bool finished;
}

/// 플랫폼이 가진 코덱으로 음원을 16비트 PCM으로 푸는 통로.
///
/// 재생 엔진이 내장한 디코더는 mp3, wav, ogg, flac뿐이다. 사람들이 실제로
/// 가진 음원 중 상당수가 m4a(AAC)라 그것만으로는 라이브러리가 안 열린다.
/// 안드로이드는 MediaCodec, iOS는 AVFoundation이 AAC를 기본으로 지원하므로
/// 디코딩만 플랫폼에 맡기고, EQ와 배속 같은 처리는 엔진 쪽에 그대로 둔다.
class PlatformDecoder {
  PlatformDecoder._();

  static final PlatformDecoder instance = PlatformDecoder._();

  static const MethodChannel _channel =
      MethodChannel('com.pomento.app/decoder');

  /// 엔진이 직접 읽을 수 있는 확장자. 이건 굳이 플랫폼을 거치지 않는다.
  static const Set<String> engineNativeExtensions = {
    '.mp3',
    '.wav',
    '.flac',
    '.ogg',
    '.oga',
  };

  /// 음악 앱 보관함의 곡은 확장자와 무관하게 항상 이 통로로 간다. 엔진은
  /// 파일만 열 수 있고 보관함 항목은 파일이 아니다.
  static bool needsPlatformDecoder(String path) =>
      isLibraryPath(path) ||
      !engineNativeExtensions.contains(p.extension(path).toLowerCase());

  /// 열지 못하면 null. 호출한 쪽에서 엔진 기본 경로로 넘긴다.
  Future<DecoderHandle?> open(String path) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'open',
        {'path': path},
      );
      if (res == null) return null;
      return DecoderHandle(
        id: (res['id'] as num).toInt(),
        sampleRate: (res['sampleRate'] as num).toInt(),
        channels: (res['channels'] as num).toInt(),
        duration: Duration(microseconds: (res['durationUs'] as num).toInt()),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<DecoderChunk> read(int id, {int maxBytes = 128 * 1024}) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'read',
        {'id': id, 'maxBytes': maxBytes},
      );
      if (res == null) return DecoderChunk(Uint8List(0), true);
      final data = res['data'];
      return DecoderChunk(
        data is Uint8List ? data : Uint8List(0),
        res['finished'] as bool? ?? true,
      );
    } on PlatformException {
      return DecoderChunk(Uint8List(0), true);
    }
  }

  /// 실제로 이동한 위치를 돌려준다. 컨테이너에 따라 요청한 지점과 조금 다를 수
  /// 있어서 그 값을 그대로 위치 계산의 기준으로 쓴다.
  Future<Duration> seek(int id, Duration to) async {
    try {
      final us = await _channel.invokeMethod<int>(
        'seek',
        {'id': id, 'us': to.inMicroseconds},
      );
      return Duration(microseconds: us ?? 0);
    } on PlatformException {
      return Duration.zero;
    }
  }

  Future<void> close(int id) async {
    try {
      await _channel.invokeMethod<bool>('close', {'id': id});
    } on PlatformException {
      // 이미 닫혔으면 신경 쓸 것 없다.
    }
  }
}
