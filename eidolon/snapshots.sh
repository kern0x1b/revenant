#!/bin/bash
# snapshots.sh [--accept]: render the snapshot scenarios in the emulated device and compare them with
# eidolon/Snapshots/reference. The scenarios need a key window and SpringBoard's own lifecycle, so they
# are the demo application built as the snapshot bundle (the same sources, another Info.plist) and
# started through SpringBoard by xmake emulate launch; until-exit holds the guest until it has rendered
# them all and quit. Every scenario is drawn as well as dumped, so the picture can be looked at.
# ONLY=<name> renders one scenario: it is a key of the bundle's Info.plist, so the port is configured
# with it and the bundle rebuilt.
set -eu
cd "$(dirname "$0")"
accept=${1:-}
name=snap-$(date +%H%M%S)
out=$PWD/runs.noindex/$name
mkdir -p "$out/shots"
# exported, not set on one command: xmake reads the port again at every step (configure, build, launch), and a step that does not see the
# name builds the bundle for every scenario
export EIDOLON_SNAPSHOT_ONLY=${ONLY:-}
# -c, as in run-emu.sh: the package versions of the last configure are not kept, so the run is of the pin as it stands
xmake f -c -P eidolon -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
status=0
xmake emulate -P eidolon -d "${DEVICE:-iPod4,1}" -r "${RELEASE:-6.0}" -s "${SECONDS_BUDGET:-240}" -t 3000 \
    launch space.kern0x1b.eidolon.snapshots until-exit > "$out/launch.log" 2>&1 || status=$?
cat "$out/launch.log"
folder=$(sed -n 's/^run folder //p' "$out/launch.log" | tail -1)
if [ -z "$folder" ] || [ ! -d "$folder/results/eidolon-snapshots" ]; then
  echo "no snapshots were written; the launch log is $out/launch.log" >&2
  exit 1
fi
cp "$folder"/results/eidolon-snapshots/* "$out/shots/"
cp "$folder"/verdict.json "$out/" 2>/dev/null || true
grep -a "snapshot\|snapshots done" "$folder/results/app.stdout" 2>/dev/null || true
[ "$status" -ne 0 ] && { echo "the launch failed, exit=$status" >&2; exit "$status"; }
# The scenarios the run owes, not the ones it produced: a scenario the application did not render is
# a missing file, and a loop over what arrived would compare 36 of 37 and pass. comm names the
# difference, and a difference is the run's failure.
ls "$out"/shots/*.txt >/dev/null 2>&1 || { echo "no scenario was rendered; the launch log is $out/launch.log" >&2; exit 1; }
ls eidolon/Snapshots/reference/*.txt | xargs -n1 basename | sort > "$out/wanted"
# one scenario owes one file, whether it has a reference yet or not: a new scenario's reference is written by its first run
if [ -n "${ONLY:-}" ]; then echo "$ONLY.txt" > "$out/wanted"; fi
ls "$out"/shots/*.txt | xargs -n1 basename | sort > "$out/got"
if ! missing=$(comm -23 "$out/wanted" "$out/got") || [ -n "$missing" ]; then
  echo "these scenarios were not rendered: $(echo "$missing" | tr '\n' ' ')" >&2
  exit 1
fi
if extra=$(comm -13 "$out/wanted" "$out/got") && [ -n "$extra" ]; then
  echo "the run wrote scenarios there are no references for: $(echo "$extra" | tr '\n' ' ')" >&2
  exit 1
fi
fail=0
for shot in "$out"/shots/*.txt; do
  base=$(basename "$shot"); reference=eidolon/Snapshots/reference/$base
  if [ ! -e "$reference" ] || [ "$accept" = --accept ]; then
    cp "$shot" "$reference"; echo "reference $base written"
  elif cmp -s "$shot" "$reference"; then
    echo "match $base"
  else
    echo "DIFFERS $base"; diff -u "$reference" "$shot" | head -20; fail=1
  fi
done
exit $fail
