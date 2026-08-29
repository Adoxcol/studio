# Studio media-kit Windows libraries

This is the Windows plugin shell from `media_kit_libs_windows_video` 1.0.11,
with its native archive updated to media-kit's official `20241021` build.

The published package downloads mpv `v0.36.0-403-g652a1dd907` from September
2023. That core only implements the three-argument `af-command`, so it cannot
address one filter inside Studio's persistent ten-band lavfi graph. Its bundled
FFmpeg also omits the `aresample` filter needed by automatic format negotiation.

The replacement archives and MD5 hashes are the ones published in media-kit's
upstream Windows CMake configuration. The release-specific extraction folder
prevents CMake from reusing an older `libmpv` directory from a previous build.

Upstream sources:

- https://github.com/media-kit/media-kit/tree/main/libs/windows/media_kit_libs_windows_video
- https://github.com/media-kit/libmpv-win32-video-cmake/releases/tag/20241021
