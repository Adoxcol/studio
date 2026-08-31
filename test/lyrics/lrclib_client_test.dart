import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_query.dart';

class FakeHttpClient implements HttpClient {
  Future<HttpClientRequest> Function(Uri url)? onGetUrl;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (onGetUrl != null) return onGetUrl!(url);
    throw UnimplementedError();
  }

  @override
  void close({bool force = false}) {}

  @override
  set userAgent(String? userAgent) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  final FakeHttpHeaders _headers = FakeHttpHeaders();
  Future<HttpClientResponse> Function()? onClose;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() {
    if (onClose != null) return onClose!();
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FakeHttpClientResponse({
    required this.statusCode,
    String? body,
    this.simulatedDelay,
  }) : _body = body != null ? utf8.encode(body) : [];

  @override
  final int statusCode;
  final List<int> _body;
  final Duration? simulatedDelay;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (simulatedDelay != null) {
      return Stream<List<int>>.fromFuture(
        Future.delayed(simulatedDelay!, () => _body),
      ).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }
    return Stream.value(_body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LrclibClient', () {
    const query = LyricsQuery(title: 'Test Song', artist: 'Test Artist');

    test('returns missing when status code is 404', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          final request = FakeHttpClientRequest()
            ..onClose = () async => FakeHttpClientResponse(statusCode: 404);
          return request;
        };

      final client = LrclibClient(http: mockHttp);
      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.missing);
    });

    test('returns unavailable when status code is 429', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          final request = FakeHttpClientRequest()
            ..onClose = () async => FakeHttpClientResponse(statusCode: 429);
          return request;
        };

      final client = LrclibClient(http: mockHttp);
      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.unavailable);
    });

    test('returns unavailable when status code is 500', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          final request = FakeHttpClientRequest()
            ..onClose = () async => FakeHttpClientResponse(statusCode: 500);
          return request;
        };

      final client = LrclibClient(http: mockHttp);
      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.unavailable);
    });

    test('returns unavailable on exception', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          throw const SocketException('Network is unreachable');
        };

      final client = LrclibClient(http: mockHttp);
      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.unavailable);
    });

    // fake_async is not in dev_dependencies. Since memory limits modifying pubspec.yaml unless
    // explicitly instructed and fake_async requires changes there (and it's not possible to
    // modify pubspec.yaml properly in this setup without also changing it via downgrading Dart
    // constraints which then messes up pubspec.yaml/lock in the final diff), we use a fast
    // network simulated timeout logic instead of a real-time wait. We mock a TimeoutException.

    test('returns unavailable on timeout (simulated)', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          final request = FakeHttpClientRequest()
            ..onClose = () async {
              throw TimeoutException('Simulated timeout');
            };
          return request;
        };

      final client = LrclibClient(http: mockHttp);

      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.unavailable);
    });

    test('returns found on successful response with valid body', () async {
      final mockHttp = FakeHttpClient()
        ..onGetUrl = (url) async {
          final request = FakeHttpClientRequest()
            ..onClose = () async => FakeHttpClientResponse(
              statusCode: 200,
              body: jsonEncode({
                'syncedLyrics': '[00:01.00] Line 1',
                'plainLyrics': 'Line 1',
                'instrumental': false,
              }),
            );
          return request;
        };

      final client = LrclibClient(http: mockHttp);
      final result = await client.lookup(query);

      expect(result.status, LyricsLookupStatus.found);
      expect(result.record?.syncedLyrics, '[00:01.00] Line 1');
      expect(result.record?.plainLyrics, 'Line 1');
      expect(result.record?.instrumental, false);
    });

    test(
      'returns unavailable on successful response with invalid body',
      () async {
        final mockHttp = FakeHttpClient()
          ..onGetUrl = (url) async {
            final request = FakeHttpClientRequest()
              ..onClose = () async => FakeHttpClientResponse(
                statusCode: 200,
                body: 'Not valid JSON',
              );
            return request;
          };

        final client = LrclibClient(http: mockHttp);
        final result = await client.lookup(query);

        expect(result.status, LyricsLookupStatus.unavailable);
      },
    );
  });
}
