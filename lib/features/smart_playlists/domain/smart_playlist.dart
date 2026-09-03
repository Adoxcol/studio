import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';

enum SmartField {
  search('Search'),
  artist('Artist'),
  album('Album'),
  genre('Genre'),
  year('Year'),
  format('File format'),
  bitrate('Estimated bitrate (kbps)'),
  sampleRate('Sample rate (Hz)'),
  lossless('Lossless format'),
  folder('Folder ID');

  const SmartField(this.label);
  final String label;
  bool get numeric => [year, bitrate, sampleRate, folder].contains(this);
  List<SmartOperator> get operators => this == lossless
      ? [SmartOperator.equals]
      : numeric
      ? [SmartOperator.equals, SmartOperator.atLeast, SmartOperator.atMost]
      : this == search
      ? [SmartOperator.contains]
      : [SmartOperator.contains, SmartOperator.equals];
}

enum SmartOperator {
  contains('contains'),
  equals('is'),
  atLeast('at least'),
  atMost('at most');

  const SmartOperator(this.label);
  final String label;
}

class SmartRule {
  const SmartRule(this.field, this.operator, this.value);
  final SmartField field;
  final SmartOperator operator;
  final String value;

  String? validate() {
    if (!field.operators.contains(operator))
      return 'Unsupported rule operator.';
    if (value.trim().isEmpty) return '${field.label} needs a value.';
    if (field.numeric &&
        (int.tryParse(value.trim()) == null || int.parse(value.trim()) < 0)) {
      return '${field.label} must be a non-negative whole number.';
    }
    if (field == SmartField.lossless && value != 'true' && value != 'false') {
      return 'Choose yes or no for lossless format.';
    }
    return null;
  }

  bool matches(Track track) {
    if (validate() != null) return false;
    final needle = value.trim().toLowerCase();
    if (field == SmartField.search)
      return LibraryQuery.matchesQuery(track, needle);
    if (field == SmartField.lossless)
      return LibraryQuery.isLossless(track) == (value == 'true');
    if (field.numeric) {
      final actual = switch (field) {
        SmartField.year => track.year,
        SmartField.bitrate => LibraryQuery.estimatedBitrateKbps(track),
        SmartField.sampleRate => track.sampleRateHz,
        SmartField.folder => track.folderId,
        _ => null,
      };
      // Missing technical data never satisfies a numeric comparison.
      if (actual == null) return false;
      final expected = int.parse(needle);
      return switch (operator) {
        SmartOperator.equals => actual == expected,
        SmartOperator.atLeast => actual >= expected,
        SmartOperator.atMost => actual <= expected,
        _ => false,
      };
    }
    if (field == SmartField.artist && operator == SmartOperator.equals) {
      return LibraryQuery.creditsInclude(track, value.trim());
    }
    final actual = switch (field) {
      SmartField.artist => track.artist,
      SmartField.album => track.album,
      SmartField.genre => track.genre,
      SmartField.format =>
        p.extension(track.locator.split('?').first).replaceFirst('.', ''),
      _ => null,
    };
    if (actual == null) return false;
    return operator == SmartOperator.equals
        ? actual.trim().toLowerCase() == needle
        : actual.toLowerCase().contains(needle);
  }

  Map<String, Object> toJson() => {
    'field': field.name,
    'operator': operator.name,
    'value': value.trim(),
  };
  factory SmartRule.fromJson(Map<String, dynamic> json) => SmartRule(
    SmartField.values.byName(json['field'] as String),
    SmartOperator.values.byName(json['operator'] as String),
    json['value'] as String,
  );
}

class SmartPlaylistDefinition {
  SmartPlaylistDefinition({
    required List<SmartRule> rules,
    this.matchAll = true,
    this.sort = LibrarySort.title,
    this.order = LibraryOrder.ascending,
  }) : rules = List.unmodifiable(rules);

  final List<SmartRule> rules;
  final bool matchAll;
  final LibrarySort sort;
  final LibraryOrder order;

  String? validate() {
    if (rules.isEmpty) return 'Add at least one rule.';
    for (final rule in rules) {
      final error = rule.validate();
      if (error != null) return error;
    }
    return null;
  }

  List<Track> evaluate(List<Track> tracks) {
    if (validate() != null) return [];
    return LibraryQuery.sorted(
      tracks: tracks
          .where(
            (track) => matchAll
                ? rules.every((rule) => rule.matches(track))
                : rules.any((rule) => rule.matches(track)),
          )
          .toList(),
      sort: sort,
      order: order,
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'matchAll': matchAll,
    'sort': sort.name,
    'order': order.name,
    'rules': rules.map((rule) => rule.toJson()).toList(),
  });

  factory SmartPlaylistDefinition.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['version'] != 1)
      throw const FormatException('Unsupported smart playlist version.');
    final result = SmartPlaylistDefinition(
      rules: (json['rules'] as List)
          .map((rule) => SmartRule.fromJson(rule as Map<String, dynamic>))
          .toList(),
      matchAll: json['matchAll'] as bool,
      sort: LibrarySort.values.byName(json['sort'] as String),
      order: LibraryOrder.values.byName(json['order'] as String),
    );
    final error = result.validate();
    if (error != null) throw FormatException(error);
    return result;
  }

  factory SmartPlaylistDefinition.fromFilters({
    required LibraryTrackFilters filters,
    String query = '',
    String? artist,
    String? album,
    String? genre,
    int? folderId,
    LibrarySort sort = LibrarySort.title,
    LibraryOrder order = LibraryOrder.ascending,
  }) => SmartPlaylistDefinition(
    sort: sort,
    order: order,
    rules: [
      if (query.trim().isNotEmpty)
        SmartRule(SmartField.search, SmartOperator.contains, query),
      if (artist != null)
        SmartRule(SmartField.artist, SmartOperator.equals, artist),
      if (album != null)
        SmartRule(SmartField.album, SmartOperator.equals, album),
      if (genre != null)
        SmartRule(SmartField.genre, SmartOperator.equals, genre),
      if (filters.genre != null)
        SmartRule(SmartField.genre, SmartOperator.equals, filters.genre!),
      if (filters.year != null)
        SmartRule(SmartField.year, SmartOperator.equals, '${filters.year}'),
      if (filters.losslessOnly)
        const SmartRule(SmartField.lossless, SmartOperator.equals, 'true'),
      if (filters.minimumSampleRateHz != null)
        SmartRule(
          SmartField.sampleRate,
          SmartOperator.atLeast,
          '${filters.minimumSampleRateHz}',
        ),
      if (filters.minimumBitrateKbps != null)
        SmartRule(
          SmartField.bitrate,
          SmartOperator.atLeast,
          '${filters.minimumBitrateKbps}',
        ),
      if (folderId != null)
        SmartRule(SmartField.folder, SmartOperator.equals, '$folderId'),
      if (filters.folderId != null)
        SmartRule(
          SmartField.folder,
          SmartOperator.equals,
          '${filters.folderId}',
        ),
    ],
  );
}
