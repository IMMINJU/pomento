import 'dart:async';

import 'package:flutter/services.dart';

/// 기기 미디어 저장소에서 찾은 음원 한 건.
class NativeAudioItem {
  const NativeAudioItem({
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    this.path,
  });

  /// content:// URI. 경로가 없을 때 이걸로 복사해온다.
  final String uri;

  /// 직접 읽을 수 있는 절대 경로. 없으면 null이고 복사가 필요하다.
  final String? path;

  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;

  factory NativeAudioItem.fromMap(Map<dynamic, dynamic> m) => NativeAudioItem(
        uri: m['uri'] as String? ?? '',
        path: m['path'] as String?,
        title: m['title'] as String? ?? '',
        artist: m['artist'] as String? ?? '',
        album: m['album'] as String? ?? '',
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

/// 지금 소리가 나가고 있는 출력 기기.
class OutputDevice {
  const OutputDevice({required this.type, required this.productName});

  static const OutputDevice unknown =
      OutputDevice(type: 'unknown', productName: '');

  /// speaker, wired, bluetooth, usb, overear, car 중 하나로 정규화된 값.
  final String type;

  /// 기기가 알려주는 이름. 예: "Galaxy Buds3 Pro".
  final String productName;

  /// 프리셋 매칭에 쓰는 설명 문자열. 종류와 이름을 모두 담는다.
  String get descriptor => '$type $productName'.toLowerCase();

  String get label => productName.isEmpty ? _typeLabel : productName;

  String get _typeLabel => switch (type) {
        'speaker' => '폰 스피커',
        'wired' => '유선 이어폰',
        'bluetooth' => '블루투스',
        'usb' => 'USB 오디오',
        'overear' => '헤드폰',
        'car' => '차량',
        _ => '알 수 없음',
      };

  factory OutputDevice.fromMap(Map<dynamic, dynamic> m) => OutputDevice(
        type: m['type'] as String? ?? 'unknown',
        productName: m['productName'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is OutputDevice &&
      other.type == type &&
      other.productName == productName;

  @override
  int get hashCode => Object.hash(type, productName);
}

/// 안드로이드 MediaStore와 오디오 라우팅에 접근하는 채널.
///
/// iOS에는 대응하는 구현이 없다. iOS는 앱 Documents 폴더의 파일만 다루고,
/// 애플뮤직 보관함(MPMediaLibrary)에는 접근하지 않는다. Info.plist에
/// NSAppleMusicUsageDescription을 넣지 않았으므로 접근 자체가 막혀 있다.
class NativeMedia {
  NativeMedia._();

  static final NativeMedia instance = NativeMedia._();

  static const MethodChannel _method =
      MethodChannel('com.pomento.app/media');
  static const EventChannel _events =
      EventChannel('com.pomento.app/output_device');

  Stream<OutputDevice>? _deviceStream;

  /// 기기에 있는 음원 목록. 안드로이드 전용이고 그 외에서는 빈 목록이다.
  Future<List<NativeAudioItem>> scanDeviceAudio() async {
    try {
      final res = await _method.invokeMethod<List<dynamic>>('scanAudio');
      if (res == null) return const [];
      return res
          .map((e) => NativeAudioItem.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// content:// URI의 내용을 [destPath]로 복사한다.
  Future<bool> copyUriToFile(String uri, String destPath) async {
    try {
      final ok = await _method.invokeMethod<bool>('copyUri', {
        'uri': uri,
        'dest': destPath,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<OutputDevice> currentOutputDevice() async {
    try {
      final res =
          await _method.invokeMethod<Map<dynamic, dynamic>>('currentOutput');
      if (res == null) return OutputDevice.unknown;
      return OutputDevice.fromMap(res);
    } on MissingPluginException {
      return OutputDevice.unknown;
    } on PlatformException {
      return OutputDevice.unknown;
    }
  }

  /// 이어폰을 꽂거나 빼면 새 값이 흘러나온다.
  Stream<OutputDevice> get outputDeviceChanges {
    return _deviceStream ??= _events
        .receiveBroadcastStream()
        .map((e) => OutputDevice.fromMap(e as Map<dynamic, dynamic>))
        .handleError((Object _) {})
        .asBroadcastStream();
  }
}
