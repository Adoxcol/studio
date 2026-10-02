import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio/library/library_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/state/library_browser_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_browse_view.dart';
import 'package:studio/features/library_folders/presentation/library_folders_panel.dart';
import 'package:studio/features/library_source/presentation/library_source_provider.dart';
import 'package:studio/features/metadata_editor/presentation/batch_metadata_editor_dialog.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/features/playlist_management/presentation/playlist_dialogs.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/features/smart_playlists/presentation/smart_playlist_editor.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/library_browser/library_track_table.dart';
import 'package:studio/ui/track_actions/track_actions_menu.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_providers.dart';

part 'library_page_chrome.dart';
part 'library_filter_dialog.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _search = TextEditingController();
  Timer? _searchTimer;
  LibraryView? _view;
  Object? _viewKey;

  void _onSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        ref.read(libraryBrowserProvider.notifier).setSearchQuery(_search.text);
      }
    });
  }

  void _syncSearch() {
    _searchTimer?.cancel();
    ref.read(libraryBrowserProvider.notifier).setSearchQuery(_search.text);
  }

  List<String> _selectedRemoteLocators(List<Track> visibleTracks, Set<int> selectedTrackIds) => [
    for (final track in visibleTracks)
      if (selectedTrackIds.contains(track.id) &&
          track.source == TrackLocator.subsonic)
        track.locator,
  ];

  Future<void> _editSelected(List<Track> visibleTracks, Set<int> selectedTrackIds) async {
    final selected = visibleTracks
        .where((track) => selectedTrackIds.contains(track.id))
        .toList();
    if (selected.isEmpty) return;
    final changed = await showBatchMetadataEditor(
      context: context,
      tracks: selected,
    );
    if (changed && mounted) {
      ref.read(libraryBrowserProvider.notifier).clearSelection();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _open(VoidCallback updateState) {
    _syncSearch(); // force immediate sync before capturing
    updateState();
    _search.clear();
    ref.read(libraryBrowserProvider.notifier).setSearchQuery('');
  }

  void _goBack() {
    ref.read(libraryBrowserProvider.notifier).goBack((searchVal) {
      _search.value = TextEditingValue(
        text: searchVal,
        selection: TextSelection.collapsed(offset: searchVal.length),
      );
      _syncSearch();
    });
  }

  void _selectTab(LibraryTab tab) {
    ref.read(libraryBrowserProvider.notifier).selectTab(tab, (searchVal) {
      _search.value = TextEditingValue(
        text: searchVal,
        selection: TextSelection.collapsed(offset: searchVal.length),
      );
      _syncSearch();
    });
  }

  void _selectSource(LibrarySource source, LibraryTab currentTab) {
    ref.read(librarySourceProvider.notifier).select(source);
    _search.clear();
    final newTabIfFolders = (source == LibrarySource.navidrome && currentTab == LibraryTab.folders)
      ? LibraryTab.all
      : currentTab;
    ref.read(libraryBrowserProvider.notifier).selectSourceSwitch(newTabIfFolders);
  }

  Future<void> _playlistAction(Future<void> Function() action) async {
    final notifier = ref.read(libraryBrowserProvider.notifier);
    final browserState = ref.read(libraryBrowserProvider);
    if (browserState.playlistBusy) return;

    notifier.setPlaylistBusy(true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update the playlist. $error')),
        );
      }
    } finally {
      if (mounted) {
        notifier.setPlaylistBusy(false);
      }
    }
  }

  Future<void> _createPlaylist() => _playlistAction(() async {
    final name = await showPlaylistNameDialog(context);
    if (name == null || !mounted) return;
    await ref.read(studioDatabaseProvider).createPlaylist(name);
  });

  Future<void> _renamePlaylist(Playlist playlist) => _playlistAction(() async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Rename playlist',
      initialName: playlist.name,
      action: 'Rename',
    );
    if (name == null || !mounted) return;
    await ref.read(studioDatabaseProvider).renamePlaylist(playlist.id, name);
  });

  Future<void> _duplicatePlaylist(
    Playlist playlist,
  ) => _playlistAction(() async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Duplicate playlist',
      initialName: '${playlist.name} (copy)',
      action: 'Duplicate',
      description: playlist.smartRules == null
          ? 'Copy every track in its current order. Music files are not copied.'
          : 'Copy the rules into a new smart playlist. The copy will also update automatically.',
    );
    if (name == null || !mounted) return;
    final id = await ref
        .read(studioDatabaseProvider)
        .duplicatePlaylist(playlist.id, name);
    if (mounted) {
      _open(() {
        ref.read(libraryBrowserProvider.notifier).open(
          tab: LibraryTab.playlists,
          playlistId: id,
          filters: const LibraryTrackFilters(),
        );
      });
    }
  });

  Future<void> _deletePlaylist(Playlist playlist) => _playlistAction(() async {
    if (!await confirmPlaylistDeletion(context, playlist) || !mounted) {
      return;
    }
    await ref.read(studioDatabaseProvider).deletePlaylist(playlist.id);
    if (!mounted) return;

    final notifier = ref.read(libraryBrowserProvider.notifier);
    notifier.removePlaylistHistory(playlist.id);

    final browserState = ref.read(libraryBrowserProvider);
    if (browserState.playlistId == playlist.id && browserState.tab == LibraryTab.playlists) {
      _selectTab(LibraryTab.playlists);
    }
  });

  Future<void> _editSmartPlaylist({
    Playlist? playlist,
    SmartPlaylistDefinition? initial,
  }) async {
    final id = await showSmartPlaylistEditor(
      context: context,
      playlist: playlist,
      initial: initial,
    );
    final browserState = ref.read(libraryBrowserProvider);
    if (id == null || !mounted || id == browserState.playlistId) return;

    _open(() {
      ref.read(libraryBrowserProvider.notifier).open(
        tab: LibraryTab.playlists,
        playlistId: id,
        filters: const LibraryTrackFilters(),
      );
    });
  }

  Future<void> _showFilters(
    LibraryTrackFilters trackFilters,
    List<Track> tracks,
    List<LibraryFolder> folders,
  ) async {
    final selected = await showDialog<LibraryTrackFilters>(
      context: context,
      builder: (context) => _LibraryFilterDialog(
        initial: trackFilters,
        tracks: tracks,
        folders: folders,
      ),
    );
    if (selected != null && mounted) {
      ref.read(libraryBrowserProvider.notifier).setFilters(selected);
    }
  }

  Future<void> _showTrackMenu(Track track, Offset globalPosition) async {
    await showTrackActions(
      context: context,
      ref: ref,
      track: track,
      position: globalPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(libraryNavigationProvider, (_, request) {
      final playlistId = request.playlistId;
      final notifier = ref.read(libraryBrowserProvider.notifier);
      if (playlistId != null) {
        _open(() {
          notifier.open(
            tab: LibraryTab.playlists,
            playlistId: playlistId,
            artistFilter: null,
            albumFilter: null,
            genreFilter: null,
            folderId: null,
            filters: const LibraryTrackFilters(),
          );
        });
        return;
      }
      final artist = request.artist;
      if (artist == null) return;
      final album = request.album;
      if (album == null) {
        _open(() {
          notifier.selectArtist(artist);
        });
      } else {
        _open(() {
          notifier.selectAlbum(artist, album);
        });
      }
    });

    final palette = StudioPalette.of(context);
    final scanActive = ref.watch(libraryScanProvider.select((s) => s.active));
    final localFolders = ref.watch(libraryFoldersProvider).value ?? const [];
    final remoteTracks = ref.watch(subsonicTracksProvider).value ?? const [];
    final hasNavidrome = ref.watch(subsonicConfigProvider) != null;
    final source = effectiveLibrarySource(
      chosen: ref.watch(librarySourceProvider),
      hasLocalFolders: localFolders.isNotEmpty,
      hasNavidrome: hasNavidrome,
    );
    final isRemoteSource = source == LibrarySource.navidrome;
    // Folders belong to this computer; a Navidrome library has none here.
    final folders = isRemoteSource ? const <LibraryFolder>[] : localFolders;
    final tracks = ref.watch(libraryTracksProvider);
    final browserState = ref.watch(libraryBrowserProvider);

    // Initial search sync in case it differs (rare, but good for safety)
    if (_search.text != browserState.searchQuery && _searchTimer == null) {
      _search.text = browserState.searchQuery;
    }

    return tracks.when(
      data: (rows) => _body(
        context,
        palette,
        isRemoteSource ? remoteTracks : rows,
        folders,
        localFolders,
        scanActive,
        source,
        hasNavidrome,
        browserState,
      ),
      loading: () => _body(
        context,
        palette,
        isRemoteSource ? remoteTracks : const <Track>[],
        folders,
        localFolders,
        scanActive,
        source,
        hasNavidrome,
        browserState,
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
    List<LibraryFolder> localFolders,
    bool scanning,
    LibrarySource source,
    bool hasNavidrome,
    LibraryBrowserState browserState,
  ) {
    final notifier = ref.read(libraryBrowserProvider.notifier);
    final index = LibraryIndex(allTracks);
    final remote = source == LibrarySource.navidrome;
    final tab = remote && browserState.tab == LibraryTab.folders ? LibraryTab.all : browserState.tab;
    final folder = tab == LibraryTab.folders
        ? folders.where((f) => f.id == browserState.folderId).firstOrNull
        : null;
    final viewingFolder = folder != null;
    final folderFilterId = folder?.id;
    final key = (
      index,
      browserState.searchQuery,
      browserState.artistFilter,
      browserState.albumFilter,
      browserState.genreFilter,
      folder?.id,
      browserState.filters.losslessOnly,
      browserState.filters.minimumSampleRateHz,
      browserState.filters.minimumBitrateKbps,
      browserState.filters.genre,
      browserState.filters.year,
      browserState.filters.folderId,
      browserState.sort,
      browserState.order,
    );
    if (_viewKey != key) {
      _viewKey = key;
      _view = LibraryView(
        index: index,
        query: browserState.searchQuery,
        artist: browserState.artistFilter,
        album: browserState.albumFilter,
        genre: browserState.genreFilter,
        folderId: folderFilterId,
        filters: browserState.filters,
        sort: browserState.sort,
        order: browserState.order,
      );
    }
    final view = _view!;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final viewingPlaylist = tab == LibraryTab.playlists && browserState.playlistId != null;
    final selectedPlaylist = viewingPlaylist
        ? ref.watch(playlistsByIdProvider)[browserState.playlistId]
        : null;
    final smartPlaylist =
        viewingPlaylist && selectedPlaylist?.smartRules != null;
    final playlistTracks = viewingPlaylist
        ? (ref.watch(playlistTracksProvider(browserState.playlistId!)).value ?? const [])
        : const <Track>[];
    final filteredPlaylistTracks = viewingPlaylist
        ? playlistTracks.where(browserState.filters.matches).toList()
        : const <Track>[];
    final showTable = tab == LibraryTab.all || viewingFolder || viewingPlaylist;
    // Catalogue Play All resolves sorting only when clicked.
    List<Track> tracksToPlay() =>
        viewingPlaylist ? filteredPlaylistTracks : view.sorted;
    final tableTracks = showTable ? tracksToPlay() : const <Track>[];
    final canPlay = viewingPlaylist
        ? filteredPlaylistTracks.isNotEmpty
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
                          hint: tab == LibraryTab.folders && !viewingFolder
                              ? 'Search folders'
                              : 'Search your library',
                          trailing: hasNavidrome
                              ? _SourceSwitch(
                                  selected: source,
                                  onSelect: (s) => _selectSource(s, browserState.tab),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _Tabs(
                          selected: tab,
                          tabs: [
                            for (final t in LibraryTab.values)
                              if (!remote || t != LibraryTab.folders) t,
                          ],
                          onSelect: _selectTab,
                        ),
                        const SizedBox(height: 12),
                        if (viewingPlaylist && selectedPlaylist != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selectedPlaylist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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
                        if (tab != LibraryTab.folders || viewingFolder)
                          _Actions(
                            sort: browserState.sort,
                            order: browserState.order,
                            canPlay: canPlay,
                            showSort: tab != LibraryTab.playlists,
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
                            onCycleSort: () {
                              final next = LibraryQuery.nextSort(browserState.sort);
                              // Date added starts newest first; leaving it
                              // returns to A-Z.
                              if (next == LibrarySort.added ||
                                  browserState.sort == LibrarySort.added) {
                                notifier.setOrder(next.defaultOrder);
                              }
                              notifier.setSort(next);
                            },
                            onToggleOrder: () {
                              notifier.setOrder(LibraryQuery.toggleOrder(browserState.order));
                            },
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
                            filterCount: browserState.filters.activeCount,
                            onFilters: () =>
                                _showFilters(browserState.filters, allTracks, localFolders),
                            extras: [
                              if (showTable && !viewingPlaylist)
                                LibraryTextAction(
                                  label: 'Save as smart playlist',
                                  onTap: () => _editSmartPlaylist(
                                    initial:
                                        SmartPlaylistDefinition.fromFilters(
                                          filters: browserState.filters,
                                          query: browserState.searchQuery,
                                          artist: browserState.artistFilter,
                                          album: browserState.albumFilter,
                                          genre: browserState.genreFilter,
                                          folderId: folder?.id,
                                          sort: browserState.sort,
                                          order: browserState.order,
                                        ),
                                  ),
                                ),
                              if (tab == LibraryTab.playlists &&
                                  !viewingPlaylist)
                                LibraryTextAction(
                                  label: 'New smart playlist',
                                  onTap: () => _editSmartPlaylist(),
                                ),
                              if (smartPlaylist)
                                LibraryTextAction(
                                  label: 'Edit rules',
                                  onTap: () => _editSmartPlaylist(
                                    playlist: selectedPlaylist,
                                  ),
                                ),
                              if (browserState.selectionMode) ...[
                                Text(
                                  '${tableTracks.where((track) => browserState.selectedTrackIds.contains(track.id)).length} selected',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                LibraryTextAction(
                                  label: 'Select all',
                                  onTap: () {
                                    notifier.selectAll(tableTracks.map((track) => track.id));
                                  },
                                ),
                              ],
                              if (browserState.selectionMode &&
                                  browserState.selectedTrackIds.isNotEmpty)
                                LibraryTextAction(
                                  label: 'Edit metadata',
                                  onTap: () => _editSelected(tableTracks, browserState.selectedTrackIds),
                                ),
                              if (browserState.selectionMode &&
                                  _selectedRemoteLocators(
                                    tableTracks, browserState.selectedTrackIds
                                  ).isNotEmpty &&
                                  ref.watch(
                                    offlineDownloadsProvider.select(
                                      (s) => s.available,
                                    ),
                                  ))
                                LibraryTextAction(
                                  label: 'Download for offline',
                                  onTap: () => ref
                                      .read(offlineDownloadsProvider.notifier)
                                      .download(
                                        _selectedRemoteLocators(tableTracks, browserState.selectedTrackIds),
                                      ),
                                ),
                              if (showTable)
                                LibraryTextAction(
                                  label: browserState.selectionMode
                                      ? 'Done selecting'
                                      : 'Select',
                                  onTap: () {
                                    if (browserState.selectionMode) {
                                      notifier.clearSelection();
                                    } else {
                                      notifier.setSelectionMode(true);
                                    }
                                  },
                                  muted: browserState.selectionMode,
                                ),
                              if (tab == LibraryTab.all &&
                                  (browserState.artistFilter != null ||
                                      browserState.albumFilter != null ||
                                      browserState.genreFilter != null))
                                LibraryTextAction(
                                  label: 'All tracks',
                                  onTap: () => _selectTab(LibraryTab.all),
                                ),
                              if (tab == LibraryTab.playlists)
                                LibraryTextAction(
                                  label: 'New playlist',
                                  onTap: _createPlaylist,
                                  enabled: !browserState.playlistBusy,
                                ),
                              if (viewingPlaylist &&
                                  selectedPlaylist != null) ...[
                                LibraryTextAction(
                                  label: 'Rename playlist',
                                  enabled: !browserState.playlistBusy,
                                  onTap: () =>
                                      _renamePlaylist(selectedPlaylist),
                                ),
                                LibraryTextAction(
                                  label: 'Duplicate playlist',
                                  enabled: !browserState.playlistBusy,
                                  onTap: () =>
                                      _duplicatePlaylist(selectedPlaylist),
                                ),
                                if (!smartPlaylist)
                                  LibraryTextAction(
                                    label: 'Reorder tracks',
                                    enabled:
                                        !browserState.playlistBusy &&
                                        playlistTracks.length > 1,
                                    onTap: () => _playlistAction(
                                      () => showPlaylistOrderEditor(
                                        context,
                                        database: ref.read(
                                          studioDatabaseProvider,
                                        ),
                                        playlist: selectedPlaylist,
                                      ),
                                    ),
                                  ),
                                LibraryTextAction(
                                  label: 'Delete playlist',
                                  enabled: !browserState.playlistBusy,
                                  onTap: () =>
                                      _deletePlaylist(selectedPlaylist),
                                  muted: true,
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          // Each history entry owns its scroll storage. The
                          // identity key recreates the scrollable on navigation,
                          // restoring its offset during layout, before painting.
                          child: PageStorage(
                            key: ObjectKey(browserState.scrollStorage),
                            bucket: browserState.scrollStorage,
                            child: KeyedSubtree(
                              key: const PageStorageKey('library-content'),
                              child: tab == LibraryTab.folders && !viewingFolder
                                  ? LibraryFoldersPanel(
                                      query: browserState.searchQuery,
                                      onOpen: (selected) {
                                        _open(() {
                                          notifier.open(folderId: selected.id);
                                        });
                                      },
                                    )
                                  : tab == LibraryTab.playlists &&
                                        !viewingPlaylist
                                  ? LibraryBrowseView(
                                      tab: tab,
                                      artists: const [],
                                      albums: const [],
                                      genres: const [],
                                      playlists: playlists,
                                      onSelectArtist: (name) => _open(() => notifier.selectArtist(name)),
                                      onSelectAlbum: (artist, album) => _open(() => notifier.selectAlbum(artist, album)),
                                      onSelectGenre: (genre) => _open(() => notifier.selectGenre(genre)),
                                      onSelectPlaylist: (playlist) {
                                        _open(() => notifier.open(playlistId: playlist.id));
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
                                                ? smartPlaylist
                                                      ? 'No tracks match this smart playlist. Edit its rules or add music to your library.'
                                                      : 'This playlist is empty. Right-click a track to add it.'
                                                : viewingFolder &&
                                                      _search.text
                                                          .trim()
                                                          .isEmpty
                                                ? 'No tracks in this folder yet.'
                                                : 'No matching tracks.',
                                          )
                                        : LibraryTrackTable(
                                            tracks: tableTracks,
                                            selectionMode: browserState.selectionMode,
                                            selectedIds: browserState.selectedTrackIds,
                                            onToggleSelection: (track) => notifier.toggleSelection(track.id),
                                            bottomInset: browserState.history.isEmpty
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
                                      tab: tab,
                                      artists: tab == LibraryTab.artists
                                          ? view.artists
                                          : const [],
                                      albums: tab == LibraryTab.albums
                                          ? view.albums
                                          : const [],
                                      genres: tab == LibraryTab.genres
                                          ? view.genres
                                          : const [],
                                      playlists: playlists,
                                      onSelectArtist: (name) => _open(() => notifier.selectArtist(name)),
                                      onSelectAlbum: (artist, album) => _open(() => notifier.selectAlbum(artist, album)),
                                      onSelectGenre: (genre) => _open(() => notifier.selectGenre(genre)),
                                      onSelectPlaylist: (playlist) {
                                        _open(() => notifier.open(playlistId: playlist.id));
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (browserState.history.isNotEmpty)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: _LibraryBackButton(
                        label: 'Back to ${browserState.history.last.tab.label}',
                        onPressed: _goBack,
                      ),
                    ),
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: _RefreshButton(
                      enabled: !scanning && !remote && folders.isNotEmpty,
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
