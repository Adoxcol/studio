import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/theming/studio_palette.dart';

class SubsonicPage extends ConsumerStatefulWidget {
  const SubsonicPage({super.key});

  @override
  ConsumerState<SubsonicPage> createState() => _SubsonicPageState();
}

class _SubsonicPageState extends ConsumerState<SubsonicPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _tracksFilterController = TextEditingController();

  String _currentTab = 'albums';
  SubsonicAlbum? _selectedAlbum;
  SubsonicArtist? _selectedArtist;
  List<SubsonicAlbum>? _artistAlbums;
  bool _loadingArtistAlbums = false;
  List<SubsonicSong>? _albumSongs;
  bool _loadingAlbum = false;
  Map<String, dynamic>? _searchResults;
  String _tracksFilter = '';

  @override
  void initState() {
    super.initState();
    final config = ref.read(subsonicConfigProvider);
    if (config != null) {
      _urlController.text = config.serverUrl;
      _userController.text = config.username;
      _passController.text = config.password;
      _nameController.text = config.serverName;
    }
    _tracksFilterController.addListener(() {
      setState(() {
        _tracksFilter = _tracksFilterController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    _tracksFilterController.dispose();
    super.dispose();
  }

  void _connect() {
    final config = SubsonicServerConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text,
      serverName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Navidrome',
    );
    ref.read(subsonicConfigProvider.notifier).updateConfig(config);
  }

  void _disconnect() {
    ref.read(subsonicPlaybackServiceProvider).clearSubsonicCache();
    ref.read(subsonicConfigProvider.notifier).updateConfig(null);
    setState(() {
      _selectedAlbum = null;
      _selectedArtist = null;
      _artistAlbums = null;
      _albumSongs = null;
      _searchResults = null;
    });
  }

  Future<void> _openAlbum(SubsonicAlbum album) async {
    setState(() {
      _selectedAlbum = album;
      _loadingAlbum = true;
      _albumSongs = null;
    });

    final client = ref.read(subsonicClientProvider);
    if (client == null) return;

    try {
      final songs = await client.getAlbum(album.id);
      if (mounted && _selectedAlbum?.id == album.id) {
        setState(() {
          _albumSongs = songs;
          _loadingAlbum = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAlbum = false);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
      });
      return;
    }
    final client = ref.read(subsonicClientProvider);
    if (client == null) return;

    try {
      final results = await client.search3(query.trim());
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (_) {
      // Ignored
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final config = ref.watch(subsonicConfigProvider);
    final connection = ref.watch(subsonicConnectionProvider);

    if (config == null || !connection.isConnected) {
      return _buildSetupView(context, palette, connection);
    }

    return _buildConnectedView(context, palette, connection);
  }

  Widget _buildSetupView(
    BuildContext context,
    StudioPalette palette,
    SubsonicConnectionInfo connection,
  ) {
    final spectral = GoogleFonts.spectral(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      color: palette.ink,
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: palette.bg,
              border: Border.all(color: palette.hairline),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_outlined,
                        color: palette.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote Music Server', style: spectral),
                        Text(
                          'Subsonic / Navidrome / Airsonic / LMS',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect to your remote music server to stream your collection. Remote tracks remain strictly isolated from your local library catalogue.',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.inkMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (connection.status == SubsonicConnectionStatus.error &&
                    connection.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.accentPressed.withAlpha(30),
                      border: Border.all(color: palette.accentPressed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: palette.accentPressed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            connection.errorMessage!,
                            style: TextStyle(fontSize: 12, color: palette.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildField(
                  label: 'SERVER URL',
                  controller: _urlController,
                  hint: 'https://music.example.com or http://192.168.1.10:4533',
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'USERNAME',
                  controller: _userController,
                  hint: 'username',
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'PASSWORD',
                  controller: _passController,
                  hint: '••••••••',
                  obscure: true,
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'SERVER NAME (OPTIONAL)',
                  controller: _nameController,
                  hint: 'Home Navidrome',
                  palette: palette,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed:
                        connection.status == SubsonicConnectionStatus.connecting
                        ? null
                        : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.ink,
                      foregroundColor: palette.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        connection.status == SubsonicConnectionStatus.connecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Connect to Server',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required StudioPalette palette,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: palette.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(fontSize: 13, color: palette.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: palette.inkDim),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: palette.hairlineSoft.withAlpha(40),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: palette.hairline),
              borderRadius: BorderRadius.circular(6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: palette.accent),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView(
    BuildContext context,
    StudioPalette palette,
    SubsonicConnectionInfo connection,
  ) {
    final scanState = ref.watch(subsonicScanProvider);

    return Column(
      children: [
        // Top Server Bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.hairline)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withAlpha(120),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${connection.serverType} ${connection.serverVersion}'
                    .toUpperCase(),
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 24),
              // Sub tabs
              _buildTabButton('albums', 'Albums', palette),
              _buildTabButton('artists', 'Artists', palette),
              _buildTabButton('tracks', 'Tracks', palette),
              const Spacer(),
              // Scan server library button
              _buildScanButton(palette),
              const SizedBox(width: 12),
              // Search field
              SizedBox(
                width: 220,
                height: 34,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 12, color: palette.ink),
                  onSubmitted: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Search remote server...',
                    hintStyle: TextStyle(fontSize: 12, color: palette.inkDim),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: palette.inkMuted,
                    ),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: palette.hairlineSoft.withAlpha(40),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: palette.hairline),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.power_settings_new, size: 18),
                tooltip: 'Disconnect Server',
                color: palette.inkMuted,
                onPressed: _disconnect,
              ),
            ],
          ),
        ),

        // Live Scanning Progress Bar
        if (scanState.isScanning) _buildScanProgressBar(palette, scanState),

        // Main Content Area
        Expanded(
          child: _selectedAlbum != null
              ? _buildAlbumDetailView(palette)
              : _selectedArtist != null
              ? _buildArtistDetailView(palette)
              : _searchController.text.trim().isNotEmpty &&
                    _searchResults != null
              ? _buildSearchResultsView(palette)
              : _currentTab == 'artists'
              ? _buildArtistsGrid(palette)
              : _currentTab == 'tracks'
              ? _buildTracksView(palette)
              : _buildAlbumsGrid(palette),
        ),
      ],
    );
  }

  Widget _buildScanButton(StudioPalette palette) {
    final scanState = ref.watch(subsonicScanProvider);
    if (scanState.isScanning) {
      return TextButton.icon(
        onPressed: () => ref.read(subsonicScanProvider.notifier).cancelScan(),
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(
          'Scanning (${scanState.currentAlbum}/${scanState.totalAlbums})',
          style: TextStyle(fontSize: 11, color: palette.accent),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => ref.read(subsonicScanProvider.notifier).startScan(),
      icon: Icon(Icons.sync, size: 14, color: palette.ink),
      label: Text(
        'Scan Server',
        style: TextStyle(fontSize: 12, color: palette.ink),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: palette.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildScanProgressBar(
    StudioPalette palette,
    SubsonicScanState scanState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: palette.accent.withAlpha(20),
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scanning remote library: Album ${scanState.currentAlbum} of ${scanState.totalAlbums} • ${scanState.totalTracks} tracks indexed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                    if (scanState.currentAlbumName.isNotEmpty)
                      Flexible(
                        child: Text(
                          scanState.currentAlbumName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: scanState.progress,
                  backgroundColor: palette.hairlineSoft,
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                  minHeight: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Cancel scan',
            onPressed: () =>
                ref.read(subsonicScanProvider.notifier).cancelScan(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, StudioPalette palette) {
    final active =
        _currentTab == tabKey &&
        _selectedAlbum == null &&
        _selectedArtist == null;
    return InkWell(
      onTap: () {
        setState(() {
          _currentTab = tabKey;
          _selectedAlbum = null;
          _selectedArtist = null;
          _artistAlbums = null;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? palette.accent : palette.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid(StudioPalette palette) {
    final albumsState = ref.watch(subsonicAlbumsNotifierProvider);
    final currentSort = ref.watch(subsonicAlbumSortProvider);

    return Column(
      children: [
        // Sort & Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.hairlineSoft)),
          ),
          child: Row(
            children: [
              Text(
                'SORT:',
                style: GoogleFonts.workSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.inkDim,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: SubsonicAlbumSort.values.map((sort) {
                  final active = sort == currentSort;
                  return ChoiceChip(
                    label: Text(sort.label),
                    selected: active,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(subsonicAlbumSortProvider.notifier)
                            .setSort(sort);
                      }
                    },
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? palette.accent : palette.inkMuted,
                    ),
                    selectedColor: palette.accent.withAlpha(30),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: active ? palette.accent : palette.hairline,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              if (albumsState.albums.isNotEmpty)
                Text(
                  '${albumsState.albums.length} albums',
                  style: TextStyle(fontSize: 11, color: palette.inkMuted),
                ),
              if (albumsState.hasMore) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: albumsState.isLoadingMore
                      ? null
                      : () => ref
                            .read(subsonicAlbumsNotifierProvider.notifier)
                            .loadAll(),
                  child: const Text('Load All', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),

        // Grid of Albums
        Expanded(
          child: albumsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : albumsState.error != null
              ? Center(
                  child: Text('Failed to load albums: ${albumsState.error}'),
                )
              : albumsState.albums.isEmpty
              ? const Center(child: Text('No albums found on server.'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (scroll) {
                    if (scroll.metrics.pixels >=
                            scroll.metrics.maxScrollExtent - 200 &&
                        albumsState.hasMore &&
                        !albumsState.isLoadingMore) {
                      ref
                          .read(subsonicAlbumsNotifierProvider.notifier)
                          .loadMore();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                                childAspectRatio: 0.72,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) => _buildAlbumCard(
                              albumsState.albums[idx],
                              palette,
                            ),
                            childCount: albumsState.albums.length,
                          ),
                        ),
                      ),
                      if (albumsState.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (albumsState.hasMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: () => ref
                                    .read(
                                      subsonicAlbumsNotifierProvider.notifier,
                                    )
                                    .loadMore(),
                                child: const Text('Load More Albums'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard(SubsonicAlbum album, StudioPalette palette) {
    final client = ref.read(subsonicClientProvider);
    final coverUri = client?.buildCoverArtUri(album.coverArtId);

    return InkWell(
      onTap: () => _openAlbum(album),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: palette.hairlineSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: coverUri != null
                  ? Image.network(
                      coverUri.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.album,
                          size: 48,
                          color: palette.inkDim,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.album, size: 48, color: palette.inkDim),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsGrid(StudioPalette palette) {
    final artistsAsync = ref.watch(subsonicArtistsProvider);

    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load artists: $err')),
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(child: Text('No artists found on server.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: artists.length,
          separatorBuilder: (context, index) =>
              Divider(color: palette.hairlineSoft, height: 1),
          itemBuilder: (context, idx) {
            final artist = artists[idx];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: palette.hairlineSoft,
                child: Icon(
                  Icons.person_outline,
                  color: palette.inkMuted,
                  size: 20,
                ),
              ),
              title: Text(
                artist.name,
                style: TextStyle(fontSize: 14, color: palette.ink),
              ),
              subtitle: Text(
                '${artist.albumCount} ${artist.albumCount == 1 ? "album" : "albums"}',
                style: TextStyle(fontSize: 11, color: palette.inkMuted),
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () async {
                setState(() {
                  _selectedArtist = artist;
                  _loadingArtistAlbums = true;
                  _artistAlbums = null;
                });
                final client = ref.read(subsonicClientProvider);
                if (client == null) return;
                try {
                  final albums = await client.getArtist(artist.id);
                  if (mounted && _selectedArtist?.id == artist.id) {
                    setState(() {
                      _artistAlbums = albums;
                      _loadingArtistAlbums = false;
                    });
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() => _loadingArtistAlbums = false);
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildArtistDetailView(StudioPalette palette) {
    final artist = _selectedArtist!;
    final albums = _artistAlbums;

    return Column(
      children: [
        // Back Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.hairlineSoft)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to artists',
                onPressed: () => setState(() {
                  _selectedArtist = null;
                  _artistAlbums = null;
                }),
              ),
              const SizedBox(width: 8),
              Text(
                'Back to ARTISTS',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
        ),

        // Artist Hero
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: palette.hairlineSoft,
                child: Icon(Icons.person, size: 40, color: palette.inkDim),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: GoogleFonts.spectral(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${albums?.length ?? artist.albumCount} ${albums?.length == 1 ? "album" : "albums"}',
                      style: TextStyle(fontSize: 13, color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Albums Grid
        Expanded(
          child: _loadingArtistAlbums
              ? const Center(child: CircularProgressIndicator())
              : albums == null || albums.isEmpty
              ? const Center(child: Text('No albums found for this artist.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (context, idx) {
                    final album = albums[idx];
                    return _buildAlbumCard(album, palette);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTracksView(StudioPalette palette) {
    final tracksAsync = ref.watch(subsonicTracksProvider);

    return tracksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load tracks: $err')),
      data: (allTracks) {
        final filteredTracks = _tracksFilter.isEmpty
            ? allTracks
            : allTracks.where((t) {
                final q = _tracksFilter;
                return t.title.toLowerCase().contains(q) ||
                    (t.artist?.toLowerCase().contains(q) ?? false) ||
                    (t.album?.toLowerCase().contains(q) ?? false);
              }).toList();

        if (allTracks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 48,
                    color: palette.inkDim,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No remote tracks indexed yet',
                    style: GoogleFonts.spectral(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run a server scan to index and browse all songs from your remote collection, or explore via Albums and Artists.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(subsonicScanProvider.notifier).startScan(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Scan Entire Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: const Color(0xFF13110F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Action header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.hairlineSoft)),
              ),
              child: Row(
                children: [
                  Text(
                    '${allTracks.length} tracks indexed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(subsonicPlaybackServiceProvider)
                        .playTracks(filteredTracks, startIndex: 0),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Play All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: const Color(0xFF13110F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final shuffled = [...filteredTracks]..shuffle();
                      ref
                          .read(subsonicPlaybackServiceProvider)
                          .playTracks(shuffled, startIndex: 0);
                    },
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Shuffle All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.hairline),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    height: 32,
                    child: TextField(
                      controller: _tracksFilterController,
                      style: TextStyle(fontSize: 12, color: palette.ink),
                      decoration: InputDecoration(
                        hintText: 'Filter tracks...',
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: palette.inkDim,
                        ),
                        prefixIcon: Icon(
                          Icons.filter_list,
                          size: 15,
                          color: palette.inkMuted,
                        ),
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: palette.hairlineSoft.withAlpha(40),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: palette.hairline),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Track list table
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: filteredTracks.length,
                separatorBuilder: (context, idx) =>
                    Divider(color: palette.hairlineSoft, height: 1),
                itemBuilder: (context, idx) {
                  final track = filteredTracks[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    leading: SizedBox(
                      width: 32,
                      child: Text(
                        (track.trackNumber ?? idx + 1).toString(),
                        style: TextStyle(fontSize: 11, color: palette.inkDim),
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                    subtitle: Text(
                      '${track.artist ?? "Unknown Artist"} • ${track.album ?? "Unknown Album"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: palette.inkMuted),
                    ),
                    trailing: Text(
                      track.durationMs != null
                          ? _formatDuration(
                              Duration(milliseconds: track.durationMs!),
                            )
                          : '',
                      style: TextStyle(fontSize: 11, color: palette.inkDim),
                    ),
                    onTap: () {
                      ref
                          .read(subsonicPlaybackServiceProvider)
                          .playTracks(filteredTracks, startIndex: idx);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlbumDetailView(StudioPalette palette) {
    final album = _selectedAlbum!;
    final client = ref.read(subsonicClientProvider);
    final coverUri = client?.buildCoverArtUri(album.coverArtId, size: 300);

    return Column(
      children: [
        // Back Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => setState(() => _selectedAlbum = null),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedArtist != null
                    ? 'Back to ${_selectedArtist!.name}'
                    : 'Back to ${_currentTab.toUpperCase()}',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
        ),

        // Album Header & Tracklist
        Expanded(
          child: _loadingAlbum
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: palette.hairlineSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.hairline),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: coverUri != null
                              ? Image.network(
                                  coverUri.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.album,
                                        size: 48,
                                        color: palette.inkDim,
                                      ),
                                )
                              : Icon(
                                  Icons.album,
                                  size: 48,
                                  color: palette.inkDim,
                                ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.name,
                                style: GoogleFonts.spectral(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                album.artist,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: palette.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (album.year != null)
                                    Text(
                                      '${album.year} • ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: palette.inkDim,
                                      ),
                                    ),
                                  Text(
                                    '${_albumSongs?.length ?? 0} tracks',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.inkDim,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed:
                                        _albumSongs == null ||
                                            _albumSongs!.isEmpty
                                        ? null
                                        : () {
                                            ref
                                                .read(
                                                  subsonicPlaybackServiceProvider,
                                                )
                                                .playSongs(
                                                  _albumSongs!,
                                                  startIndex: 0,
                                                );
                                          },
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 18,
                                    ),
                                    label: const Text('Play Album'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: palette.accent,
                                      foregroundColor: const Color(0xFF13110F),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _albumSongs == null ||
                                            _albumSongs!.isEmpty
                                        ? null
                                        : () {
                                            final shuffled = [..._albumSongs!]
                                              ..shuffle();
                                            ref
                                                .read(
                                                  subsonicPlaybackServiceProvider,
                                                )
                                                .playSongs(
                                                  shuffled,
                                                  startIndex: 0,
                                                );
                                          },
                                    icon: const Icon(Icons.shuffle, size: 18),
                                    label: const Text('Shuffle'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: palette.ink,
                                      side: BorderSide(color: palette.hairline),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Divider(color: palette.hairline),
                    const SizedBox(height: 16),
                    // Track Table
                    if (_albumSongs != null)
                      ...List.generate(_albumSongs!.length, (idx) {
                        final song = _albumSongs![idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          leading: SizedBox(
                            width: 28,
                            child: Text(
                              (song.trackNumber ?? idx + 1).toString(),
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.inkDim,
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: palette.ink,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.inkMuted,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (song.suffix != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: palette.hairline),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    song.suffix!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: palette.inkDim,
                                    ),
                                  ),
                                ),
                              Text(
                                _formatDuration(song.duration),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.inkDim,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref
                                .read(subsonicPlaybackServiceProvider)
                                .playSongs(_albumSongs!, startIndex: idx);
                          },
                        );
                      }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView(StudioPalette palette) {
    final songs = _searchResults?['songs'] as List<SubsonicSong>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Search Results for "${_searchController.text}"',
          style: GoogleFonts.spectral(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 16),
        if (songs.isEmpty)
          const Text('No matching songs found on remote server.')
        else
          ...songs.map((song) {
            return ListTile(
              leading: Icon(Icons.music_note, color: palette.accent),
              title: Text(
                song.title,
                style: TextStyle(fontSize: 13, color: palette.ink),
              ),
              subtitle: Text(
                '${song.artist} • ${song.album}',
                style: TextStyle(fontSize: 11, color: palette.inkMuted),
              ),
              trailing: Text(
                _formatDuration(song.duration),
                style: TextStyle(fontSize: 11, color: palette.inkDim),
              ),
              onTap: () {
                ref.read(subsonicPlaybackServiceProvider).playSong(song);
              },
            );
          }),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, "0")}';
  }
}
