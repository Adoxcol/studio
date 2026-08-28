import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Named FIFO that mpv's `ao=pcm` can fopen() while Dart reads float32 frames.
///
/// Windows uses `PIPE_NOWAIT` so [read] never blocks the UI isolate.
class PcmFifo {
  PcmFifo._({
    required this.writerPath,
    required Future<Uint8List> Function(int maxBytes) read,
    required Future<void> Function() close,
  }) : _read = read,
       _close = close;

  final String writerPath;
  final Future<Uint8List> Function(int maxBytes) _read;
  final Future<void> Function() _close;

  Future<Uint8List> read(int maxBytes) => _read(maxBytes);

  Future<void> close() => _close();

  static Future<PcmFifo> create() {
    if (Platform.isWindows) return _WindowsPipe.create();
    return _PosixFifo.create();
  }
}

class _PosixFifo {
  static Future<PcmFifo> create() async {
    final path =
        '${Directory.systemTemp.path}/studio-fft-$pid-${DateTime.now().microsecondsSinceEpoch}.pcm';
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    final result = await Process.run('mkfifo', [path]);
    if (result.exitCode != 0) {
      throw StateError('mkfifo failed: ${result.stderr}');
    }
    final opener = file.open(mode: FileMode.read);
    RandomAccessFile? raf;
    return PcmFifo._(
      writerPath: path,
      read: (maxBytes) async {
        raf ??= await opener.timeout(const Duration(seconds: 5));
        return raf!.read(max(1, maxBytes));
      },
      close: () async {
        try {
          await raf?.close();
        } on Object {
          // Best-effort.
        }
        try {
          if (file.existsSync()) file.deleteSync();
        } on Object {
          // Best-effort.
        }
      },
    );
  }
}

class _WindowsPipe {
  static const _pipeAccessInbound = 0x00000001;
  static const _fileFlagFirstPipeInstance = 0x00080000;
  static const _pipeTypeByte = 0x00000000;
  static const _pipeNoWait = 0x00000001;
  static const _errorPipeConnected = 535;
  static const _errorPipeListening = 536;
  static const _errorNoData = 232;

  static Future<PcmFifo> create() async {
    final name =
        '\\\\.\\pipe\\studio-fft-$pid-${DateTime.now().microsecondsSinceEpoch}';
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final createNamedPipe = kernel32
        .lookupFunction<
          IntPtr Function(
            Pointer<Utf16>,
            Uint32,
            Uint32,
            Uint32,
            Uint32,
            Uint32,
            Uint32,
            Pointer<Void>,
          ),
          int Function(
            Pointer<Utf16>,
            int,
            int,
            int,
            int,
            int,
            int,
            Pointer<Void>,
          )
        >('CreateNamedPipeW');
    final connectNamedPipe = kernel32
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Void>),
          int Function(int, Pointer<Void>)
        >('ConnectNamedPipe');
    final readFile = kernel32
        .lookupFunction<
          Int32 Function(
            IntPtr,
            Pointer<Void>,
            Uint32,
            Pointer<Uint32>,
            Pointer<Void>,
          ),
          int Function(int, Pointer<Void>, int, Pointer<Uint32>, Pointer<Void>)
        >('ReadFile');
    final closeHandle = kernel32
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'CloseHandle',
        );
    final getLastError = kernel32
        .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

    final namePtr = name.toNativeUtf16();
    final handle = createNamedPipe(
      namePtr,
      _pipeAccessInbound | _fileFlagFirstPipeInstance,
      _pipeTypeByte | _pipeNoWait,
      1,
      262144,
      262144,
      0,
      nullptr,
    );
    calloc.free(namePtr);
    if (handle == 0 || handle == -1) {
      throw StateError('CreateNamedPipe failed (${getLastError()})');
    }

    var connected = false;
    var closed = false;

    Future<void> ensureConnected() async {
      if (connected) return;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!closed && DateTime.now().isBefore(deadline)) {
        final ok = connectNamedPipe(handle, nullptr);
        final err = getLastError();
        if (ok != 0 || err == _errorPipeConnected) {
          connected = true;
          return;
        }
        if (err != _errorPipeListening && err != _errorNoData) {
          throw StateError('ConnectNamedPipe failed ($err)');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      throw TimeoutException('PCM pipe connect');
    }

    return PcmFifo._(
      writerPath: name,
      read: (maxBytes) async {
        if (closed) return Uint8List(0);
        await ensureConnected();
        final n = max(1, maxBytes);
        final buffer = calloc<Uint8>(n);
        final readPtr = calloc<Uint32>();
        try {
          final ok = readFile(handle, buffer.cast(), n, readPtr, nullptr);
          if (ok == 0) {
            final err = getLastError();
            if (err == _errorNoData || err == _errorPipeListening) {
              return Uint8List(0);
            }
            return Uint8List(0);
          }
          return Uint8List.fromList(buffer.asTypedList(readPtr.value));
        } finally {
          calloc.free(buffer);
          calloc.free(readPtr);
        }
      },
      close: () async {
        closed = true;
        closeHandle(handle);
      },
    );
  }
}
