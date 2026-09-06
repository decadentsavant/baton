#!/usr/bin/env bash
# Isolated, labelled demo of the real widget/service. No public waves or clipboard writes.
set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d /tmp/baton-demo.XXXXXX)
output="${BATON_PREVIEW_OUTPUT:-$src}"
mkdir -p "$output/docs"
export BATON_PREVIEW_FRAMES="$work/frames"
export BATON_PREVIEW_RELAY="http://127.0.0.1:${BATON_PREVIEW_PORT:-18081}"
export XDG_STATE_HOME="$work/state"
export XDG_CACHE_HOME="$work/cache"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
mkdir -p "$BATON_PREVIEW_FRAMES" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
cp -r /usr/share/omarchy/shell/Commons /usr/share/omarchy/shell/Ui "$work/"
ln -s "$src" "$work/Baton"
cp "$src/dev/Preview.qml" "$work/shell.qml"
# Suppress actual desktop notifications in this isolated shell only. The
# preview displays their illustrative equivalent; production code is unchanged.
python3 - "$work/Commons/Util.qml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();a=s.index('  function execArgv(argv) {');b=s.index('\n  }',a)
s=s[:a]+'  function execArgv(argv) { console.log("Preview notification: " + JSON.stringify(argv))'+s[b:];p.write_text(s)
PY
bin="${BIN:-$src/../baton-relay/baton-relay}"
if [[ ! -x "$bin" ]]; then echo 'Build the separate relay first: cd ../baton-relay && go build -o baton-relay .' >&2; exit 1; fi
pids=()
trap 'for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done' EXIT
"$bin" -addr "127.0.0.1:${BATON_PREVIEW_PORT:-18081}" -cooldown 5s -trusted-proxies 127.0.0.1/32 >"$work/relay.log" 2>&1 &
pids+=("$!")
for i in {1..50}; do if curl -fsS "$BATON_PREVIEW_RELAY/healthz" >/dev/null 2>&1; then break; fi; sleep .1; done
quickshell -p "$work/shell.qml" --no-color >"$work/widget.log" 2>&1 &
widget_pid=$!; pids+=("$widget_pid")
python3 - "$BATON_PREVIEW_RELAY" "$work/widget.log" <<'PY'
import sys,time,json,urllib.request,threading
from pathlib import Path
base=sys.argv[1]
# A second widget instance is in the QML scene. It must not make a second stream.
for _ in range(70):
    data=json.load(urllib.request.urlopen(base+'/stats'))
    if data['online']==1: break
    time.sleep(.1)
else: raise RuntimeError('shared widget did not connect')
time.sleep(.5)
assert json.load(urllib.request.urlopen(base+'/stats'))['online']==1
req=urllib.request.Request(base+'/stream',headers={'X-Baton-Id':'preview-stranger','CF-Connecting-IP':'198.51.100.1'})
stream=urllib.request.urlopen(req)
threading.Thread(target=lambda:list(stream),daemon=True).start()
def wave():
    req=urllib.request.Request(base+'/wave',method='POST',headers={'X-Baton-Id':'preview-stranger','CF-Connecting-IP':'198.51.100.1','X-Country':'PL'})
    data=json.load(urllib.request.urlopen(req))
    assert data.get('delivered'),data
def wait_marker(marker):
    for _ in range(1000):
        if marker in Path(sys.argv[2]).read_text(): return
        time.sleep(.1)
    raise RuntimeError('preview did not reach '+marker)
wait_marker('PREVIEW_WAVE1')
wave()
wait_marker('PREVIEW_WAVE2')
wave() # A plain wave must preserve the held baton.
wait_marker('BATON_CHECK')
assert json.load(urllib.request.urlopen(base+'/stats'))['total']==3

PY
wait "$widget_pid"
python3 - "$work/widget.log" <<'PY'
import json,sys
text=open(sys.argv[1]).read();lines=[l.split('BATON_CHECK ',1)[1] for l in text.splitlines() if 'BATON_CHECK ' in l]
assert lines,text
state=json.loads(lines[-1]);assert state==dict(connected=True,received=True,retained=True,passed=True,pending=False),state
release=[l.split('BATON_RELEASE ',1)[1] for l in text.splitlines() if 'BATON_RELEASE ' in l]
assert release and json.loads(release[-1])==dict(widgets=0,connected=False),text
assert all(error not in text for error in ('ReferenceError', 'TypeError', 'PREVIEW_TIMEOUT', 'Error:')),text
print('Multi-widget connection, plain-wave retention, handoff and cooldown: passed')
PY
ffmpeg -hide_banner -loglevel error -y -framerate 20 -i "$BATON_PREVIEW_FRAMES/frame-%04d.png" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$output/docs/preview.mp4"
ffmpeg -hide_banner -loglevel error -y -i "$BATON_PREVIEW_FRAMES/frame-0140.png" -frames:v 1 "$output/preview.webp"
printf 'Draft preview written to %s. Test logs: %s\n' "$output" "$work"
