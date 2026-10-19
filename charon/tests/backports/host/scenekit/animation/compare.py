#!/usr/bin/env python3
"""compare.py <oracle-dir> <device-dir> : holds the port's animation series (tests/backports/device/scenekit-animation.m)
to macOS SceneKit's (series.swift through record.sh), case by case.

A sample passes when it lies within a tube around SceneKit's curve (its samples joined by straight lines): 5 ms across
in time and, in value, 1e-3 for a node's values and one level for a pixel. SceneKit's own samples sit up to 3.5 ms
off the curves they follow, the time stamp of a sample being taken just before the frame that evaluates it; a second
run of SceneKit against a first stays within the tube. The shimmer group begins at media time 1.0 and repeats every 4 s,
so it is compared by phase ((abs - 1) mod 4), not by time since the add. While an animation runs its samples are held to the
tube; after it, to the value SceneKit settles on; its end, to SceneKit's within the larger sampling gap and 5 ms. The
delegate's calls must match in order and flag, and in time within 20 ms (a frame and a sleep). remove-midway is
removed by the test's own clock, so there only the part before the removal and the value after it are held.

A series that is empty, cut short, or whose values do not parse fails: every sample carries all the oracle's columns, the
running samples begin where the oracle's do (and end there, when the end is timed) within the device's largest sampling
gap and 5 ms, a running sample beyond the oracle's span by more than that is outside, and the series lasts as long as
the oracle's (compare_test.py held this until it was deleted with no caller left).

The negative control: the device's series must NOT pass against the -mutant cases, SceneKit's own series of the same
animation a little wrong (duration 5% long; a spring 22 stiff instead of 21)."""
import os, re, sys

VALUE_TOL = {"pixel": 1.0, "node": 1e-3}
TIME_TOL = 0.005
EVENT_TOL = 0.020

def read(path):
    samples, events = [], []
    added = None
    for line in open(path):
        if line.startswith("added="):
            added = float(line[6:])
            continue
        if line.startswith("events:"):
            events = re.findall(r'"(start|stop) ([0-9.]+)(?: finished=(\d))?"', line)
            continue
        if not line.startswith("t="):
            continue
        fields = line.split()
        t = float(fields[0][2:])
        absolute = float(fields[1][4:])
        running = "keys=0" not in line
        numbers = []
        for f in fields[2:]:
            if f in ("model", "pixel") or f.startswith("keys="):
                if f == "model":
                    break
                continue
            try:
                numbers.append(float(f))
            except ValueError:
                break
        samples.append((t, absolute, numbers, running, absolute - added if added is not None else t))
    return samples, [(kind, float(when), flag) for kind, when, flag in events]

def tube(points, x, v, value_tol):
    """The smallest distance from (x, v) to the oracle's polyline, with time in units of TIME_TOL and value in units
    of value_tol: at most 1 is within the tube. Looks at the segments within 0.1 s."""
    best = float("inf")
    for (x0, v0), (x1, v1) in zip(points, points[1:]):
        if x1 < x - 0.1 or x0 > x + 0.1:
            continue
        ax, ay = x0 / TIME_TOL, v0 / value_tol
        bx, by = x1 / TIME_TOL, v1 / value_tol
        px, py = x / TIME_TOL, v / value_tol
        dx, dy = bx - ax, by - ay
        length = dx * dx + dy * dy
        f = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
        cx, cy = ax + f * dx, ay + f * dy
        best = min(best, ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5)
    return best

