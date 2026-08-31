import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/desktop/desktop_transport.dart';

void main() {
  group('desktopPlayPauseLabel', () {
    test('returns Pause when playing', () {
      expect(desktopPlayPauseLabel(true), 'Pause');
    });

    test('returns Play when not playing', () {
      expect(desktopPlayPauseLabel(false), 'Play');
    });
  });

  group('desktopTrayTooltip', () {
    test('returns Studio when there is no track', () {
      expect(
        desktopTrayTooltip(hasTrack: false, playing: false, title: 'Title'),
        'Studio',
      );
    });

    test('returns Paused status without artist', () {
      expect(
        desktopTrayTooltip(hasTrack: true, playing: false, title: 'Song Title'),
        'Paused · Song Title',
      );
    });

    test('returns Playing status without artist', () {
      expect(
        desktopTrayTooltip(hasTrack: true, playing: true, title: 'Song Title'),
        'Playing · Song Title',
      );
    });

    test('returns Paused status with empty artist', () {
      expect(
        desktopTrayTooltip(
          hasTrack: true,
          playing: false,
          title: 'Song Title',
          artist: '',
        ),
        'Paused · Song Title',
      );
    });

    test('returns Playing status with artist', () {
      expect(
        desktopTrayTooltip(
          hasTrack: true,
          playing: true,
          title: 'Song Title',
          artist: 'Artist Name',
        ),
        'Playing · Song Title — Artist Name',
      );
    });
  });

  group('desktopTransportForMenuKey', () {
    test('returns correct DesktopTransport for mapped keys', () {
      expect(
        desktopTransportForMenuKey('playPause'),
        DesktopTransport.playPause,
      );
      expect(desktopTransportForMenuKey('next'), DesktopTransport.next);
      expect(desktopTransportForMenuKey('previous'), DesktopTransport.previous);
      expect(desktopTransportForMenuKey('show'), DesktopTransport.show);
      expect(desktopTransportForMenuKey('quit'), DesktopTransport.quit);
    });

    test('returns null for unmapped keys', () {
      expect(desktopTransportForMenuKey('unknown'), isNull);
      expect(desktopTransportForMenuKey(''), isNull);
      expect(desktopTransportForMenuKey(null), isNull);
    });
  });
}
