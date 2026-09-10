import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/metadata_editor/data/track_metadata_writer.dart';
import 'package:studio/features/metadata_editor/domain/track_metadata_edit.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_palette.dart';

Future<bool> showBatchMetadataEditor({
  required BuildContext context,
  required List<Track> tracks,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BatchMetadataEditorDialog(tracks: tracks),
      ) ??
      false;
}

class _BatchMetadataEditorDialog extends ConsumerStatefulWidget {
  const _BatchMetadataEditorDialog({required this.tracks});

  final List<Track> tracks;

  @override
  ConsumerState<_BatchMetadataEditorDialog> createState() =>
      _BatchMetadataEditorDialogState();
}

class _BatchMetadataEditorDialogState
    extends ConsumerState<_BatchMetadataEditorDialog> {
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _genre = TextEditingController();
  final _year = TextEditingController();
  final Set<String> _enabledFields = {};
  Uint8List? _coverBytes;
  String? _coverMime;
  bool _removeCover = false;
  bool _saving = false;
  int _processed = 0;
  int _written = 0;
  int _total = 0;
  bool _finished = false;
  List<String> _failures = const [];
  String? _error;

  List<Track> get _writableTracks {
    final writer = ref.read(trackMetadataWriterProvider);
    return widget.tracks
        .where(
          (track) => track.source == 'local' && writer.supports(track.locator),
        )
        .toList();
  }

  bool get _artworkChanged => _coverBytes != null || _removeCover;
  bool get _hasChanges => _enabledFields.isNotEmpty || _artworkChanged;

  TrackMetadataEdit _editFor(Track track) => TrackMetadataEdit(
    title: track.title,
    artist: _valueFor('artist', _artist.text, track.artist),
    album: _valueFor('album', _album.text, track.album),
    genre: _valueFor('genre', _genre.text, track.genre),
    year: _enabledFields.contains('year')
        ? int.tryParse(_year.text.trim())
        : track.year,
    trackNumber: track.trackNumber,
  ).normalized();

  List<Track> get _targets => _writableTracks
      .where(
        (track) =>
            _artworkChanged || _editFor(track).changesFrom(track).isNotEmpty,
      )
      .toList();

  @override
  void dispose() {
    _artist.dispose();
    _album.dispose();
    _genre.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choose cover art for selected tracks',
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );
      if (picked?.path == null || !mounted) return;
      final bytes = await File(picked!.path!).readAsBytes();
      if (!mounted) return;
      if (bytes.length > 20 * 1024 * 1024) {
        throw const FormatException('Cover art must be 20 MB or smaller.');
      }
      final mime = _imageMime(bytes);
      if (mime == null) {
        throw const FormatException('Choose a valid JPEG or PNG image.');
      }
      setState(() {
        _coverBytes = bytes;
        _coverMime = mime;
        _removeCover = false;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  String? _validate() {
    if (_enabledFields.contains('year')) {
      final text = _year.text.trim();
      if (text.isNotEmpty) {
        final year = int.tryParse(text);
        if (year == null || year < 1000 || year > 2100) {
          return 'Year must be empty or between 1000 and 2100.';
        }
      }
    }
    return null;
  }

  Future<void> _apply() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final targets = _targets;
    if (targets.isEmpty) return;
    setState(() {
      _saving = true;
      _processed = 0;
      _written = 0;
      _total = targets.length;
      _finished = false;
      _failures = const [];
      _error = null;
    });

    String? cachedCover;
    if (_coverBytes case final bytes?) {
      try {
        cachedCover = await ref
            .read(artworkStoreProvider)
            ?.save(bytes, mime: _coverMime);
        if (cachedCover == null) {
          throw StateError('Studio artwork storage is unavailable.');
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = 'Could not store the selected cover.\n$error';
          });
        }
        return;
      }
    }

    final failures = <String>[];
    final writer = ref.read(trackMetadataWriterProvider);
    final database = ref.read(studioDatabaseProvider);
    for (final track in targets) {
      var fileWritten = false;
      try {
        final edit = _editFor(track);
        final cover = _coverBytes != null
            ? EmbeddedCoverEdit.replace(_coverBytes!, _coverMime!)
            : _removeCover
            ? const EmbeddedCoverEdit.remove()
            : const EmbeddedCoverEdit.keep();
        final stat = await writer.write(track.locator, edit, cover: cover);
        fileWritten = true;
        await database.updateTrackTags(
          id: track.id,
          title: edit.title,
          artist: edit.artist,
          album: edit.album,
          genre: edit.genre,
          year: edit.year,
          trackNumber: edit.trackNumber,
          fileModifiedMs: stat.modified.millisecondsSinceEpoch,
          artworkPath: _removeCover ? null : cachedCover,
          updateArtwork: _artworkChanged,
        );
        _written++;
      } on Object catch (error) {
        failures.add(
          '${track.title}: ${fileWritten ? 'File updated; library refresh failed. Rescan required. ' : 'File write failed. '}$error',
        );
      }
      _processed++;
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failures = failures;
      _finished = true;
    });
  }

  String? _valueFor(String field, String text, String? original) {
    return _enabledFields.contains(field) ? text : original;
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final writable = _writableTracks.length;
    final skipped = widget.tracks.length - writable;
    final complete = _finished;
    final affected = _targets.length;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const ValueKey('batch-metadata-editor'),
        backgroundColor: palette.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: palette.hairline),
        ),
        title: Text(
          'Edit ${widget.tracks.length} tracks',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$writable writable${skipped == 0 ? '' : ' · $skipped will be skipped'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: 20),
                Text(
                  'Only checked fields change. A checked empty field clears it. Titles and track numbers stay individual.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final entry in [
                  ('artist', 'Artist credits', _artist),
                  ('album', 'Album', _album),
                  ('genre', 'Genre', _genre),
                  ('year', 'Year', _year),
                ])
                  _BatchField(
                    id: entry.$1,
                    label: entry.$2,
                    controller: entry.$3,
                    checked: _enabledFields.contains(entry.$1),
                    enabled: !_saving && !complete,
                    onChanged: () => setState(() => _error = null),
                    onToggle: (checked) => setState(() {
                      if (checked) {
                        _enabledFields.add(entry.$1);
                      } else {
                        _enabledFields.remove(entry.$1);
                      }
                      _error = null;
                    }),
                  ),
                const SizedBox(height: 12),
                if (_coverBytes case final bytes?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.memory(
                      bytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                Text(
                  'Cover art',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _removeCover
                      ? 'Remove embedded artwork from every writable track'
                      : _coverBytes != null
                      ? 'Use the selected image for every writable track'
                      : 'Leave each track’s current artwork unchanged',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
                Wrap(
                  spacing: 14,
                  children: [
                    TextButton(
                      key: const ValueKey('batch-choose-cover'),
                      onPressed:
                          !_saving &&
                              !complete &&
                              ref.read(artworkStoreProvider) != null
                          ? _pickCover
                          : null,
                      child: const Text('Choose image'),
                    ),
                    TextButton(
                      onPressed: !_saving && !complete
                          ? () => setState(() {
                              _coverBytes = null;
                              _coverMime = null;
                              _removeCover = true;
                            })
                          : null,
                      child: const Text('Remove all'),
                    ),
                    if (_artworkChanged)
                      TextButton(
                        onPressed: !_saving && !complete
                            ? () => setState(() {
                                _coverBytes = null;
                                _coverMime = null;
                                _removeCover = false;
                              })
                            : null,
                        child: const Text('Leave unchanged'),
                      ),
                  ],
                ),
                if (_saving || complete) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _total == 0 ? 0 : _processed / _total,
                    minHeight: 1,
                    color: palette.accent,
                    backgroundColor: palette.hairline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complete
                        ? 'Updated $_written of $_total tracks.'
                        : 'Writing $_processed of $_total…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_failures.length} track${_failures.length == 1 ? '' : 's'} could not be updated:',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.accent),
                  ),
                  for (final failure in _failures)
                    Text(
                      failure,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                    ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.accent),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => Navigator.pop(context, complete && _written > 0),
            child: Text(complete ? 'Done' : 'Cancel'),
          ),
          if (!complete)
            TextButton(
              key: const ValueKey('apply-batch-metadata'),
              onPressed: _saving || !_hasChanges || affected == 0
                  ? null
                  : _apply,
              child: Text('Apply to $affected tracks'),
            ),
        ],
      ),
    );
  }
}

class _BatchField extends StatelessWidget {
  const _BatchField({
    required this.id,
    required this.label,
    required this.controller,
    required this.checked,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  final String id;
  final String label;
  final TextEditingController controller;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Row(
      children: [
        Checkbox(
          key: ValueKey('batch-field-$id'),
          value: checked,
          onChanged: enabled ? (value) => onToggle(value ?? false) : null,
          side: BorderSide(color: palette.hairlineStrong),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            enabled: enabled && checked,
            keyboardType: id == 'year'
                ? TextInputType.number
                : TextInputType.text,
            cursorColor: palette.accent,
            decoration: InputDecoration(
              labelText: label,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: palette.hairline),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: palette.accent),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: palette.hairlineSoft),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String? _imageMime(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  return null;
}
