# Preview assets

The root `preview.webp` is the marketplace still. `docs/preview.mp4` is a
27-second H.264 video for the README. The marketplace discovers PNG, JPEG,
WebP, or AVIF root previews; GIF and MP4 are not listing-preview formats.
See the [submission requirements](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md).

## The still

`preview.webp` is a 2000×1000 listing card rendered from
`dev/listing/listing.html`. Its right side embeds `dev/listing/bar.png`, an
unedited screenshot of the real widget and its tooltip in the Omarchy bar. The
two notification cards reproduce the text the widget sends through
`omarchy-notification-send`; the title, feature list, rings, and colours are
presentation artwork. Regenerate it with:

```bash
./dev/listing.sh
```

That needs chromium, ImageMagick, Noto Sans, Noto Color Emoji, and JetBrainsMono
Nerd Font. Retake `bar.png` first when the tooltip wording or bar changes. Set
`BATON_LISTING_OUTPUT` to write elsewhere.

## The video

The video renders the real Baton widget and service against an isolated local
relay. The hand is enlarged 7× so its state is readable. The green background,
progress marks, click ring, and captions are presentation artwork, not added
plugin UI or a recording of a complete desktop. No public users are involved.

## Pacing

| Video time | Visible step |
|---|---|
| 0–4 seconds | Ready to receive a hello. |
| 4–12 seconds | A wave arrives with a baton. |
| 12–16 seconds | A second wave leaves the held baton intact. |
| 16–22 seconds | The widget's actual left-click handler passes it on. |
| 22–27 seconds | Closing explanation. |

The captions stay visible after the brief widget animation ends. Frame counts
control these reading times, so a slow render cannot shorten them. Network
requests wait for scene markers; captures pause while awaiting each result.
The 20 fps encode contains 540 completed frames.

## Regenerate

From the client repository root, with Go, Quickshell, curl, Python 3, and ffmpeg:

```bash
git clone https://github.com/decadentsavant/baton-relay.git ../baton-relay
(cd ../baton-relay && go build -o baton-relay .)
./dev/preview.sh
```

Skip cloning if the separate relay checkout already exists. `BIN` can select
another built relay. The script uses an offscreen software renderer, temporary
identities, and port 18081 (override with `BATON_PREVIEW_PORT`). It does not
enable the plugin, change the user's shell configuration, write to the clipboard,
or contact public Baton users. Desktop notifications are logged instead of
sent in the isolated copy of the shell utility.

Two widget instances verify that multiple monitors share one connection.
Assertions cover receipt, plain-wave retention, baton handoff, completed send,
and disconnecting after both widgets are released.

Logs and PNG frames stay in the printed `/tmp/baton-demo.*` directory. The
script stops its own processes on exit. Set `BATON_PREVIEW_OUTPUT` to a
temporary directory to write `docs/preview.mp4` there instead of replacing the
repository asset. The script no longer touches `preview.webp`.

## Theme compatibility

The client uses Omarchy's `BarIconButton`: foreground and active colors and
font family come from the host bar, while font size and slot size come from
`Style`. Tooltip and notification surfaces are rendered by Omarchy. The client
has no hard-coded color palette.

An isolated check on 2026-09-06 exercised all 22 installed theme palettes, three
states (ready, holding a baton, offline), and font base sizes 12 and 18: 132
cases, each with horizontal and vertical widgets. Property bindings and positive
widget dimensions passed. Light and dark renders were visually inspected.
This check injected state into an isolated copy with identity startup disabled;
it did not switch the desktop theme or contact a relay. The separate live-relay
demo above checks the network behavior.
