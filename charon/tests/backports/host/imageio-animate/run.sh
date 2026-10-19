#!/bin/sh
# run.sh: the PORT's CGAnimateImageAtURLWithBlock and CGAnimateImageDataWithBlock against the HOST's own
# ImageIO, case by case, with mutations planted to show the comparison can go red.
#
# WHY TWO BINARIES AND NOT ONE: a function has one name in both libraries, so linking the port's object and
# the host's ImageIO into one program cannot happen. Each build answers the same cases over the same fixture
# files - write-gifs.m writes them once, before both builds, so the input is one input - and this script
# compares the two outputs line by line.
#
# THE ANIMATION IS ASYNCHRONOUS, which the comparison has to respect: the host answers the call before the
# first frame is drawn (measured, and cases.m records it), so each build prints the calls that arrived while
# a run loop was given room to run them. A call that has not come is printed as a line anyway, as "-", so the
# two builds always print the same number of records and a call only one of them made is a value in a line
# both printed.
#
# A difference is only allowed where known-differences.txt declares it, with the case name spelled exactly.
# An undeclared difference fails; a declared difference that stops differing fails too, because then the
# declaration is stale.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
build=${BUILD:-$root/.agent-work/runs/imageio-animate}
mkdir -p "$build"

# THE OBJECT LIST IS A FILE, so a band extends this harness instead of forking it, and an object on disk the
# list does not name is an object nothing would check. The check for that is asserted below.
objects=$here/objects.txt
[ -f "$objects" ] || { echo "FAIL  no objects.txt beside run.sh"; exit 1; }
files=""
while read -r f <&3 || [ -n "$f" ]; do
  case "$f" in \#*|"") continue ;; esac
  [ -f "$port/$f" ] || { echo "FAIL  objects.txt names $f and there is no $port/$f"; exit 1; }
  files="$files $port/$f"
done 3< "$objects"
files=${files# }
[ -n "$files" ] || { echo "FAIL  objects.txt names no object"; exit 1; }
ls "$port"/ImageIOAnimation*.m | xargs -n1 basename | sort > "$build/ondisk.txt"
grep -v '^#' "$objects" | grep -v '^[[:space:]]*$' | sort > "$build/listed.txt"
miss=$(comm -23 "$build/ondisk.txt" "$build/listed.txt")
[ -z "$miss" ] || { echo "FAIL  an animation object is on disk and NOT in objects.txt:"; echo "$miss" | sed 's/^/    /'; exit 1; }
echo "  COVERAGE: an animation object on disk and not in objects.txt is detected, and is named"

# THE FIXTURES, written once by the host's own writer and read by both builds.
xcrun clang -w -fobjc-arc "$here/write-gifs.m" \
  -framework Foundation -framework ImageIO -framework CoreGraphics -framework CoreServices -o "$build/write-gifs" \
  2>"$build/write-gifs.log" || { echo "BUILD  write-gifs"; head -3 "$build/write-gifs.log" | sed 's/^/    /'; exit 1; }
"$build/write-gifs" "$build" > "$build/fixtures.txt" 2>&1 || { echo "FIXTURES"; cat "$build/fixtures.txt" | sed 's/^/    /'; exit 1; }
grep -q '^read back delay 0 = 0.1' "$build/fixtures.txt" || { echo "FAIL  the three-frame fixture does not carry the delays the cases compare"; cat "$build/fixtures.txt" | sed 's/^/    /'; exit 1; }
echo "  FIXTURES: three.gif carries per-frame delays 0.1, 0.3 and 0.5, written once for both builds"

# THE PORT BUILD: its own object plus the option names it reads, which this band does not export below 13.4.
# A definition in an object wins over one in a dylib, which is what the port relies on at run time, and
# cases.m proves it with dladdr.
# shellcheck disable=SC2086  # $files is a LIST and must word-split
xcrun clang -w -DCHARON_PORT -fobjc-arc -I"$port" $files "$port/ImageIONames130.m" "$here/cases.m" \
  -framework Foundation -framework CoreGraphics -framework ImageIO -o "$build/port" 2>"$build/port.log" || {
  echo "BUILD  port"; head -5 "$build/port.log" | sed 's/^/    /'; exit 1; }
xcrun clang -w -DCHARON_HOST -fobjc-arc "$here/cases.m" \
  -framework Foundation -framework CoreGraphics -framework ImageIO -o "$build/host" 2>"$build/host.log" || {
  echo "BUILD  host"; head -5 "$build/host.log" | sed 's/^/    /'; exit 1; }

"$build/port" "$build" > "$build/port.out" 2>"$build/port.err" || { echo "FAIL  the port build raised (exit $?)"; head -5 "$build/port.err" | sed 's/^/    /'; exit 1; }
"$build/host" "$build" > "$build/host.out" 2>"$build/host.err" || { echo "FAIL  the host build raised (exit $?)"; head -5 "$build/host.err" | sed 's/^/    /'; exit 1; }

portonly=$(grep -c '^PORTONLY' "$build/port.out" || true)
hostonly=$(grep -c '^PORTONLY' "$build/host.out" || true)
[ "$portonly" -gt 0 ] || { echo "FAIL  the port printed no PORTONLY record, so its guards are not being asked"; exit 1; }
[ "$hostonly" -eq 0 ] || { echo "FAIL  the host printed $hostonly PORTONLY records; they are the port's guards"; exit 1; }
binding=$(sed -n 's/^PORTONLY binding\t//p' "$build/port.out")
case "$binding" in
  *'=imageio,'*) echo "FAIL  a function this slice carries is still ImageIO's, not the port's: $binding"; exit 1 ;;
  *'=port'*) ;;
  *) echo "FAIL  the binding record did not name every function: $binding"; exit 1 ;;
