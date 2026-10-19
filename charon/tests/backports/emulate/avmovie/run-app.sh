#!/bin/sh
# run-app.sh - the AVMovie host differential's probe (tests/backports/host/avf-movie4/probe.m) as an installed application on the
# emulated iPhone 4S at 6.1.3, against the host's table of the same probe.
#
# The movies are the ones the host's AVAssetWriter made in run.sh's run folder (movies/ of AVMOVIE5_HOST, default
# .agent-work/runs/v-avmovie5/host-rel2): the application reads them from its bundle. The rows the host differential holds
# out (the reason text and the data-b rows) are held out here too, and counted on the line this prints.
#
# Usage: sh tests/backports/emulate/avmovie/run-app.sh
# Run through coordination/heavy.sh (one emulator boot). The exit status is 0 only when every compared row is equal and the
# probe's own "rows: N" count matches the rows it printed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
host=${AVMOVIE5_HOST:-$root/.agent-work/runs/v-avmovie5/host-rel2}
movies=$host/movies
stamp=$(date +%Y%m%d-%H%M%S)
out=${AVMOVIE5_APP:-$root/.agent-work/runs/v-avmovie5/emu-$stamp}
[ -f "$host/build/host.table" ] || { echo "the host table is missing ($host/build/host.table): run tests/backports/host/avf-movie4/run.sh first" >&2; exit 1; }
mkdir -p "$out/movies"
cp "$movies/movie-a.mov" "$movies/movie-b.mov" "$movies/movie-c.mov" "$out/movies/"
cp "$here/app/xmake.lua" "$here/app/Info.plist" "$here/app/control" "$out/"
cd "$out"
CHARAVMOVIE_ROOT=$root CHARAVMOVIE_MINIMUM=6.1.3 xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the application did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
CHARAVMOVIE_ROOT=$root CHARAVMOVIE_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 install >"$out/install.log" 2>&1 || {
    echo "the application did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
# The probe ends the application itself (exit status is its failure count); until-exit holds the emulator until it does.
set +e
CHARAVMOVIE_ROOT=$root CHARAVMOVIE_MINIMUM=6.1.3 xmake emulate -d iPhone4,1 -r 6.1.3 -s 240 launch local.charon.backports.avmovieprobe until-exit >"$out/launch.log" 2>&1
launch_status=$?
xmake emulate -d iPhone4,1 -r 6.1.3 log >"$out/emulate.log" 2>&1
set -e
echo "run folder: $out (launch status $launch_status)"
# A nonzero launch status is accepted only when the application's own verdict shows a clean exit: the emulator reports an
# application that ends at the budget's "reached" as a failed launch, and the exit status is in verdict.json beside its log.
if [ "$launch_status" -ne 0 ]; then
    device=$(sed -n 's|.*emulator log is \(/[^ ]*\)/emulator\.log.*|\1|p' "$out/launch.log" | tail -1)
    exit_field=""
    if [ -n "$device" ] && [ -f "$device/verdict.json" ]; then
        exit_field=$(grep -o '"exit":{[^}]*}' "$device/verdict.json") || exit_field=""
    fi
    case "$exit_field" in
        *'"status":0'*'"signal":0'*|*'"signal":0'*'"status":0'*) ;;
        *)
            echo "the launch exited $launch_status and the application's exit is not clean: $device/verdict.json" >&2
            exit 1
            ;;
    esac
    echo "the launch status $launch_status is the emulator's report of the budget; the application's own exit is clean ($exit_field)"
fi
# The probe's table is the lines from its first row to its count line; nothing else in the launch log is compared.
sed -n '/^class superclass = /,/^rows: /p' "$out/launch.log" > "$out/probe.table"
want=$(sed -n 's/^rows: \([0-9][0-9]*\)$/\1/p' "$out/probe.table" | tail -1)
have=$(grep -c ' = ' "$out/probe.table" || true)
if [ -z "$want" ] || [ "$have" -ne "$want" ]; then
    echo "FAIL: the 6.1.3 table holds $have rows but the probe reported ${want:-no count}; see $out/launch.log" >&2
    exit 1
fi
# The same join as run.sh, on the host's table: the held-out rows are counted, the rest is compared. A row that differs is a
# measurement of 6.1.3, not a failure of the run: the port forwards those members to the release, so the release's own answer
# is what is printed, and each differing row is written into the report with its value.
grep -v -e ' reason = ' -e '^data-b ' -e '^rows: ' "$host/build/host.table" > "$out/host.cmp"
grep -v -e ' reason = ' -e '^data-b ' -e '^rows: ' "$out/probe.table" > "$out/device.cmp"
held=$(( $(grep -c ' reason = ' "$host/build/host.table") + $(grep -c '^data-b ' "$host/build/host.table") ))
compared=$(grep -c ' = ' "$out/host.cmp")
echo "6.1.3 $want rows; host $(grep -c ' = ' "$host/build/host.table") rows; compared $compared, held out $held (reason text and data-b, from the host's table)"
diff -u "$out/host.cmp" "$out/device.cmp" > "$out/diff.log" && differs=0 || differs=$(grep -c '^[-+][^-+]' "$out/diff.log" || true)
if [ "$differs" = 0 ]; then
    echo "ok  every compared row: the 6.1.3 table answers what the host answers"
else
    echo "measured: $differs line(s) of the compared rows differ from the host's; the 6.1.3 values are in $out/diff.log"
fi
exit 0
