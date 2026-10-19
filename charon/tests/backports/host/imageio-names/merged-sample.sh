#!/bin/sh
# The 40 already-implemented ImageIO constants, sampled with seed 20260929, read through the SAME reader
# and compared with the port's own values. This was first run by hand as a throwaway script, which is not
# evidence anyone can repeat; it is here instead, with the 40 names listed in sample40.txt beside it, so
# the claim "the merged rows are right" is a check and not a claim.
#
# It is a control on the port, not on this slice: it asks whether a rule the port might have been built on
# - "the value is the symbol's name" - holds for rows that were merged before the harness existed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
build=${BUILD:-$root/.agent-work/runs/imageio-names}
mkdir -p "$build"
[ -x "$build/probe" ] || xcrun clang -w "$here/probe.c" -framework CoreFoundation -framework ImageIO -o "$build/probe"

rm -rf "$build/merged-obj"; mkdir -p "$build/merged-obj"
for f in "$port"/ImageIONames*.m; do
  xcrun clang -w -I"$root/packages/a/apple-backports" -c "$f" -o "$build/merged-obj/$(basename "$f" .m).o" 2>>"$build/merged.log" || {
    echo "BUILD  $f"; head -3 "$build/merged.log" | sed 's/^/    /'; exit 1; }
done
all=$(ls "$build/merged-obj"/*.o)
xcrun clang -w "$here/portread.c" $all -framework CoreFoundation -o "$build/merged-pr" 2>"$build/merged-pr.log" || {
  echo "BUILD  merged reader did not link"; head -3 "$build/merged-pr.log" | sed 's/^/    /'; exit 1; }

examined=0; match=0; bad=0
: > "$build/merged-bad.txt"
# the || guard matters: a names file with no trailing newline loses its LAST name to read, and a
# sample that quietly examined 39 of 40 would still have reported a clean result.
while read -r name <&3 || [ -n "$name" ]; do
  examined=$((examined+1))
  h=$("$build/probe" "$name" 2>/dev/null | sed -n 's/^  VALUE //p')
  p=$("$build/merged-pr" "$name" 2>/dev/null | sed -n 's/^  VALUE //p')
  if [ -z "$p" ] || [ -z "$h" ]; then echo "$name (unread)" >> "$build/merged-bad.txt"; bad=$((bad+1)); continue; fi
  if [ "$p" = "$h" ]; then match=$((match+1)); else echo "$name port=$p host=$h" >> "$build/merged-bad.txt"; bad=$((bad+1)); fi
done 3< "$here/sample40.txt"
echo "  MERGED SAMPLE (seed 20260929): $examined names examined, $match match, $bad differ"
[ "$examined" -eq 40 ] || { echo "FAIL  the sample examined $examined names, not 40"; exit 1; }
if [ "$bad" -ne 0 ]; then echo "  the merged rows that DISAGREE with the host:"; sed 's/^/    /' "$build/merged-bad.txt"; exit 1; fi
exit 0