esac
echo "  BINDING: every function this slice carries resolves to the port's object"

grep -v '^PORTONLY' "$build/port.out" > "$build/port.cmp"
grep -v '^PORTONLY' "$build/host.out" > "$build/host.cmp"
n=$(wc -l < "$build/port.cmp" | tr -d ' ')
h=$(wc -l < "$build/host.cmp" | tr -d ' ')
[ "$n" -gt 0 ] || { echo "FAIL  no case printed anything"; exit 1; }
[ "$n" -eq "$h" ] || { echo "FAIL  the two builds printed $n and $h records, so the comparison would pair different cases"; exit 1; }
# the status records must agree before anything else is read: if they do not, every later difference is noise
diff -u "$build/host.cmp" "$build/port.cmp" > "$build/diff.txt" || true
grep '^-' "$build/diff.txt" | grep -v '^---' | sed 's/^-\([^-].*\)$/\1/' | cut -f1 | sort -u > "$build/differing-cases.txt"
differing=$(wc -l < "$build/differing-cases.txt" | tr -d ' ')
declared=0
if [ -f "$here/known-differences.txt" ]; then
  grep -v '^#' "$here/known-differences.txt" | grep -v '^[[:space:]]*$' | cut -d'#' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort -u > "$build/declared.txt"
  declared=$(wc -l < "$build/declared.txt" | tr -d ' ')
fi
echo "  COMPARED: $n records, $differing differ, $declared declared in known-differences.txt"
if [ -s "$build/declared.txt" ]; then
  stale=$(comm -23 "$build/declared.txt" "$build/differing-cases.txt")
  [ -z "$stale" ] || { echo "FAIL  declared as differing and no longer differing:"; echo "$stale" | sed 's/^/    /'; exit 1; }
fi
undeclared=$(comm -13 "$build/declared.txt" "$build/differing-cases.txt")
[ -z "$undeclared" ] || { echo "FAIL  the port differs from the host on a case nobody declared:"; echo "$undeclared" | sed 's/^/    /'; head -20 "$build/diff.txt" | sed 's/^/    /'; exit 1; }
[ "$differing" -gt 0 ] || echo "  GREEN: every record answers what the host answers"

