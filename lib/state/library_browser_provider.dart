import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/library_query.dart';

typedef LibraryLocation = ({
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
  LibraryTrackFilters filters,
});

class LibraryBrowserState {
  const LibraryBrowserState({
    this.tab = LibraryTab.all,
    this.sort = LibrarySort.title,
    this.order = LibraryOrder.ascending,
    this.searchQuery = '',
    this.artistFilter,
    this.albumFilter,
    this.genreFilter,
    this.playlistId,
    this.folderId,
    this.filters = const LibraryTrackFilters(),
    this.selectionMode = false,
    this.selectedTrackIds = const {},
    this.playlistBusy = false,
    required this.history,
    required this.scrollStorage,
  });

  final LibraryTab tab;
  final LibrarySort sort;
  final LibraryOrder order;
  final String searchQuery;
  final String? artistFilter;
  final String? albumFilter;
  final String? genreFilter;
  final int? playlistId;
  final int? folderId;
  final LibraryTrackFilters filters;
  final bool selectionMode;
  final Set<int> selectedTrackIds;
  final bool playlistBusy;
  final List<LibraryLocation> history;
  final PageStorageBucket scrollStorage;

  LibraryBrowserState copyWith({
    LibraryTab? tab,
    LibrarySort? sort,
    LibraryOrder? order,
    String? searchQuery,
    String? Function()? artistFilter,
    String? Function()? albumFilter,
    String? Function()? genreFilter,
    int? Function()? playlistId,
    int? Function()? folderId,
    LibraryTrackFilters? filters,
    bool? selectionMode,
    Set<int>? selectedTrackIds,
    bool? playlistBusy,
    List<LibraryLocation>? history,
    PageStorageBucket? scrollStorage,
  }) {
    return LibraryBrowserState(
      tab: tab ?? this.tab,
      sort: sort ?? this.sort,
      order: order ?? this.order,
      searchQuery: searchQuery ?? this.searchQuery,
      artistFilter: artistFilter != null ? artistFilter() : this.artistFilter,
      albumFilter: albumFilter != null ? albumFilter() : this.albumFilter,
      genreFilter: genreFilter != null ? genreFilter() : this.genreFilter,
      playlistId: playlistId != null ? playlistId() : this.playlistId,
      folderId: folderId != null ? folderId() : this.folderId,
      filters: filters ?? this.filters,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
      playlistBusy: playlistBusy ?? this.playlistBusy,
      history: history ?? this.history,
      scrollStorage: scrollStorage ?? this.scrollStorage,
    );
  }
}

class LibraryBrowserNotifier extends Notifier<LibraryBrowserState> {
  @override
  LibraryBrowserState build() {
    return LibraryBrowserState(history: [], scrollStorage: PageStorageBucket());
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    clearSelection();
  }

  void clearSelection() {
    if (state.selectionMode || state.selectedTrackIds.isNotEmpty) {
      state = state.copyWith(selectionMode: false, selectedTrackIds: const {});
    }
  }

  void setSelectionMode(bool value) {
    state = state.copyWith(selectionMode: value);
  }

  void toggleSelection(int trackId) {
    final newSelected = Set<int>.from(state.selectedTrackIds);
    if (!newSelected.add(trackId)) {
      newSelected.remove(trackId);
    }
    state = state.copyWith(selectedTrackIds: newSelected);
  }

  void selectAll(Iterable<int> trackIds) {
    state = state.copyWith(selectedTrackIds: Set<int>.from(trackIds));
  }

  void setPlaylistBusy(bool busy) {
    state = state.copyWith(playlistBusy: busy);
  }

  void setFilters(LibraryTrackFilters filters) {
    state = state.copyWith(filters: filters);
    clearSelection();
  }

  void setSort(LibrarySort sort) {
    state = state.copyWith(sort: sort);
  }

  void setOrder(LibraryOrder order) {
    state = state.copyWith(order: order);
  }

