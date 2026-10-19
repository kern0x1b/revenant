#!/bin/sh
# With --measure it writes values.tsv from the host's own NaturalLanguage, which is where the port's
# definitions come from; without it, it checks the port's table against the host again.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BUILD=${BUILD:-$(runs_fresh revenant-naturaltags)}
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -o "$BUILD/differential" "$here/differential.m" \
    -framework Foundation -framework NaturalLanguage -ldl
"$BUILD/differential" "$@"
