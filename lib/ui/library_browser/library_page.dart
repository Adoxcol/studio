import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio/library/library_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_browse_view.dart';
import 'package:studio/features/library_folders/presentation/library_folders_panel.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/library_browser/library_track_table.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

typedef _LibraryLocation = ({
  LibraryTab tab,
  LibrarySort sort,
  LibraryOrder order,
  TextEditingValue search,
  String? artist,
  String? album,
  String? genre,
  int? playlistId,
  int? folderId,
  PageStorageBucket scrollStorage,
});

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _search = TextEditingController();
  Timer? _searchTimer;
  String _query = '';
  LibraryView? _view;
  Object? _viewKey;

  void _onSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = _search.text);
    });
  }

  void _syncSearch() {
    _searchTimer?.cancel();
    _query = _search.text;
  }

  final _history = <_LibraryLocation>[];
  var _scrollStorage = PageStorageBucket();
  var _tab = LibraryTab.all;
  var _sort = LibrarySort.title;
  var _order = LibraryOrder.ascending;
  String? _artistFilter;
  String? _albumFilter;
  String? _genreFilter;
  int? _playlistId;
  int? _folderId;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _open(VoidCallback select) {
    setState(() {
      _history.add((
        tab: _tab,
        sort: _sort,
        order: _order,
        search: _search.value,
        artist: _artistFilter,
        album: _albumFilter,
        genre: _genreFilter,
        playlistId: _playlistId,
        folderId: _folderId,
        scrollStorage: _scrollStorage,
      ));
      _scrollStorage = PageStorageBucket();
      // A catalogue search selects a group, not a subset of its tracks.
      // Keep the original query in history and open the complete group.
      _search.clear();
      _syncSearch();
      select();
    });
  }

  void _goBack() {
    if (_history.isEmpty) return;
    setState(() {
      final previous = _history.removeLast();
      _tab = previous.tab;
      _sort = previous.sort;
      _order = previous.order;
      _search.value = previous.search;
      _syncSearch();
      _artistFilter = previous.artist;
      _albumFilter = previous.album;
      _genreFilter = previous.genre;
      _playlistId = previous.playlistId;
      _folderId = previous.folderId;
      _scrollStorage = previous.scrollStorage;
    });
  }

  void _selectTab(LibraryTab tab) {
    if (_history.isNotEmpty && _history.last.tab == tab) {
      _goBack();
      return;
    }
    setState(() {
      if (_tab != tab || _history.isNotEmpty) {
        _scrollStorage = PageStorageBucket();
      }
      _syncSearch();
      _history.clear();
      _tab = tab;
      _folderId = null;
      _playlistId = null;
      _artistFilter = null;
      _albumFilter = null;
      _genreFilter = null;
    });
  }

  void _selectArtist(String name) {
    _open(() {
      _artistFilter = name;
      _albumFilter = null;
      _genreFilter = null;
      _tab = LibraryTab.all;
    });
  }

  void _selectAlbum(String artist, String album) {
    _open(() {
      _artistFilter = artist;
      _albumFilter = album;
      _genreFilter = null;
      _tab = LibraryTab.all;
      _sort = LibrarySort.track;
      _order = LibraryOrder.ascending;
    });
  }

  void _selectGenre(String genre) {
    _open(() {
      _genreFilter = genre;
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
        const PopupMenuItem<Object>(
          value: 'play-next',
          child: Text('Play next'),
        ),
        const PopupMenuItem<Object>(
          value: 'add-to-queue',
          child: Text('Add to queue'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          value: 'details',
          child: Text('View details'),
        ),
        const PopupMenuDivider(),
        for (final list in lists)
          PopupMenuItem<Object>(value: list.id, child: Text(list.name)),
        PopupMenuItem<Object>(
          value: 'new',
          child: Text(lists.isEmpty ? 'New playlist' : 'New playlist…'),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    if (selected == 'play-next') {
      ref.read(playbackControllerProvider.notifier).playNext(track.id);
      return;
    }
    if (selected == 'add-to-queue') {
      ref.read(playbackControllerProvider.notifier).addToQueue(track.id);
      return;
    }
    if (selected == 'details') {
      ref.read(detailSelectionProvider.notifier).inspect(track.id);
      return;
    }
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
    ref.listen(libraryNavigationProvider, (_, request) {
      final artist = request.artist;
      if (artist == null) return;
      final album = request.album;
      if (album == null) {
        _selectArtist(artist);
      } else {
        _selectAlbum(artist, album);
      }
    });
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
    final index = ref.watch(libraryIndexProvider);
    final folder = _tab == LibraryTab.folders
        ? folders.where((f) => f.id == _folderId).firstOrNull
        : null;
    final viewingFolder = folder != null;
    final key = (
      index,
      _query,
      _artistFilter,
      _albumFilter,
      _genreFilter,
      folder?.id,
      _sort,
      _order,
    );
    if (_viewKey != key) {
      _viewKey = key;
      _view = LibraryView(
        index: index,
        query: _query,
        artist: _artistFilter,
        album: _albumFilter,
        genre: _genreFilter,
        folderId: folder?.id,
        sort: _sort,
        order: _order,
      );
    }
    final view = _view!;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final viewingPlaylist = _tab == LibraryTab.playlists && _playlistId != null;
    final playlistTracks = viewingPlaylist
        ? (ref.watch(playlistTracksProvider(_playlistId!)).value ?? const [])
        : const <Track>[];
    final showTable =
        _tab == LibraryTab.all || viewingFolder || viewingPlaylist;
    // Catalogue Play All resolves sorting only when clicked.
    List<Track> tracksToPlay() =>
        viewingPlaylist ? playlistTracks : view.sorted;
    final tableTracks = showTable ? tracksToPlay() : const <Track>[];
    final canPlay = viewingPlaylist
        ? playlistTracks.isNotEmpty
        : view.filtered.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          onSearch: _onSearch,
                          hint: _tab == LibraryTab.folders && !viewingFolder
                              ? 'Search folders'
                              : 'Search your library',
                        ),
                        const SizedBox(height: 16),
                        _Tabs(selected: _tab, onSelect: _selectTab),
                        const SizedBox(height: 12),
                        if (viewingFolder) ...[
                          Row(
                            children: [
                              LibraryTextAction(
                                label: 'All folders',
                                onTap: () => _selectTab(LibraryTab.folders),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  folder.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: palette.inkMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_tab != LibraryTab.folders || viewingFolder)
                          _Actions(
                            sort: _sort,
                            order: _order,
                            canPlay: canPlay,
                            showSort: _tab != LibraryTab.playlists,
                            showView: showTable,
                            trackLayout: ref
                                .watch(appearanceProvider)
                                .trackLayout,
                            onPlayAll: () {
                              ref
                                  .read(playbackControllerProvider.notifier)
                                  .playTracks(
                                    tracksToPlay().map((t) => t.id).toList(),
                                    shuffle: false,
                                  );
                            },
                            onShuffle: () {
                              ref
                                  .read(playbackControllerProvider.notifier)
                                  .playTracks(
                                    tracksToPlay().map((t) => t.id).toList(),
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
                              if (_tab == LibraryTab.all &&
                                  (_artistFilter != null ||
                                      _albumFilter != null ||
                                      _genreFilter != null))
                                LibraryTextAction(
                                  label: 'All tracks',
                                  onTap: () => _selectTab(LibraryTab.all),
                                ),
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
                                    if (!mounted ||
                                        _tab != LibraryTab.playlists ||
                                        _playlistId != id) {
                                      return;
                                    }
                                    _selectTab(LibraryTab.playlists);
                                  },
                                  muted: true,
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          // Each history entry owns its scroll storage. The
                          // identity key recreates the scrollable on navigation,
                          // restoring its offset during layout, before painting.
                          child: PageStorage(
                            key: ObjectKey(_scrollStorage),
                            bucket: _scrollStorage,
                            child: KeyedSubtree(
                              key: const PageStorageKey('library-content'),
                              child:
                                  _tab == LibraryTab.folders && !viewingFolder
                                  ? LibraryFoldersPanel(
                                      query: _query,
                                      onOpen: (selected) {
                                        _open(() {
                                          _folderId = selected.id;
                                        });
                                      },
                                    )
                                  : _tab == LibraryTab.playlists &&
                                        !viewingPlaylist
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
                                        _open(() => _playlistId = playlist.id);
                                      },
                                    )
                                  : allTracks.isEmpty &&
                                        !viewingPlaylist &&
                                        !viewingFolder
                                  ? _EmptyLibrary(palette: palette)
                                  : showTable
                                  ? tableTracks.isEmpty
                                        ? _EmptyLibrary(
                                            palette: palette,
                                            text: viewingPlaylist
                                                ? 'This playlist is empty. Right-click a track to add it.'
                                                : viewingFolder &&
                                                      _search.text
                                                          .trim()
                                                          .isEmpty
                                                ? 'No tracks in this folder yet.'
                                                : 'No matching tracks.',
                                          )
                                        : LibraryTrackTable(
                                            tracks: tableTracks,
                                            bottomInset: _history.isEmpty
                                                ? 0
                                                : 64,
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
                                      artists: _tab == LibraryTab.artists
                                          ? view.artists
                                          : const [],
                                      albums: _tab == LibraryTab.albums
                                          ? view.albums
                                          : const [],
                                      genres: _tab == LibraryTab.genres
                                          ? view.genres
                                          : const [],
                                      playlists: playlists,
                                      onSelectArtist: _selectArtist,
                                      onSelectAlbum: _selectAlbum,
                                      onSelectGenre: _selectGenre,
                                      onSelectPlaylist: (playlist) {
                                        _open(() => _playlistId = playlist.id);
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_history.isNotEmpty)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: _LibraryBackButton(
                        label: 'Back to ${_history.last.tab.label}',
                        onPressed: _goBack,
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

class _LibraryBackButton extends StatelessWidget {
  const _LibraryBackButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Material(
      color: palette.bg,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: palette.hairline)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        key: const ValueKey('library-back'),
        tooltip: label,
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back, size: 20),
        color: palette.ink,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onSearch,
    this.hint = 'Search your library',
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= 280;
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
                  hintText: hint,
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
