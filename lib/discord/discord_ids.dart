/// Public Discord application id. Not a secret — RPC talks to the local
/// Discord client over IPC and does not use the Client Secret.
const String kDiscordApplicationId = '1543019700970328154';

/// Art asset names uploaded under Rich Presence in the Developer Portal.
const String kDiscordLargeImageKey = 'studio';
const String kDiscordPlayImageKey = 'play';
const String kDiscordPauseImageKey = 'pause';

/// Discord cannot read local files, so covers have to be an HTTPS URL —
/// catbox.moe takes anonymous uploads and needs no API key.
const String kCatboxUploadUrl = 'https://catbox.moe/user/api.php';
const int kDiscordAssetLimit = 256;
