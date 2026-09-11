import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlaybackModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
  void toggle() => state = !state;
}

final playbackModeProvider = NotifierProvider<PlaybackModeNotifier, bool>(
  PlaybackModeNotifier.new,
);

enum PlaybackStageMode {
  splitStage('Split Stage', 'Split'),
  visualArt('Visual Art', 'Art'),
  pureLyrics('Pure Lyrics', 'Lyrics'),
  editorialFocus('Editorial Focus', 'Focus');

  const PlaybackStageMode(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

enum PlaybackCoverMode {
  original('Original'),
  vinylSleeve('Vinyl Sleeve'),
  fullBleed('Full Bleed');

  const PlaybackCoverMode(this.label);
  final String label;
}

class EditorialStageModeNotifier extends Notifier<PlaybackStageMode> {
  @override
  PlaybackStageMode build() => PlaybackStageMode.splitStage;

  void select(PlaybackStageMode mode) => state = mode;
}

final editorialStageModeProvider =
    NotifierProvider<EditorialStageModeNotifier, PlaybackStageMode>(
      EditorialStageModeNotifier.new,
    );

class EditorialCoverModeNotifier extends Notifier<PlaybackCoverMode> {
  @override
  PlaybackCoverMode build() => PlaybackCoverMode.vinylSleeve;

  void select(PlaybackCoverMode mode) => state = mode;
}

final editorialCoverModeProvider =
    NotifierProvider<EditorialCoverModeNotifier, PlaybackCoverMode>(
      EditorialCoverModeNotifier.new,
    );

class EditorialLyricsScaleNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void increase() => state = (state + 0.15).clamp(0.7, 1.8);
  void decrease() => state = (state - 0.15).clamp(0.7, 1.8);
  void reset() => state = 1.0;
}

final editorialLyricsScaleProvider =
    NotifierProvider<EditorialLyricsScaleNotifier, double>(
      EditorialLyricsScaleNotifier.new,
    );

class EditorialLyricsSerifNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setSerif(bool serif) => state = serif;
}

final editorialLyricsSerifProvider =
    NotifierProvider<EditorialLyricsSerifNotifier, bool>(
      EditorialLyricsSerifNotifier.new,
    );

enum EditorialLyricsColorMode {
  defaultColor('Default Ink'),
  accentColor('Follow Cover Art Accent'),
  mutedColor('Muted Minimal'),
  pureWhite('High Contrast');

  const EditorialLyricsColorMode(this.label);
  final String label;
}

class EditorialLyricsColorNotifier extends Notifier<EditorialLyricsColorMode> {
  @override
  EditorialLyricsColorMode build() => EditorialLyricsColorMode.defaultColor;

  void select(EditorialLyricsColorMode mode) => state = mode;
  void toggle() => state = switch (state) {
    EditorialLyricsColorMode.defaultColor =>
      EditorialLyricsColorMode.accentColor,
    EditorialLyricsColorMode.accentColor => EditorialLyricsColorMode.mutedColor,
    EditorialLyricsColorMode.mutedColor => EditorialLyricsColorMode.pureWhite,
    EditorialLyricsColorMode.pureWhite => EditorialLyricsColorMode.defaultColor,
  };
}

final editorialLyricsColorModeProvider =
    NotifierProvider<EditorialLyricsColorNotifier, EditorialLyricsColorMode>(
      EditorialLyricsColorNotifier.new,
    );

class EditorialShowTopBarNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setShow(bool show) => state = show;
}

final editorialShowTopBarProvider =
    NotifierProvider<EditorialShowTopBarNotifier, bool>(
      EditorialShowTopBarNotifier.new,
    );
