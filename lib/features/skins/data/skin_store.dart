import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/skins/domain/skin.dart';

/// Installed skins and which one is active.
abstract class SkinStore {
  Future<void> init() async {}
  List<Skin> load();
  void install(Skin skin);
  void remove(String id);
  String? loadActive();
  void saveActive(String? id);
}

class MemorySkinStore implements SkinStore {
  MemorySkinStore([List<Skin> skins = const [], this.active]) {
    for (final skin in skins) {
      _skins[skin.id] = skin;
    }
  }

  final _skins = <String, Skin>{};
  String? active;

  @override
  Future<void> init() async {}

  @override
  List<Skin> load() => _skins.values.toList();

  @override
  void install(Skin skin) => _skins[skin.id] = skin;

  @override
  void remove(String id) => _skins.remove(id);

  @override
  String? loadActive() => active;

  @override
  void saveActive(String? id) => active = id;
}

/// One `<id>.studioskin` file per skin, plus `active.json`.
class FileSkinStore implements SkinStore {
  FileSkinStore(this.directory);

  final Directory directory;

  File _file(String id) =>
      File(p.join(directory.path, '$id.${Skin.fileExtension}'));

  File get _active => File(p.join(directory.path, 'active.json'));
  List<Skin>? _cachedSkins;
  String? _cachedActive;
  bool _isInitialized = false;

  /// Asynchronously loads skin definitions and active skin status from disk into memory.
  /// Pre-warming this cache during application startup prevents the UI isolate
  /// from being blocked by synchronous file reads during the first Riverpod access.
  @override
  Future<void> init() async {
    if (_isInitialized) return;
    final skins = <Skin>[];
    if (await directory.exists()) {
      await for (final file in directory.list()) {
        if (file is! File || p.extension(file.path) != '.${Skin.fileExtension}')
          continue;
        try {
          skins.add(Skin.parse(await file.readAsString()));
        } on Object catch (error) {
          debugPrint('Skipping unreadable skin ${file.path}: $error');
        }
      }
    }
    skins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cachedSkins = skins;

    try {
      final json = jsonDecode(await _active.readAsString());
      _cachedActive = json is Map && json['id'] is String
          ? json['id'] as String
          : null;
    } on Object {
      _cachedActive = null;
    }
    _isInitialized = true;
  }

  @override
  List<Skin> load() {
    if (_isInitialized && _cachedSkins != null) return _cachedSkins!;
    if (!directory.existsSync()) return const [];
    final skins = <Skin>[];
    for (final file in directory.listSync().whereType<File>()) {
      if (p.extension(file.path) != '.${Skin.fileExtension}') continue;
      try {
        skins.add(Skin.parse(file.readAsStringSync()));
      } on Object catch (error) {
        debugPrint('Skipping unreadable skin ${file.path}: $error');
      }
    }
    skins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _cachedSkins = skins;
  }

  @override
  void install(Skin skin) {
    _write(_file(skin.id), skin.encode());
    if (_cachedSkins != null) {
      _cachedSkins!.removeWhere((s) => s.id == skin.id);
      _cachedSkins!.add(skin);
      _cachedSkins!.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
  }

  @override
  void remove(String id) {
    final file = _file(id);
    if (file.existsSync()) file.deleteSync();
    if (_cachedSkins != null) {
      _cachedSkins!.removeWhere((s) => s.id == id);
    }
  }

  @override
  String? loadActive() {
    if (_isInitialized) return _cachedActive;
    try {
      final json = jsonDecode(_active.readAsStringSync());
      return _cachedActive = json is Map && json['id'] is String
          ? json['id'] as String
          : null;
    } on Object {
      return _cachedActive = null;
    }
  }

  @override
  void saveActive(String? id) {
    _cachedActive = id;
    _write(_active, jsonEncode({'id': id}));
  }

  void _write(File file, String contents) {
    directory.createSync(recursive: true);
    final part = File(
      '${file.path}.${Random.secure().nextInt(1 << 32).toRadixString(16)}.part',
    );
    part.writeAsStringSync(contents, flush: true);
    part.renameSync(file.path);
  }
}
