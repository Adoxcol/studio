import 'dart:io';

import 'package:http/http.dart' as http;

/// Contains no response body, request headers, or credential-bearing URL.
class ArtistServiceException extends http.ClientException {
  ArtistServiceException(this.host, this.status, {this.retryAfter})
    : super('$host returned HTTP $status');
  final String host;
  final int status;
  final DateTime? retryAfter;
}

DateTime? artistRetryAfter(String? header, DateTime now) {
  if (header == null) return null;
  final seconds = int.tryParse(header.trim());
  if (seconds != null) {
    // Ignore invalid values; cap pathological server values at one day.
    return seconds < 0
        ? null
        : now.add(Duration(seconds: seconds.clamp(0, 86400)));
  }
  try {
    final date = HttpDate.parse(header);
    if (!date.isAfter(now)) return null;
    final limit = now.add(const Duration(days: 1));
    return date.isAfter(limit) ? limit : date;
  } on FormatException {
    return null;
  } on HttpException {
    return null;
  }
}