  void open({
    LibraryTab? tab,
    LibrarySort? sort,
    LibraryOrder? order,
    String? artistFilter,
    String? albumFilter,
    String? genreFilter,
    int? playlistId,
    int? folderId,
    LibraryTrackFilters? filters,
    TextEditingValue? searchValue,
  }) {
    final currentSearch =
        searchValue ?? TextEditingValue(text: state.searchQuery);

    final newHistory = List<LibraryLocation>.from(state.history)
      ..add((
        tab: state.tab,
        sort: state.sort,
        order: state.order,
        search: currentSearch,
        artist: state.artistFilter,
        album: state.albumFilter,
        genre: state.genreFilter,
        playlistId: state.playlistId,
        folderId: state.folderId,
        scrollStorage: state.scrollStorage,
        filters: state.filters,
      ));

    state = state.copyWith(
      history: newHistory,
      scrollStorage: PageStorageBucket(),
      tab: tab ?? state.tab,
      sort: sort ?? state.sort,
      order: order ?? state.order,
      artistFilter: () => artistFilter ?? state.artistFilter,
      albumFilter: () => albumFilter ?? state.albumFilter,
      genreFilter: () => genreFilter ?? state.genreFilter,
      playlistId: () => playlistId ?? state.playlistId,
      folderId: () => folderId ?? state.folderId,
      filters: filters ?? state.filters,
    );

    clearSelection();
  }

  void goBack(void Function(String) onRestoreSearch) {
    if (state.history.isEmpty) return;
    final newHistory = List<LibraryLocation>.from(state.history);
    final previous = newHistory.removeLast();

    state = state.copyWith(
      history: newHistory,
      tab: previous.tab,
      sort: previous.sort,
      order: previous.order,
      artistFilter: () => previous.artist,
      albumFilter: () => previous.album,
      genreFilter: () => previous.genre,
      playlistId: () => previous.playlistId,
      folderId: () => previous.folderId,
      scrollStorage: previous.scrollStorage,
      filters: previous.filters,
      searchQuery: previous.search.text,
    );

    onRestoreSearch(previous.search.text);
    clearSelection();
  }

  void selectTab(LibraryTab tab, void Function(String) onRestoreSearch) {
    if (state.history.isNotEmpty && state.history.last.tab == tab) {
      goBack(onRestoreSearch);
      return;
    }

    state = state.copyWith(
      scrollStorage: (state.tab != tab || state.history.isNotEmpty)
          ? PageStorageBucket()
          : state.scrollStorage,
      history: const [],
      tab: tab,
      folderId: () => null,
      playlistId: () => null,
      artistFilter: () => null,
      albumFilter: () => null,
      genreFilter: () => null,
    );
    clearSelection();
  }

  void clearHistory() {
    state = state.copyWith(
      scrollStorage: PageStorageBucket(),
      history: const [],
      folderId: () => null,
      playlistId: () => null,
      artistFilter: () => null,
      albumFilter: () => null,
      genreFilter: () => null,
      filters: const LibraryTrackFilters(),
    );
    clearSelection();
  }

  void selectSourceSwitch(LibraryTab newTabIfFolders) {
    state = state.copyWith(
      scrollStorage: PageStorageBucket(),
      history: const [],
      tab: newTabIfFolders,
      folderId: () => null,
      playlistId: () => null,
      artistFilter: () => null,
      albumFilter: () => null,
      genreFilter: () => null,
      filters: const LibraryTrackFilters(),
    );
    clearSelection();
  }

  void selectArtist(String name) {
    open(
      artistFilter: name,
      albumFilter: null,
      genreFilter: null,
      tab: LibraryTab.all,
    );
  }

  void selectAlbum(String artist, String album) {
    open(
      artistFilter: artist,
      albumFilter: album,
      genreFilter: null,
      tab: LibraryTab.all,
      sort: LibrarySort.track,
      order: LibraryOrder.ascending,
    );
  }

  void selectGenre(String genre) {
    open(
      genreFilter: genre,
      artistFilter: null,
      albumFilter: null,
      tab: LibraryTab.all,
    );
  }

  void removePlaylistHistory(int playlistId) {
    final newHistory = state.history
        .where((location) => location.playlistId != playlistId)
        .toList();
    state = state.copyWith(history: newHistory);
  }
}

final libraryBrowserProvider =
    NotifierProvider<LibraryBrowserNotifier, LibraryBrowserState>(
      LibraryBrowserNotifier.new,
    );
