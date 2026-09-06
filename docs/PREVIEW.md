# Draft preview

`preview.webp` and `preview.mp4` show the actual Baton widget and shared service
running against an isolated local relay. The surrounding bar and notification
are illustrative presentation chrome, clearly labelled in the capture. This is
not a recording of public activity or a claim about the size of the community.

From the client repository root, regenerate on Omarchy with Go, Quickshell,
curl, Python 3, and ffmpeg installed:

    git clone https://github.com/decadentsavant/baton-relay.git ../baton-relay
    (cd ../baton-relay && go build -o baton-relay .)
    ./dev/preview.sh

The script uses an offscreen QML window, temporary identities, and port 18081
(override with `BATON_PREVIEW_PORT`). `BIN` can select another built relay.
It does not enable the plugin, alter the user's shell configuration, write to
the clipboard, or contact public Baton users. Desktop notifications are
suppressed in the isolated demo's copy of the shell utility.

Two widget instances verify that multiple monitors share one connection. A
local stranger passes a baton, sends a plain wave (which must preserve it),
then receives the baton back. These are assertions against the live service;
frame capture uses Qt's renderer, not hand-drawn replacement widget artwork.

The demo writes logs and PNG frames into its printed `/tmp/baton-demo.*`
directory and stops its own processes on exit. Draft media goes into `docs/`
by default. Set `BATON_PREVIEW_OUTPUT` to a temporary directory to run the
integration assertions without replacing the drafts.

These assets are pending replacement and are not the final marketplace preview.
When the replacement still is approved, place it at the repository root as
`preview.webp` (or another supported preview format) for automatic discovery.
The marketplace preview is optional; keep drafts here until then.