def check(oracle_path, device_path, kind, clock="first frame", timed_end=True):
    oracle, oracle_events = read(oracle_path)
    device, device_events = read(device_path)
    key = {"phase": lambda s: (s[1] - 1.0) % 4.0, "add": lambda s: s[4], "first frame": lambda s: s[0]}[clock]
    ordered = sorted(oracle, key=key)
    columns = len(ordered[0][2]) if ordered else 0
    worst = 0.0
    bad = []
    running = [s for s in ordered if s[3]]
    if not running:
        raise SystemExit("%s: SceneKit's own series has no running sample" % oracle_path)
    # a series that is empty, cut short or unparsed must not pass: every sample carries all the columns, and the running
    # samples cover the oracle's running span from its start to (when the end is timed) its end, within the sampling gap
    if not device:
        bad.append(("no samples", device_path))
    bad += [("columns", round(key(s), 4), len(s[2]), columns) for s in device if len(s[2]) != columns]
    if device and max(s[0] for s in device) < max(s[0] for s in oracle) - (max([y[0] - x[0] for x, y in zip(device, device[1:])] + [0.0]) + TIME_TOL):
        bad.append(("series ends early", max(s[0] for s in oracle), max(s[0] for s in device)))
    device_running = sorted(key(s) for s in device if s[3])
    gap = max([b - a for a, b in zip(device_running, device_running[1:])] + [0.0]) + TIME_TOL
    if not device_running or device_running[0] > key(running[0]) + gap or (timed_end and device_running[-1] < key(running[-1]) - gap):
        bad.append(("span", (key(running[0]), key(running[-1])), (device_running[0], device_running[-1]) if device_running else None))
    polylines = [[(key(s), s[2][c]) for s in running if len(s[2]) > c] for c in range(columns)]
    settled = [s for s in oracle if not s[3]]
    for sample in device:
        x = key(sample)
        if not sample[3]:
            # after the animation: the value SceneKit settles on, whenever the frame
            if settled:
                for c, got in enumerate(sample[2][:columns]):
                    error = abs(got - settled[-1][2][c]) / VALUE_TOL[kind]
                    worst = max(worst, error)
                    if error > 1:
                        bad.append(("after", round(x, 4), c, got, settled[-1][2][c]))
            continue
        if x < key(running[0]) or x > key(running[-1]):
            # beyond the oracle's span by more than the end tolerance: outside
            if timed_end and (x < key(running[0]) - gap or x > key(running[-1]) + gap):
                bad.append(("beyond the span", round(x, 4)))
            continue
        for c, got in enumerate(sample[2][:columns]):
            distance = tube(polylines[c], x, got, VALUE_TOL[kind])
            worst = max(worst, distance)
            if distance > 1:
                bad.append((round(x, 4), c, got, round(distance, 2)))
    if timed_end:
        # when the animation ends: the first sample without it, within the larger sampling gap and the time tolerance
        def end(series):
            for before, after in zip(series, series[1:]):
                if before[3] and not after[3]:
                    return after[0], after[0] - before[0]
            return None, 0
        (oracle_end, oracle_gap), (device_end, device_gap) = end(oracle), end(device)
        if (oracle_end is None) != (device_end is None) or (oracle_end is not None and abs(oracle_end - device_end) > max(oracle_gap, device_gap) + TIME_TOL):
            bad.append(("end", oracle_end, device_end))
    event_bad = []
    if [(k, f) for k, _, f in oracle_events] != [(k, f) for k, _, f in device_events]:
        event_bad.append(("sequence", oracle_events, device_events))
    elif timed_end:
        for (k, a, _), (_, b, _) in zip(oracle_events, device_events):
            if abs(a - b) > EVENT_TOL:
                event_bad.append((k, a, b))
    return bad, event_bad, worst, len(device)

CASES = [("euler-basic", "node"), ("euler-spring", "node"), ("euler-spring-velocity", "node"), ("scale-reverse", "node"),
         ("opacity-later", "node"), ("remove-midway", "node"), ("gradient", "pixel"), ("shimmer", "pixel")]

def main(oracle_dir, device_dir):
    status = 0
    for name, kind in CASES:
        bad, event_bad, worst, n = check(os.path.join(oracle_dir, name + ".txt"), os.path.join(device_dir, name + ".txt"),
                                         kind, clock={"shimmer": "phase", "opacity-later": "add"}.get(name, "first frame"),
                                         timed_end=name != "remove-midway")
        ok = not bad and not event_bad
        status |= not ok
        print("%s: %d samples, worst distance to SceneKit's curve %.2f of the tube; %s%s" % (
            name, n, worst, "within" if ok else "OUTSIDE", "" if ok else " %s %s" % (bad[:3], event_bad)))
    # the port's gradient and shimmer against SceneKit drawing Metal's own levels: reported, not held (their levels
    # differ from the rule's at ties; facts/SceneKit/SCNView.md, "Textures")
    for name in ("gradient", "shimmer"):
        bad, event_bad, worst, n = check(os.path.join(oracle_dir, name + "-metal.txt"), os.path.join(device_dir, name + ".txt"),
                                         "pixel", clock={"shimmer": "phase"}.get(name, "first frame"))
        print("reported, not held: %s against Metal's levels, worst %.2f of the tube, %d samples outside" % (name, worst, len(bad)))
    for name in ("euler-basic", "euler-spring"):
        bad, event_bad, worst, _ = check(os.path.join(oracle_dir, name + "-mutant.txt"), os.path.join(device_dir, name + ".txt"), "node")
        caught = bool(bad)
        status |= not caught
        print("negative control %s-mutant: %s (%d samples outside the tube, worst %.2f)" % (
            name, "OUTSIDE, as it must be" if caught else "within: the check cannot tell it", len(bad), worst))
    return status

if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
