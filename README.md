# Baton

**Wave at a random Omarchy user, somewhere in the world. One bit out, one bit back.**

![Baton: a wave arrives from another Omarchy user](preview.webp)

[Watch the 27-second demo](docs/preview.mp4). It shows the real widget at 7×
magnification, with an isolated local relay and explanatory captions.

Click the hand in your Omarchy bar. Somewhere, a stranger's bar pulses:

```text
🇵🇱  Someone in Poland
```

They can wave back. That is the entire product. Baton has no accounts, names,
messages, threads, friends list, or feed. It is a small hello in the corner of
your desktop, from someone who chose the same odd operating system you did.

## Install

On an Omarchy system:

```bash
omarchy plugin add https://github.com/decadentsavant/baton.git --enable
omarchy bar put io.github.decadentsavant.baton --section right
```

The widget connects to `https://relay.baton.buzz`. Left-click waves. Right-click
opens the public baton page. Middle-click copies an invite.

## Requirements and permissions

Requires Omarchy Quattro with its Quickshell bar and plugin commands. Runtime
commands used by the widget are:

| Dependency | Purpose |
|---|---|
| `curl` | HTTPS stream and wave requests to the configured relay. |
| `bash`, coreutils (`mkdir`, `head`, `base32`, `tr`, `mv`, `cat`), `flock` (util-linux) | Create and read the local random identity under a file lock. |
| `omarchy-notification-send` | Incoming-wave and clipboard notifications. |
| `xdg-open` (xdg-utils) | Open the public baton page on right-click. |
| `wl-copy` (wl-clipboard) | Copy an invite on middle-click or the invite command. |
| `canberra-gtk-play` (libcanberra, optional) | Incoming chime when `sound` is enabled. |

The plugin runs with your user permissions inside the existing shell. It needs
no root access, package installation script, additional daemon, downloaded
executable, or remote build. It writes an identity and lock file under
`${XDG_STATE_HOME:-~/.local/state}/baton/`. Enabling the widget opens a connection
to the configured relay; no wave is sent until you click or invoke the wave
command. Browser and clipboard actions happen only when requested.

## Update, disable, and remove

```bash
omarchy plugin update io.github.decadentsavant.baton
omarchy plugin disable io.github.decadentsavant.baton
omarchy plugin enable io.github.decadentsavant.baton
omarchy plugin remove io.github.decadentsavant.baton
```

Omarchy does not update plugins on its own. The widget is a git clone that
moves only when you run the update command above. The relay tells each widget
the oldest version it still fully supports. If yours is older, the tooltip
gains an "Update available" line with the command, and you get one notification
per session. Older widgets keep working until the relay changes the protocol.

Disabling or removing the last widget closes its relay connection. Removal
leaves the local identity directory in place so a reinstall retains it. To
forget the identity too, after removal delete only
`${XDG_STATE_HOME:-$HOME/.local/state}/baton` using your file manager. A future
install will generate a new identity. The public relay is unaffected.

## Batons

Some waves carry a baton. A baton remembers only aggregate facts:

```text
412 hops · alive 3 weeks · 23 countries
```

If a baton reaches you, the widget lights up. Your next wave passes it to
another person and adds a hop. Batons are created as the community grows, about
one per 25 connected clients, with at least one for a two-person community and
no more than 64.

Each person holds at most one baton. If a recipient already has one, the wave
still goes through and the sender keeps theirs. If a holder disconnects, the
baton waits for someone with a free hand. Re-homing does not count as a hop.

Shareable baton pages show a baton's hop count, age, and country count. They do
not identify holders, and they never show a trail.

## Why one bit

A status bar is about twenty pixels tall. One bit is the honest capacity of the
medium, so Baton does not pretend to offer a conversation.

The constraint buys something real. **You cannot be cruel in one bit.** There is
no payload to put an insult in, so the channel is structurally incapable of
carrying harassment rather than moderated into safety after the fact. That is
why a plugin connecting anonymous strangers can ship without a reporting flow,
a moderation queue, or a trust-and-safety budget. The only abuse left is volume,
and the cooldown handles volume.

### Non-goals

Every feature that adds a payload removes that property. So, with affection,
these are not coming: emoji reactions, custom text, replies, profiles, a way to
find the same stranger twice, or a feed of who waved. The answer is no, and it
is the same no for the maintainer's own ideas.

