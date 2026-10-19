#!/bin/sh
# What the release itself does with a source's handlers on an emulated iPhone3,1, on every release asked
# for, one scenario per process, through heavy.sh.
#
#   run.sh [release ...]        default 6.1.3; e.g. run.sh 6.1.3 7.1.2 8.4.1 9.3.6
#
# Two measured facts about iOS 6.1.3 started this, and they are what the table at the bottom is for:
#
#   1. libdispatch-228 already runs a source's cancellation and registration handler alone on a concurrent
#      target queue. The shims that used to stand beside those readings are withdrawn - they answered
#      alone=yes where the release already answers alone=yes, and the step where they take the handler off
#      the source ends the process on signal 5 here - so no shim of the cancellation or registration kind is
#      in the binary at all, and the nm gate below refuses a build that has one.
#   2. The same holds for a source's EVENT handler, with or without a barrier block and with or without
#      the barrier event handler's shim, which is on origin/main. That is what put the shim's premise in
#      doubt, and it is active below iOS 10, so 6.1.3 alone cannot decide it: one release is not the range.
#      This runs as many as it is given.
#
# `alone` is only a reading because of the ordinaryasync case: an ordinary block submitted to a concurrent
# target queue answers alone=no on every release measured, so a queue that answered alone=yes would be one
# running a single block at a time, and none of these does. ordinaryevent is the sharper control for the
# event handler: an ordinary block literal as the same source's event handler, which on a release whose
# libdispatch reads no block's flags is exactly what a caller there hands to the setter.
#
# Two things about the guest are measured, not assumed: `xmake emulate run` takes a bare path (a command
# with words after it comes back `fail(spawn error 2)`, and a bare path gives argc=1), so the scenario can
# only be named by forking; and a forked child's writes to this guest's standard output do not reach the
# runner's capture, so a child answers through a pipe and its parent reads it and prints it. fork itself
# works - the six guest checks at the top of the program's output - and run.sh fails if they do not.
#
# The binary is built for the release it runs on, one argument and not two: a reading is a reading of the
# libdispatch that produced it. LC_UUID, not a byte hash: strip rewrites the bytes before the signature and
# ldid -S changes those again, and neither touches LC_UUID. The image is found by that UUID and never by
# `ls -d <prefix>-* | head -1`: a project's configuration is part of its image's name, so each release
# brings a new image and the glob cannot tell them apart.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
# Four ".." up from this directory (tests/backports/device/srchandlers-probe) is the repository root: the
# directory is device's child, device is backports', backports is tests', tests is the root's.
root=${SRCH_ROOT:-$here/../../../..}
out="$here/run"
mkdir -p "$out"
cd "$here"
export SRCH_ROOT="$root"

