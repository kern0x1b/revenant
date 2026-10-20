#!/bin/sh
# The PORT's ImageIO name constants against the HOST's own ImageIO, and a mutant per constant.
#
# The port's object is COMPILED, LINKED into a private copy of portread.c, and READ through dlsym, so the
# value compared against Apple's is the port's own and not a string this script already had. The previous
# version of this harness read ImageIONames130.m for NAMES only, wrote the host's answers to green.txt and
# then grepped that file for a mutant marker it could never contain: changing all 22 CFSTR values still
# printed 22 of 22 and exited 0. A comparison that cannot go red proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
# the band objects the generator writes (generate() in modules/apple/backports.lua builds them): a band is in the library's folder or here
gen=$root/packages/a/apple-backports/.gen/ImageIO
build=${BUILD:-$(runs_folder imageio-names)}
mkdir -p "$build"
obj=${PORT_OBJ:-$build/slice.o}

# THE OBJECT LIST IS A FILE, not a name in this script, so a slice EXTENDS the harness instead of forking
# it: every band this run covers is named in objects.txt, and a band left out of that file is NOT covered.
objects=$here/objects.txt
[ -f "$objects" ] || { echo "FAIL  no objects.txt beside run.sh"; exit 1; }
files=""
while read -r f <&3 || [ -n "$f" ]; do
  if [ -f "$port/$f" ]; then p="$port/$f"; elif [ -f "$gen/$f" ]; then p="$gen/$f"; else
    echo "FAIL  objects.txt names $f and there is no $port/$f or $gen/$f (run generate(): the build writes .gen)"; exit 1; fi
  files="$files $p"
done 3< "$objects"
files=${files# }   # the accumulator starts with a space and a leading one becomes a pathname
# The count accepts BOTH spellings of a CFStringRef global - `CFStringRef const X` and `const CFStringRef
# X` - and it counts a band that is written as DEFINITIONS ONLY, with no extern line at all, which is the
# form the port's own const-first files use: all 11 of them declare nothing and define everything.
#
# WHAT THE COUNT COMPARES, stated honestly because a line count cannot mean both things at once: the two
# raw line counts CANNOT be compared for a mixed tree. With a const-first definitions-only band listed, the
# old check reported "40 declared and 58 defined" and failed, and it was right to fail - 58 is not 40 -
# but the message named a disagreement that was not one: 18 of those 58 are names nothing declares. So the
# count is per NAME now, not per line: names.txt is the union of declared and defined names, and every one
# of them must be defined exactly once. A name declared and not defined fails, and a name defined and not
# declared does not - which is what a definitions-only band is.
name_re='^(extern[[:space:]]+(const[[:space:]]+)?CFStringRef|extern[[:space:]]+CFStringRef[[:space:]]+const)[[:space:]]+([A-Za-z0-9_]+)[[:space:]]*;'
def_re='^(const[[:space:]]+CFStringRef|CFStringRef[[:space:]]+const)[[:space:]]+([A-Za-z0-9_]+)[[:space:]]*='
: > "$build/declared.txt"; : > "$build/defined.txt"
grep -hE "$name_re" $files | sed -E 's/.*[[:space:]]([A-Za-z0-9_]+)[[:space:]]*;$/\1/' | sort -u > "$build/declared.txt"
grep -hE "$def_re" $files | sed -E 's/.*[[:space:]]([A-Za-z0-9_]+)[[:space:]]*=.*/\1/' | sort > "$build/defined.txt"
# no process substitution: this is /bin/sh, not bash, and `<(...)` is a syntax error there
sort -u "$build/defined.txt" > "$build/defined-u.txt"
comm -23 "$build/declared.txt" "$build/defined-u.txt" > "$build/declared-undefined.txt"
cat "$build/declared.txt" "$build/defined.txt" | sort -u > "$build/names.txt"
n=$(wc -l < "$build/names.txt" | tr -d ' ')
d=$(wc -l < "$build/defined.txt" | tr -d ' ')
decl=$(wc -l < "$build/declared.txt" | tr -d ' ')
[ "$n" -gt 0 ] || { echo "FAIL  no constants counted at all"; exit 1; }
[ "$d" -eq "$n" ] || { echo "FAIL  $n names counted and $d defined - every counted name must be defined once"; exit 1; }
[ ! -s "$build/declared-undefined.txt" ] || { echo "FAIL  declared and never defined:"; head -3 "$build/declared-undefined.txt" | sed 's/^/    /'; exit 1; }
# every band file in the directory must be COVERED: a band present and unlisted is invisible to everything
# below, which is how a count shrinks quietly. This is asserted, and planted.
# COVERAGE, as a function so it can be asked twice: once for the real list and once for a doctored one.
# Eleven ImageIONames objects existed on disk that objects.txt never named - every band the port had built
# before this harness - and this assertion named all eleven on its first run. They were invisible to every
# check below, which is exactly what a band missing from the list is.
coverage_missing() {  # $1 = a list file; prints the band files on disk that it does not name
  ls "$port"/ImageIONames*.m "$gen"/ImageIONames*.m | xargs -n1 basename | sort > "$build/ondisk.txt"
  sort "$1" > "$build/listed.txt"
  comm -23 "$build/ondisk.txt" "$build/listed.txt"
}
miss=$(coverage_missing "$objects")
[ -z "$miss" ] || { echo "FAIL  a band object is on disk and NOT in objects.txt, so nothing would check it:"; echo "$miss" | sed 's/^/    /'; exit 1; }
# A FIXED EXPECTED TOTAL PER SLICE. $d -eq $n pins nothing on its own: drop a band from objects.txt and
# both sides of that equality fall together, so the run shrinks and stays green - which is exactly what
# the reviewer measured on the previous commit (constants: 52, 52 mutants, exit 0). The coverage check
# above catches a band on disk that the list omits, and this catches a total that moves for any reason at
# all. Both numbers are in expected.txt, which is the file to edit when a slice adds a band.
expected=$here/expected.txt
[ -f "$expected" ] || { echo "FAIL  no expected.txt beside run.sh"; exit 1; }
exp_n=$(sed -n 's/^constants=//p' "$expected" | tr -d ' ')
exp_o=$(sed -n 's/^objects=//p' "$expected" | tr -d ' ')
[ -n "$exp_n" ] && [ -n "$exp_o" ] || { echo "FAIL  expected.txt must hold constants= and objects="; exit 1; }
[ "$n" -eq "$exp_n" ] || { echo "FAIL  expected $exp_n constants and counted $n - a band was dropped or added"; exit 1; }
[ "$(wc -l < "$objects" | tr -d ' ')" -eq "$exp_o" ] || { echo "FAIL  expected $exp_o objects in objects.txt and there are $(wc -l < "$objects" | tr -d ' ')"; exit 1; }
echo "  TOTAL: $n constants over $(wc -l < "$objects" | tr -d ' ') objects, as expected.txt pins"
grep -v '^ImageIONames70\.m$' "$objects" > "$build/objects-minus-one.txt"
m2=$(coverage_missing "$build/objects-minus-one.txt")
case "$m2" in *ImageIONames70.m*) echo "  COVERAGE: an unlisted band on disk is detected, and is named" ;;
  *) echo "FAIL  the coverage check did not detect ImageIONames70.m removed from the list"; exit 1 ;; esac
