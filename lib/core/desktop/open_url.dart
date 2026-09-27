import 'dart:io';

/// Opens [url] in the default browser. Returns false if no opener ran.
Future<bool> openUrl(Uri url) async {
  final (command, args) = switch (Platform.operatingSystem) {
    'macos' => ('open', [url.toString()]),
    // rundll32 avoids cmd.exe re-parsing `&` in query strings.
    'windows' => ('rundll32', ['url.dll,FileProtocolHandler', url.toString()]),
    _ => ('xdg-open', [url.toString()]),
  };
  try {
    await Process.start(command, args, mode: ProcessStartMode.detached);
    return true;
  } on Object {
    return false;
  }
}
