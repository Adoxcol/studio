import 'package:flutter/material.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/theming/studio_palette.dart';

class LibraryBrowseView extends StatelessWidget {
  const LibraryBrowseView({
    super.key,
    required this.tab,
    required this.artists,
    required this.albums,
    required this.genres,
    this.playlists = const [],
    required this.onSelectArtist,
    required this.onSelectAlbum,
    required this.onSelectGenre,
    this.onSelectPlaylist,
  });

  final LibraryTab tab;
  final List<LibraryGroup> artists;
  final List<AlbumSection> albums;
  final List<LibraryGroup> genres;
  final List<Playlist> playlists;
  final ValueChanged<String> onSelectArtist;
  final void Function(String artist, String album) onSelectAlbum;
  final ValueChanged<String> onSelectGenre;
  final ValueChanged<Playlist>? onSelectPlaylist;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      LibraryTab.artists => _ArtistGrid(
        groups: artists,
        onSelect: onSelectArtist,
      ),
      LibraryTab.albums => _AlbumSections(
        sections: albums,
        onSelect: onSelectAlbum,
      ),
      LibraryTab.genres => _GenreGrid(groups: genres, onSelect: onSelectGenre),
      LibraryTab.playlists => PlaylistListView(
        playlists: playlists,
        onSelect: onSelectPlaylist ?? (_) {},
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      ),
    );
  }
}

class PlaylistListView extends StatelessWidget {
  const PlaylistListView({
    super.key,
    required this.playlists,
    required this.onSelect,
  });

  final List<Playlist> playlists;
  final ValueChanged<Playlist> onSelect;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const _EmptyCopy(text: 'No playlists yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountLabel(count: playlists.length, noun: 'PLAYLIST'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 72,
              crossAxisSpacing: 24,
              mainAxisSpacing: 8,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _NameTile(
                name: playlist.name,
                detail: 'Playlist',
                onTap: () => onSelect(playlist),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistGrid extends StatelessWidget {
  const _ArtistGrid({required this.groups, required this.onSelect});

  final List<LibraryGroup> groups;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _EmptyCopy(text: 'No artists yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountLabel(count: groups.length, noun: 'ARTIST'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 72,
              crossAxisSpacing: 24,
              mainAxisSpacing: 8,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final albums = group.albumCount ?? 0;
              return _NameTile(
                name: group.name,
                detail: _plural(albums, 'album'),
                onTap: () => onSelect(group.name),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenreGrid extends StatelessWidget {
  const _GenreGrid({required this.groups, required this.onSelect});

  final List<LibraryGroup> groups;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _EmptyCopy(text: 'No genres yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountLabel(count: groups.length, noun: 'GENRE'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 72,
              crossAxisSpacing: 24,
              mainAxisSpacing: 8,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _NameTile(
                name: group.name,
                detail: _plural(group.trackCount, 'track'),
                onTap: () => onSelect(group.name),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlbumSections extends StatelessWidget {
  const _AlbumSections({required this.sections, required this.onSelect});

  final List<AlbumSection> sections;
  final void Function(String artist, String album) onSelect;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const _EmptyCopy(text: 'No albums yet.');
    }
    final palette = StudioPalette.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.artist,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              for (final album in section.albums)
                GestureDetector(
                  onTap: () => onSelect(section.artist, album.name),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${album.name}  ·  ${_plural(album.trackCount, 'track')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({
    required this.name,
    required this.detail,
    required this.onTap,
  });

  final String name;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.count, required this.noun});

  final int count;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final label = count == 1 ? noun : '${noun}S';
    return Text(
      '$count $label',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.inkMuted,
        letterSpacing: 1.4,
        fontSize: 11,
      ),
    );
  }
}

String _plural(int count, String noun) {
  return count == 1 ? '1 $noun' : '$count ${noun}s';
}