echo "  constants: $n"

xcrun clang -w "$here/probe.c" -framework CoreFoundation -framework ImageIO -o "$build/probe" 2>"$build/probe.log" || {
  echo "BUILD  probe"; head -3 "$build/probe.log" | sed 's/^/    /'; exit 1; }
# one object per source file: clang refuses a single -o for several inputs, so they are compiled apart and
# the reader is linked with all of them, which is also what the port itself does
# each source is compiled ONCE into $build/slice-obj, and a mutant recompiles ONLY the file it changes and
# re-links with the rest: with seventeen band objects a per-mutant full rebuild would be thousands of
# compiles for no extra proof.
rm -rf "$build/slice-obj"; mkdir -p "$build/slice-obj"
objs=""
for f in $files; do
  o="$build/slice-obj/$(basename "$f" .m).o"
  xcrun clang -w -I"$root/packages/a/apple-backports" -c "$f" -o "$o" 2>"$build/port.log" || {
    echo "BUILD  $f"; head -3 "$build/port.log" | sed 's/^/    /'; exit 1; }
  objs="$objs $o"
done
objs=${objs# }

value_of() {  # $1 = program, $2 = symbol: the value it READS, empty if it did not read one
  "$1" "$2" 2>/dev/null | sed -n 's/^  VALUE //p'
}

# compare the port's read values against the host's, for every name
compare() {  # $1 = label, $2 = the port object to link, $3 = expect (agree|differ)
  # shellcheck disable=SC2086  # $2 is a LIST of objects and must word-split
  xcrun clang -w "$here/portread.c" $2 -framework CoreFoundation -o "$build/pr" 2>"$build/pr.log" || {
    echo "BUILD  $1: portread did not link"; head -3 "$build/pr.log" | sed 's/^/    /'; exit 1; }
  agree=0; differ=0
  : > "$build/differs.txt"
  while read -r name <&3; do
    p=$(value_of "$build/pr" "$name"); h=$(value_of "$build/probe" "$name")
    if [ -z "$p" ]; then echo "FAIL  $1: the port reader returned nothing for $name"; exit 1; fi
    if [ "$p" = "$h" ]; then agree=$((agree+1)); else differ=$((differ+1)); echo "$name" >> "$build/differs.txt"; fi
  done 3< "$build/names.txt"
  echo "  $1: $agree agree, $differ differ"
  case "$3" in
    agree)  [ "$differ" -eq 0 ] || { echo "FAIL  $1: the port disagrees with Apple on $(head -1 "$build/differs.txt")"; exit 1; } ;;
    all) [ "$differ" -eq "$n" ] || { echo "FAIL  $1: $differ differed, not all $n"; exit 1; } ;;
    differ) [ "$differ" -ge 1 ] || { echo "FAIL  $1: nothing differed, so the comparison cannot be seen to fail"; exit 1; }
            [ "${4:-}" = "exact" ] && { [ "$differ" -eq 1 ] || { echo "FAIL  $1: $differ differed, not exactly 1"; exit 1; }; } ;;
  esac
}

