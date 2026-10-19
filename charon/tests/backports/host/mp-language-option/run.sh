#!/bin/sh
# run.sh - what Apple's own MediaPlayer answers for MPNowPlayingInfoLanguageOption's two "automatic"
# accessors, measured on this machine. It needs no arguments and reads nothing outside this directory.
#
#     sh run.sh
#
# The binary is removed BEFORE the compile, so a compile that fails cannot leave the last run's numbers
# on screen to be read as this one's - which is how two earlier runs of the other probe in this tree
# reported values its source had never produced. The probe's own two controls are checked here rather
# than trusted: without them a framework that had dropped the type, or that did not declare the
# initialiser at all, would print a table of NOs that reads like a measurement.
#
# This is a READ of Apple's behaviour, not a check of the port: the port's own check is
# tests/backports/host/mediaplayeritem/languageoption90.m, which compiles the port's source against the
# stand-in header so that what is measured is the port and not this Mac's MediaPlayer.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${MP_LANGUAGE_OPTION_BUILD:-$(runs_folder mp-language-option-$$)}
mkdir -p "$build"
out=$build/probe.bin
text=$build/probe.txt

rm -f "$out" "$text"
if ! xcrun clang -fobjc-arc -w -framework Foundation -framework MediaPlayer -o "$out" "$here/probe.m" \
      2> "$build/build.log"; then
    echo "BUILD  probe.m did not compile:"
    grep "error:" "$build/build.log" | head -5 | sed 's/^/    /'
    exit 1
fi
[ -x "$out" ] || { echo "BUILD  probe.m produced no binary"; exit 1; }

status=0
"$out" > "$text" 2>&1 || status=$?
sed 's/^/  /' "$text"
[ "$status" -eq 0 ] || { echo "PROBE  exited $status, which is a control failing, not a result"; exit 1; }

grep -q 'CONTROL.*declares the five-argument initialiser' "$text" ||
    { echo "PROBE  the initialiser control is missing, so nothing below was measured"; exit 1; }
grep -q 'CONTROL.*both types round-trip' "$text" ||
    { echo "PROBE  the type round-trip control is missing, so a NO below could be a dropped argument"; exit 1; }
grep -q '== SUMMARY.*options built=' "$text" ||
    { echo "PROBE  no summary line, so the run did not finish"; exit 1; }

rm -rf "$build"
echo "mp-language-option: Apple's own answers measured, both controls answered"