device=${SRCH_DEVICE:-iPhone3,1}
[ $# -gt 0 ] && releases="$*" || releases=${SRCH_RELEASE:-6.1.3}
# -t is the wall-clock limit on a whole boot and -s how long the command run itself may take. 900 s is the
# default because a boot that shares a machine with other work does not always finish inside it: measured
# 2026-10-04 on 7.1.2 with the load at 9.9, the guest reached its service check-in with 195 services ready
# and then spent 85 guest s - 850 host s at this scale - waiting for installd to answer, and was reported
# boot-blocked(Setup, installd) at 902 host s. Nothing was wrong with that image; the limit was this
# script's. Both are raised here for a busy machine, and neither is a property of the measurement.
boot=${SRCH_BOOT_TIMEOUT:-900}
seconds=${SRCH_RUN_SECONDS:-300}
xmake=/opt/homebrew/bin/xmake
heavy=$HOME/Git/projects/ios/coordination/heavy.sh

uuid_of() {
  [ -f "$1" ] || { echo "(no file)"; return; }
  /usr/bin/otool -l "$1" 2>/dev/null | awk '/cmd +LC_UUID/ { seen = 1; next } seen && $1 == "uuid" { print $2; exit }'
}

program=sourcehandlers

for release in $releases; do
  export SRCH_RELEASE=$release
  echo "=== $device at $release"

  # Configure, build and install run directly and only the emulator run goes through heavy.sh, which puts
  # it in the bulk lane. heavy.sh breaks this project's `xmake f`: measured 2026-10-04 with the same lock in
  # place, the same command under heavy.sh fails its configure with every package reported as not found -
  # shade, swiftshader, emulator-guest, iphoneos-sdk, ld64, ldid, llvm, firmware-tools - and
  # `error: <no error object>`, while run directly it configures with rc=0.
  "$xmake" f -p iphoneos -a armv7 -y > "$out/configure-$release.log" 2>&1
  "$xmake" -y > "$out/build-$release.log" 2>&1
  "$xmake" emulate -d "$device" -r "$release" install > "$out/install-$release.log" 2>&1

  built="$here/build/iphoneos/armv7/release/$program"

  # Which image of this project holds this build. One is printed per release, so a wrong pick is visible
  # rather than silent.
  built_uuid=$(uuid_of "$built")
  installed=
  for candidate in "$HOME"/.charon/emulator/images.noindex/srchandlersprobe-*/"${device}"_*/rootfs/usr/libexec/$program; do
    [ -f "$candidate" ] || continue
    if [ "$(uuid_of "$candidate")" = "$built_uuid" ]; then
      installed=$candidate
      break
    fi
  done
  {
    printf 'built     %s\n' "$built"
    printf 'built     LC_UUID %s\n' "$built_uuid"
    printf 'installed %s\n' "${installed:-NOT FOUND}"
    printf 'every image of this project, and the LC_UUID of the program in each:\n'
    for candidate in "$HOME"/.charon/emulator/images.noindex/srchandlersprobe-*; do
      [ -d "$candidate" ] || continue
      printf '  %s  %s\n' "$(basename "$candidate")" \
        "$(uuid_of "$candidate/${device}_10B329/rootfs/usr/libexec/$program")"
    done
    if [ -n "$installed" ]; then
      printf 'the image holding this build was found by its LC_UUID, not by its name\n'
      printf 'HASHES MATCH\n'
    else
      printf 'no image holds a program with this build LC_UUID, so the run is NOT going ahead\n'
      printf 'HASHES MISMATCH\n'
    fi
  } > "$out/hash-$release.txt" 2>&1
  grep -q "HASHES MATCH" "$out/hash-$release.txt" || { cat "$out/hash-$release.txt"; exit 1; }
  cat "$out/hash-$release.txt"

  # What the binary must hold and must not hold, which is the point of this gate. It must NOT hold any of
  # the six shims whose premise the run refuted: a build that linked one again would answer the
  # cancellation and registration questions with the shim rather than with the release. It MUST hold the
  # two the event cases compare against - the barrier event handler's shim and the resume that writes the
  # activation record it asks, both on origin/main. And the plain dispatch names the binary claims must be
  # dispatch_block_create alone: a shim that claimed a plain name would answer these calls instead of
  # libdispatch's. Counts come from nm's third field, the symbol's own name, because
  # _charon_dispatch_source_create contains _dispatch_ and a substring count would read a shim as a claim on
  # the release's name.
  {
    printf 'every charon_dispatch_* this binary defines:\n'
    nm "$built" 2>/dev/null | awk '$2 == "t" || $2 == "T" { print $1, $2, $3 }' | grep -E ' _charon_dispatch_' | sort -k3 || true
    printf 'the release names this binary defines itself (dispatch_block_create is the one a shim claims):\n'
    nm "$built" 2>/dev/null | awk '$2 == "t" || $2 == "T" { print $1, $2, $3 }' | grep -E ' _dispatch_' | sort -k3 || true
  } > "$out/symbols-$release.txt" 2>&1
  present=$(awk '$3 ~ /^_charon_dispatch_(source_create|set_target_queue|source_set_cancel_handler|source_set_registration_handler|source_cancel)$/ { print $3 }' "$out/symbols-$release.txt" | tr '\n' ' ')
  wanted=$(awk '$3 ~ /^_charon_dispatch_(resume|source_set_event_handler)$/ { print $3 }' "$out/symbols-$release.txt" | sort | tr '\n' ' ')
  claimed=$(awk '$3 ~ /^_dispatch_/ { print $3 }' "$out/symbols-$release.txt" | tr '\n' ' ')
  cat "$out/symbols-$release.txt"
  printf 'the withdrawn shims in the binary: %s\n' "${present:-none}"
  printf 'the event handler shims in the binary: %s\n' "${wanted:-none}"
  printf 'the release names this binary claims: %s\n' "${claimed:-none}"
  if [ -n "$present" ]; then
    printf 'a withdrawn shim is linked in, so these readings would not be the release own, so NO run\n'
    printf 'SYMBOLS MISMATCH\n'
    exit 1
  fi
  if [ "$wanted" != "_charon_dispatch_resume _charon_dispatch_source_set_event_handler " ] && \
     [ "$wanted" != "_charon_dispatch_source_set_event_handler _charon_dispatch_resume " ]; then
    printf 'the event handler shims are not both linked, so the two columns would not be two columns, so NO run\n'
    printf 'SYMBOLS MISMATCH\n'
    exit 1
  fi
  if [ "$claimed" != "_dispatch_block_create " ] && [ "$claimed" != "_dispatch_block_create" ]; then
    printf 'the binary claims a plain dispatch name other than dispatch_block_create, so NO run\n'
    printf 'SYMBOLS MISMATCH\n'
    exit 1
  fi
  printf 'no withdrawn shim is linked, both event handler shims are, and the only release name this binary claims is dispatch_block_create\n'
  printf 'SYMBOLS MATCH\n'

  # The raw log keeps its colour codes for reading by eye; the plain one is what the gate compares against,
  # because a row it cannot match is a check that fails for the wrong reason.
  "$heavy" "$xmake" emulate -d "$device" -r "$release" -t "$boot" -s "$seconds" run \
      "/usr/libexec/$program" > "$out/run-$release.raw" 2>&1 || true
  "$xmake" emulate log > "$out/guest-$release.log" 2>&1 || true
  sed 's/\x1b\[[0-9;]*m//g' "$out/run-$release.raw" > "$out/run-$release.log"
  sed 's/\x1b\[[0-9;]*m//g' "$out/run-$release.log"
done

# The measured table, as a gate, one row per release/case/width/column, read field by field in the order
# the program prints them. A row that stops answering, or answers differently, fails by name; a row for a
# release that was not run is not compared, so the table can hold a release whose rows are still to be
# measured - which is the honest state of a measurement not yet taken.
#
# The 6.1.3 rows are what the run recorded on 2026-10-04 and are the reason the shims were withdrawn.
# The twelve 6.1.3 event rows are all the same line, and that is its own finding: on that release a
# source's event handler does not run while another block is holding a CONCURRENT target queue - not with a
# barrier block made by dispatch_block_create, not with a plain block literal, not with the shim and not
# with the release's own call.
cat > "$out/wanted.tsv" <<'TABLE'
6.1.3	cancel	concurrent	system	held=yes ran=yes alone=yes second=no returned=yes order=-
6.1.3	cancel	serial	system	held=yes ran=yes alone=yes second=no returned=yes order=-
6.1.3	registration	concurrent	system	held=yes ran=yes alone=yes second=no returned=yes order=-
6.1.3	registration	serial	system	held=yes ran=yes alone=yes second=no returned=yes order=-
6.1.3	neverresumed	concurrent	system	held=yes ran=no alone=n/a second=n/a returned=yes order=-
6.1.3	neverresumed	serial	system	held=yes ran=no alone=n/a second=n/a returned=yes order=-
6.1.3	retargetbefore	concurrent	system	held=yes ran=yes alone=yes second=yes returned=yes order=-
6.1.3	retargetbefore	serial	system	held=yes ran=yes alone=yes second=yes returned=yes order=-
6.1.3	retargetafter	concurrent	system	held=yes ran=yes alone=yes second=yes returned=yes order=-
6.1.3	retargetafter	serial	system	held=yes ran=yes alone=yes second=yes returned=yes order=-
6.1.3	onqueue	concurrent	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	onqueue	serial	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	resumecancel	concurrent	system	held=n/a ran=yes alone=yes second=no returned=no order=RC
6.1.3	resumecancel	serial	system	held=n/a ran=yes alone=yes second=no returned=no order=RC
6.1.3	ordinaryasync	concurrent	system	held=yes ran=yes alone=no second=n/a returned=yes order=-
6.1.3	ordinaryasync	serial	system	held=yes ran=yes alone=yes second=n/a returned=yes order=-
6.1.3	event	concurrent	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	event	concurrent	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	event	serial	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	event	serial	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	eventafresume	concurrent	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	eventafresume	concurrent	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	eventafresume	serial	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	eventafresume	serial	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	ordinaryevent	concurrent	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	ordinaryevent	concurrent	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	ordinaryevent	serial	system	held=n/a ran=yes alone=yes second=no returned=yes order=-
6.1.3	ordinaryevent	serial	shim	held=n/a ran=yes alone=yes second=no returned=yes order=-
TABLE

# A child that ended on a signal has no row, and a row that is missing must fail: with the withdrawn shims
# linked that is exactly how a run reported sixteen clean ends and no answers at all.
# OUT is passed with awk's own -v and not as OUT="$out" before the program: that sets an ENVIRONMENT
# variable, which awk only sees through ENVIRON["OUT"], so the bare name OUT below would be an
# uninitialized awk variable and every lookup would read /run-<release>.log. It was exactly that, and the
# gate refused all twenty-eight rows for it.
awk -v wanted="$out/wanted.tsv" -v releases="$releases" -v OUT="$out" '
# The handle is closed on every call, including the one that finds nothing. awk keeps the position of a
# file between getline calls, so an unclosed handle would make each row start where the previous one
# stopped, and the comparison would then only work while the table happened to be in the same order as
# the log - which is a property of a run, not of the check.
function answer(which, width, api, logpath,   line) {
    while ((getline line < logpath) > 0) {
        if (index(line, which " " width " " api ": ") == 1) {
            close(logpath)
            return line
        }
    }
    close(logpath)
    return ""
}
function field(line, key,   rest) {
    rest = line
    while (match(rest, key "=")) {
        rest = substr(rest, RSTART + length(key) + 1)
        if (match(rest, /^[^ ]+/))
            return substr(rest, RSTART, RLENGTH)
    }
    return "?"
}
BEGIN {
    fails = 0
    n = split(releases, asked, " ")
    for (r = 1; r <= n; r++) {
        release = asked[r]
        logpath = OUT "/" "run-" release ".log"
        died = 0
        guestFailed = 0
        while ((getline line < logpath) > 0) {
            if (index(line, "CHILD ENDED") > 0) died++
            if (line ~ /^guest .*: (ENDED|FORK FAILED)/) guestFailed++
        }
        close(logpath)
        # Only the rows of a release that was run are compared, and a release that was run must have had
        # at least one: a release whose rows are not in the table yet compares nothing, has no scenario
        # that ended without answering because none ran, and would report success. That is not a check
        # that can fail, and it reported ok for 7.1.2 whose guest never reached the runner at all.
        compared = 0
        while ((getline row < wanted) > 0) {
            split(row, parts, "\t")
            if (parts[1] != release) continue
            which = parts[2]; width = parts[3]; api = parts[4]; expect = parts[5]
            compared++
            got = answer(which, width, api, logpath)
            sub(/^[^:]*: /, "", got)
            if (got == "") {
                printf "FAIL  %s: the %s case on a %s target queue, %s column, did not answer at all\n", release, which, width, api
                fails++
            } else if (got != expect) {
                printf "FAIL  %s: the %s column answers \"%s\" for the %s case on a %s target queue, where this measurement recorded \"%s\"\n", release, api, got, which, width, expect
                fails++
            }
        }
        if (compared == 0) {
            printf "FAIL  %s: no row of the table is for this release, so nothing was compared and this run says nothing about it\n", release
            fails++
        }
        if (died != 0) {
            printf "FAIL  %s: %s scenario(s) ended without answering, so the table above cannot be complete\n", release, died
            fails++
        }
        if (guestFailed != 0) {
            printf "FAIL  %s: %s of the guest capability checks did not pass, so fork is not sound here\n", release, guestFailed
            fails++
        }
        # A "?" here is a reading that is not there, and it is printed as one so the table cannot be read
        # as if the release had answered; the FAIL line above is what says so in words.
        printf "%-7s  event=%s  cancel=%s  registration=%s  ordinaryevent=%s  ordinaryasync=%s\n", release,
               field(answer("event", "concurrent", "system", logpath), "alone"),
               field(answer("cancel", "concurrent", "system", logpath), "alone"),
               field(answer("registration", "concurrent", "system", logpath), "alone"),
               field(answer("ordinaryevent", "concurrent", "system", logpath), "alone"),
               field(answer("ordinaryasync", "concurrent", "system", logpath), "alone")
    }
    close(wanted)
    if (fails == 0)
        printf "ok    every release run answered, every row of it holds, and the ordinary-block controls are in the table above them\n"
    else
        printf "%d checks failed\n", fails
    exit(fails == 0 ? 0 : 1)
}
'
