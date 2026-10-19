#!/bin/sh
# The SQLite3 backport's functions against the HOST's own libsqlite3, in one process each: the string builder (sqlite3_str_*,
# differential-str.c) and the keyword functions (sqlite3_keyword_*, differential-keywords.c). The port is compiled with each of
# its names renamed to revenant_port_*, so the host's function and the port's are both callable. Each family has a planted control
# that changes the port, and the differential must fail on it: a differential that cannot fail proves nothing.
# Usage: run.sh   (the build area is .agent-work/runs/sqlite3-host under the checkout)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
src="$root/packages/a/apple-backports/SQLite3"
build=${SQLITE3_BUILD:-$root/.agent-work/runs/sqlite3-host}
rm -rf "$build"
mkdir -p "$build/planted"
names="new finish append appendall appendchar vappendf appendf reset errcode length value"
renames=""
for name in $names; do
    renames="$renames -Dsqlite3_str_$name=revenant_port_sqlite3_str_$name"
done
keyword_renames="-Dsqlite3_keyword_count=revenant_port_sqlite3_keyword_count -Dsqlite3_keyword_name=revenant_port_sqlite3_keyword_name -Dsqlite3_keyword_check=revenant_port_sqlite3_keyword_check"

xcrun clang -O2 -w $renames -c "$src/StringBuilder.c" -o "$build/StringBuilder.o"
xcrun clang -O2 -w $keyword_renames -c "$src/Keywords.c" -o "$build/Keywords.o"
xcrun clang -O2 -w "$here/differential-str.c" "$build/StringBuilder.o" -lsqlite3 -o "$build/differential-str"
xcrun clang -O2 -w "$here/differential-keywords.c" "$build/Keywords.o" -lsqlite3 -o "$build/differential-keywords"
status=0
"$build/differential-str" > "$build/log" 2>&1 || status=1
cat "$build/log"
"$build/differential-keywords" > "$build/keywords-log" 2>&1 || status=1
cat "$build/keywords-log"
[ "$status" -eq 0 ] || { echo "differential failed"; exit 1; }

# the control for the string builder: the port's length is one more than the builder holds, and the differential must say so
sed 's/return p == NULL ? 0 : (int)p->length;/return p == NULL ? 0 : (int)p->length + 1;/' "$src/StringBuilder.c" > "$build/planted/StringBuilder.c"
grep -q '(int)p->length + 1;' "$build/planted/StringBuilder.c"
xcrun clang -O2 -w $renames -c "$build/planted/StringBuilder.c" -o "$build/planted/StringBuilder.o"
xcrun clang -O2 -w "$here/differential-str.c" "$build/planted/StringBuilder.o" -lsqlite3 -o "$build/planted/differential-str"
control=0
"$build/planted/differential-str" > "$build/planted/log" 2>&1 || control=$?
if [ "$control" -eq 0 ] || ! grep -q '^FAIL ' "$build/planted/log"; then
    echo "control: the planted length was not caught"
    exit 1
fi
echo "control: planted length caught ($(grep -c '^FAIL' "$build/planted/log") failing scenarios)"

# the control for the keywords: the port's count is one more than the table holds, and the differential must say so
sed 's/return kKeywordCount;/return kKeywordCount + 1;/' "$src/Keywords.c" > "$build/planted/Keywords.c"
grep -q 'return kKeywordCount + 1;' "$build/planted/Keywords.c"
xcrun clang -O2 -w $keyword_renames -c "$build/planted/Keywords.c" -o "$build/planted/Keywords.o"
xcrun clang -O2 -w "$here/differential-keywords.c" "$build/planted/Keywords.o" -lsqlite3 -o "$build/planted/differential-keywords"
control=0
"$build/planted/differential-keywords" > "$build/planted/keywords-log" 2>&1 || control=$?
if [ "$control" -eq 0 ] || ! grep -q '^FAIL keyword-count ' "$build/planted/keywords-log"; then
    echo "control: the planted count was not caught"
    exit 1
fi
echo "control: planted count caught ($(grep -c '^FAIL' "$build/planted/keywords-log") failing checks)"
echo "logs=$build"
