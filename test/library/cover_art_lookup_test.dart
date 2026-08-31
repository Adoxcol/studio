import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/cover_art_lookup.dart';

void main() {
  test('artworkUrlFromSearch picks the first album image and enlarges it', () {
    const body = '''
{"resultCount":1,"results":[{"artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/Music/ab/100x100bb.jpg"}]}
''';
    expect(
      ITunesCoverArtLookup.artworkUrlFromSearch(body),
      'https://is1-ssl.mzstatic.com/image/thumb/Music/ab/600x600bb.jpg',
    );
  });

  test('artworkUrlFromSearch is null when iTunes has no results', () {
    expect(
      ITunesCoverArtLookup.artworkUrlFromSearch(
        '{"resultCount":0,"results":[]}',
      ),
      equals(null),
    );
    expect(ITunesCoverArtLookup.artworkUrlFromSearch('{'), equals(null));
  });
}
