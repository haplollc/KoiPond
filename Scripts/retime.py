#!/usr/bin/env python3
"""Rebuilds a paced Koi Pond recording at a steady 60 fps from its stamps.

usage: retime.py <raw.mp4> <out.mp4> --length 17.4 [--fps 60] [--scale 3]

A simulator recording's timestamps wobble under load (a frame can land tens
of milliseconds late), but every frame of a take carries the pond's clock in
the corner stamp (see sync.py). For each output frame this picks the
recorded frame whose stamp is nearest that instant of the take, so the
result is timed exactly by the take's clock: second 0 is the take's start.
A scripted take keeps its clock to whole 60ths of a second, so at 60 fps
every output frame is an exact instant of the take.
"""
import argparse
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sync import frame_times, stamps  # noqa: E402


def frame_size(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                          "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path],
                         capture_output=True, text=True, check=True).stdout.strip()
    w, h = out.split("x")
    return int(w), int(h)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--length", type=float, required=True, help="the take's length in seconds")
    ap.add_argument("--fps", type=float, default=60)
    ap.add_argument("--scale", type=int, default=3, help="pixels per point of the recorded screen")
    args = ap.parse_args()

    times = np.array(frame_times(args.raw))
    clocks = np.array(stamps(args.raw, len(times), args.scale))
    # Only frames of the take itself. A frame left on screen from before it
    # (the warm-up's frozen instant as the app is killed, the home screen)
    # can carry a readable stamp, and keeping it would hold back every real
    # frame until the clock caught up with it. The take's frames all lie on
    # one line, recording time against take time, so find that line from
    # the stamps themselves (the median slope between frames well apart)
    # and keep only the frames on it.
    valid = np.flatnonzero((clocks > 0.0) & (clocks < args.length + 1))
    t, c = times[valid], clocks[valid]
    span = max(len(valid) // 3, 1)
    dc = c[span:] - c[:-span]
    if not np.any(dc > 0.1):
        sys.exit("no running clock found in the recording")
    pace = np.median((t[span:] - t[:-span])[dc > 0.1] / dc[dc > 0.1])
    start = np.median(t - pace * c)
    valid = valid[np.abs(t - pace * c - start) < 0.25]
    # ...and a clock that never runs backwards (a misread stamp would).
    keep, last = [], -1.0
    for i in valid:
        if clocks[i] >= last:
            keep.append(i)
            last = clocks[i]
    keep = np.array(keep)
    kc = clocks[keep]
    print(f"# pace {pace:.3f}; {len(keep)} frames of the take, "
          f"{int(np.sum((clocks > 0.0) & (clocks < args.length + 1))) - len(keep)} stray ones dropped")

    n_out = int(round(args.length * args.fps))
    picks, errors = [], []
    for k in range(n_out):
        t = k / args.fps
        j = int(np.argmin(np.abs(kc - t)))
        picks.append(int(keep[j]))
        errors.append(abs(kc[j] - t))
    errors = np.array(errors) * 1000
    repeats = sum(1 for a, b in zip(picks, picks[1:]) if a == b)
    print(f"# {n_out} frames from {len(set(picks))} recorded ones; timing error "
          f"median {np.median(errors):.1f} ms, max {errors.max():.1f} ms; {repeats} repeated")

    w, h = frame_size(args.raw)
    size = w * h * 3
    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-i", args.raw, "-fps_mode", "passthrough",
                            "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                            "-s", f"{w}x{h}", "-r", str(args.fps), "-i", "-",
                            "-c:v", "libx264", "-preset", "medium", "-crf", "10",
                            "-pix_fmt", "yuv420p", args.out], stdin=subprocess.PIPE)
    wanted = {}
    for p in picks:
        wanted[p] = wanted.get(p, 0) + 1
    last_needed = max(picks)
    index = 0
    while index <= last_needed:
        frame = dec.stdout.read(size)
        if len(frame) < size:
            break
        for _ in range(wanted.get(index, 0)):
            enc.stdin.write(frame)
        index += 1
    dec.stdout.close()
    dec.kill()
    enc.stdin.close()
    enc.wait()
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