# THE GREEN RUN: the port's own object, linked and read
# shellcheck disable=SC2086  # $objs is a LIST of objects and must word-split
compare "GREEN (port vs host)" "$objs" agree
echo "  GREEN: all $n of the port's values read through the port's own object equal Apple's"

# THE CONTROL on the planted name: the host reader must report a name it does not have
"$build/probe" kCGImagePropertyNoSuchNameForTheControl > "$build/ctl.txt" 2>&1 || true
grep -q 'VERDICT missing' "$build/ctl.txt" || { echo "FAIL  the planted name was not reported missing"; exit 1; }
echo "  CONTROL: the planted name is reported missing by the host reader"

# THE SPELLING PLANT: a band written `const CFStringRef X` instead of `CFStringRef const X` must still be
# COUNTED. The narrow `^CFStringRef const` pattern made such a band vanish from the count with nothing
# reported, which is the shape of bug a count can have and cannot be allowed to have.
sp=$build/spelling
rm -rf "$sp"; mkdir -p "$sp"
base=$(cat "$build/names.txt" | head -1)
cat > "$sp/ImageIONamesSpelling.m" <<SP
#import <ImageIO/ImageIO.h>
const CFStringRef $base = CFSTR("revenant-spelling-plant");
SP
# the same constant, spelled the other way round, in a band of its own
# the plant is a DEFINITIONS-ONLY band, which is the form the port's own const-first files use: all 11 of
# them declare nothing and define everything, so a plant with an extern line proved nothing about them.
# It is read with $name_re and $def_re THEMSELVES - the previous version restated both patterns as literals,
# so narrowing the real one still let the plant pass, which is what the reviewer demonstrated.
grep -hE "$def_re" "$sp/ImageIONamesSpelling.m" | sed -E 's/.*[[:space:]]([A-Za-z0-9_]+)[[:space:]]*=.*/\1/' | sort -u > "$build/spelling-names.txt"
sn=$(wc -l < "$build/spelling-names.txt" | tr -d ' ')
[ "$sn" -eq 1 ] || { echo "FAIL  the definitions-only spelling plant counted $sn names, not 1"; exit 1; }
[ "$(cat "$build/spelling-names.txt")" = "$base" ] || { echo "FAIL  the spelling plant counted the wrong name"; exit 1; }
echo "  SPELLING: a definitions-only band written const CFStringRef is counted ($sn name, declared by nothing)"

