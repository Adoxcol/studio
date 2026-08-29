# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved. Use of this source code is governed by the MIT license.

cmake_minimum_required(VERSION 3.14)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatibility.
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

function(download_and_verify url md5 destination)
  if(EXISTS "${destination}")
    file(MD5 "${destination}" archive_md5)
    if(NOT md5 STREQUAL archive_md5)
      file(REMOVE "${destination}")
      message(STATUS "MD5 mismatch. Deleted ${destination}.")
    endif()
  endif()

  if(NOT EXISTS "${destination}")
    message(STATUS "Downloading ${url}...")
    file(DOWNLOAD "${url}" "${destination}" SHOW_PROGRESS)
    file(MD5 "${destination}" archive_md5)
    if(NOT md5 STREQUAL archive_md5)
      message(FATAL_ERROR "Integrity check failed for ${destination}.")
    endif()
  endif()
endfunction()

if("${FLUTTER_TARGET_PLATFORM}" STREQUAL "windows-x64")
  set(LIBMPV_ARCH "x86_64")
  set(LIBMPV "mpv-dev-x86_64-20241021-git-0f78584.7z")
  set(LIBMPV_MD5 "6ecf18e85b093c3f7edb16f3ee6603f3")
elseif("${FLUTTER_TARGET_PLATFORM}" STREQUAL "windows-arm64")
  set(LIBMPV_ARCH "aarch64")
  set(LIBMPV "mpv-dev-aarch64-20241021-git-0f78584.7z")
  set(LIBMPV_MD5 "5b507a35db13eee6cb7eb21e8be7c83d")
else()
  message(FATAL_ERROR "Unsupported Windows target: ${FLUTTER_TARGET_PLATFORM}")
endif()

set(LIBMPV_URL
    "https://github.com/media-kit/libmpv-win32-video-cmake/releases/download/20241021/${LIBMPV}")
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV}")
# A release-specific path prevents a stale 2023 extraction from being reused.
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv-20241021-${LIBMPV_ARCH}")

download_and_verify("${LIBMPV_URL}" "${LIBMPV_MD5}" "${LIBMPV_ARCHIVE}")

if(NOT EXISTS "${LIBMPV_SRC}/libmpv-2.dll")
  file(MAKE_DIRECTORY "${LIBMPV_SRC}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "${LIBMPV_ARCHIVE}"
    WORKING_DIRECTORY "${LIBMPV_SRC}"
    RESULT_VARIABLE LIBMPV_EXTRACT_RESULT
  )
  if(NOT LIBMPV_EXTRACT_RESULT EQUAL 0 OR
     NOT EXISTS "${LIBMPV_SRC}/libmpv-2.dll")
    message(FATAL_ERROR "Failed to extract ${LIBMPV_ARCHIVE}.")
  endif()
endif()

# ANGLE archive containing the pre-built shared libraries and headers.
set(ANGLE "ANGLE.7z")
set(ANGLE_URL
    "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

download_and_verify("${ANGLE_URL}" "${ANGLE_MD5}" "${ANGLE_ARCHIVE}")

if(NOT EXISTS "${ANGLE_SRC}/libEGL.dll")
  file(MAKE_DIRECTORY "${ANGLE_SRC}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "${ANGLE_ARCHIVE}"
    WORKING_DIRECTORY "${ANGLE_SRC}"
    RESULT_VARIABLE ANGLE_EXTRACT_RESULT
  )
  if(NOT ANGLE_EXTRACT_RESULT EQUAL 0 OR
     NOT EXISTS "${ANGLE_SRC}/libEGL.dll")
    message(FATAL_ERROR "Failed to extract ${ANGLE_ARCHIVE}.")
  endif()
endif()

set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES CXX_VISIBILITY_PRESET hidden
)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
