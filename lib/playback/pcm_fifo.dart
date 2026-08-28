import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Named FIFO that mpv's `ao=pcm` can fopen() while Dart reads float32 frames.
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
        raf ??= await opener;
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
  static const _pipeWait = 0x00000000;
  static const _errorPipeConnected = 535;

  static Future<PcmFifo> create() async {
    final name = '\\\\.\\pipe\\studio-fft-$pid';
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

    final namePtr = name.toNativeUtf16();
    final handle = createNamedPipe(
      namePtr,
      _pipeAccessInbound | _fileFlagFirstPipeInstance,
      _pipeTypeByte | _pipeWait,
      1,
      65536,
      65536,
      0,
      nullptr,
    );
    calloc.free(namePtr);
    if (handle == 0 || handle == -1) {
      throw StateError('CreateNamedPipe failed');
    }

    final connected = Isolate.run(() => _connect(handle));

    return PcmFifo._(
      writerPath: name,
      read: (maxBytes) async {
        await connected;
        final n = max(1, maxBytes);
        final buffer = calloc<Uint8>(n);
        final readPtr = calloc<Uint32>();
        try {
          final ok = readFile(handle, buffer.cast(), n, readPtr, nullptr);
          if (ok == 0) return Uint8List(0);
          return Uint8List.fromList(buffer.asTypedList(readPtr.value));
        } finally {
          calloc.free(buffer);
          calloc.free(readPtr);
        }
      },
      close: () async {
        closeHandle(handle);
      },
    );
  }

  static int _connect(int handle) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final connectNamedPipe = kernel32
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Void>),
          int Function(int, Pointer<Void>)
        >('ConnectNamedPipe');
    final getLastError = kernel32
        .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
    final ok = connectNamedPipe(handle, nullptr);
    if (ok == 0 && getLastError() != _errorPipeConnected) {
      throw StateError('ConnectNamedPipe failed (${getLastError()})');
    }
    return 0;
  }
}
