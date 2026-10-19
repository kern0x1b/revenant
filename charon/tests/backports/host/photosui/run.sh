#!/bin/sh
# run.sh - the port's PhotosUI against the host's own, one answer per line, in two binaries and one
# comparison.
#
#   sh tests/backports/host/photosui/run.sh              # both sides, compared
#   sh tests/backports/host/photosui/run.sh --mutated    # one answer changed on purpose: it must fail
#   sh tests/backports/host/photosui/run.sh --recorded   # and both sides must still answer what answers/ holds
#
# What each side is:
#
#   the host   cases.m compiled against the SDK's own <PhotosUI/PhotosUI.h> and linked against the
#              host's PhotosUI framework. This is the oracle: Apple's own implementation of the
#              eleven filters, the two properties and the two methods this queue names.
#   the port   the same cases.m compiled against the transcribed header beside it, linked with the
#              port's own objects - PHPickerFilter14.m, PHPickerFilter15.m, PHPickerFilter16.m,
#              PHPickerConfiguration14.m, PHPickerConfiguration15.m and PHPickerViewController16.m -
#              built from packages/a/apple-backports/Photos with no change to any of them, and
#              without the host's PhotosUI framework in the link at all. With them the class of
#              PHPickerViewControllerStub.m, because the 14.0 object that defines
#              PHPickerViewController is UIKit's and this harness has no UIKit; the category of iOS
#              16 needs a class to attach to, and no answer the stub gives is compared.
#
# Two binaries and not one, on purpose: the port's PHPickerFilter, PHPickerConfiguration and
# PHPickerViewController have the same names as the host's, so one binary holding both would install
# the port's categories over the host's classes and the host's answers would be the port's. That is
# the defect the review of the ImageIO pixel differential found, where the port probe was the host.
#
# The comparison is over the whole set of lines: a line on one side and not the other is a
# difference, not a pass. Four questions are outside what the host's own implementation answers, and
# they are listed with their reasons in stated-differences.tsv; a listed difference that stops
# differing fails the run, because a statement about a measurement that has moved is stale.
# --mutated rewrites one answer in the port's own output before the comparison, which is what proves
# the comparison can fail: one that never differs reads as a pass and guards nothing.
#
# answers/ holds what both sides answered on the day the series was written, byte for byte, and
# --recorded holds this run to it. A committed file that says "34 the same, and 4 the host does not
# answer" is a claim about a run, and a claim about a run needs the run beside it: these two files are
# it, and this mode is what stops them going stale in the tree. Neither file is read by the
# comparison above - the two answers are always compared with each other, never with a recording.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
port=${PORT:-$here/../../../../packages/a/apple-backports/Photos}
build=${PHOTOSUI_BUILD:-$here/../../../../.agent-work/build/photosui-host}
rm -rf "$build"
mkdir -p "$build"

objects=""
for source in PHPickerFilter14 PHPickerFilter15 PHPickerFilter16 PHPickerConfiguration14 PHPickerConfiguration15 PHPickerViewController16; do
    xcrun clang -fobjc-arc -w -I"$here" -I"$port" -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -w -I"$here" -c "$here/PHPickerViewControllerStub.m" -o "$build/stub.o"
objects="$objects $build/stub.o"

# The port's side. -I"$here" is ahead of the SDK's framework path, so <PhotosUI/PhotosUI.h> is the
# transcription beside this script and the real PhotosUI.framework is never linked in.
xcrun clang -fobjc-arc -w -I"$here" "$here/cases.m" $objects -framework Foundation -o "$build/port"
# The host's side: the SDK's own header, the host's own framework, and no -I"$here".
xcrun clang -fobjc-arc -w -Wno-unguarded-availability -Wno-unguarded-availability-new \
    -DCHARON_HOST_REFERENCE "$here/cases.m" -framework Foundation -framework PhotosUI -o "$build/host"

"$build/host" > "$build/host.answers"
"$build/port" > "$build/port.answers"
# The mutation is applied to a copy and never to the run's own answer file. An earlier version wrote
# the mutated answers back over $build/port.answers, and the file the next reader copied into
# answers/ was the falsified one: --recorded caught it on its first run, which is the only reason
# this is worth saying. What a run answered is what the run leaves behind, changed or not.
if [ "${1:-}" = "--mutated" ]; then
    # The port's own answer for one filter, changed on purpose. A comparison that cannot fail is not
    # a comparison, and this is what shows that this one can.
    awk 'BEGIN { FS = "\t"; OFS = "\t" } $1 == "filter.panoramas" { $2 = "NSObject" } { print }' \
        "$build/port.answers" > "$build/port.mutated"
    echo "mutated: filter.panoramas now answers NSObject on the port's side, in $build/port.mutated"
fi

port_answers="$build/port.answers"
if [ "${1:-}" = "--mutated" ]; then
    port_answers="$build/port.mutated"
fi

result=0
xmake l "$here/compare.lua" "$build/host.answers" "$port_answers" "$here/stated-differences.tsv" || result=1
if [ "${1:-}" = "--recorded" ]; then
    for side in host port; do
        if diff -u "$here/answers/$side.answers" "$build/$side.answers" > "$build/$side.recorded.diff"; then
            echo "ok    answers/$side.answers is what this run answered, $(wc -l < "$build/$side.answers" | tr -d ' ') lines"
        else
            echo "not ok: this run's $side answers are not what answers/$side.answers holds"
            cat "$build/$side.recorded.diff"
            result=1
        fi
    done
fi
if [ "${1:-}" = "--mutated" ] && [ "$result" = 0 ]; then
    echo "not ok: --mutated changed an answer and the comparison still passed"
    exit 1
fi
echo "answers: $build/host.answers and $build/port.answers"
exit "$result"
