#!/bin/bash
# run-emu.sh [NAME]: the engine tests in the emulated device, as xmake emulate run starts them: the
# port's packages go into the image, the test binary is the guest's first process, and its exit status
# is the verdict. NAME is the run folder under runs.noindex, tests-<time> by default.
set -eu
cd "$(dirname "$0")"
name=${1:-tests-$(date +%H%M%S)}
out=$PWD/runs.noindex/$name
[ -e "$out" ] && { echo "run $out exists" >&2; exit 1; }
mkdir -p "$out"
# xmake emulate needs the packages it copies already in the store, so the port is configured and
# built here first. REVENANT_REPO points the package repository at a checkout, REVENANT_ADDON at the addon
# version to build with; both default to what the machine has. -c: without it xmake keeps the package
# versions it resolved at the last configure, so a pin that moved (a new version in the recipe, another
# REVENANT_REPO) was not installed and the run tested the tree it had tested before; nothing the script
# sets lives in the cache it clears.
xmake f -c -P SwiftUI -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
xmake emulate -P SwiftUI -d iPhone4,1 -r 6.1.3 install > "$out/install.log" 2>&1
ran=0
marker=$out/.marked
: > "$marker"
xmake emulate -P SwiftUI -d iPhone4,1 -r 6.1.3 -s "${SECONDS_BUDGET:-240}" -t 1500 \
    run /usr/libexec/SwiftUITests > "$out/run.log" 2>&1 || ran=$?
cat "$out/run.log"
echo "the run itself exited $ran"
# This run's verdict, not the newest on the machine: a marker is written just before the run and the
# verdict is the one written after it, and zero or more than one is refused rather than guessed at. The
# verdict carries the absolute paths of what the test binary wrote, so the folder comes from there. An
# older console line is the last resort, for a tree that prints one.
find "${HOME}/.revenant/emulator/images.noindex" -path "*/iPhone4,1_*/run/verdict.json" -newer "$marker" \
    > "$out/.verdicts" 2>/dev/null || true
count=$(grep -c . "$out/.verdicts" || true)
if [ "$count" -gt 1 ]; then
  echo "$count runs wrote a verdict after this run began, so which is this one is not known:" >&2
  sed 's/^/  /' "$out/.verdicts" >&2
  exit 1
fi
folder=""
if [ "$count" = 1 ]; then
  # the text before the last "/results/" of the verdict's stdout, as rsplit("/results/", 1)[0] gives it
  folder=$(jq -r '(.stdout // "") | split("/results/") | if length > 1 then .[:-1] | join("/results/") else (.[0] // "") end' "$(cat "$out/.verdicts")" 2>/dev/null || true)
fi
[ -n "$folder" ] || folder=$(sed -n 's/^run folder //p' "$out/run.log" | tail -1)
if [ -z "$folder" ] || [ ! -d "$folder/results" ]; then
  echo "this run named no results folder; its log is $out/run.log" >&2
  exit 1
fi
cp -R "$folder/results/." "$out/"
cp "$folder/verdict.json" "$out/" 2>/dev/null || true
status=$ran
grep -a "FAIL\|checks " "$out/test.stdout" | tail -20 || true
echo "exit=$status run folder $folder" | tee -a "$out/verdict.txt"
exit "$status"
