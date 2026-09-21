import 'package:flutter/foundation.dart';

enum SubsonicConnectionStatus { disconnected, connecting, connected, error }

@immutable
class SubsonicServerConfig {
  const SubsonicServerConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.serverName = 'Navidrome / Subsonic',
  });

  final String serverUrl;
  final String username;
  final String password;
  final String serverName;

  String get normalizedUrl {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'serverName': serverName,
  };

  factory SubsonicServerConfig.fromJson(Map<String, dynamic> json) {
    return SubsonicServerConfig(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      serverName: json['serverName'] as String? ?? 'Navidrome / Subsonic',
    );
  }

  SubsonicServerConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? serverName,
  }) {
    return SubsonicServerConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      serverName: serverName ?? this.serverName,
    );
  }
}

@immutable
class SubsonicConnectionInfo {
  const SubsonicConnectionInfo({
    required this.status,
    this.serverType = '',
    this.serverVersion = '',
    this.errorMessage,
  });

  final SubsonicConnectionStatus status;
  final String serverType;
  final String serverVersion;
  final String? errorMessage;

  bool get isConnected => status == SubsonicConnectionStatus.connected;

  static const disconnected = SubsonicConnectionInfo(
    status: SubsonicConnectionStatus.disconnected,
  );
}

@immutable
class SubsonicArtist {
  const SubsonicArtist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.coverArtId,
    this.artistImageUrl,
  });

  final String id;
  final String name;
  final int albumCount;
  final String? coverArtId;
  final String? artistImageUrl;

  factory SubsonicArtist.fromJson(Map<String, dynamic> json) {
    return SubsonicArtist(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Artist',
      albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
      coverArtId: json['coverArt']?.toString(),
      artistImageUrl: json['artistImageUrl'] as String?,
    );
  }
}

@immutable
class SubsonicAlbum {
  const SubsonicAlbum({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.coverArtId,
    this.songCount = 0,
    this.durationSeconds = 0,
    this.year,
    this.genre,
  });

  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? coverArtId;
  final int songCount;
  final int durationSeconds;
  final int? year;
  final String? genre;

  factory SubsonicAlbum.fromJson(Map<String, dynamic> json) {
    return SubsonicAlbum(
      id: json['id']?.toString() ?? '',
      name:
          json['name'] as String? ??
          json['title'] as String? ??
          'Unknown Album',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      artistId: json['artistId']?.toString(),
      coverArtId: json['coverArt']?.toString(),
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
    );
  }
}

@immutable
class SubsonicSong {
  const SubsonicSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artistId,
    this.albumId,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.coverArtId,
    this.sizeBytes,
    this.contentType,
    this.suffix,
    this.durationSeconds = 0,
    this.bitRateKbps,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artistId;
  final String? albumId;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final String? coverArtId;
  final int? sizeBytes;
  final String? contentType;
  final String? suffix;
  final int durationSeconds;
  final int? bitRateKbps;

  Duration get duration => Duration(seconds: durationSeconds);

  factory SubsonicSong.fromJson(Map<String, dynamic> json) {
    return SubsonicSong(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Unknown Album',
      artistId: json['artistId']?.toString(),
      albumId: json['albumId']?.toString(),
      trackNumber: (json['track'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      coverArtId: json['coverArt']?.toString(),
      sizeBytes: (json['size'] as num?)?.toInt(),
      contentType: json['contentType'] as String?,
      suffix: json['suffix'] as String?,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      bitRateKbps: (json['bitRate'] as num?)?.toInt(),
    );
  }
}

@immutable
class SubsonicPlaylist {
  const SubsonicPlaylist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.isPublic = false,
    this.songCount = 0,
    this.durationSeconds = 0,
    this.created,
    this.changed,
    this.coverArtId,
  });

  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool isPublic;
  final int songCount;
  final int durationSeconds;
  final DateTime? created;
  final DateTime? changed;
  final String? coverArtId;

