# Marketplace cover

The root `preview.webp` is the 2000×1000 marketplace cover. The marketplace
discovers PNG, JPEG, WebP, or AVIF root previews; the WebP keeps this artwork
small while preserving the embedded UI screenshot.

The cover is rendered from `dev/listing/listing.html`. Its right side embeds
`dev/listing/card.png`, an unedited screenshot of the real hover card. The
title, feature list, rings, and colours are presentation artwork.

Regenerate it with:

```bash
./dev/listing.sh
```

That needs Chromium, ImageMagick, Noto Sans, Noto Color Emoji, and JetBrains
Mono Nerd Font. Retake `card.png` when the card changes materially. Set
`BATON_LISTING_OUTPUT` to write the result somewhere other than the repository
root.

The client uses Omarchy's `BarIconButton`: foreground and active colors and
font family come from the host bar, while font size and slot size come from
`Style`. The card and notification surfaces are rendered by Omarchy. The
client has no hard-coded color palette.
