#!/bin/sh
# run.sh — the two measurements the next band of this family needs, re-runnable, with their controls.
#
# NEITHER OF THESE CHECKS THE PORT. Both measure the ORACLE, because what was missing was a fact about the
# host: what CGImageMetadataCopyTagMatchingImageProperty answers for every (dictionary, property) pair the
# iOS 16.4 header declares, and what CGImageMetadataSetValueMatchingImageProperty does with the same pairs.
# run.sh asserts the counts it measured so a change in the host's own behaviour is visible rather than
# silent, and it prints both numbers and the controls beside them. The port's own differential is run.sh's
# neighbour, run.sh in this directory's parent, which binds the port's object and can fail.
#
# ONE PAIR PER PROCESS, and that is the measurement method rather than a workaround: a pair the host
# cannot answer for has to be recordable on its own, and only a process per pair says which. A SIGTRAP
# (exit 133) would be such an answer, and the count of them is checked below - not because this host
# produces any, which it does not, but because a harness that only ever sees zero traps would not notice
# a pair that started trapping.
#
# WHAT AN EARIER READING OF THIS FILE SAID, AND WHY IT WAS WRONG: it reported "173 of 192 pairs TRAP the
# host (SIGTRAP)" and read the trap as ImageIO refusing the pair. The trap was in this harness: the set
# branch printed the tag it had just read with [NSString appendFormat:@"%@", <a const char *>], and a %@
# with a C string sends -respondsToSelector: to a stack address, where the ObjC runtime traps. Set had
# already returned true and written its tag before that line ran. With the format fixed, all 192 pairs
# answer and 173 of them answer true - the same 173 the table in spec/ImageIO/property-map.tsv carries.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${BUILD:-$(runs_folder imageio-mapping)}
mkdir -p "$build"

xcrun clang -w -fobjc-arc -I"$here" "$here/property-mapping.m" \
  -framework ImageIO -framework Foundation -framework CoreFoundation -o "$build/property-mapping" \
  2>"$build/build.log" || { echo "BUILD  property-mapping"; head -3 "$build/build.log" | sed 's/^/    /'; exit 1; }

# 1. THE LOOKUP DIRECTION: 192 pairs, each asked against a container holding the property's own name in
# each of the nine public namespaces, so the answer names the namespace instead of guessing it.
"$build/property-mapping" > "$build/property-mapping.txt" 2>/dev/null
# every line names the section it came from in its first field, so a count cannot add two sections up
pairs=$(grep -c '^ownname' "$build/property-mapping.txt" || true)
identity=$(awk -F'\t' '$1=="ownname" && $4!="none"' "$build/property-mapping.txt" | wc -l | tr -d ' ')
nonen=$(awk -F'\t' '$1=="ownname" && $4=="none"' "$build/property-mapping.txt" | wc -l | tr -d ' ')
echo "  LOOKUP: $pairs pairs, $identity answered at the property's own name, $nonen answered at no name"
echo "  LOOKUP namespaces:"; awk -F'\t' '$1=="ownname" && $4!="none"{print "    "$4}' "$build/property-mapping.txt" | sort | uniq -c | sed 's/^/  /'
# CONTROLS, or a table of zeros would prove nothing: a dictionary and a property no header declares answer
# NULL, and the one property the container does hold is answered with the tag the container holds.
control_dict=$(grep '^control	NoSuchDictionary	Orientation	' "$build/property-mapping.txt" | cut -f7)
control_prop=$(grep '^control	Exif	NoSuchProperty	' "$build/property-mapping.txt" | cut -f7 | head -1)
held=$(grep '^control	TIFF	Orientation-filled	' "$build/property-mapping.txt" | cut -f7,8,9,10 | tr '\t' ' ')
[ "$control_dict" = "NULL" ] || { echo "FAIL  a dictionary no header declares answered $control_dict, not NULL"; exit 1; }
[ "$control_prop" = "NULL" ] || { echo "FAIL  a property no header declares answered $control_prop, not NULL"; exit 1; }
case "$held" in
  *"Orientation"*) : ;;
  *) echo "FAIL  the pair the container really holds answered $held"; exit 1 ;;
esac
echo "  CONTROL: a dictionary and a property no header declares answer NULL, and the pair the container holds is answered"

# 2. THE SET DIRECTION, one process per pair, and the exit status IS the answer.
: > "$build/property-set-answers.txt"
i=0
while [ "$i" -lt "$pairs" ]; do
  out=$("$build/property-mapping" "$i" 2>/dev/null) && code=0 || code=$?
  printf '%s\t%s\n' "$code" "$out" >> "$build/property-set-answers.txt"
  i=$((i+1))
done
trapped=$(awk -F'\t' '$1!=0' "$build/property-set-answers.txt" | wc -l | tr -d ' ')
answered=$(awk -F'\t' '$1==0' "$build/property-set-answers.txt" | wc -l | tr -d ' ')
true_answers=$(awk -F'\t' '$1==0 && $5==1' "$build/property-set-answers.txt" | wc -l | tr -d ' ')
echo "  SET: $pairs pairs, $trapped TRAP the host (SIGTRAP), $answered answer, $true_answers of those answer true"
[ "$trapped" -eq 0 ] || { echo "FAIL  $trapped pairs trap the host; the facts page says none does, and a trap needs a process of its own to be looked at"; exit 1; }
[ "$answered" -eq "$pairs" ] || { echo "FAIL  only $answered of $pairs pairs answered; every one of them answers something"; exit 1; }
[ "$true_answers" -gt 0 ] || { echo "FAIL  no pair answers true; the table carries $true_answers of them for this slice of the pair list, so that has to be re-read"; exit 1; }
echo "imageio-mapping: lookup $identity/$pairs at the property's own name, set $true_answers/$pairs answered true"
exit 0
