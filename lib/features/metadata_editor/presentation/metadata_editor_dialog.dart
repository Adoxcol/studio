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
import 'package:studio/ui/now_playing/cover_art.dart';

Future<bool> showMetadataEditor({
  required BuildContext context,
  required Track track,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MetadataEditorDialog(track: track),
      ) ??
      false;
}

class _MetadataEditorDialog extends ConsumerStatefulWidget {
  const _MetadataEditorDialog({required this.track});

  final Track track;

  @override
  ConsumerState<_MetadataEditorDialog> createState() =>
      _MetadataEditorDialogState();
}

class _MetadataEditorDialogState extends ConsumerState<_MetadataEditorDialog> {
  late final _title = TextEditingController(text: widget.track.title);
  late final _artist = TextEditingController(text: widget.track.artist ?? '');
  late final _album = TextEditingController(text: widget.track.album ?? '');
  late final _genre = TextEditingController(text: widget.track.genre ?? '');
  late final _year = TextEditingController(
    text: (widget.track.year ?? 0) > 0 ? '${widget.track.year}' : '',
  );
  late final _trackNumber = TextEditingController(
    text: (widget.track.trackNumber ?? 0) > 0
        ? '${widget.track.trackNumber}'
        : '',
  );
  String? _error;
  bool _saving = false;
  Uint8List? _coverBytes;
  String? _coverMime;
  bool _removeCover = false;

  bool get _writable =>
      widget.track.source == 'local' &&
      ref.read(trackMetadataWriterProvider).supports(widget.track.locator);

  TrackMetadataEdit get _edit => TrackMetadataEdit(
    title: _title.text,
    artist: _artist.text,
    album: _album.text,
    genre: _genre.text,
    year: int.tryParse(_year.text.trim()),
    trackNumber: int.tryParse(_trackNumber.text.trim()),
  ).normalized();

  bool get _artworkChanged => _coverBytes != null || _removeCover;

  EmbeddedCoverEdit get _coverEdit => switch ((_coverBytes, _coverMime)) {
    (final bytes?, final mime?) => EmbeddedCoverEdit.replace(bytes, mime),
    _ when _removeCover => const EmbeddedCoverEdit.remove(),
    _ => const EmbeddedCoverEdit.keep(),
  };

  List<MetadataChange> get _changes => [
    ..._edit.changesFrom(widget.track),
    if (_artworkChanged)
      MetadataChange(
        'Cover art',
        widget.track.artworkPath == null ? null : 'Current cover',
        _removeCover ? null : 'Selected image',
      ),
  ];

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _genre.dispose();
    _year.dispose();
    _trackNumber.dispose();
    super.dispose();
  }

  void _changed(String _) {
    if (_error != null) _error = null;
    setState(() {});
  }

  Future<void> _pickCover() async {
    late final Uint8List bytes;
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choose cover art',
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );
      if (picked?.path == null || !mounted) return;
      bytes = await File(picked!.path!).readAsBytes();
      if (!mounted) return;
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not read the selected image.\n$error');
      return;
    }
    if (bytes.length > 20 * 1024 * 1024) {
      setState(() => _error = 'Cover art must be 20 MB or smaller.');
      return;
    }
    final mime = _imageMime(bytes);
    if (mime == null) {
      setState(() => _error = 'Choose a valid JPEG or PNG image.');
      return;
    }
    setState(() {
      _coverBytes = bytes;
      _coverMime = mime;
      _removeCover = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final edit = _edit;
    final error = edit.validate() ?? _numericError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_changes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? artworkPath = widget.track.artworkPath;
    if (_coverBytes case final bytes?) {
      try {
        artworkPath = await ref
            .read(artworkStoreProvider)
            ?.save(bytes, mime: _coverMime);
        if (artworkPath == null) {
          throw StateError('Studio artwork storage is unavailable.');
        }
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = 'Could not store the selected cover.\n$error';
        });
        return;
      }
    } else if (_removeCover) {
      artworkPath = null;
    }
    late final FileStat stat;
    try {
      stat = await ref
          .read(trackMetadataWriterProvider)
          .write(widget.track.locator, edit, cover: _coverEdit);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Could not write these tags. The original file was kept.\n$error';
      });
      return;
    }

    try {
      await ref
          .read(studioDatabaseProvider)
          .updateTrackTags(
            id: widget.track.id,
            title: edit.title,
            artist: edit.artist,
            album: edit.album,
            genre: edit.genre,
            year: edit.year,
            trackNumber: edit.trackNumber,
            fileModifiedMs: stat.modified.millisecondsSinceEpoch,
            artworkPath: artworkPath,
            updateArtwork: _artworkChanged,
          );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'The file tags were written, but Studio could not refresh its '
            'library. Rescan the library to pick up the changes.\n$error';
      });
    }
  }

  String? _numericError() {
    if (_year.text.trim().isNotEmpty &&
        int.tryParse(_year.text.trim()) == null) {
      return 'Year must be a number.';
    }
    if (_trackNumber.text.trim().isNotEmpty &&
        int.tryParse(_trackNumber.text.trim()) == null) {
      return 'Track number must be a number.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final changes = _changes;
    final contentWidth = (MediaQuery.sizeOf(context).width - 96).clamp(
      280.0,
      720.0,
    );
    final wide = contentWidth >= 620;
    final form = _MetadataForm(
      title: _title,
      artist: _artist,
      album: _album,
      genre: _genre,
      year: _year,
      trackNumber: _trackNumber,
      enabled: _writable && !_saving,
      onChanged: _changed,
    );
    final preview = _ChangePreview(changes: changes);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const ValueKey('metadata-editor'),
        backgroundColor: palette.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: palette.hairline),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Edit metadata',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Text(
              _fileType(widget.track.locator),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
        content: SizedBox(
          width: contentWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.locator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: 18),
                if (!_writable) ...[
                  _ReadOnlyNotice(
                    locator: widget.track.locator,
                    remote: widget.track.source != 'local',
                  ),
                  const SizedBox(height: 18),
                ],
                _ArtworkEditor(
                  currentPath: widget.track.artworkPath,
                  selectedBytes: _coverBytes,
                  removed: _removeCover,
                  enabled:
                      _writable &&
                      !_saving &&
                      ref.read(artworkStoreProvider) != null,
                  onChoose: _pickCover,
                  onRemove: () => setState(() {
                    _coverBytes = null;
                    _coverMime = null;
                    _removeCover = true;
                    _error = null;
                  }),
                  onRestore: () => setState(() {
                    _coverBytes = null;
                    _coverMime = null;
                    _removeCover = false;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 24),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: form),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: preview),
                    ],
                  )
                else ...[
                  form,
                  const SizedBox(height: 28),
                  preview,
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
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
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          if (_writable)
            TextButton(
              key: const ValueKey('write-metadata'),
              onPressed: _saving || changes.isEmpty ? null : _save,
              child: Text(_saving ? 'Writing…' : 'Write changes'),
            ),
        ],
      ),
    );
  }
}

