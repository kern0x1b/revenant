#!/bin/sh
# run-app.sh - the Bonjour printer picker (UIPrinterPickerController from libUIKitBackports) as an installed application on
# the emulated iPhone 4S at 6.1.3 (app/main.m). The application runs a bare browse as a control, presents the picker over
# its key window, and reads the completion. On this guest the browse fails ("did not search", -72004) for the bare browser
# and the picker alike, so the picker dismisses with userDidSelect NO before any list appears: the emulator shows the
# presentation and that dismissal, not an empty list and not a Cancel.
#
# Usage: sh tests/backports/emulate/uikitprinter/run-app.sh [--minimum 6.1.3]
# Run it through the heavy lane: $HOME/Git/projects/ios/coordination/heavy.sh sh ... (the emulator is the bulk lane).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
minimum=6.1.3
while [ $# -gt 0 ]; do
    case "$1" in
        --minimum) minimum=$2; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done
stamp=$(date +%Y%m%d-%H%M%S)
# A run folder of this checkout, never the system temp directory; the project is built apart from the port's tree.
out=${UIKITPRINTER_APP_BUILD:-$root/.agent-work/runs/uikitprinter-app/$minimum-$stamp}
mkdir -p "$out"
cp "$here/app/xmake.lua" "$here/app/control" "$here/app/Info.plist" "$out/"
cd "$out"
CHARUIKITPRINTER_ROOT=$root CHARUIKITPRINTER_MINIMUM=$minimum xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the application did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
CHARUIKITPRINTER_ROOT=$root CHARUIKITPRINTER_MINIMUM=$minimum xmake emulate -d iPhone4,1 -r "$minimum" install >"$out/install.log" 2>&1 || {
    echo "the application did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
# The application ends by itself when the picker completes (or at its 60-second deadline); nothing is tapped. The guest's
# browse fails at once, so the picker dismisses before any tap could reach it.
set +e
CHARUIKITPRINTER_ROOT=$root CHARUIKITPRINTER_MINIMUM=$minimum xmake emulate -d iPhone4,1 -r "$minimum" -s 120 launch local.charon.backports.uikitprinterapp until-exit >"$out/launch.log" 2>&1
launch_status=$?
xmake emulate -d iPhone4,1 -r "$minimum" log >"$out/emulate.log" 2>&1
set -e
cat "$out/launch.log"
echo "run folder: $out (launch status $launch_status)"
# The application's own output is the verdict, read from this run's launch log alone.
fail=0
need() {
    grep -qF "$1" "$out/launch.log" || { echo "MISSING in this run's output: $1" >&2; fail=1; }
}
forbid() {
    grep -qF "$1" "$out/launch.log" && { echo "UNEXPECTED in this run's output: $1" >&2; fail=1; }
    return 0
}
# The control: a bare browse on this guest also reports "did not search", so the picker's failure is the guest's.
need "bare browse: did not search"
need "present: YES"
need "delegate: did dismiss"
need "completion 1: userDidSelect NO, error Error Domain=NSNetServicesErrorDomain Code=-72004"
need "finished: 1 completion(s)"
forbid "deadline:"
[ "$fail" -eq 0 ] || { echo "the picker did not behave as the run expects; see $out/launch.log" >&2; exit 1; }
echo "uikitprinter-app $minimum: presented, dismissed with userDidSelect NO on the guest's browse failure (bare browse fails too)"
