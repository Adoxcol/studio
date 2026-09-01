class DiscordSettings {
  const DiscordSettings({
    this.enabled = false,
    this.nameTemplate = defaultNameTemplate,
    this.detailsTemplate = defaultDetailsTemplate,
    this.stateTemplate = defaultStateTemplate,
    this.artworkTextTemplate = defaultArtworkTextTemplate,
    this.showProgress = true,
  });

  static const defaultNameTemplate = '[{artist} - ]{title}';
  static const defaultDetailsTemplate = '{title}';
  static const defaultStateTemplate = '{artist}';
  static const defaultArtworkTextTemplate = '{album}';
  static const defaults = DiscordSettings();

  final bool enabled;
  final String nameTemplate;
  final String detailsTemplate;
  final String stateTemplate;
  final String artworkTextTemplate;
  final bool showProgress;

  DiscordSettings copyWith({
    bool? enabled,
    String? nameTemplate,
    String? detailsTemplate,
    String? stateTemplate,
    String? artworkTextTemplate,
    bool? showProgress,
  }) {
    return DiscordSettings(
      enabled: enabled ?? this.enabled,
      nameTemplate: nameTemplate ?? this.nameTemplate,
      detailsTemplate: detailsTemplate ?? this.detailsTemplate,
      stateTemplate: stateTemplate ?? this.stateTemplate,
      artworkTextTemplate: artworkTextTemplate ?? this.artworkTextTemplate,
      showProgress: showProgress ?? this.showProgress,
    );
  }
}
