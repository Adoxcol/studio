import 'dart:io';

import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/data/musicbrainz_artist_picture_lookup.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

/// Opt-in live diagnostic; unlike unit tests, this sends the supplied artist
/// name (and optional album) to MusicBrainz and downloads an artist thumbnail.
/// Does not read the library or write any files.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln(
      'Usage: dart run tool/probe_artist_picture.dart [--fanart-settings <path>] [--mbid <known ID>] "Artist" ["Album"]',
    );
    return;
  }
  var fanart = const FanartSettings();
  String? knownId;
  while (args.isNotEmpty && args.first.startsWith('--')) {
    if (args.length < 3) {
      throw ArgumentError('Option value and artist required');
    }
    switch (args.first) {
      case '--fanart-settings':
        fanart = FanartSettingsStore(file: File(args[1])).load();
      case '--mbid':
        knownId = args[1];
      default:
        throw ArgumentError('Unknown option');
    }
    args = args.skip(2).toList();
  }
  final artist = ArtistImageRequest(args.first, albums: args.skip(1).toList());
  final identities = ArtistIdentityStore();
  if (knownId != null) await identities.save(artist, knownId);
  final lookup = MusicBrainzArtistPictureLookup(
    fanart: fanart,
    enableAudioDb: true,
    identities: identities,
    log: ArtistPictureLog(stdout.writeln),
  );
  try {
    final result = await lookup.fetch(artist);
    stdout.writeln(
      result == null
          ? 'No confident photo match.'
          : '${result.bytes.length} bytes; ${result.credit.license}; ${result.credit.pageUrl}',
    );
  } on Object catch (error) {
    stderr.writeln('Lookup failed: $error');
    exitCode = 1;
  } finally {
    lookup.close();
  }
}
