import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/features/metadata_editor/presentation/metadata_editor_dialog.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

sealed class _TrackAction {
  const _TrackAction();
}

class _NamedAction extends _TrackAction {
  const _NamedAction(this.name);
  final String name;
}

class _ArtistAction extends _TrackAction {
  const _ArtistAction(this.artist);
  final String artist;
}

class _PlaylistAction extends _TrackAction {
  const _PlaylistAction(this.id);
  final int id;
}

Future<void> showTrackActions({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
  required Offset position,
  VoidCallback? onPlayNow,
  VoidCallback? onRemove,
  String removeLabel = 'Remove',
}) async {
  final playlists = (ref.read(playlistsProvider).value ?? const <Playlist>[])
      .where((playlist) => playlist.smartRules == null)
      .toList();
  final artists = LibraryQuery.creditedArtists(
    track.artist,
  ).where((artist) => artist != LibraryQuery.unknownArtist).toList();
  final album = LibraryQuery.albumName(track);
  final leadArtist = LibraryQuery.artistName(track);
  final hasAlbum =
      album != LibraryQuery.unknownAlbum &&
      leadArtist != LibraryQuery.unknownArtist;
  final palette = StudioPalette.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final anchor = overlay.globalToLocal(position);
  final selected = await showMenu<_TrackAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(anchor.dx, anchor.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    color: palette.bg,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: palette.hairline),
      borderRadius: BorderRadius.zero,
    ),
    items: [
      const PopupMenuItem(
        value: _NamedAction('play-now'),
        child: Text('Play now'),
      ),
      const PopupMenuItem(
        value: _NamedAction('play-next'),
        child: Text('Play next'),
      ),
      const PopupMenuItem(
        value: _NamedAction('add-to-queue'),
        child: Text('Add to queue'),
      ),
      const PopupMenuDivider(),
      for (final artist in artists)
        PopupMenuItem(
          value: _ArtistAction(artist),
          child: Text(
            artists.length == 1 ? 'View artist' : 'View artist — $artist',
          ),
        ),
      if (hasAlbum)
        const PopupMenuItem(
          value: _NamedAction('view-album'),
          child: Text('View album'),
        ),
      const PopupMenuItem(
        value: _NamedAction('edit-metadata'),
        child: Text('Edit metadata'),
      ),
      const PopupMenuItem(
        value: _NamedAction('details'),
        child: Text('Track details'),
      ),
      const PopupMenuDivider(),
      for (final playlist in playlists)
        PopupMenuItem(
          value: _PlaylistAction(playlist.id),
          child: Text('Add to ${playlist.name}'),
        ),
      PopupMenuItem(
        value: const _NamedAction('new-playlist'),
        child: Text(playlists.isEmpty ? 'New playlist' : 'New playlist…'),
      ),
      if (onRemove != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: const _NamedAction('remove'),
          child: Text(removeLabel),
        ),
      ],
    ],
  );
  if (selected == null || !context.mounted) return;
  final playback = ref.read(playbackControllerProvider.notifier);
  switch (selected) {
    case _NamedAction(name: 'play-now'):
      onPlayNow?.call();
      if (onPlayNow == null) await playback.playTracks([track.id]);
    case _NamedAction(name: 'play-next'):
      playback.playNext(track.id);
    case _NamedAction(name: 'add-to-queue'):
      playback.addToQueue(track.id);
    case _NamedAction(name: 'view-album'):
      ref
          .read(libraryNavigationProvider.notifier)
          .openAlbum(artist: leadArtist, album: album);
      ref.read(studioNavProvider.notifier).select(StudioDestination.library);
    case _NamedAction(name: 'details'):
      ref.read(detailSelectionProvider.notifier).inspect(track.id);
      ref.read(studioNavProvider.notifier).select(StudioDestination.track);
    case _NamedAction(name: 'edit-metadata'):
      await showMetadataEditor(context: context, track: track);
    case _NamedAction(name: 'new-playlist'):
      final name = await _promptPlaylistName(context);
      if (name == null || !context.mounted) return;
      final db = ref.read(studioDatabaseProvider);
      final id = await db.createPlaylist(name);
      await db.addTrackToPlaylist(playlistId: id, trackId: track.id);
    case _NamedAction(name: 'remove'):
      onRemove?.call();
    case _ArtistAction(:final artist):
      ref.read(libraryNavigationProvider.notifier).openArtist(artist);
      ref.read(studioNavProvider.notifier).select(StudioDestination.library);
    case _PlaylistAction(:final id):
      await ref
          .read(studioDatabaseProvider)
          .addTrackToPlaylist(playlistId: id, trackId: track.id);
    case _NamedAction():
      break;
  }
}

Future<String?> _promptPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class TrackActionsButton extends ConsumerWidget {
  const TrackActionsButton({
    super.key,
    required this.track,
    this.onPlayNow,
    this.onRemove,
    this.removeLabel = 'Remove',
    this.color,
  });

  final Track track;
  final VoidCallback? onPlayNow;
  final VoidCallback? onRemove;
  final String removeLabel;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Track actions',
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final box = context.findRenderObject()! as RenderBox;
        final origin = box.localToGlobal(Offset.zero);
        showTrackActions(
          context: context,
          ref: ref,
          track: track,
          position: Offset(
            origin.dx + box.size.width,
            origin.dy + box.size.height,
          ),
          onPlayNow: onPlayNow,
          onRemove: onRemove,
          removeLabel: removeLabel,
        );
      },
      icon: Icon(
        Icons.more_horiz,
        size: 19,
        color: color ?? StudioPalette.of(context).inkMuted,
      ),
    );
  }
}
