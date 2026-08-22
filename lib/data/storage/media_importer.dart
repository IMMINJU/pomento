import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../db/database.dart';
import '../platform/native_media.dart';

/// 가져오기 한 건의 결과.
class ImportResult {
  const ImportResult({required this.added, required this.skipped, this.errors = 0});

  final int added;
  final int skipped;
  final int errors;

  String get summary {
    final parts = <String>['$added곡 추가'];
    if (skipped > 0) parts.add('$skipped곡은 이미 있음');
    if (errors > 0) parts.add('$errors곡 실패');
    return parts.join(' · ');
  }
}

/// 기기 항목 한 건을 넣은 결과.
class NativeImportOutcome {
  const NativeImportOutcome({required this.added, this.tagSource});

  static const NativeImportOutcome skipped = NativeImportOutcome(added: false);

  final bool added;

  /// 음악 앱 보관함의 곡일 때만 채워진다. 'file'이면 곡 정보를 파일 태그에서,
  /// 'library'면 음악 앱 DB에서 읽었다는 뜻이다.
  final String? tagSource;
}

/// 음원을 라이브러리에 들여오는 일을 맡는다.
///
/// 원칙이 하나 있다. 원본 파일에는 절대 쓰지 않는다. 태그와 자켓은 가져오는
/// 순간 읽어서 앱 DB와 앱 폴더에 복사해두고, 이후로는 그 사본만 본다. 다른
/// 앱이 원본 파일의 태그나 자켓을 바꿔도 우리가 보여주는 값은 그대로다.
class MediaImporter {
  MediaImporter(this.db);

  final AppDatabase db;

