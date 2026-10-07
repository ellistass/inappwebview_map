#!/usr/bin/env python3
"""Drive the Android emulator's GPS along a route from a captured response.

Feeds one `adb emu geo fix` per second along the route's polyline, so the
app's navigation mode can be tested without moving.

    python3 tool/simulate_drive.py [fixture] [route] [start_m] [end_m] [m_per_s]

Defaults: test/fixtures/directions_desktop.txt, route 0, 0 m → end, 15 m/s
(~54 km/h). The fixture must be a *desktop* response (it has geometry at
d[0][7]). Start navigation on the same route in the app first, or it will
reroute.
"""
import itertools
import json
import math
import os
import subprocess
import sys
import time

ADB = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')

args = sys.argv[1:] + [None] * 5
fixture = args[0] or 'test/fixtures/directions_desktop.txt'
route = int(args[1] or 0)

text = open(fixture).read()
d = json.loads(text[text.index('['):])
g = d[0][7][route]
pts = [(a / 1e7, b / 1e7)
       for a, b in zip(itertools.accumulate(g[0]), itertools.accumulate(g[1]))]


def dist(a, b):
    kx = 111320 * math.cos(math.radians(a[0]))
    return math.hypot((b[0] - a[0]) * 111320, (b[1] - a[1]) * kx)


cum = [0.0]
for a, b in zip(pts, pts[1:]):
    cum.append(cum[-1] + dist(a, b))


def at(m):
    i = next((k for k in range(1, len(cum)) if cum[k] >= m), len(cum) - 1)
    span = cum[i] - cum[i - 1]
    t = 0 if span == 0 else max(0, min(1, (m - cum[i - 1]) / span))
    a, b = pts[i - 1], pts[i]
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


start = float(args[2] or 0)
end = float(args[3] or cum[-1])
speed = float(args[4] or 15)
print(f'route {route}: {cum[-1]:.0f} m, driving {start:.0f} → {end:.0f} m at {speed} m/s')

m = start
while m <= end:
    lat, lng = at(m)
    # geo fix takes longitude first.
    subprocess.run([ADB, 'emu', 'geo', 'fix', str(lng), str(lat)], capture_output=True)
    m += speed
    time.sleep(1)
print('done')
