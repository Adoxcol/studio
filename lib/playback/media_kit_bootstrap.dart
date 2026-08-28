import 'dart:io';

import 'package:path/path.dart' as p;

/// media_kit debug-mode file that stores a pointer to leftover mpv handles
/// so hot-restart can `quit` them. The name includes [pid]; Windows reuses
/// PIDs, so a crashed run leaves a file that the next process `Located`s
/// and then walks as a dangling pointer — `Lost connection to device`.
const mediaKitReferenceHolderFileName =
    'com.alexmercerind.media_kit.NativeReferenceHolder';

File mediaKitReferenceHolderFile({int? processId}) {
  return File(
    p.join(
      Directory.systemTemp.path,
      '$mediaKitReferenceHolderFileName.${processId ?? pid}',
    ),
  );
}

/// Drop the leftover handle file before [MediaKit.ensureInitialized].
/// Safe if the file is missing.
void discardStaleMediaKitReferenceHolder() {
  try {
    final file = mediaKitReferenceHolderFile();
    if (file.existsSync()) file.deleteSync();
  } on Object {
    // Best-effort: media_kit will allocate a fresh buffer.
  }
}
