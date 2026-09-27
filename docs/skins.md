# Skins

A skin recolours Studio's surfaces and text in light and dark mode. Skins are small JSON
files with the `.studioskin` extension, so they are easy to share. Import one from
**Settings → Skins → Import skin…**; **Export skin…** saves the current look
(the built-in Editorial palette when no skin is active) as a starting point to edit.

The accent colour is not part of a skin: it keeps following your album art or your
custom colour. A skin may suggest an `accentHue` (0–360), which is applied as your custom
colour when you choose the skin.

## Format

```json
{
  "format": "studio-skin",
  "version": 1,
  "name": "Midnight Paper",
  "author": "Your name",
  "accentHue": 220,
  "light": {
    "bg": "#FBFAF7",
    "ink": "#15161A"
  },
  "dark": {
    "bg": "#0B0D14",
    "ink": "#E8EAF2",
    "inkMuted": "#8B90A0",
    "hairline": "#23273A"
  }
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `format` | yes | Always `studio-skin`. |
| `version` | yes | Always `1`. |
| `name` | yes | Up to 60 characters. |
| `author` | no | Shown next to the name. |
| `accentHue` | no | Suggested custom accent hue in degrees. |
| `light`, `dark` | no | Colour overrides for each mode. |

Each palette may set any of these tokens, as `#RRGGBB`. Tokens you leave out keep
Studio's own colour, and unknown tokens are ignored.

| Token | Used for |
| --- | --- |
| `bg` | Window and panel background |
| `ink` | Primary text and icons |
| `inkMuted`, `inkMutedAlt`, `inkDim` | Secondary text, labels and inactive icons |
| `inkBright` | Emphasised text on dark surfaces |
| `hairline`, `hairlineSoft`, `hairlineStrong`, `hairlineAlt` | Dividers, borders and grids |
| `artSwatch` | Placeholder behind missing album art |

## Checks on import

Studio refuses a skin, and says why, when:

- it is larger than 64 KB, or is not valid JSON in the format above;
- a colour is not `#RRGGBB` (transparency is not allowed);
- text would be hard to read in either mode: `ink` must have at least **4.5:1** contrast
  against `bg` (WCAG AA), and `inkMuted` at least **3:1**.