class _MetadataForm extends StatelessWidget {
  const _MetadataForm({
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.year,
    required this.trackNumber,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController title;
  final TextEditingController artist;
  final TextEditingController album;
  final TextEditingController genre;
  final TextEditingController year;
  final TextEditingController trackNumber;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetadataField(
          label: 'Title',
          controller: title,
          enabled: enabled,
          autofocus: enabled,
          onChanged: onChanged,
        ),
        _MetadataField(
          label: 'Artist credits',
          controller: artist,
          enabled: enabled,
          onChanged: onChanged,
        ),
        _MetadataField(
          label: 'Album',
          controller: album,
          enabled: enabled,
          onChanged: onChanged,
        ),
        _MetadataField(
          label: 'Genre',
          controller: genre,
          enabled: enabled,
          onChanged: onChanged,
        ),
        Row(
          children: [
            Expanded(
              child: _MetadataField(
                label: 'Year',
                controller: year,
                enabled: enabled,
                numeric: true,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _MetadataField(
                label: 'Track',
                controller: trackNumber,
                enabled: enabled,
                numeric: true,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArtworkEditor extends StatelessWidget {
  const _ArtworkEditor({
    required this.currentPath,
    required this.selectedBytes,
    required this.removed,
    required this.enabled,
    required this.onChoose,
    required this.onRemove,
    required this.onRestore,
  });

  final String? currentPath;
  final Uint8List? selectedBytes;
  final bool removed;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onRemove;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final changed = selectedBytes != null || removed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRect(
          child: selectedBytes != null
              ? Image.memory(
                  selectedBytes!,
                  key: const ValueKey('selected-cover-preview'),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : CoverArt(path: removed ? null : currentPath, size: 72),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cover art', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                removed
                    ? 'Will be removed from the audio file'
                    : selectedBytes != null
                    ? 'New JPEG or PNG selected'
                    : 'Embedded artwork shown throughout Studio',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                children: [
                  TextButton(
                    key: const ValueKey('choose-cover'),
                    onPressed: enabled ? onChoose : null,
                    child: const Text('Choose image'),
                  ),
                  if (!changed && currentPath != null)
                    TextButton(
                      key: const ValueKey('remove-cover'),
                      onPressed: enabled ? onRemove : null,
                      child: const Text('Remove'),
                    ),
                  if (changed)
                    TextButton(
                      key: const ValueKey('restore-cover'),
                      onPressed: enabled ? onRestore : null,
                      child: const Text('Restore current'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataField extends StatelessWidget {
  const _MetadataField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.numeric = false,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final bool numeric;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: Theme.of(context).textTheme.bodyMedium,
        cursorColor: palette.accent,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: palette.inkMuted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.hairline),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.accent),
          ),
          disabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.hairline),
          ),
        ),
      ),
    );
  }
}

class _ChangePreview extends StatelessWidget {
  const _ChangePreview({required this.changes});

  final List<MetadataChange> changes;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHANGES',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.inkMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (changes.isEmpty)
          Text(
            'Nothing changed yet.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          )
        else
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    change.field,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_display(change.before)}  →  ${_display(change.after)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.locator, required this.remote});

  final String locator;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Text(
      remote
          ? 'Streaming tracks are read-only.'
          : '${_fileType(locator)} tags are read-only in Studio. Writing is supported for MP3, M4A/MP4, FLAC, WAV, and APE.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
    );
  }
}

String _display(String? value) =>
    value == null || value.isEmpty ? 'Empty' : value;

String _fileType(String path) {
  final clean = path.split('?').first;
  final dot = clean.lastIndexOf('.');
  return dot < 0 ? 'FILE' : clean.substring(dot + 1).toUpperCase();
}

String? _imageMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
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
