#!/usr/bin/env bash
# Render the actual card with fixture data. No service or public relay traffic.
set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d /tmp/baton-card.XXXXXX)
cp -r /usr/share/omarchy/shell/Commons /usr/share/omarchy/shell/Ui "$work/"
ln -s "$src" "$work/Baton"
cp "$src/dev/CardPreview.qml" "$work/shell.qml"
export BATON_CARD_OUTPUT="${BATON_CARD_OUTPUT:-$work/cards.png}"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 20 quickshell -p "$work/shell.qml" --no-color
printf 'Card preview: %s\n' "$BATON_CARD_OUTPUT"