  static const Set<String> supportedExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.oga',
    '.opus',
    '.m4a',
    '.aac',
  };

  static bool isSupported(String path) =>
      supportedExtensions.contains(p.extension(path).toLowerCase());

  /// 아티스트·앨범·제목을 정규화한 키.
  ///
  /// 두 사람이 같은 곡에 붙인 설정을 맞출 때 쓴다. 파일이 서로 달라도 같은
  /// 곡이면 같은 키가 나오게 한다.
  static String contentKeyFor(String artist, String album, String title) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-\.]+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '');
    return '${norm(artist)}|${norm(album)}|${norm(title)}';
  }

  static String _stableKey(String input) =>
      sha1.convert(utf8.encode(input)).toString().substring(0, 16);

  /// 파일 하나를 라이브러리에 넣는다.
  ///
  /// [copyIntoApp]이 참이면 앱 저장소로 복사한다. iOS는 항상 참이어야 하고,
  /// 안드로이드는 원본 경로를 읽을 수 있으면 거짓으로 두어 용량을 아낀다.
  Future<bool> importFile(
    String sourcePath, {
    required bool copyIntoApp,
    String? fallbackTitle,
    String? fallbackArtist,
    String? fallbackAlbum,
    int? fallbackDurationMs,
  }) async {
    try {
      final src = File(sourcePath);
      if (!src.existsSync()) return false;

      var playPath = sourcePath;
      if (copyIntoApp) {
        final destName =
            '${_stableKey(sourcePath)}${p.extension(sourcePath).toLowerCase()}';
        final dest = File(p.join(AppPaths.instance.media.path, destName));
        if (!dest.existsSync()) {
          await src.copy(dest.path);
        }
        playPath = dest.path;
      }

      final existing = await (db.select(db.tracks)
            ..where((t) => t.filePath.equals(playPath)))
          .getSingleOrNull();
      if (existing != null) return false;

      final snap = await _snapshot(
        readFrom: sourcePath,
        playPath: playPath,
        fallbackTitle: fallbackTitle,
        fallbackArtist: fallbackArtist,
        fallbackAlbum: fallbackAlbum,
        fallbackDurationMs: fallbackDurationMs,
        managed: copyIntoApp,
      );

      await db.into(db.tracks).insert(snap, mode: InsertMode.insertOrIgnore);
      return true;
    } catch (e) {
      debugPrint('가져오기 실패 [$sourcePath]: $e');
      return false;
    }
  }

  /// 앱 폴더에 들어온 음원을 훑어서 라이브러리에 넣는다.
  ///
  /// iOS에서는 파일 앱으로 앱 폴더에 직접 옮겨 넣는 것이 유일한 반입 경로다.
  /// 넣은 파일이 보이려면 앱이 폴더를 다시 훑어야 한다. 안드로이드에서도
  /// 앱이 복사해둔 파일을 다시 찾을 때 쓴다.
  Future<ImportResult> scanAppFolder() async {
    final root = AppPaths.instance.root;
    if (!root.existsSync()) {
      return const ImportResult(added: 0, skipped: 0);
    }

    final existing = (await db.select(db.tracks).get())
        .map((t) => t.filePath)
        .toSet();
    final artworkDir = AppPaths.instance.artwork.path;
    final userArtworkDir = AppPaths.instance.userArtwork.path;

    var added = 0;
    var skipped = 0;
    var errors = 0;

    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!isSupported(path)) continue;
        // 우리가 만든 자켓 폴더는 건너뛴다.
        if (path.startsWith(artworkDir) || path.startsWith(userArtworkDir)) {
          continue;
        }
        if (existing.contains(path)) {
          skipped++;
          continue;
        }
        // 이미 앱 안에 있는 파일이라 복사하지 않는다.
        if (await importFile(path, copyIntoApp: false)) {
          added++;
        } else {
          errors++;
        }
      }
    } catch (e) {
      debugPrint('앱 폴더 훑기 실패: $e');
    }

    return ImportResult(added: added, skipped: skipped, errors: errors);
  }

  /// 기기 미디어 저장소에서 찾은 항목을 넣는다.
  Future<NativeImportOutcome> importNativeItem(NativeAudioItem item) async {
    if (item.isLibraryItem) return _importLibraryItem(item);

    final path = item.path;
    if (path != null && File(path).existsSync()) {
      // 원본을 읽을 수 있으면 복사하지 않고 참조만 한다.
      final ok = await importFile(
        path,
        copyIntoApp: false,
        fallbackTitle: item.title,
        fallbackArtist: item.artist,
        fallbackAlbum: item.album,
        fallbackDurationMs: item.durationMs,
      );
      return NativeImportOutcome(added: ok);
    }

    // 경로를 못 읽으면 content URI에서 앱 저장소로 복사한다.
    final destName = '${_stableKey(item.uri)}.audio';
    final dest = p.join(AppPaths.instance.media.path, destName);
    if (!File(dest).existsSync()) {
      final copied = await NativeMedia.instance.copyUriToFile(item.uri, dest);
      if (!copied) return NativeImportOutcome.skipped;
    }
    final ok = await importFile(
      dest,
      copyIntoApp: false,
      fallbackTitle: item.title,
      fallbackArtist: item.artist,
      fallbackAlbum: item.album,
      fallbackDurationMs: item.durationMs,
    );
    return NativeImportOutcome(added: ok);
  }

  /// 음악 앱 보관함(iOS)의 곡을 참조로 들여온다.
  ///
  /// 파일을 복사하지 않는다. 보관함 하나를 통째로 가져오면 몇 기가가 되고,
  /// 뽑아내는 과정에서 mp3가 AAC로 다시 인코딩된다. 재생할 때마다 보관함에서
  /// 열어 PCM을 받는 쪽이 원본 그대로다.
  ///
  /// 태그와 자켓은 지금 한 번 읽어 앱 DB와 앱 폴더에 복사해둔다. 이후 음악
  /// 앱 쪽 값이 바뀌어도 우리가 보여주는 값은 그대로다. 파일에서 가져올
  /// 때와 같은 원칙이다.
  Future<NativeImportOutcome> _importLibraryItem(NativeAudioItem item) async {
    final existing = await (db.select(db.tracks)
          ..where((t) => t.filePath.equals(item.uri)))
        .getSingleOrNull();
    if (existing != null) return NativeImportOutcome.skipped;

    final tags = await NativeMedia.instance.libraryMetadata(item.uri);

    // 목록에서 받은 값은 음악 앱 DB에서 온 것이라 뒤로 둔다.
    final title = _firstNonEmpty([tags?.title, item.title, '제목 없음']);
    final artist = _firstNonEmpty([
      tags?.artist,
      item.artist,
      '알 수 없는 아티스트',
    ]);
    final album = _firstNonEmpty([tags?.album, item.album, '']);
    final albumArtist = _firstNonEmpty([tags?.albumArtist, artist]);

    final tagged = tags?.durationMs ?? 0;
    final durationMs = tagged > 0 ? tagged : item.durationMs;

    final artworkPath = await _saveLibraryArtwork(item.uri, tags?.artwork);

    await db.into(db.tracks).insert(
          TracksCompanion.insert(
            filePath: item.uri,
            title: title,
            // 앱이 들고 있는 파일이 아니다. 트랙을 지워도 지울 파일이 없다.
            managed: const Value(false),
            artist: Value(artist),
            album: Value(album),
            albumArtist: Value(albumArtist),
            year: Value(tags?.year),
            trackNo: Value(tags?.trackNo),
            durationMs: Value(durationMs),
            sizeBytes: Value(item.sizeBytes),
            artworkPath: Value(artworkPath),
            contentKey: Value(contentKeyFor(artist, album, title)),
            importedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return NativeImportOutcome(added: true, tagSource: tags?.tagSource);
  }

  /// 보관함에서 받은 자켓을 앱 폴더에 둔다. 온라인 조회는 하지 않는다.
  Future<String?> _saveLibraryArtwork(String uri, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final dest = AppPaths.instance.artworkFileFor(_stableKey(uri));
    try {
      await File(dest).writeAsBytes(bytes, flush: true);
      return dest;
    } catch (e) {
      debugPrint('자켓 저장 실패 [$uri]: $e');
      return null;
    }
  }

  /// 태그와 자켓을 읽어 DB에 넣을 형태로 만든다.
  Future<TracksCompanion> _snapshot({
    required String readFrom,
    required String playPath,
    required bool managed,
    String? fallbackTitle,
    String? fallbackArtist,
    String? fallbackAlbum,
    int? fallbackDurationMs,
  }) async {
    // 파일을 직접 파싱한다. 통째로 읽고 파는 일이라 격리에서 돌린다.
    // 가져오기는 한 번에 수백 곡을 훑을 수 있어서, 본 격리에서 하면
    // 그동안 화면이 멈춘다.
    AudioMetadata? tag;
    try {
      tag = await Isolate.run(
        () => readMetadata(File(readFrom), getImage: true),
      );
    } catch (e) {
      debugPrint('태그 읽기 실패 [$readFrom]: $e');
    }

    final title = _firstNonEmpty([
      tag?.title,
      fallbackTitle,
      p.basenameWithoutExtension(readFrom),
    ]);
    final artist = _firstNonEmpty([
      tag?.artist,
      fallbackArtist,
      '알 수 없는 아티스트',
    ]);
    final album = _firstNonEmpty([tag?.album, fallbackAlbum, '']);

    // 이 파서에는 앨범 아티스트가 따로 없다. 전에도 없으면 아티스트로
    // 떨어뜨렸으므로 결과가 같은 자리가 대부분이다.
    final albumArtist = artist;

    final tagged = tag?.duration?.inMilliseconds ?? 0;
    final durationMs = tagged > 0 ? tagged : (fallbackDurationMs ?? 0);

    final artworkPath = await _extractArtwork(tag, playPath, readFrom);

    var size = 0;
    try {
      size = File(playPath).lengthSync();
    } catch (_) {}

    return TracksCompanion.insert(
      filePath: playPath,
      title: title,
      managed: Value(managed),
      artist: Value(artist),
      album: Value(album),
      albumArtist: Value(albumArtist),
      year: Value(tag?.year?.year),
      trackNo: Value(tag?.trackNumber),
      durationMs: Value(durationMs),
      sizeBytes: Value(size),
      artworkPath: Value(artworkPath),
      contentKey: Value(contentKeyFor(artist, album, title)),
      importedAt: DateTime.now(),
    );
  }

  /// 자켓 확보 순서: 파일에 박힌 그림 → 같은 폴더의 표지 파일.
  ///
  /// 온라인 조회는 하지 않는다. 자동으로 자켓을 바꾸는 동작이 이 앱에서
  /// 피하려는 바로 그 문제다.
  Future<String?> _extractArtwork(
    AudioMetadata? tag,
    String playPath,
    String readFrom,
  ) async {
    final key = _stableKey(playPath);
    final dest = AppPaths.instance.artworkFileFor(key);

    if (File(dest).existsSync()) return dest;

    final pics = tag?.pictures ?? const [];
    if (pics.isNotEmpty) {
      try {
        final bytes = pics.first.bytes;
        if (bytes.isNotEmpty) {
          await File(dest).writeAsBytes(bytes, flush: true);
          return dest;
        }
      } catch (e) {
        debugPrint('자켓 저장 실패: $e');
      }
    }

    // 폴더에 놓인 표지 파일을 찾아본다.
    try {
      final dir = Directory(p.dirname(readFrom));
      if (dir.existsSync()) {
        const names = ['cover', 'folder', 'front', 'albumart'];
        const exts = ['.jpg', '.jpeg', '.png'];
        for (final n in names) {
          for (final e in exts) {
            final f = File(p.join(dir.path, '$n$e'));
            if (f.existsSync()) {
              await f.copy(dest);
              return dest;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('폴더 표지 탐색 실패: $e');
    }

    return null;
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c.trim();
    }
    return '';
  }

  /// 사용자가 고른 이미지를 이 곡의 자켓으로 지정한다.
  ///
  /// 이 값은 어떤 자동 동작으로도 덮어쓰지 않는다.
  Future<void> setUserArtwork(int trackId, String imagePath) async {
    final dest = AppPaths.instance.userArtworkFileFor('t$trackId');
    await File(imagePath).copy(dest);
    await (db.update(db.tracks)..where((t) => t.id.equals(trackId)))
        .write(TracksCompanion(userArtworkPath: Value(dest)));
  }

  /// 사용자가 지정한 자켓을 지우고 원래 자켓으로 되돌린다.
  Future<void> clearUserArtwork(int trackId) async {
    final row = await (db.select(db.tracks)..where((t) => t.id.equals(trackId)))
        .getSingleOrNull();
    final path = row?.userArtworkPath;
    if (path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await (db.update(db.tracks)..where((t) => t.id.equals(trackId)))
        .write(const TracksCompanion(userArtworkPath: Value(null)));
  }
}
