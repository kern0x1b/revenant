#!/bin/sh
# run.sh - the AVMovie and AVMovieTrack read side, the host against the port.
#
# writer.m makes three movies with the host's AVAssetWriter (movie-a and movie-b: one H.264 video track and one
# AAC audio track, fixed durations, 1.0 s and 2.0 s; movie-c is movie-b with the audio track's alternate group
# set to 3 by patching the track header's bytes, so a non-zero alternateGroupID is in the table too).
# probe.m is then built twice: plain, against Apple's AVMovie; and with REVENANT_PORT_BUILD=1, against the port's
# RevenantMovie. The port's AVMovie.m is compiled from a scratch copy that changes only its runtime names (so the
# two classes do not clash in one process), and, for the macOS SDK only, the one body that reads an iOS-only
# property (the probe does not ask that member; see below). Both tables are then joined row by row.
#
# Run DIRECTLY, not through heavy.sh: a few small compiles and a few short runs.
#
# What makes it a check rather than a comparison:
#
#   * a member the port does not define is a RUNTIME error, and the probe stops with it, so a missing method
#     cannot read as "both sides absent and therefore equal";
#   * the row count is taken from the probe's own last line ("rows: N") and compared with the rows each table
#     holds, so an empty or truncated table is a red and not a clean diff;
#   * the PLANTED control: AVMOVIE4_MUTANT=1 applies one wrong track filter (tracksWithMediaType: answers no
#     track) to the scratch copy, the apply is checked by count, and the run must go red;
#   * a build failure is "RUN FAILED" with the compiler's first lines, never a noticed mutation.
#
# Held out of the diff, and counted on the line it prints (each has a reason in the report):
#   * "reason" rows: the text of a raised exception. The host's wording is not this library's, and the exception's
#     NAME is what is compared;
#   * "data-b" rows: a movie made with movieWithData: from the bytes of movie-b. The host cannot open that data (its
#     status is failed, error AVFoundationErrorDomain -11800, and it has no tracks); the port writes the bytes to
#     a file and opens that. This divergence is the design's own and is reported, not hidden: the rows are still
#     printed in the table, and the join says how many it did not compare.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
run=${AVMOVIE4_RUN:-$root/.agent-work/runs/v-avmovie4}
mutant=${AVMOVIE4_MUTANT:-0}
movies=$run/movies
build=$run/build
rm -rf "$movies" "$build"
mkdir -p "$movies" "$build/src"
# -Wno-deprecated-declarations: AVAssetTrack.naturalSize is deprecated on the macOS SDK and the probe reads it on purpose.
# Every other warning is an error to read, so the flags are -Wall and not -w.
flags="-fobjc-arc -Wall -Wno-deprecated-declarations -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo"

# 1. the movies, made by the host's AVAssetWriter
# shellcheck disable=SC2086
xcrun clang $flags "$here/writer.m" -o "$build/writer" > "$build/writer.log" 2>&1 || {
    echo "RUN FAILED: writer.m did not build"; head -8 "$build/writer.log"; exit 1; }
timeout 120 "$build/writer" "$movies" > "$build/writer.out" 2> "$build/writer.err" || {
    echo "RUN FAILED: the writer did not make the movies"; head -5 "$build/writer.err"; exit 1; }

# movie-c: movie-b with the audio track's alternate group set to 3. The second tkhd box is the audio track's (the
# track order is video, then audio, as the probe prints it); its alternate_group is 2 bytes at 38 bytes past the
# 'tkhd' text (8 bytes of box header less the 4 of the type, then version and flags, the creation, modification,
# track ID, reserved and duration fields and 8 reserved bytes, then the layer: 4+20+8+2 = 34 from the payload).
cp "$movies/movie-b.mov" "$movies/movie-c.mov"
tkhd_at=$(LC_ALL=C grep -abo tkhd "$movies/movie-c.mov" | tail -1 | cut -d: -f1)
[ -n "$tkhd_at" ] || { echo "RUN FAILED: movie-c has no track header to patch"; exit 1; }
printf '\000\003' | dd of="$movies/movie-c.mov" bs=1 seek=$((tkhd_at + 38)) conv=notrunc > /dev/null 2> "$build/dd.err" || {
    echo "RUN FAILED: the track header of movie-c could not be patched"; cat "$build/dd.err"; exit 1; }
patched=$(od -A n -t x1 -j $((tkhd_at + 38)) -N 2 "$movies/movie-c.mov" | tr -d ' ')
[ "$patched" = "0003" ] || { echo "RUN FAILED: movie-c's alternate group reads $patched, not 0003"; exit 1; }

# 2. the host table: the probe against Apple's own AVMovie
# shellcheck disable=SC2086
xcrun clang $flags "$here/probe.m" -o "$build/host" > "$build/host.log" 2>&1 || {
    echo "RUN FAILED: the host probe did not build"; head -8 "$build/host.log"; exit 1; }
