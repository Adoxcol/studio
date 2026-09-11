/// Shared product metadata. Keep display name here so UI and tests agree.
const String kAppName = 'Studio';
const String kAppPublisher = 'Adoxcol';
const String kAppVersion = String.fromEnvironment(
  'STUDIO_VERSION',
  defaultValue: '0.0.0-dev',
);
const String kAppHomepage = 'https://github.com/Adoxcol/studio';