## The cooldown

One wave an hour. A wave you could send every second would be worth nothing,
and the one you receive only lands because the sender spent their hour on it.

A wave into an empty room costs a minute, not an hour. Nobody was affected, and
early on the crowd will sometimes be just you. The widget says so when it
happens, so a click never silently does nothing.

## Privacy

Plainly, because this crowd will read the source anyway:

- **Your identity is a random token** minted locally on first run and stored at
  `~/.local/state/baton/id`. It is not an account. Delete the file and you are
  a different stranger. Nothing is registered and nothing is recoverable.
- **Waves carry a country, never a city, never an address.** The country is
  worked out by the relay from your connecting address using a public-domain
  range list, then dropped. Turn off *Share my country* and yours arrive as
  "somewhere". The widget never reads your location and sends none.
- **The relay sees your IP while you are connected.** Every HTTP server does.
  It hashes it with a salt that changes on every restart, uses the hash only to
  cap waves and streams per address, keeps it in memory, and never writes it
  down. The operator can see how many people are connected, not who.
- **The relay stores aggregates only**: the total wave count and each baton's
  id, birth time, hop count, and country count. Not holders, not who waved at
  whom. While routing a wave the relay necessarily knows sender and recipient,
  and it forgets that relationship the moment the wave is queued.
- **Nothing phones home.** The widget talks to the relay you configure and to
  nothing else. There is no telemetry, no update check, no analytics on the
  public pages.

## Architecture

Baton is centralized, and says so. The client holds one long-lived HTTP stream
open to a relay. The relay keeps the connected clients in memory, picks a random
recipient, and writes the wave down that recipient's stream. There is no
peer-to-peer discovery, no federation, and no distributed anything.

That is a choice, not a shortcut. Random-stranger discovery needs some
rendezvous point that knows who is online right now, and behind home NAT a
peer-to-peer version would still need a central server to introduce two
clients, at which point you have a central server anyway plus hole-punching to
move a single bit. The trade is honest: the public relay is a single point of
failure, and its operator can see who is connected while they are connected.
What the operator cannot do is reconstruct history, because none is written.

## Self-hosting

The server lives in the separate [baton-relay repository](https://github.com/decadentsavant/baton-relay).
It contains the Go service, public pages, Dockerfile, deployment instructions,
and protocol documentation. This client repository does not build or start a
server. Client installations download only this client repository.

The default public relay needs no setup. If you choose to host your own, follow
[the relay guide](https://github.com/decadentsavant/baton-relay#readme), then point
the widget at it:

```bash
omarchy bar set io.github.decadentsavant.baton relayUrl https://relay.example.com
```

You can only wave at people using the same relay; instances do not federate.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `relayUrl` | `https://relay.baton.buzz` | Relay to use. |
| `shareRegion` | `true` | Include your country with waves. Set to `false` to arrive as “somewhere”. |
| `sound` | `false` | Play a chime for incoming waves. |
| `showCounter` | `true` | Show aggregate counters in the tooltip. |

Booleans set from the command line need `--json`, otherwise the shell stores
the word rather than the value:

```bash
omarchy bar set io.github.decadentsavant.baton sound true --json
```

Country sharing is enabled by default, but it is optional and can be turned off:

```bash
omarchy bar set io.github.decadentsavant.baton shareRegion false --json
```

The widget also accepts the words, so either form works. Bar instances on a
multi-monitor desktop share one connection, cooldown, and incoming
notification.

## Keybind

`omarchy-shell baton wave` sends a wave and `omarchy-shell baton invite` copies
an invite, so both can be assigned in your Hyprland keybinding configuration.

## Development

Run the client model tests and validate the plugin without installing it:

```bash
node dev/model-test.js
omarchy plugin validate .
```

The client runtime is QML and JavaScript, loaded by the existing Omarchy shell.
There is no build step. Development tests require Node.js. The optional
[`dev/preview.sh`](dev/preview.sh) integration demo uses a separately built
`../baton-relay/baton-relay` (override with `BIN`), temporary identities, and an
isolated local relay. See [the preview guide](docs/PREVIEW.md) for dependencies
and assertions. Server tests live in the relay repository.

## License

MIT. See [LICENSE](LICENSE).
