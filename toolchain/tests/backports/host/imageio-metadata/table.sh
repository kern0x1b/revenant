#!/bin/sh
# table.sh: the HOST's property-to-tag table, measured over every (dictionary, property) pair the SDK's
# CGImageProperties.h declares, one process per pair, with the controls that say the numbers mean something.
#
# WHAT IT MEASURES, which is the whole input of the table in packages/a/apple-backports/spec/ImageIO/
# property-map.tsv: for each pair, what tag the host's own CGImageMetadataSetValueMatchingImageProperty
# writes, and what its own CGImageMetadataCopyTagMatchingImageProperty then answers for that pair. The
# names are the host's answers and nothing here decides what a property maps to.
#
# IT CHECKS THE ORACLE, NOT THE PORT. run.sh in this directory's parent is the differential: it builds the
# port's own object and the host's ImageIO into two programs and compares their answers case by case. This
# script's job is to say that the oracle's own numbers have not moved, so a table that stops matching is
# either a port defect or a change in the host, and this run says which.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
build=${BUILD:-$(runs_folder imageio-table)}
mkdir -p "$build"

xcrun clang -w -fobjc-arc -I"$here" "$here/property-table.m" \
  -framework ImageIO -framework Foundation -framework CoreFoundation -framework CoreServices -o "$build/property-table" \
  2>"$build/build.log" || { echo "BUILD  property-table"; head -3 "$build/build.log" | sed 's/^/    /'; exit 1; }

# the pair list is generated from the header, so the count is the header's and not this script's
pairs=$(grep -c '^    out\[[0-9]*\]\.dictionary' "$here/property-pairs-all.h")
[ "$pairs" -gt 400 ] || { echo "FAIL  the pair list has $pairs rows; it is generated from the header and is not small"; exit 1; }
echo "  PAIRS: $pairs, generated from the SDK's CGImageProperties.h by tools/gen/property_map.lua"

# ONE PROCESS PER PAIR, and the exit status is part of the answer: a pair the host cannot answer for is a
# row the table does not carry, and a pair that traps would be a row the harness has to look at by hand.
# the exit status of a pair goes in its own file, one line per pair, so the records themselves stay
# exactly what the pair printed: a code folded into the first line of a record would make every count over
# that file a count over lines instead of over pairs.
: > "$build/table.txt"
: > "$build/table-codes.txt"
i=0
while [ "$i" -lt "$pairs" ]; do
  out=$("$build/property-table" "$i" 2>/dev/null) && code=0 || code=$?
  printf '%s\n' "$code" >> "$build/table-codes.txt"
  printf '%s\n' "$out" >> "$build/table.txt"
  i=$((i + 1))
done

trapped=$(awk '$1!=0' "$build/table-codes.txt" | wc -l | tr -d ' ')
mapped=$(grep -c '^set	1$' "$build/table.txt" || true)
unmapped=$(grep -c '^set	0$' "$build/table.txt" || true)
echo "  TABLE: $pairs pairs, $mapped the host maps, $unmapped it does not, $trapped TRAP it (SIGTRAP)"
[ "$trapped" -eq 0 ] || { echo "FAIL  $trapped pairs trap the host; the numbers below would then not be the host's answers"; exit 1; }
[ $((mapped + unmapped)) -eq "$pairs" ] || { echo "FAIL  $mapped + $unmapped is not $pairs, so a pair answered neither"; exit 1; }
[ "$mapped" -gt 0 ] || { echo "FAIL  no pair is mapped, so the table would be empty"; exit 1; }
[ "$unmapped" -gt 0 ] || { echo "FAIL  no pair is unmapped; the header says \"Not all dictionaries and properties are supported\", and that has to show up"; exit 1; }

# THE HOST'S OWN TWO FUNCTIONS AGREE with each other on every mapped pair: the tag the set direction wrote
# is the tag the lookup answers, in the tree the set wrote and in a fresh tree holding only that tag. A
# disagreement would mean the table is two tables and this whole family is the wrong shape.
in_place=$(grep -c '^lookup-written-in-place	tag$' "$build/table.txt" || true)
fresh=$(grep -c '^lookup-fresh	tag	' "$build/table.txt" || true)
empty=$(grep -c '^lookup-empty	NULL$' "$build/table.txt" || true)
echo "  AGREE: $in_place/$mapped answer the tag the set wrote, $fresh/$mapped answer it in a fresh tree, $empty/$mapped answer NULL in an empty one"
[ "$in_place" -eq "$mapped" ] || { echo "FAIL  only $in_place of $mapped mapped pairs answer the tag the set direction wrote"; exit 1; }
[ "$fresh" -eq "$mapped" ] || { echo "FAIL  only $fresh of $mapped mapped pairs answer that tag in a fresh tree holding it alone"; exit 1; }
[ "$empty" -eq "$mapped" ] || { echo "FAIL  $((mapped - empty)) mapped pairs answered a tag in an empty tree; the lookup must answer NULL for a tree that holds nothing"; exit 1; }

# WHERE THE TAGS LAND, which is the fact the table exists for and the one no naming convention produces.
echo "  NAMESPACES of the $mapped rows:"
awk -F'\t' '$1=="set" && $2=="0" && $3=="tag" {print "    "$4" "$5}' "$build/table.txt" | sort | uniq -c | sort -rn | sed 's/^/  /'
# and the pairs the host does not map, by the dictionary they belong to: this is the header's own sentence
# about a partial table, and it names the dictionaries.
echo "  NOT MAPPED by dictionary:"
awk -F'\t' '$1=="# pair" {cur=$2} $1=="set" && NF==2 && $2=="0" {print cur}' "$build/table.txt" | sort | uniq -c | sort -rn | sed 's/^/  /'

echo "imageio-table: $pairs pairs, $mapped mapped, $unmapped not mapped, 0 trapped"
exit 0
