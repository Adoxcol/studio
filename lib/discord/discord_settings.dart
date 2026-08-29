class DiscordSettings {
  const DiscordSettings({this.enabled = false});

  static const defaults = DiscordSettings();

  final bool enabled;

  DiscordSettings copyWith({bool? enabled}) {
    return DiscordSettings(enabled: enabled ?? this.enabled);
  }
}