  factory SubsonicPlaylist.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return SubsonicPlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Untitled Playlist',
      comment: json['comment'] as String?,
      owner: json['owner'] as String?,
      isPublic: json['public'] == true,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      created: parseDate(json['created']),
      changed: parseDate(json['changed']),
      coverArtId: json['coverArt']?.toString(),
    );
  }
}

enum SubsonicAlbumSort {
  alphabeticalByName('alphabeticalByName', 'A–Z'),
  recent('recent', 'Recently Added'),
  newest('newest', 'Newest Releases'),
  frequent('frequent', 'Most Played'),
  random('random', 'Random');

  const SubsonicAlbumSort(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

@immutable
class SubsonicScanState {
  const SubsonicScanState({
    this.isScanning = false,
    this.currentAlbum = 0,
    this.totalAlbums = 0,
    this.totalTracks = 0,
    this.currentAlbumName = '',
    this.totalPlaylists = 0,
    this.syncedPlaylists = 0,
    this.currentPlaylistName = '',
    this.totalArtists = 0,
    this.syncedArtists = 0,
    this.currentArtistName = '',
    this.statusMessage,
    this.error,
    this.isCompleted = false,
  });

  final bool isScanning;
  final int currentAlbum;
  final int totalAlbums;
  final int totalTracks;
  final String currentAlbumName;
  final int totalPlaylists;
  final int syncedPlaylists;
  final String currentPlaylistName;
  final int totalArtists;
  final int syncedArtists;
  final String currentArtistName;
  final String? statusMessage;
  final String? error;
  final bool isCompleted;

  double get progress {
    if (totalAlbums == 0 && totalPlaylists == 0 && totalArtists == 0) {
      return 0.0;
    }
    final albumWeight = totalAlbums > 0 ? 0.7 : 0.0;
    final playlistWeight = totalPlaylists > 0 ? 0.15 : 0.0;
    final artistWeight = totalArtists > 0 ? 0.15 : 0.0;
    final totalWeight = albumWeight + playlistWeight + artistWeight;
    if (totalWeight == 0) return 0.0;

    final albumProgress = totalAlbums > 0
        ? (currentAlbum / totalAlbums).clamp(0.0, 1.0)
        : 0.0;
    final playlistProgress = totalPlaylists > 0
        ? (syncedPlaylists / totalPlaylists).clamp(0.0, 1.0)
        : 0.0;
    final artistProgress = totalArtists > 0
        ? (syncedArtists / totalArtists).clamp(0.0, 1.0)
        : 0.0;

    return ((albumProgress * albumWeight +
                playlistProgress * playlistWeight +
                artistProgress * artistWeight) /
            totalWeight)
        .clamp(0.0, 1.0);
  }

  SubsonicScanState copyWith({
    bool? isScanning,
    int? currentAlbum,
    int? totalAlbums,
    int? totalTracks,
    String? currentAlbumName,
    int? totalPlaylists,
    int? syncedPlaylists,
    String? currentPlaylistName,
    int? totalArtists,
    int? syncedArtists,
    String? currentArtistName,
    String? statusMessage,
    String? error,
    bool? isCompleted,
  }) {
    return SubsonicScanState(
      isScanning: isScanning ?? this.isScanning,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      totalAlbums: totalAlbums ?? this.totalAlbums,
      totalTracks: totalTracks ?? this.totalTracks,
      currentAlbumName: currentAlbumName ?? this.currentAlbumName,
      totalPlaylists: totalPlaylists ?? this.totalPlaylists,
      syncedPlaylists: syncedPlaylists ?? this.syncedPlaylists,
      currentPlaylistName: currentPlaylistName ?? this.currentPlaylistName,
      totalArtists: totalArtists ?? this.totalArtists,
      syncedArtists: syncedArtists ?? this.syncedArtists,
      currentArtistName: currentArtistName ?? this.currentArtistName,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
