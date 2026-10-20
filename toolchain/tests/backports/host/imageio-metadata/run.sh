#!/bin/sh
# run.sh — the PORT's CGImageMetadata against the HOST's own ImageIO, case by case, with a mutation
# planted to show the comparison can go red.
#
# WHY TWO BINARIES AND NOT ONE: a function has one name in both libraries. Linking the port's object and
# the host's ImageIO into one program cannot happen (the linker sees the same definition twice), so each
# build answers the same cases and run.sh compares the two outputs line by line. What the port's answers
# come from the port is proved in the PORT build itself, not assumed: cases.m's PORTONLY binding record
# reads dladdr() for every function this slice carries and fails if any of them is still ImageIO's.
#
# WHAT IT IS NOT: it is not tests/backports/host/imageio/run.sh, which links the host's ImageIO on both
# sides of every one of its five checks and so compares the host with itself. Nothing in this tree compared
# the port's CGImageMetadata with anything before this file.
#
# A difference is only allowed where known-differences.txt declares it, with the case name spelled exactly.
# An undeclared difference fails; a declared difference that stops differing fails too, because then the
# declaration is stale and a reader would trust a difference that is no longer there.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
# ImageIOMetadata7.m is written by tools/gen (spec/ImageIO/property-map.tsv) into .gen/ImageIO, so a name the list gives is looked for in both
gen=$root/packages/a/apple-backports/.gen/ImageIO
build=${BUILD:-$(runs_folder imageio-metadata)}
mkdir -p "$build"

# THE OBJECT LIST IS A FILE, so a band extends this harness instead of forking it, and a band on disk that
# the list does not name is a band nothing would check. The check for that is asserted, by planting a name
# the list does not have and asking again.
objects=$here/objects.txt
[ -f "$objects" ] || { echo "FAIL  no objects.txt beside run.sh"; exit 1; }
files=""
while read -r f <&3 || [ -n "$f" ]; do
  if [ -f "$port/$f" ]; then files="$files $port/$f"
  elif [ -f "$gen/$f" ]; then files="$files $gen/$f"
  else echo "FAIL  objects.txt names $f and there is no $port/$f or $gen/$f"; exit 1
  fi
done 3< "$objects"
files=${files# }
[ -n "$files" ] || { echo "FAIL  objects.txt names no object"; exit 1; }

coverage_missing() {  # $1 = a list file; prints the objects on disk that it does not name
  ls "$port"/ImageIOMetadata*.m "$gen"/ImageIOMetadata*.m 2>/dev/null | xargs -n1 basename | sort > "$build/ondisk.txt"
  sort "$1" > "$build/listed.txt"
  comm -23 "$build/ondisk.txt" "$build/listed.txt"
}
miss=$(coverage_missing "$objects")
[ -z "$miss" ] || { echo "FAIL  an object is on disk and NOT in objects.txt, so nothing would check it:"; echo "$miss" | sed 's/^/    /'; exit 1; }
{ grep -v '^ImageIOMetadata7\.m$' "$objects" || true; } > "$build/objects-minus-one.txt"
case "$(coverage_missing "$build/objects-minus-one.txt")" in
  *ImageIOMetadata7.m*) : ;;
  *) echo "FAIL  the coverage check did not detect ImageIOMetadata7.m removed from the list"; exit 1 ;;
esac
echo "  COVERAGE: an object on disk and not in objects.txt is detected, and is named"

# THE PORT BUILD: its own objects plus the name objects the cases ask for by symbol (the prefixes of the
# namespaces are 7.0 names the release does not export, so they come from the port), and ImageIO itself
# for the namespace constants iOS 6 does export. A definition in an object wins over one in a dylib, which
# is what the port relies on at run time, and cases.m proves it with dladdr.
# shellcheck disable=SC2086  # $files is a LIST and must word-split
xcrun clang -w -DREVENANT_PORT -fobjc-arc -I"$port" $files "$here/cases.m" \
  -framework Foundation -framework CoreFoundation -framework ImageIO -o "$build/port" 2>"$build/port.log" || {
  echo "BUILD  port"; head -5 "$build/port.log" | sed 's/^/    /'; exit 1; }
xcrun clang -w -DREVENANT_HOST -fobjc-arc "$here/cases.m" \
  -framework Foundation -framework CoreFoundation -framework ImageIO -o "$build/host" 2>"$build/host.log" || {
  echo "BUILD  host"; head -5 "$build/host.log" | sed 's/^/    /'; exit 1; }

"$build/port" > "$build/port.out" 2>"$build/port.err" || { echo "FAIL  the port build raised"; head -5 "$build/port.err" | sed 's/^/    /'; exit 1; }
"$build/host" > "$build/host.out" 2>"$build/host.err" || { echo "FAIL  the host build raised"; head -5 "$build/host.err" | sed 's/^/    /'; exit 1; }

