#!/bin/zsh
# usage: Scripts/record.sh <out.mp4>
#
# Records one of the demo's scripted takes on an iPhone simulator and
# rebuilds it as an exact 60 fps video in <out.mp4>.
#
# The take runs slowed down (PACE), so a busy machine still captures every
# frame, and stamps the pond's clock in the screen's top-left corner;
# sync.py reads that stamp back to check the take was sampled densely
# enough, and retime.py picks, for each 1/60 s of the take, the recorded
# frame whose stamp shows that instant. The stamp sits where a device
# frame's rounded corner hides it.
#
#   SCRIPT=hero     the take: hero (pool, then pond, then pool; 17.4 s),
#                   pool (8.6 s) or pond (9.8 s)
#   PACE=8          run the pond's clock this many times slower
#   HOLD=6          real seconds the take holds its first instant
#   SIM=<udid>      the simulator (default: the first booted iPhone)
#   EVENTS=<file>   also log what happened when, as JSON, for laying sound
#                   under the video (taps, grabs, gulps, bounces, ...)
#   BUILD=0         skip building and installing the demo (Release)
#
# Needs Xcode, ffmpeg, and Python 3 with numpy and Pillow.
set -euo pipefail
# Paths are taken from where the script is run (the events file is written
# by the app inside the simulator, so it has to be absolute anyway).
OUT="${1:?usage: Scripts/record.sh <out.mp4>}"
OUT=${OUT:a}
EVENTS=${EVENTS:-}
if [[ -n "$EVENTS" ]]; then EVENTS=${EVENTS:a}; fi
cd "$(dirname "$0")/.."
SCRIPT=${SCRIPT:-hero}
PACE=${PACE:-8}
HOLD=${HOLD:-6}
APP_ID=com.haplo.KoiPondDemo
case $SCRIPT in
  hero) LENGTH=17.4 ;;
  pool) LENGTH=8.6 ;;
  pond) LENGTH=9.8 ;;
  *) echo "SCRIPT must be hero, pool or pond" >&2; exit 1 ;;
esac

if [[ -z "${SIM:-}" ]]; then
  SIM=$(xcrun simctl list devices booted -j | python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if 'iPhone' in d.get('deviceTypeIdentifier', '') and 'iOS' in runtime:
            print(d['udid']); sys.exit()
sys.exit('no booted iPhone simulator: boot one, or set SIM')")
fi
echo "recording the $SCRIPT take on $SIM at pace $PACE"

if [[ "${BUILD:-1}" != 0 ]]; then
  xcodebuild -project Demo/KoiPondDemo.xcodeproj -scheme KoiPondDemo -configuration Release \
    -destination "id=$SIM" -derivedDataPath build/DerivedData -quiet build
  xcrun simctl install "$SIM" build/DerivedData/Build/Products/Release-iphonesimulator/KoiPondDemo.app
fi

mkdir -p build/takes
RAW="build/takes/$SCRIPT-raw.mp4"
SHOT="build/takes/warm.png"

# Whether the water is on screen: until the shader's pipeline is built (it
# can take half a minute the first time on a busy machine) the pond is black.
drawn() {
  xcrun simctl io "$SIM" screenshot --type=png "$SHOT" >/dev/null 2>&1 || return 1
  python3 - "$SHOT" <<'PY'
import sys
import numpy as np
from PIL import Image
pixels = np.asarray(Image.open(sys.argv[1]).convert("RGB").resize((110, 239)))
black = (pixels.max(axis=2) < 10).mean()
sys.exit(0 if black < 0.05 else 1)
PY
}

# Warm up: open the take (barely moving) until the water is drawn, so the
# pipeline is built before the recording starts.
xcrun simctl terminate "$SIM" $APP_ID 2>/dev/null || true
env SIMCTL_CHILD_KOIPOND_DEMO=1 SIMCTL_CHILD_KOIPOND_SCRIPT="$SCRIPT" SIMCTL_CHILD_KOIPOND_PACE=100 \
  xcrun simctl launch "$SIM" $APP_ID >/dev/null
for i in {1..60}; do drawn && break; sleep 2; done
xcrun simctl terminate "$SIM" $APP_ID 2>/dev/null || true
rm -f "$SHOT"

# The take.
rm -f "$RAW"
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$RAW" >/dev/null 2>&1 &
REC=$!
sleep 1.5
env SIMCTL_CHILD_KOIPOND_DEMO=1 SIMCTL_CHILD_KOIPOND_SCRIPT="$SCRIPT" SIMCTL_CHILD_KOIPOND_PACE="$PACE" \
  SIMCTL_CHILD_KOIPOND_HOLD="$HOLD" ${EVENTS:+SIMCTL_CHILD_KOIPOND_EVENTS="$EVENTS"} \
  xcrun simctl launch "$SIM" $APP_ID >/dev/null
sleep $(( HOLD + LENGTH * PACE + 4 ))
kill -INT $REC
wait $REC 2>/dev/null || true
xcrun simctl terminate "$SIM" $APP_ID 2>/dev/null || true

python3 Scripts/sync.py "$RAW" --pace "$PACE"
python3 Scripts/retime.py "$RAW" "$OUT" --length "$LENGTH"
rm -f "$RAW"
