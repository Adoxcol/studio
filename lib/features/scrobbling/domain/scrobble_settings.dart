/// Built-in Last.fm API credentials, injected at build time with
/// `--dart-define=STUDIO_LASTFM_API_KEY=... --dart-define=STUDIO_LASTFM_SECRET=...`.
const kLastFmApiKey = String.fromEnvironment('STUDIO_LASTFM_API_KEY');
const kLastFmSecret = String.fromEnvironment('STUDIO_LASTFM_SECRET');

class ScrobbleSettings {
  const ScrobbleSettings({
    this.lastFmApiKey = '',
    this.lastFmSecret = '',
    this.lastFmSessionKey = '',
    this.lastFmUser = '',
    this.lastFmExpired = false,
    this.listenBrainzToken = '',
    this.listenBrainzUser = '',
    this.listenBrainzExpired = false,
  });

  static const defaults = ScrobbleSettings();

  /// User-supplied API credentials; empty means use the built-in ones.
  final String lastFmApiKey;
  final String lastFmSecret;
  final String lastFmSessionKey;
  final String lastFmUser;

  /// Last.fm rejected the saved session; the user must reconnect.
  final bool lastFmExpired;

  final String listenBrainzToken;
  final String listenBrainzUser;
  final bool listenBrainzExpired;

  String get effectiveLastFmApiKey =>
      lastFmApiKey.isNotEmpty ? lastFmApiKey : kLastFmApiKey;
  String get effectiveLastFmSecret =>
      lastFmSecret.isNotEmpty ? lastFmSecret : kLastFmSecret;

  bool get hasLastFmKeys =>
      effectiveLastFmApiKey.isNotEmpty && effectiveLastFmSecret.isNotEmpty;
  bool get lastFmConnected => hasLastFmKeys && lastFmSessionKey.isNotEmpty;
  bool get listenBrainzConnected => listenBrainzToken.isNotEmpty;

  ScrobbleSettings copyWith({
    String? lastFmApiKey,
    String? lastFmSecret,
    String? lastFmSessionKey,
    String? lastFmUser,
    bool? lastFmExpired,
    String? listenBrainzToken,
    String? listenBrainzUser,
    bool? listenBrainzExpired,
  }) {
    return ScrobbleSettings(
      lastFmApiKey: lastFmApiKey ?? this.lastFmApiKey,
      lastFmSecret: lastFmSecret ?? this.lastFmSecret,
      lastFmSessionKey: lastFmSessionKey ?? this.lastFmSessionKey,
      lastFmUser: lastFmUser ?? this.lastFmUser,
      lastFmExpired: lastFmExpired ?? this.lastFmExpired,
      listenBrainzToken: listenBrainzToken ?? this.listenBrainzToken,
      listenBrainzUser: listenBrainzUser ?? this.listenBrainzUser,
      listenBrainzExpired: listenBrainzExpired ?? this.listenBrainzExpired,
    );
  }

  Map<String, Object?> toJson() => {
    'lastFmApiKey': lastFmApiKey,
    'lastFmSecret': lastFmSecret,
    'lastFmSessionKey': lastFmSessionKey,
    'lastFmUser': lastFmUser,
    'lastFmExpired': lastFmExpired,
    'listenBrainzToken': listenBrainzToken,
    'listenBrainzUser': listenBrainzUser,
    'listenBrainzExpired': listenBrainzExpired,
  };

  static ScrobbleSettings fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    return ScrobbleSettings(
      lastFmApiKey: text('lastFmApiKey'),
      lastFmSecret: text('lastFmSecret'),
      lastFmSessionKey: text('lastFmSessionKey'),
      lastFmUser: text('lastFmUser'),
      lastFmExpired: json['lastFmExpired'] == true,
      listenBrainzToken: text('listenBrainzToken'),
      listenBrainzUser: text('listenBrainzUser'),
      listenBrainzExpired: json['listenBrainzExpired'] == true,
    );
  }
}
