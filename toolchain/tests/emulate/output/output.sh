#!/bin/bash
set -eu
cd "$(dirname "$0")"
. ../../backports/common/runs.sh "$PWD"
device=${1:-iPhone2,1}
release=${2:-6.1.3}
out=${OUT_DIR:-$(runs_folder emulate-output)}
known=revenant-emulate-output
mkdir -p "$out"

verdict() { xmake l "$PWD/verdict.lua" "$@"; }
runner() {
  if text=$(verdict "$1" runner 2>/dev/null); then echo "$text"; else echo unknown; fi
}
verdicts() {
  find "$HOME/.revenant/emulator/images.noindex" -path "*/${device}_*/run/verdict.json" -newer "$marker" 2>/dev/null | sort
}
named() { verdict "$1" "$2"; }

xmake f -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
xmake emulate install -d "$device" -r "$release" > "$out/install.log" 2>&1

status=0
mode_failed=0
report_mode() {
  if [ "$mode_failed" = 0 ]; then
    echo "$mode: every check of this mode passed, so this mode exits 0"
  else
    echo "$mode: a check of this mode failed, so this mode exits 1" >&2
    status=1
  fi
}
for mode in end hang; do
  log=$out/$mode.log
  marker=$out/.marked
  mode_failed=0
  : > "$marker"
  ran=0
  if [ "$mode" = hang ]; then
    xmake emulate -d "$device" -r "$release" -s 6 -t 900 \
        run /usr/libexec/emulateoutput --hang > "$log" 2>&1 || ran=$?
  else
    xmake emulate -d "$device" -r "$release" -s 60 -t 900 \
        run /usr/libexec/emulateoutput > "$log" 2>&1 || ran=$?
  fi
  echo "$mode: the run itself exited $ran"
  verdicts > "$out/.verdicts"
  count=$(grep -c . "$out/.verdicts" || true)
  if [ "$count" -eq 0 ]; then
    echo "$mode: no run's verdict was written after this run; the log is $log" >&2
    mode_failed=1
    report_mode
    continue
  fi
  if [ "$count" -gt 1 ]; then
    echo "$mode: $count runs wrote a verdict after this run began, so which is this one is not known:" >&2
    sed 's/^/  /' "$out/.verdicts" >&2
    mode_failed=1
    mode_failed=1
    mode_failed=1
    continue
  fi
  v=$(cat "$out/.verdicts")
  which_runner=$(runner "$v")
  echo "$mode: the runner was $which_runner ($v)"
  stdout=$(named "$v" stdout)
  stderr=$(named "$v" stderr)
  if [ -n "$stderr" ] && grep -q "$known: stderr line 1 reached the host" "$stderr"; then
    echo "$mode: the control, unbuffered stderr, is in the file the verdict names"
    control=yes
  else
    echo "$mode: the control stderr is NOT there (${stderr:-no path}); the file was not captured at all" >&2
    control=no
    mode_failed=1
    mode_failed=1
  fi
  if [ -n "$stdout" ] && grep -q "$known: stdout line 1 reached the host" "$stdout"; then
    echo "$mode: the program's buffered stdout reached the file"
    first=yes
  else
    echo "$mode: the program's buffered stdout did NOT reach the file (${stdout:-no path})" >&2
    first=no
    mode_failed=1
  fi
  if [ "$mode" = hang ] && [ -n "$stdout" ] && grep -q "$known: stdout line 2 reached the host" "$stdout"; then
    second=yes
  else
    second=no
  fi
  xmake emulate -d "$device" -r "$release" log "$known" > "$out/$mode-filtered.log" 2>&1 || true
  if grep -q "$known: stdout line 1 reached the host" "$out/$mode-filtered.log"; then
    echo "$mode: the line comes back through xmake emulate log"
    logged=yes
  else
    echo "$mode: the line does NOT come back through xmake emulate log" >&2
    logged=no
    mode_failed=1
  fi
  if [ "$mode" = hang ]; then
    case $which_runner in
      tree)
        if [ "$control" = yes ] && [ "$first" = yes ] && [ "$second" = yes ] && [ "$logged" = yes ]; then
          echo "hang: with the tree's runner, nothing a program wrote and never flushed was lost"
        else
          echo "hang: THE TREE'S RUNNER LOST IT: control=$control first=$first second=$second logged=$logged" >&2
          mode_failed=1
          mode_failed=1
        fi
        ;;
      *)
        if [ "$first" = no ] || [ "$second" = no ]; then
          echo "hang: UNMEASURED - the installed runner buffers, so the line a program never flushed is"
          echo "      gone, which is the behaviour the unbuffered spawn fixes. Rerun with the addon"
          echo "      rebuilt from this tree; this run is not a pass of it."
        else
          echo "hang: the line survived under a runner that has no unbuffered spawn, so the verdict's" >&2
          echo "      runner key says installed but the behaviour says otherwise; not counting it." >&2
          mode_failed=1
          mode_failed=1
        fi
        ;;
    esac
  fi
  report_mode
done
exit $status
