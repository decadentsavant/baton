# Marketplace preparation

No submission has been made. The revised still and 27-second video are ready
for visual review.

## Listing values

- Repository: https://github.com/decadentsavant/baton
- Plugin ID: `io.github.decadentsavant.baton` (keep this permanent)
- Category: `Widgets`
- Tags: `bar`, `quickshell`
- License: MIT

## Repository readiness

The client has one root `manifest.json`, a namespaced ID, a matching QML entry
point, a root README and license, and no symlinks. The README covers installation,
removal, retained identity files, dependencies, network access, and permissions.
The relay source and deployment tools now live in
https://github.com/decadentsavant/baton-relay. Each repository has its own
independent history; the client contains no relay source.

Validation commands:

```bash
omarchy plugin validate .
node dev/model-test.js
```

The isolated runtime demo also checks shared connections across widgets,
plain-wave retention, baton handoff, cooldown, and releasing the last widget.
See [PREVIEW.md](PREVIEW.md) to run it against the separate relay without
changing the installed desktop or replacing the draft assets.

On the current Omarchy installation, standalone `qmllint` needs a temporary
import root mapping `qs` to the installed shell directory. It reports existing
style-property and `QProcess::ExitStatus` metadata warnings; the isolated
Quickshell runtime test passes. Do not describe lint as warning-free.

## Before submitting later

Review the new root `preview.webp` and `docs/preview.mp4`. The still is configured
for marketplace discovery; the video is linked from the README. See
[PREVIEW.md](PREVIEW.md) for pacing, regeneration, and theme checks.

Recheck the permanent ID against the registry and rerun validation on the final
commit. Review the ownership and submission checklist yourself, then use the
[marketplace submission guide](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md).
The marketplace performs its own validation and commit-specific static checks;
local preparation is not listing approval.
