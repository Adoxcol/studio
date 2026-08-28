import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/desktop/desktop_transport.dart';

void main() {
  test('play/pause tray label follows playing state', () {
    expect(desktopPlayPauseLabel(true), 'Pause');
    expect(desktopPlayPauseLabel(false), 'Play');
  });

  test('tray tooltip names the track while playing', () {
    expect(
      desktopTrayTooltip(hasTrack: false, playing: false, title: 'Not playing'),
      'Studio',
    );
    expect(
      desktopTrayTooltip(
        hasTrack: true,
        playing: true,
        title: 'Helplessness Blues',
        artist: 'Fleet Foxes',
      ),
      'Playing · Helplessness Blues — Fleet Foxes',
    );
    expect(
      desktopTrayTooltip(
        hasTrack: true,
        playing: false,
        title: 'Helplessness Blues',
      ),
      'Paused · Helplessness Blues',
    );
  });

  test('menu keys map to transport actions', () {
    expect(desktopTransportForMenuKey('playPause'), DesktopTransport.playPause);
    expect(desktopTransportForMenuKey('next'), DesktopTransport.next);
    expect(desktopTransportForMenuKey('quit'), DesktopTransport.quit);
    expect(desktopTransportForMenuKey('nope'), isNull);
  });

  test('close hides to tray only after the icon exists', () {
    expect(shouldHideToTray(trayReady: false, quitting: false), isFalse);
    expect(shouldHideToTray(trayReady: true, quitting: false), isTrue);
    expect(shouldHideToTray(trayReady: true, quitting: true), isFalse);
  });
}
