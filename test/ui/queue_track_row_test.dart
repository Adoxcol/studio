import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/queue/queue_track_row.dart';

import '../helpers/tracks.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows artwork, title over artist, and duration on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: QueueTrackRow(
                track: testTrack(
                  title: 'Aerial Lines',
                  artist: 'Aria Solvang',
                  durationMs: 238000,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final title = find.text('Aerial Lines');
    final artist = find.text('Aria Solvang');
    final duration = find.text('3:58');
    final palette = StudioPalette.of(tester.element(artist));

    expect(find.byType(CoverArt), findsOneWidget);
    expect(tester.getSize(find.byType(CoverArt)), const Size(40, 40));
    expect(tester.getCenter(title).dy, lessThan(tester.getCenter(artist).dy));
    expect(
      tester.getCenter(duration).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(tester.widget<Text>(artist).style?.color, palette.inkMuted);
    expect(tester.widget<Text>(duration).style?.color, palette.inkMuted);
  });
}