# THE TIMING IS HELD TO THE FRAME'S OWN DELAY and not to the scheduler, and this is the check that says so.
# Two loops of the three-frame file draw six frames and therefore every gap there is, and each one has to
# fall in the bucket of the delay the frame just drawn declares: 0.10, 0.30, 0.50, 0.10, 0.30.
# slot:expected, so the two halves cannot drift apart as a list grows
for pair in 1:0.10 2:0.30 3:0.50 4:0.10 5:0.30; do
  slot=${pair%%:*}
  expected=${pair##*:}
  got=$(sed -n "s/^three-loop-2 gap $slot\t//p" "$build/port.cmp")
  if [ "$got" != "$expected" ]; then
    echo "FAIL  the gap before call $slot is $got, and the frame just drawn declares $expected"
    exit 1
  fi
done
first=$(sed -n "s/^three-loop-2 gap 0\t//p" "$build/port.cmp")
[ "$first" = "first" ] || { echo "FAIL  the gap before the first frame is $first, and it is drawn at once"; exit 1; }
echo "  TIMING: the five gaps of two loops are the delays the file declares (0.10, 0.30, 0.50, 0.10, 0.30) in 20ms buckets, and the first frame is drawn at once"

# THE MUTATIONS: the port's own source changed, and the run has to notice. Two plants, because the two
# halves of this object fail differently - one is the frame walk, the other is the source it walks.
plant=$build/plant
rm -rf "$plant"; mkdir -p "$plant"
cp "$here/cases.m" "$plant/cases.m"
# shellcheck disable=SC2086
for f in $files; do cp "$f" "$plant/$(basename "$f")"; done

build_plant() {  # $1 = label; builds the planted port
  rm -f "$plant"/*.o
  objs=""
  for f in "$plant"/*.m; do
    [ "$f" = "$plant/cases.m" ] && continue
    xcrun clang -w -DCHARON_PORT -fobjc-arc -I"$port" -c "$f" -o "$f.o" 2>"$build/plant.log" || {
      echo "BUILD  the mutated port ($f)"; head -3 "$build/plant.log" | sed 's/^/    /'; exit 1; }
    objs="$objs $f.o"
  done
  xcrun clang -w -DCHARON_PORT -fobjc-arc "$port/ImageIONames130.m" $objs "$plant/cases.m" \
    -framework Foundation -framework CoreGraphics -framework ImageIO -o "$build/plantbin" 2>"$build/plant.log" || {
    echo "BUILD  the mutated port ($1)"; head -3 "$build/plant.log" | sed 's/^/    /'; exit 1; }
}

# 1. the frame walk: stop after the first frame instead of wrapping
animation=$plant/ImageIOAnimation134.m
sed -i '' 's/_index = index + 1;/_index = index;/' "$animation"
hit=$(grep -c '_index = index;' "$animation" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the first mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "frame walk" > /dev/null
"$build/plantbin" "$build" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  an animation that never advances the frame index and the comparison did not see it"; exit 1
fi
echo "  MUTATION 1: an animation that does not advance the index moves records, so the frame walk can go red"

# 2. the delay: every frame drawn at the delay the file gives the FIRST frame
sed -i '' 's/double delay = charon_frame_delay(_source, index);/double delay = charon_frame_delay(_source, 0);/' "$animation"
hit=$(grep -c 'charon_frame_delay(_source, 0)' "$animation" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the second mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "delay" > /dev/null
"$build/plantbin" "$build" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  drawing every frame at the first frame's delay and the comparison did not see it"; exit 1
fi
echo "  MUTATION 2: drawing every frame at one delay moves records, so the per-frame delay can go red too"

cp "$here/cases.m" "$plant/cases.m"

echo "imageio-animate: $n records compared, $differing declared differences, mutation RED"
exit 0