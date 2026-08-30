import 'dart:convert';

/// The app supplies Flutter's throttled console writer; tests can capture lines.
/// No files or telemetry are written, and diagnostics cannot interrupt fetching.
class ArtistPictureLog {
  const ArtistPictureLog([this.write]);
  final void Function(String)? write;

  void call(String message, {String? artist}) {
    if (write == null) return;
    String singleLine(String value) {
      final clean = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
      return clean.length > 600 ? '${clean.substring(0, 600)}…' : clean;
    }

    final label = artist == null ? '' : ' [${jsonEncode(singleLine(artist))}]';
    try {
      write!('[Artist pictures]$label ${singleLine(message)}');
    } on Object {
      // A closed or unavailable console must not change image/playback behavior.
    }
  }
}
