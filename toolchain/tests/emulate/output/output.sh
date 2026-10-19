#!/bin/bash
# output.sh [DEVICE] [RELEASE]: a run's program output, measured, on a real guest. Two runs, and the
# second is the one that matters:
#
#   end   a program that returns. Its stdio is flushed by the exit, so this passes with any runner; it
#         says the file was captured and that xmake emulate log brings the line back.
#   hang  a program the deadline kills, which never flushes. A program's stdio is block buffered once it
#         is a file, so the lines it wrote are still in the buffer when SIGKILL arrives and the only thing
#         that can have put them in the file is the runner spawning it unbuffered - NSUnbufferedIO=YES,
#         which this series' revenant-runner sets and the installed addon does not. The runner the run used
#         is read out of the run's own verdict, and the three hang checks stand or fall together on it:
#         with the tree's runner all three must hold, with the installed one the miss is expected and is
#         reported as unmeasured rather than as a pass.
#
# stderr is the control: it is unbuffered by default, so its line lands with either runner and its
# presence says the file was captured at all. The stdout lines are the claim.
#
# The run's files are found through *this* run's verdict, not through the newest one on the machine: a
# marker is written just before the run and the verdict is the one newer than it, and more than one
# newer than it is an ambiguity this script refuses rather than picking. The verdict carries the absolute
# paths of what the program wrote, and the installed addon writes it, so the check does not depend on
# which addon is in use.
set -eu
cd "$(dirname "$0")"
device=${1:-iPhone2,1}
release=${2:-6.1.3}
out=${OUT_DIR:-.agent-work/output}
known=revenant-emulate-output
mkdir -p "$out"

# This run's verdict: the one written after the marker. The key that says which runner wrote it is the
# host's own result's top-level `output`, which emulator.verdict() copies out of the runner's verdict
# (`test.output`) and run_task then writes over the file - the runner's `test` object is not in the file
# that is on disk, so reading it there finds nothing and excuses every miss.
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

# The run's own exit is the emulator's, not this script's: a hang run ends in a timeout by design, so
# folding its status into the exit made a run whose checks all passed exit 255. It is reported, and the
# checks alone decide the exit. Each mode ends by its own checks and says so.
status=0
mode_failed=0
report_mode() {  # one place says what a mode decided, and it decides the script's exit
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
    # One expectation, taken from the run's own verdict, and all three hang checks behind it. The tree's
    # runner spawns the program unbuffered, so a program that never flushed must still be whole in the
    # file; the installed runner has no `output` field and buffers, so there the three are expected to
    # miss, and a miss there says the run is unmeasured rather than that the port passed.
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
