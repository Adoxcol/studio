import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_browse_view.dart';
import 'package:studio/ui/library_browser/library_sidebar.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/library_browser/library_track_table.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _search = TextEditingController();
  var _sidebarOpen = true;
  var _tab = LibraryTab.all;
  var _sort = LibrarySort.title;
  var _order = LibraryOrder.ascending;
  String? _artistFilter;
  String? _albumFilter;
  String? _genreFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Add music folder',
    );
    if (path == null) return;
    await ref.read(libraryScanProvider.notifier).scanFolder(path);
  }

  void _selectArtist(String name) {
    setState(() {
      _artistFilter = _artistFilter == name ? null : name;
      _albumFilter = null;
      _genreFilter = null;
      _tab = LibraryTab.all;
    });
  }

  void _selectAlbum(String artist, String album) {
    setState(() {
      _artistFilter = artist;
      _albumFilter = album;
      _genreFilter = null;
      _tab = LibraryTab.all;
    });
  }

  void _selectGenre(String genre) {
    setState(() {
      _genreFilter = _genreFilter == genre ? null : genre;
      _artistFilter = null;
      _albumFilter = null;
      _tab = LibraryTab.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final scan = ref.watch(libraryScanProvider);
    final scanning = scan.active;
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final tracks = ref.watch(libraryTracksProvider);
    final playingId = ref.watch(
      playbackControllerProvider.select((s) => s.trackId),
    );

    return tracks.when(
      data: (rows) =>
          _body(context, palette, rows, folders, playingId, scanning),
      loading: () => _body(
        context,
        palette,
        const <Track>[],
        folders,
        playingId,
        scanning,
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text('$error', style: TextStyle(color: palette.inkMuted)),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    StudioPalette palette,
    List<Track> allTracks,
    List<LibraryFolder> folders,
    int? playingId,
    bool scanning,
  ) {
    final searched = LibraryQuery.filter(
      tracks: allTracks,
      query: _search.text,
    );
    final recentlyAdded = _tab == LibraryTab.recentlyAdded;
    final visible = LibraryQuery.sorted(
      tracks: LibraryQuery.filter(
        tracks: searched,
        artist: _artistFilter,
        album: _albumFilter,
        genre: _genreFilter,
      ),
      sort: _sort,
      order: recentlyAdded ? LibraryOrder.descending : _order,
      byIndexedAt: recentlyAdded,
    );
    final artists = LibraryQuery.groupArtists(searched);
    final showTable =
        _tab == LibraryTab.all || _tab == LibraryTab.recentlyAdded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibrarySidebar(
          expanded: _sidebarOpen,
          folders: folders,
          artists: artists,
          selectedArtist: _artistFilter,
          onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
          onSelectArtist: _selectArtist,
          onRemoveFolder: (id) {
            ref.read(libraryScanProvider.notifier).removeFolder(id);
          },
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      controller: _search,
                      onSearch: () => setState(() {}),
                      onAddFolder: scanning ? null : _addFolder,
                    ),
                    const SizedBox(height: 16),
                    _Tabs(
                      selected: _tab,
                      onSelect: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 12),
                    _Actions(
                      sort: _sort,
                      order: _order,
                      canPlay: visible.isNotEmpty,
                      onPlayAll: () {
                        ref
                            .read(playbackControllerProvider.notifier)
                            .playTracks(
                              visible.map((t) => t.id).toList(),
                              shuffle: false,
                            );
                      },
                      onShuffle: () {
                        ref
                            .read(playbackControllerProvider.notifier)
                            .playTracks(
                              visible.map((t) => t.id).toList(),
                              shuffle: true,
                            );
                      },
                      onCycleSort: () =>
                          setState(() => _sort = LibraryQuery.nextSort(_sort)),
                      onToggleOrder: () => setState(
                        () => _order = LibraryQuery.toggleOrder(_order),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _tab == LibraryTab.playlists
                          ? LibraryBrowseView(
                              tab: _tab,
                              artists: const [],
                              albums: const [],
                              genres: const [],
                              onSelectArtist: _selectArtist,
                              onSelectAlbum: _selectAlbum,
                              onSelectGenre: _selectGenre,
                            )
                          : allTracks.isEmpty
                          ? _EmptyLibrary(palette: palette)
                          : showTable
                          ? visible.isEmpty
                                ? _EmptyLibrary(
                                    palette: palette,
                                    text: 'No matching tracks.',
                                  )
                                : LibraryTrackTable(
                                    tracks: visible,
                                    playingId: playingId,
                                    onPlay: (index) {
                                      ref
                                          .read(
                                            playbackControllerProvider.notifier,
                                          )
                                          .playTracks(
                                            visible.map((t) => t.id).toList(),
                                            startIndex: index,
                                          );
                                    },
                                  )
                          : LibraryBrowseView(
                              tab: _tab,
                              artists: LibraryQuery.groupArtists(
                                searched,
                                order: _order,
                              ),
                              albums: LibraryQuery.albumSections(
                                searched,
                                order: _order,
                              ),
                              genres: LibraryQuery.groupGenres(
                                searched,
                                order: _order,
                              ),
                              onSelectArtist: _selectArtist,
                              onSelectAlbum: _selectAlbum,
                              onSelectGenre: _selectGenre,
                            ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: _RefreshButton(
                  enabled: !scanning && folders.isNotEmpty,
                  onTap: () {
                    ref.read(libraryScanProvider.notifier).rescanKnown();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onSearch,
    required this.onAddFolder,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback? onAddFolder;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Row(
      children: [
        Text('Library', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 24),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onSearch(),
            cursorColor: palette.ink,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search your library',
              hintStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 16),
        LibraryTextAction(
          label: 'Add folder',
          onTap: onAddFolder ?? () {},
          enabled: onAddFolder != null,
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final LibraryTab selected;
  final ValueChanged<LibraryTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in LibraryTab.values)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: GestureDetector(
                  onTap: () => onSelect(tab),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      tab.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tab == selected ? palette.ink : palette.inkMuted,
                        fontWeight: tab == selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sort,
    required this.order,
    required this.canPlay,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onCycleSort,
    required this.onToggleOrder,
  });

  final LibrarySort sort;
  final LibraryOrder order;
  final bool canPlay;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onCycleSort;
  final VoidCallback onToggleOrder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LibraryTextAction(
          label: 'Play All',
          onTap: onPlayAll,
          enabled: canPlay,
        ),
        LibraryTextAction(label: 'Shuffle', onTap: onShuffle, enabled: canPlay),
        LibraryTextAction(
          label: 'Sort: ${sort.label}',
          onTap: onCycleSort,
          muted: true,
          showChevron: true,
        ),
        LibraryTextAction(
          label: 'Order: ${order.label}',
          onTap: onToggleOrder,
          muted: true,
          showChevron: true,
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.palette,
    this.text = 'Library is empty. Local files will show up here.',
  });

  final StudioPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
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

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final color = enabled ? palette.ink : palette.inkMuted;
    return Tooltip(
      message: 'Rescan library',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.bg,
              border: Border.all(color: palette.hairline),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.refresh, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
