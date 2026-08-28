import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _scanning = false;

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Add music folder',
    );
    if (path == null) return;
    setState(() => _scanning = true);
    try {
      await ref.read(folderScannerProvider).scan(path);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final tracks = ref.watch(libraryTracksProvider);
    final playingId = ref.watch(
      playbackControllerProvider.select((s) => s.trackId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
          child: Row(
            children: [
              Text(
                'Library',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _scanning ? null : _addFolder,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    _scanning ? 'Scanning…' : 'Add folder',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.when(
            data: (rows) {
              if (rows.isEmpty) {
                return _EmptyLibrary(palette: palette);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.hairlineSoft),
                itemBuilder: (context, index) {
                  final track = rows[index];
                  return _TrackRow(
                    track: track,
                    playing: track.id == playingId,
                    onPlay: () {
                      final ids = rows.map((t) => t.id).toList();
                      ref
                          .read(playbackControllerProvider.notifier)
                          .playTracks(ids, startIndex: index);
                    },
                  );
                },
              );
            },
            loading: () => _EmptyLibrary(palette: palette),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text('$error', style: TextStyle(color: palette.inkMuted)),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.palette});

  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      child: Text(
        'Library is empty. Local files will show up here.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.playing,
    required this.onPlay,
  });

  final Track track;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return InkWell(
      onTap: onPlay,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: playing
                  ? Icon(Icons.graphic_eq, size: 16, color: palette.accent)
                  : Text(
                      track.trackNumber?.toString() ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                    ),
            ),
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: playing ? palette.accent : palette.ink,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: Text(
                track.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 180,
              child: Text(
                track.album ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
