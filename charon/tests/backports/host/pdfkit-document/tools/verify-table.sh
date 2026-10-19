#!/bin/sh
# Is the -string table in facts/PDFKit/Document11.md the table these tools produce?
#
#   sh tests/backports/host/pdfkit-document/tools/verify-table.sh
#
# It regenerates the twenty-two fixtures, asks the HOST's -[PDFPage string] for each, builds the table
# the facts file claims, and diffs the two.  A difference is printed and exits 1 - including a row that
# is in the file and not produced, and a row produced and not in the file, which is how two of the
# twenty-two went missing once: the tools built four fixtures and the table listed twenty-two rows.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../../.." && pwd)
facts=${FACTS_FILE:-$tree/packages/a/apple-backports/facts/PDFKit/Document11.md}
build=${BUILD:-$tree/.agent-work/runs/pdfkit-table}
mkdir -p "$build/fixtures"

xmake l "$here/make-text-fixtures.lua" "$build/fixtures" > "$build/generated.tsv"
xcrun clang -fobjc-arc -Wall "$here/host-string.m" -framework Foundation -framework PDFKit \
    -o "$build/host-string" 2> "$build/build.log" || {
    echo "BUILD the host reader did not compile:"; head -6 "$build/build.log" | sed 's/^/    /'; exit 1; }
"$build/host-string" "$build"/fixtures/*.pdf | sort > "$build/asked.tsv"
sort "$build/generated.tsv" | cut -f1,2 > "$build/streams.tsv"

# the table as the facts file states it: the markdown rows are split on the bars and the backticks
# stripped, because a sed pattern over three backticked columns is one more way to match nothing and
# call it a check - which is what the first version of this line did: it extracted ZERO rows and the
# row-count guard fired, which is the guard working, but only after a wrong extractor.
# NOTE the missing s/\\n/…/: an earlier version converted the table's two-character \n into a real
# newline before comparing, which split the three rows that carry one into a second line beginning
# "beta" - and those three were the "25 rows" the row-count guard reported.  Both sides already hold
# the literal two characters, so nothing needs converting and nothing should.
awk -F'|' '/^\| (kern-|td-|op-|size-)/ {
    gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $3); gsub(/^[ \t]+|[ \t]+$/, "", $4)
    gsub(/`/, "", $3); gsub(/`/, "", $4)
    print $2 "\t" $3 "\t" $4
}' "$facts" | sort > "$build/claimed.tsv"

joined=$(awk -F'\t' 'NR==FNR{s[$1]=$2; next} {print $1 "\t" s[$1] "\t" $2}' \
    "$build/streams.tsv" "$build/asked.tsv" | sort)
printf '%s\n' "$joined" > "$build/produced.tsv"

produced_rows=$(wc -l < "$build/produced.tsv" | tr -d ' ')
claimed_rows=$(wc -l < "$build/claimed.tsv" | tr -d ' ')
echo "  produced $produced_rows rows, the facts file claims $claimed_rows"
if [ "$produced_rows" -ne "$claimed_rows" ]; then
    echo "  the row counts differ, so the table is not what these tools produce"
    diff "$build/claimed.tsv" "$build/produced.tsv" | sed 's/^/    /' | head -30
    exit 1
fi
if diff -u "$build/claimed.tsv" "$build/produced.tsv" > "$build/diff.txt"; then
    echo "  the table in the facts file is exactly what these tools produce"
    exit 0
fi
echo "  the table differs from what these tools produce:"
sed 's/^/    /' "$build/diff.txt" | head -40
exit 1