# PORTONLY records are the port's own guards: they exist on the port side and must not on the host's, and
# they are dropped from both before the comparison so a port-only line cannot read as a difference.
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

# AN INERT ROW SAYS SO ONCE, and that is a claim the output text cannot carry: it goes to the log. The
# cases.m PORTONLY block calls CGImageSourceRemoveCacheAtIndex twice, so a line that appeared twice would
# be a line that appeared every time, which is not what "once" means.
logged=$(grep -c 'CGImageSourceRemoveCacheAtIndex: the decoded image cache' "$build/port.err" || true)
[ "$logged" -eq 1 ] || { echo "FAIL  the port's log line for CGImageSourceRemoveCacheAtIndex appears $logged times, not once"; exit 1; }
hostlogged=$(grep -c 'CGImageSourceRemoveCacheAtIndex: the decoded image cache' "$build/host.err" || true)
[ "$hostlogged" -eq 0 ] || { echo "FAIL  the host printed the port's own log line"; exit 1; }
echo "  INERT ROW: CGImageSourceRemoveCacheAtIndex says once that it freed nothing, and only once"
grep -v '^PORTONLY' "$build/port.out" > "$build/port.cmp"
grep -v '^PORTONLY' "$build/host.out" > "$build/host.cmp"

n=$(wc -l < "$build/port.cmp" | tr -d ' ')
h=$(wc -l < "$build/host.cmp" | tr -d ' ')
[ "$n" -gt 0 ] || { echo "FAIL  no case printed anything"; exit 1; }
[ "$n" -eq "$h" ] || { echo "FAIL  the two builds printed $n and $h records, so the comparison would pair different cases"; exit 1; }

diff -u "$build/host.cmp" "$build/port.cmp" > "$build/diff.txt" || true
# a line of the diff that starts with '-' is a record the two builds answer differently
grep '^-' "$build/diff.txt" | grep -v '^---' | sed 's/^-\([^-].*\)$/\1/' | cut -f1 | sort -u > "$build/differing-cases.txt"
differing=$(wc -l < "$build/differing-cases.txt" | tr -d ' ')
declared=0
if [ -f "$here/known-differences.txt" ]; then
  # a case NAME carries a space ("tag unknown-ns-no-prefix"), so the ends are trimmed and the middle is not
  grep -v '^#' "$here/known-differences.txt" | grep -v '^[[:space:]]*$' | cut -d'#' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort -u > "$build/declared.txt"
  declared=$(wc -l < "$build/declared.txt" | tr -d ' ')
fi
echo "  COMPARED: $n cases, $differing differ, $declared declared in known-differences.txt"
# a declared difference that no longer differs is stale, and a reader would go on trusting it
if [ -s "$build/declared.txt" ]; then
  stale=$(comm -23 "$build/declared.txt" "$build/differing-cases.txt")
  [ -z "$stale" ] || { echo "FAIL  declared as differing and no longer differing:"; echo "$stale" | sed 's/^/    /'; exit 1; }
fi
undeclared=$(comm -13 "$build/declared.txt" "$build/differing-cases.txt")
[ -z "$undeclared" ] || { echo "FAIL  the port differs from the host on a case nobody declared:"; echo "$undeclared" | sed 's/^/    /'; exit 1; }
if [ "$differing" -eq 0 ]; then echo "  GREEN: every case answers what the host answers"; fi

