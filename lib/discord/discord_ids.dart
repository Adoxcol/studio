/// Public Discord application id. Not a secret — RPC talks to the local
/// Discord client over IPC and does not use the Client Secret.
const String kDiscordApplicationId = '1543019700970328154';

/// Art asset names uploaded under Rich Presence in the Developer Portal.
const String kDiscordLargeImageKey = 'studio';
const String kDiscordPlayImageKey = 'play';
const String kDiscordPauseImageKey = 'pause';

/// Freeimage's documented API endpoint and public upload key. The service uses
/// `iili.io` for direct image links, which Discord's media proxy can render.
/// This is a site-wide public key (also published in Freeimage's uploader
/// configuration), not a Studio credential or user secret.
const String kFreeImageUploadUrl = 'https://freeimage.host/api/1/upload';
const String kFreeImagePublicApiKey = '6d207e02198a847aa98d0a2a901485a5';
const int kDiscordAssetLimit = 256;