timeout 120 "$build/host" "$movies" > "$build/host.table" 2> "$build/host.err" || {
    echo "RUN FAILED: the host probe stopped (exit $?)"; head -5 "$build/host.err"; tail -2 "$build/host.table"; exit 1; }

# 3. the port's AVMovie.m, from a scratch copy: the runtime names, the iOS-only property, and the planted mutant
port_src=$build/src/AVMovie.m
sed -e 's/objc_runtime_name("AVMovie")/objc_runtime_name("revenant_host_AVMovie")/' \
    -e 's/objc_runtime_name("AVMovieTrack")/objc_runtime_name("revenant_host_AVMovieTrack")/' \
    -e 's/return _revenantAsset.compatibleWithSavedPhotosAlbum;/return NO; \/\/ iOS-only on the macOS SDK; not asked by the probe/' \
    "$avf/AVMovie.m" > "$port_src"
for name in 'revenant_host_AVMovie"' 'revenant_host_AVMovieTrack"' 'return NO; //'; do
    [ "$(grep -c "$name" "$port_src")" -ge 1 ] || { echo "RUN FAILED: the scratch copy lost '$name', so this run proves nothing"; exit 1; }
done
if [ "$mutant" != 0 ]; then
    # tracksWithMediaType: answers no track for any type. The apply is checked by count: one target, gone afterwards.
    before='if ([track.mediaType isEqualToString:mediaType])'
    after='if (NO && [track.mediaType isEqualToString:mediaType])'
    [ "$(grep -cF "$before" "$port_src")" = 1 ] || { echo "RUN FAILED: the mutant target is not unique, so this run proves nothing"; exit 1; }
    sed -e 's/if (\[track\.mediaType isEqualToString:mediaType\])/if (NO \&\& [track.mediaType isEqualToString:mediaType])/' \
        "$port_src" > "$port_src.mutant" && mv "$port_src.mutant" "$port_src"
    [ "$(grep -cF "$before" "$port_src")" = 0 ] && [ "$(grep -cF "$after" "$port_src")" = 1 ] || {
        echo "RUN FAILED: the mutant did not take, so this run proves nothing"; exit 1; }
    echo "# the mutation applied: tracksWithMediaType: answers no track (one target, one replacement)"
fi
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -c "$port_src" -o "$build/AVMovie.o" > "$build/port-object.log" 2>&1 || {
    echo "RUN FAILED: the port's AVMovie.m did not compile"; head -8 "$build/port-object.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $flags -DREVENANT_PORT_BUILD=1 "$here/probe.m" "$build/AVMovie.o" -o "$build/port" > "$build/port.log" 2>&1 || {
    echo "RUN FAILED: the port probe did not link"; head -8 "$build/port.log"; exit 1; }
timeout 120 "$build/port" "$movies" > "$build/port.table" 2> "$build/port.err" || {
    echo "RUN FAILED: the port probe stopped (exit $?)"; head -5 "$build/port.err"; tail -2 "$build/port.table"; exit 1; }

# 4. neither table may be smaller than the claim
for side in host port; do
    want=$(sed -n 's/^rows: \([0-9][0-9]*\)$/\1/p' "$build/$side.table" | tail -1)
    have=$(grep -c ' = ' "$build/$side.table" || true)
    if [ -z "$want" ] || [ "$have" -ne "$want" ]; then
        echo "FAIL: the $side table holds $have rows but the probe reported ${want:-no count}; refusing to compare"
        exit 1
    fi
done
rows=$(grep -c ' = ' "$build/host.table")

# 5. the join: the held-out rows are counted, the rest must be equal
grep -v -e ' reason = ' -e '^data-b ' -e '^rows: ' "$build/host.table" > "$build/host.cmp"
grep -v -e ' reason = ' -e '^data-b ' -e '^rows: ' "$build/port.table" > "$build/port.cmp"
held=$(( $(grep -c ' reason = ' "$build/host.table") + $(grep -c '^data-b ' "$build/host.table") ))
compared=$(grep -c ' = ' "$build/host.cmp")
echo "host $rows rows, port $(grep -c ' = ' "$build/port.table") rows; compared $compared, held out $held (reason text and data-b)"
diff -u "$build/host.cmp" "$build/port.cmp" > "$build/diff.log" && differs=0 || differs=$(grep -c '^[-+][^-+]' "$build/diff.log" || true)

if [ "$mutant" != 0 ]; then
    if [ "$differs" = 0 ]; then
        echo "FAIL: the mutation left the tables equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed, on $differs changed line(s):"
    sed -n '1,16p' "$build/diff.log"
    exit 0
fi
if [ "$differs" != 0 ]; then
    echo "FAIL: the port's table differs from the host's on $differs line(s):"
    sed -n '1,60p' "$build/diff.log"
    exit 1
fi
echo "ok  every compared row: the port answers what the host answers"
exit 0
