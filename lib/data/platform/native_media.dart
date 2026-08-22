import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/track_source.dart';

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

  /// 이 곡을 가리키는 주소.
  ///
  /// 안드로이드는 content:// URI라 경로가 없을 때 이걸로 복사해온다. iOS는
  /// `ipod://<persistentID>`라 복사하지 않고 이 값을 그대로 트랙의 주소로
  /// 삼는다.
  final String uri;

  /// 직접 읽을 수 있는 절대 경로. 없으면 null이고 복사가 필요하다.
  final String? path;

  /// 음악 앱 보관함의 곡인가. 참이면 파일이 아니라 참조로 들어간다.
  bool get isLibraryItem => isLibraryPath(uri);

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

/// 음악 앱 보관함의 곡 하나에서 읽어온 태그와 자켓.
///
/// 값의 출처가 둘이다. 파일에 박힌 태그를 먼저 보고, 못 읽으면 음악 앱
/// DB로 떨어진다. 보관함 동기화가 음악 앱 DB의 자켓과 곡 정보를 애플
/// 카탈로그 것으로 바꿔놓았을 수 있어서 이 순서를 지킨다. 어느 쪽을 썼는지
/// [tagSource]와 [artworkSource]에 담겨 온다.
class LibraryTags {
  const LibraryTags({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.durationMs,
    required this.tagSource,
    required this.artworkSource,
    this.year,
    this.trackNo,
    this.artwork,
  });

  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final int durationMs;
  final int? year;
  final int? trackNo;

  /// 자켓 원본 바이트. 없으면 null.
  final Uint8List? artwork;

  /// 'file'이면 파일 태그에서, 'library'면 음악 앱 DB에서 읽었다.
  final String tagSource;

  /// 'file', 'library', 'none' 중 하나.
  final String artworkSource;

  /// 태그를 파일에서 읽었나. 카탈로그 값이 섞이지 않았다는 뜻이다.
  bool get tagsFromFile => tagSource == 'file';

  /// 자켓을 파일에서 읽었나.
  bool get artworkFromFile => artworkSource == 'file';

  factory LibraryTags.fromMap(Map<dynamic, dynamic> m) => LibraryTags(
        title: m['title'] as String? ?? '',
        artist: m['artist'] as String? ?? '',
        album: m['album'] as String? ?? '',
        albumArtist: m['albumArtist'] as String? ?? '',
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        year: (m['year'] as num?)?.toInt(),
        trackNo: (m['trackNo'] as num?)?.toInt(),
        artwork: m['artwork'] as Uint8List?,
        tagSource: m['tagSource'] as String? ?? 'library',
        artworkSource: m['artworkSource'] as String? ?? 'none',
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

/// 기기의 음원 목록과 오디오 라우팅에 접근하는 채널.
///
/// 안드로이드는 MediaStore를, iOS는 음악 앱 보관함(MPMediaLibrary)을 훑는다.
/// 둘 다 읽기만 한다. iOS는 앱 Documents 폴더의 파일도 그대로 다룬다.
class NativeMedia {
  NativeMedia._();

  static final NativeMedia instance = NativeMedia._();

  static const MethodChannel _method =
      MethodChannel('com.pomento.app/media');
  static const EventChannel _events =
      EventChannel('com.pomento.app/output_device');

  Stream<OutputDevice>? _deviceStream;

  /// 기기에 있는 음원 목록.
  ///
  /// 안드로이드는 MediaStore, iOS는 음악 앱 보관함에서 온다. iOS에서는 읽을
  /// 수 없는 항목(애플뮤직 카탈로그에서 받은 곡)이 목록에서 빠진다.
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

  /// 보관함 곡 하나의 태그와 자켓. iOS 전용이고 그 외에서는 null이다.
  ///
  /// 곡마다 파일을 여는 일이라 목록 조회와 갈라두었다. 가져오기로 고른
  /// 곡에만 부른다.
  Future<LibraryTags?> libraryMetadata(String uri) async {
    try {
      final res = await _method.invokeMethod<Map<dynamic, dynamic>>(
        'libraryMetadata',
        {'uri': uri},
      );
      if (res == null) return null;
      return LibraryTags.fromMap(res);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
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
