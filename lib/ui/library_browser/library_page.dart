import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
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
  int? _playlistId;

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
      _sort = LibrarySort.track;
      _order = LibraryOrder.ascending;
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

  Future<String?> _promptPlaylistName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = StudioPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.bg,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'New playlist',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          content: TextField(
            key: const ValueKey('playlist-name-field'),
            controller: controller,
            autofocus: true,
            cursorColor: palette.ink,
            style: Theme.of(ctx).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Name',
              hintStyle: Theme.of(
                ctx,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value),
          ),
          actions: [
            LibraryTextAction(
              label: 'Cancel',
              onTap: () => Navigator.pop(ctx),
              muted: true,
            ),
            LibraryTextAction(
              label: 'Create',
              onTap: () => Navigator.pop(ctx, controller.text),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return name;
  }

  Future<void> _createPlaylist() async {
    final name = await _promptPlaylistName();
    if (name == null || !mounted) return;
    await ref.read(studioDatabaseProvider).createPlaylist(name);
  }

  Future<void> _showTrackMenu(Track track, Offset globalPosition) async {
    final lists = ref.read(playlistsProvider).value ?? const [];
    final palette = StudioPalette.of(context);
    final selected = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      color: palette.bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.hairline),
        borderRadius: BorderRadius.zero,
      ),
      items: [
        for (final list in lists)
          PopupMenuItem<Object>(value: list.id, child: Text(list.name)),
        PopupMenuItem<Object>(
          value: 'new',
          child: Text(lists.isEmpty ? 'New playlist' : 'New playlist…'),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    final db = ref.read(studioDatabaseProvider);
    if (selected == 'new') {
      final name = await _promptPlaylistName();
      if (name == null || !mounted) return;
      final id = await db.createPlaylist(name);
      await db.addTrackToPlaylist(playlistId: id, trackId: track.id);
      return;
    }
    if (selected is int) {
      await db.addTrackToPlaylist(playlistId: selected, trackId: track.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final scanActive = ref.watch(libraryScanProvider.select((s) => s.active));
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final tracks = ref.watch(libraryTracksProvider);

    return tracks.when(
      data: (rows) => _body(context, palette, rows, folders, scanActive),
      loading: () =>
          _body(context, palette, const <Track>[], folders, scanActive),
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
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final viewingPlaylist = _tab == LibraryTab.playlists && _playlistId != null;
    final playlistTracks = viewingPlaylist
        ? (ref.watch(playlistTracksProvider(_playlistId!)).value ?? const [])
        : const <Track>[];
    final tableTracks = viewingPlaylist ? playlistTracks : visible;
    final showTable =
        _tab == LibraryTab.all ||
        _tab == LibraryTab.recentlyAdded ||
        viewingPlaylist;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarExpanded =
            _sidebarOpen && constraints.maxWidth >= LibrarySidebar.width + 200;
        final tight = constraints.maxWidth < 360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LibrarySidebar(
              expanded: sidebarExpanded,
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
                    padding: EdgeInsets.fromLTRB(
                      tight ? 16 : 32,
                      24,
                      tight ? 16 : 32,
                      8,
                    ),
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
                          onSelect: (tab) => setState(() {
                            if (tab == LibraryTab.playlists &&
                                _tab == LibraryTab.playlists) {
                              _playlistId = null;
                            }
                            _tab = tab;
                            if (tab != LibraryTab.playlists) {
                              _playlistId = null;
                            }
                          }),
                        ),
                        const SizedBox(height: 12),
                        _Actions(
                          sort: _sort,
                          order: _order,
                          canPlay: tableTracks.isNotEmpty,
                          showSort: _tab != LibraryTab.playlists,
                          showView: showTable,
                          trackLayout: ref
                              .watch(appearanceProvider)
                              .trackLayout,
                          onPlayAll: () {
                            ref
                                .read(playbackControllerProvider.notifier)
                                .playTracks(
                                  tableTracks.map((t) => t.id).toList(),
                                  shuffle: false,
                                );
                          },
                          onShuffle: () {
                            ref
                                .read(playbackControllerProvider.notifier)
                                .playTracks(
                                  tableTracks.map((t) => t.id).toList(),
                                  shuffle: true,
                                );
                          },
                          onCycleSort: () => setState(
                            () => _sort = LibraryQuery.nextSort(_sort),
                          ),
                          onToggleOrder: () => setState(
                            () => _order = LibraryQuery.toggleOrder(_order),
                          ),
                          onCycleLayout: () {
                            final next =
                                ref.read(appearanceProvider).trackLayout ==
                                    TrackLayout.cards
                                ? TrackLayout.list
                                : TrackLayout.cards;
                            ref
                                .read(appearanceProvider.notifier)
                                .setTrackLayout(next);
                          },
                          extras: [
                            if (_tab == LibraryTab.playlists)
                              LibraryTextAction(
                                label: 'New playlist',
                                onTap: _createPlaylist,
                              ),
                            if (viewingPlaylist)
                              LibraryTextAction(
                                label: 'Delete playlist',
                                onTap: () async {
                                  final id = _playlistId;
                                  if (id == null) return;
                                  await ref
                                      .read(studioDatabaseProvider)
                                      .deletePlaylist(id);
                                  if (!mounted) return;
                                  setState(() => _playlistId = null);
                                },
                                muted: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child:
                              _tab == LibraryTab.playlists && !viewingPlaylist
                              ? LibraryBrowseView(
                                  tab: _tab,
                                  artists: const [],
                                  albums: const [],
                                  genres: const [],
                                  playlists: playlists,
                                  onSelectArtist: _selectArtist,
                                  onSelectAlbum: _selectAlbum,
                                  onSelectGenre: _selectGenre,
                                  onSelectPlaylist: (playlist) {
                                    setState(() => _playlistId = playlist.id);
                                  },
                                )
                              : allTracks.isEmpty && !viewingPlaylist
                              ? _EmptyLibrary(palette: palette)
                              : showTable
                              ? tableTracks.isEmpty
                                    ? _EmptyLibrary(
                                        palette: palette,
                                        text: viewingPlaylist
                                            ? 'This playlist is empty. Right-click a track to add it.'
                                            : 'No matching tracks.',
                                      )
                                    : LibraryTrackTable(
                                        tracks: tableTracks,
                                        onPlay: (index) {
                                          ref
                                              .read(
                                                playbackControllerProvider
                                                    .notifier,
                                              )
                                              .playTracks(
                                                tableTracks
                                                    .map((t) => t.id)
                                                    .toList(),
                                                startIndex: index,
                                              );
                                        },
                                        onTrackMenu: _showTrackMenu,
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
                                  playlists: playlists,
                                  onSelectArtist: _selectArtist,
                                  onSelectAlbum: _selectAlbum,
                                  onSelectGenre: _selectGenre,
                                  onSelectPlaylist: (playlist) {
                                    setState(() => _playlistId = playlist.id);
                                  },
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
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= 280;
        final showAddLabel = constraints.maxWidth >= 200;
        return Row(
          children: [
            if (showTitle) ...[
              Text(
                'Library',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 24),
            ],
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
            const SizedBox(width: 8),
            if (showAddLabel)
              LibraryTextAction(
                label: 'Add folder',
                onTap: onAddFolder ?? () {},
                enabled: onAddFolder != null,
              )
            else
              Tooltip(
                message: 'Add folder',
                child: GestureDetector(
                  onTap: onAddFolder,
                  child: MouseRegion(
                    cursor: onAddFolder == null
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                      color: onAddFolder == null
                          ? palette.inkMuted
                          : palette.ink,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
    required this.showSort,
    required this.showView,
    required this.trackLayout,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onCycleSort,
    required this.onToggleOrder,
    required this.onCycleLayout,
    this.extras = const [],
  });

  final LibrarySort sort;
  final LibraryOrder order;
  final bool canPlay;
  final bool showSort;
  final bool showView;
  final TrackLayout trackLayout;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onCycleSort;
  final VoidCallback onToggleOrder;
  final VoidCallback onCycleLayout;
  final List<Widget> extras;

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
        if (showSort) ...[
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
        if (showView)
          LibraryTextAction(
            label: 'View: ${trackLayout.label}',
            onTap: onCycleLayout,
            muted: true,
            showChevron: true,
          ),
        ...extras,
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
