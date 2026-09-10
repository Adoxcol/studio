## 2024-05-24 - [MEDIUM] Fix insecure temporary file creation in POSIX PcmFifo
**Vulnerability:** Predictable named pipe creation in global `/tmp` directory. The code used `${Directory.systemTemp.path}/studio-fft-$pid-...pcm` which is vulnerable to symlink and time-of-check-to-time-of-use attacks because `/tmp` is world-writable.
**Learning:** Temporary files should not be directly created in the global temporary directory with predictable names.
**Prevention:** Always use `Directory.systemTemp.createTemp(prefix)` to securely create a process-exclusive temporary directory first, and then place any required files inside it.
## 2024-05-24 - [MEDIUM] Secure preference and cache file saving with atomic writes
**Vulnerability:** Settings and cache stores (like `AppearanceStore`, `PlaybackSettingsStore`, `DiscordSettingsStore`) were written directly using `file.writeAsStringSync()`. If the application crashed or power was lost mid-write, the target files could end up corrupted or truncated, leading to data loss or invalid state parsing on the next application boot.
**Learning:** File system operations for preferences that lack fallback configurations risk severe app instability if interrupted during a direct write.
**Prevention:** In Dart, prevent partial writes by employing the atomic write pattern: always write data to a temporary file (e.g., `${file.path}.part`) using `writeAsStringSync(..., flush: true)`, and subsequently swap it into place via `part.renameSync(file.path)`.
## 2024-05-24 - [MEDIUM] Secure artwork file saving with atomic writes
**Vulnerability:** The embedded cover art cache in `ArtworkStore` was written directly using `file.writeAsBytes(bytes, flush: true)`. If the application crashed or power was lost mid-write, the target image files could end up corrupted or truncated, leading to data loss or invalid state parsing when displaying UI elements dependent on them.
**Learning:** File system operations for large binary blobs like images risk severe app instability or UI jank if interrupted during a direct write.
**Prevention:** In Dart, prevent partial writes by employing the atomic write pattern: always write data to a temporary file (e.g., `${file.path}.part`) using `writeAsBytes(..., flush: true)`, and subsequently swap it into place via `part.rename(file.path)`.
