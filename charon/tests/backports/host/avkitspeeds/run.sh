#!/bin/sh
# run.sh — the host half of the AVPlaybackSpeed differential: what the system's own AVKit answers for
# the speeds a playback UI offers. run.sh writes those answers to avkitspeeds.json in the build
# directory and prints them, so the numbers the port ships can be read against the host's rather than
# against this file's comment. The port's own values live in
# packages/a/apple-backports/AVKit/AVPlayerViewControllerSpeeds16.m and the row of AVPlaybackSpeed.
#
# A device pass would run the port's own object against this file; no such test is in the tree yet, and
# facts/AVKit/AVPlaybackSpeed.md says so rather than implying one is.
#
# The build directory is inside the worktree's .agent-work, never the system temp path, which is wiped.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
build=${BUILD:-$here/../../../../.agent-work/avkitspeeds-host}
mkdir -p "$build"
xcrun clang -fobjc-arc -w "$here/host.m" -framework AVKit -framework Foundation -o "$build/host"
"$build/host" | tee "$build/avkitspeeds.log"
python3 - "$build/avkitspeeds.log" "$build/avkitspeeds.json" <<'PY'
import json, re, sys
log, out = sys.argv[1], sys.argv[2]
speeds, other = [], {}
for line in open(log):
    line = line.rstrip("\n")
    if line.startswith("speed: "):
        fields = dict(kv.split("=", 1) for kv in line[len("speed: "):].split(" "))
        speeds.append({"rate": float(fields["rate"]), "name": fields["name"], "numeric": fields["numeric"]})
    elif ": " in line:
        key, value = line.split(": ", 1)
        other[key] = value
json.dump({"locale": other.get("locale"), "count": int(other.get("count", 0)), "speeds": speeds}, open(out, "w"), indent=2, sort_keys=True)
print("records: %d speeds, locale %s" % (len(speeds), other.get("locale")))
PY
