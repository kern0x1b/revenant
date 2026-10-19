#!/bin/sh
# measure.sh: what the HOST's own CoreImage answers for every case in cases.m, written to host-answers.tsv.
#
# WHY A TABLE AND NOT A LIVE DIFFERENTIAL: the five classes of this family have the SAME NAMES on the host and
# in the port, and on macOS every process that uses Foundation has CoreImage loaded - measured 2026-10-03 with
# DYLD_PRINT_LIBRARIES on a program that links Foundation alone, which pulls CoreImage in through
# DataDetection and AppleNeuralEngine. A port build in such a process is a duplicate class, and the runtime's
# answer to a duplicate is whichever class registered first: a first attempt at this harness had both builds
# printing the same answers because only ONE of them was running the code under test, which the binding
# record in cases.m caught (dladdr on a method IMP said "port" only after the host framework was taken out of
# the link). So the host is measured into a file and the port is compared with the file, and this script is
# what keeps the file honest: run.sh runs it on every run and fails if a fresh measurement differs.
#
# THE HOST DOES NOT SURVIVE EVERY GROUP, and the file says so. The QR, Aztec, PDF417 and Data Matrix boundary
# groups each end in a trap (exit 133) and the host's own CIPDF417CodeDescriptor dies in its own dealloc, so
# for those groups the file holds the records that were printed before the death and the exit status that
# came with them. run.sh compares what the host reached and reports how much of the group it could not.
set -eu
set +m  # the host dies on purpose in most groups; its signal is an answer here, not job control noise
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
build=${BUILD:-$root/.agent-work/runs/cibarcode}
mkdir -p "$build"

CASE_GROUPS="sweep-qr sweep-aztec sweep-pdf417 sweep-matrix qr aztec pdf417-rows pdf417-columns matrix payload payload-no-pdf417 copy copy-no-pdf417"

if ! xcrun clang -w -DCHARON_HOST -fobjc-arc "$here/cases.m" -framework Foundation -framework CoreImage \
    -o "$build/host" 2>"$build/host.log"; then
  echo "BUILD  host"
  head -5 "$build/host.log" | sed 's/^/    /'
  exit 1
fi

out=$here/host-answers.tsv
: > "$build/fresh.tsv"
for g in $CASE_GROUPS; do
  # one line per record, prefixed with the group so a group's records are found again, then the group's exit
  # status as its own line: a group's death is part of what the host does and is compared as such
  "$build/host" "$g" 2>/dev/null | sed "s/^/$g\t/" >> "$build/fresh.tsv" || true
  if "$build/host" "$g" >/dev/null 2>&1; then status=0; else status=$?; fi
  printf '%s\t#exit\t%d\n' "$g" "$status" >> "$build/fresh.tsv"
done

if [ -f "$out" ]; then
  if diff -u "$out" "$build/fresh.tsv" > "$build/measure-diff.txt"; then
    echo "  MEASURED: the host still answers every case in host-answers.tsv, unchanged"
    exit 0
  fi
  echo "FAIL  the host's answers moved from host-answers.tsv:"
  head -20 "$build/measure-diff.txt" | sed 's/^/    /'
  echo "  the new answers are in $build/fresh.tsv; read them, and if they are right, replace host-answers.tsv"
  exit 1
fi
cp "$build/fresh.tsv" "$out"
echo "  MEASURED: the host's answers written to host-answers.tsv ($(grep -c . "$out") lines)"