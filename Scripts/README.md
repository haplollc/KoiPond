# Scripts

Re-making the media from the demo app's scripted takes.

The pond keeps its own clock, so a take can run several times slower than real time (a busy machine still captures every frame) and be put back together at an exact 60 fps afterwards. In a take, the demo stamps the pond's clock in the screen's top-left corner as a 4 x 4 barcode of 3 pt cells, where a device frame's rounded corner hides it.

- `record.sh <out.mp4>` builds the demo (Release), opens the take once so the water shader's pipeline is built (it can take half a minute the first time on a busy machine), records the take on an iPhone simulator, and rebuilds it at 60 fps with the two scripts below.
- `sync.py <raw.mp4> --pace 8` reads the stamps back and reports how evenly the take was sampled (a 60 fps video needs a frame every 16.7 ms of take time).
- `retime.py <raw.mp4> <out.mp4> --length 17.4` picks, for each 1/60 s of the take, the recorded frame whose stamp shows that instant, dropping stray frames from before the take.

```sh
Scripts/record.sh hero.mp4                  # pool, then pond, then pool again (17.4 s)
SCRIPT=pond Scripts/record.sh pond.mp4      # just the pond (9.8 s)
SCRIPT=pool Scripts/record.sh pool.mp4      # just the pool (8.6 s)
```

`record.sh` also takes `PACE` (default 8), `HOLD` (real seconds the first instant is held, default 6), `SIM=<udid>` (default: the first booted iPhone), `EVENTS=<file>` (also log what happened when, as JSON, for laying sound under the video) and `BUILD=0` (skip the build). The takes themselves are `KoiScript.hero`, `.pool` and `.pond` in `Sources/KoiPond/World/KoiScript.swift`; the demo's launch switches are listed in `Demo/KoiPondDemo/DemoConfig.swift`.

The video comes out silent and edge to edge (a take hides the status bar and the home indicator); frame it however you like.

Needs Xcode, ffmpeg, and Python 3 with numpy and Pillow. Keep anything else off the recording simulator while it records (another launch ends the take), and keep an eye on free disk space: with none left, simctl writes empty files.