# THE TWO PLANTS THE REVIEWER USED, kept as permanent checks: the comparison must notice a wrong value
# whether ALL of them are wrong or ONE is. A comparison that only notices the total cannot see a single
# bad constant, and the previous harness noticed neither.
# the plants work on EVERY file of the slice, not one, so a slice of several bands is planted whole
pdir=$build/plants
rm -rf "$pdir"; mkdir -p "$pdir/all" "$pdir/one"
for f in $files; do b=$(basename "$f"); cp "$f" "$pdir/all/$b"; cp "$f" "$pdir/one/$b"; done
sed -i '' 's%CFSTR("\([^"]*\)")%CFSTR("revenant-plant-all")%g' "$pdir"/all/*.m
first=$(cat "$build/names.txt" | head -1)
sed -i '' "s%^CFStringRef const $first = CFSTR(\"[^\"]*\");%CFStringRef const $first = CFSTR(\"revenant-plant-one\");%" "$pdir"/one/*.m
plant_objs() {  # $1 = dir: compile every planted source apart and return the object list
  local o=""
  for f in "$1"/*.m; do
    xcrun clang -w -I"$root/packages/a/apple-backports" -c "$f" -o "$f.o" 2>/dev/null || { echo "BUILD  plant $f"; exit 1; }
    o="$o $f.o"
  done
  printf '%s' "${o# }"
}
compare "PLANT all $(echo $n) wrong" "$(plant_objs "$pdir/all")" all
compare "PLANT one wrong ($first)" "$(plant_objs "$pdir/one")" differ exact
echo "  PLANTS: the comparison goes red on all-wrong and on one-wrong"

sh "$here/merged-sample.sh" || { echo "FAIL  the merged-row control failed"; exit 1; }

# CONST-FIRST: how many of the objects in this list declare nothing and define everything. It is measured
# and printed because the comment above the mutation counts refers to it, and a hand-written count of it
# was wrong the moment the next slice landed.
cf=0; cf_total=0
for f in $files; do
  cf_total=$((cf_total+1))
  if ! grep -qE "$name_re" "$f" && grep -qE "$def_re" "$f"; then cf=$((cf+1)); fi
done
echo "  CONST-FIRST: $cf of $cf_total objects declare nothing and define everything"

# THE MUTANTS: one per constant, each COMPILED, LINKED and READ
i=0; ran=0; red=0
while read -r name <&3; do
  i=$((i+1))
  rm -rf "$build/m$i"; mkdir -p "$build/m$i/src"
  # every file of the slice is copied, and the ONE holding this constant is the one that is changed, so a
  # mutant still LINKS against the other bands' objects - the defect that made an earlier mutation produce
  # a copy identical to the original
  for f in $files; do cp "$f" "$build/m$i/src/$(basename "$f")"; done
  # The MUTATION pattern has to take both spellings too, and it did not: it was still the narrow
  # `^CFStringRef const`, so for a const-first band the sed matched nothing and the loop failed on "the
  # copy carries 0 mutant markers". That is the same defect as the count, in a second place - a pattern
  # that assumes one spelling of the thing it is looking at.
  for f in "$build/m$i"/src/*.m; do
    sed -E "s%^(CFStringRef[[:space:]]+const|const[[:space:]]+CFStringRef)[[:space:]]+$name[[:space:]]*=[[:space:]]*CFSTR\\(\"[^\"]*\"\\);%\\1 $name = CFSTR(\"revenant-mutant-$i\");%" \
      "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
  # The two counts below use $def_re, not a narrow literal. They guard the mutation against losing a
  # definition, and a narrow pattern could not move for a const-first band at all, so the guard was inert
  # for every const-first object in the list - the same spelling blindness as everywhere else, in a third
  # place. How many of them there are is not written here: a number in a comment goes stale the next time a
  # slice adds a band, and CONST-FIRST below is measured and printed instead.
  before=$(cat "$build/m$i"/src/*.m | grep -hcE "$def_re" | awk '{s+=$1} END{print s+0}')
  # The NARROW sed that used to sit here, after the widened one above, is GONE. It was a leftover of the
  # rewrite and it re-introduced the exact spelling assumption the line above exists to remove: for a
  # CFStringRef-const-first band it matched the ALREADY mutated line and rewrote it to the same value, so
  # it did no harm and earned nothing, and a second copy of the mutation is a second place to be wrong.
  c=$(cat "$build/m$i"/src/*.m | grep -hcE "$def_re" | awk '{s+=$1} END{print s+0}')
  [ "$c" -eq "$before" ] || { echo "FAIL  mutant $i: a definition was lost"; exit 1; }
  hit=$(cat "$build/m$i"/src/*.m | grep -c "revenant-mutant-$i" || true)
  [ "$hit" -eq 1 ] || { echo "FAIL  mutant $i: the copy carries $hit mutant markers, not 1"; exit 1; }
  held=""
  for f in "$build/m$i"/src/*.m; do
    b=$(basename "$f" .m)
    if grep -q "^CFStringRef const $name = \|^const CFStringRef $name = " "$f"; then
      xcrun clang -w -I"$root/packages/a/apple-backports" -c "$f" -o "$build/m$i/$b.o" 2>"$build/m$i/c.log" || {
        echo "BUILD  mutant $i did not compile $b"; head -3 "$build/m$i/c.log" | sed 's/^/    /'; exit 1; }
      held="$build/m$i/$b.o"
    else
      held="$held $build/slice-obj/$b.o"
    fi
  done
  mobjs=${held# }
  xcrun clang -w "$here/portread.c" $mobjs -framework CoreFoundation -o "$build/m$i/pr" 2>"$build/m$i/l.log" || {
    echo "BUILD  mutant $i did not link"; head -3 "$build/m$i/l.log" | sed 's/^/    /'; exit 1; }
  ran=$((ran+1))
  if [ "$(value_of "$build/m$i/pr" "$name")" = "$(value_of "$build/probe" "$name")" ]; then
    echo "  NOT NOTICED  mutant $i changes $name and the comparison did not see it"; exit 1
  fi
  red=$((red+1))
done 3< "$build/names.txt"
echo "imageio-names: $n constants, $ran mutants run, $red RED"
[ "$ran" -eq "$n" ] && [ "$red" -eq "$n" ] || { echo "  incomplete"; exit 1; }
exit 0