# THE MUTATION: the port's own source changed, and the run has to notice. Two plants, because the run has
# two kinds of check: one compares case answers, one counts a log line. A harness whose only proof is the
# first cannot see a change in the second.
plant=$build/plant
rm -rf "$plant"; mkdir -p "$plant"
# every header cases.m includes is copied beside it, or the mutated build cannot compile: an #include of a
# header the plant does not have fails the build and the mutation is never asked.
cp "$here/cases.m" "$plant/cases.m"
for h in "$here"/*.h; do cp "$h" "$plant/$(basename "$h")"; done
# shellcheck disable=SC2086
for f in $files; do cp "$f" "$plant/$(basename "$f")"; done

build_plant() {  # $1 = label; echoes the object list of the planted sources
  rm -f "$plant"/*.o
  objs=""
  for f in "$plant"/*.m; do
    [ "$f" = "$plant/cases.m" ] && continue
    xcrun clang -w -DREVENANT_PORT -fobjc-arc -I"$port" -c "$f" -o "$f.o" 2>"$build/plant.log" || {
      echo "BUILD  the mutated port ($f)"; head -3 "$build/plant.log" | sed 's/^/    /'; exit 1; }
    objs="$objs $f.o"
  done
  xcrun clang -w -DREVENANT_PORT -fobjc-arc -I"$port" $objs "$plant/cases.m" \
    -framework Foundation -framework CoreFoundation -framework ImageIO -o "$build/plantbin" 2>"$build/plant.log" || {
    echo "BUILD  the mutated port ($1)"; head -3 "$build/plant.log" | sed 's/^/    /'; exit 1; }
  printf '%s' "${objs# }"
}

# 1. a namespace's default prefix: a case answer must move
metadata_file=$plant/ImageIOMetadata7.m
sed -i '' "s/table\[7\].prefix = kCGImageMetadataPrefixTIFF;/table[7].prefix = CFSTR(\"revenant-plant\");/" "$metadata_file"
hit=$(grep -c "revenant-plant" "$metadata_file" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the first mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "default prefix" > /dev/null
"$build/plantbin" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  changing a namespace's default prefix and the comparison did not see it"; exit 1
fi
echo "  MUTATION 1: a changed default prefix moves a case answer, so the comparison can go red"

# 2. the one-time log line of the inert row: the count must move
git_dir=$plant/ImageIOSourceState7.m
[ -f "$git_dir" ] && {
  sed -i '' "s/the decoded image cache belongs/revenant-plant-belongs/" "$git_dir"
  hit=$(grep -c "revenant-plant-belongs" "$git_dir" || true)
  [ "$hit" -eq 1 ] || { echo "FAIL  the second mutation changed nothing (the pattern is stale)"; exit 1; }
  cp "$here/cases.m" "$plant/cases.m"
  build_plant "log line" > /dev/null
  "$build/plantbin" > /dev/null 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
  logged=$(grep -c 'CGImageSourceRemoveCacheAtIndex: the decoded image cache' "$build/plant.err" || true)
  [ "$logged" -eq 0 ] || { echo "  NOT NOTICED  changing the inert row's log line and the once-check did not see it"; exit 1; }
  echo "  MUTATION 2: a changed log line empties the once-check, so that check can go red too"
}
# 3. the property table's own rows: a name changed in one row must move a case answer
metadata_table=$plant/ImageIOMetadata7.m
sed -i '' 's|"photoshop", "DateCreated" },  // kCGImagePropertyExifDateTimeOriginal|"photoshop", "DateCreatedRevenantPlant" },  // kCGImagePropertyExifDateTimeOriginal|' "$metadata_table"
hit=$(grep -c "DateCreatedRevenantPlant" "$metadata_table" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the third mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "property table row" > /dev/null
"$build/plantbin" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  changing a row of the property table and the comparison did not see it"; exit 1
fi
echo "  MUTATION 3: a changed name in one row of the property table moves a case answer, so the table can go red"

# 4. the rule the table alone does not say: the lookup matches the namespace as well as the name, so
#    dropping the namespace compare must move a case that asks for one name out of two namespaces
sed -i '' 's|if (strcmp(xmlns, row\[2\]) == 0 \&\& strcmp(name, row\[4\]) == 0)|if (strcmp(name, row[4]) == 0)|' "$metadata_table"
hit=$(grep -c 'if (strcmp(name, row\[4\]) == 0)' "$metadata_table" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the fourth mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "namespace compare" > /dev/null
"$build/plantbin" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  dropping the namespace from the lookup's match and the comparison did not see it"; exit 1
fi
echo "  MUTATION 4: a lookup that matches names only moves a case answer, so the namespace rule can go red too"

# 5. the number spelling: keeping the CFNumber must move a record, and these records print the tag's VALUE,
#    so a plant that only turned the value back into a number is seen by the comparison and not by the type
sed -i '' 's/^    if (resolved == kCGImageMetadataTypeString)$/    if (resolved == kCGImageMetadataTypeString \&\& 0)/' "$metadata_table"
hit=$(grep -c 'kCGImageMetadataTypeString && 0' "$metadata_table" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the fifth mutation changed nothing (the pattern is stale)"; exit 1; }
build_plant "number spelling" > /dev/null
"$build/plantbin" > "$build/plant.out" 2>"$build/plant.err" || { echo "FAIL  the mutated port build raised"; exit 1; }
grep -v '^PORTONLY' "$build/plant.out" > "$build/plant.cmp"
if diff -q "$build/host.cmp" "$build/plant.cmp" > /dev/null; then
  echo "  NOT NOTICED  keeping the CFNumber in a tag and the comparison did not see it"; exit 1
fi
moved=$(grep '^-' "$build/diff.txt" > /dev/null; diff "$build/host.cmp" "$build/plant.cmp" | grep -c '^[<>] number\|^[<>] tag number\|^[<>] value number')
[ "$moved" -gt 0 ] || { echo "  NOT THE RIGHT RECORDS  keeping the CFNumber moved no number record, so the value is not what moved"; exit 1; }
echo "  MUTATION 5: keeping the CFNumber moves $moved of the number records, which print the tag's value"

cp "$here/cases.m" "$plant/cases.m"

echo "imageio-metadata: $n cases compared, $differing declared differences, mutation RED"
exit 0
