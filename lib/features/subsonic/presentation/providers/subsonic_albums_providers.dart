import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_core_providers.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_connection_providers.dart';

class SubsonicAlbumSortNotifier extends Notifier<SubsonicAlbumSort> {
  @override
  SubsonicAlbumSort build() => SubsonicAlbumSort.alphabeticalByName;

  void setSort(SubsonicAlbumSort sort) {
    state = sort;
  }
}

final subsonicAlbumSortProvider =
    NotifierProvider<SubsonicAlbumSortNotifier, SubsonicAlbumSort>(
      SubsonicAlbumSortNotifier.new,
    );

class SubsonicAlbumsState {
  const SubsonicAlbumsState({
    this.albums = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<SubsonicAlbum> albums;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  SubsonicAlbumsState copyWith({
    List<SubsonicAlbum>? albums,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return SubsonicAlbumsState(
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class SubsonicAlbumsNotifier extends Notifier<SubsonicAlbumsState> {
  static const int pageSize = 100;

  @override
  SubsonicAlbumsState build() {
    final conn = ref.watch(subsonicConnectionProvider);
    final sort = ref.watch(subsonicAlbumSortProvider);

    if (!conn.isConnected) {
      return const SubsonicAlbumsState();
    }

    Future.microtask(() => loadInitial(sort));
    return const SubsonicAlbumsState(isLoading: true);
  }

  Future<void> loadInitial(SubsonicAlbumSort sort) async {
    final client = ref.read(subsonicClientProvider);
    if (client == null) {
      state = const SubsonicAlbumsState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final albums = await client.getAlbumList(
        type: sort.apiValue,
        size: pageSize,
        offset: 0,
      );
      state = SubsonicAlbumsState(
        albums: albums,
        isLoading: false,
        hasMore: albums.length >= pageSize,
      );
    } catch (e) {
      state = SubsonicAlbumsState(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final client = ref.read(subsonicClientProvider);
    final sort = ref.read(subsonicAlbumSortProvider);
    if (client == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await client.getAlbumList(
        type: sort.apiValue,
        size: pageSize,
        offset: state.albums.length,
      );
      state = state.copyWith(
        albums: [...state.albums, ...more],
        isLoadingMore: false,
        hasMore: more.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadAll() async {
    if (state.isLoading) return;
    final client = ref.read(subsonicClientProvider);
    final sort = ref.read(subsonicAlbumSortProvider);
    if (client == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final all = await client.getAllAlbums(type: sort.apiValue, pageSize: 500);
      state = SubsonicAlbumsState(
        albums: all,
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final subsonicAlbumsNotifierProvider =
    NotifierProvider<SubsonicAlbumsNotifier, SubsonicAlbumsState>(
      SubsonicAlbumsNotifier.new,
    );

final subsonicAlbumsProvider = Provider<AsyncValue<List<SubsonicAlbum>>>((ref) {
  final state = ref.watch(subsonicAlbumsNotifierProvider);
  if (state.isLoading) {
    return const AsyncValue.loading();
  }
  if (state.error != null) {
    return AsyncValue.error(state.error!, StackTrace.current);
  }
  return AsyncValue.data(state.albums);
});
