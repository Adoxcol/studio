import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/skins/domain/skin.dart';

/// Installed skins and which one is active.
abstract class SkinStore {
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

  @override
  List<Skin> load() {
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
    return skins;
  }

  @override
  void install(Skin skin) => _write(_file(skin.id), skin.encode());

  @override
  void remove(String id) {
    final file = _file(id);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  String? loadActive() {
    try {
      final json = jsonDecode(_active.readAsStringSync());
      return json is Map && json['id'] is String ? json['id'] as String : null;
    } on Object {
      return null;
    }
  }

  @override
  void saveActive(String? id) => _write(_active, jsonEncode({'id': id}));

  void _write(File file, String contents) {
    directory.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(contents, flush: true);
    part.renameSync(file.path);
  }
}
