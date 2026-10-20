#!/bin/sh
# run.sh - the -init and +new rows of the carried ARKit and SensorKit classes (rows.inc, 63 of them).
#
# Two halves. The host half compiles check.m against the Catalyst copies of ARKit and SensorKit: for each row the
# selector is answered by the superclass's own IMP and the class defines none of its own. The port half reads the
# port's sources: the row's class has an @implementation, and none of the @implementation blocks of the port's
# ARKit and SensorKit files defines the row's selector. Together they say the port's class answers the selector
# through its superclass, as the release's does. The port's objects are not compiled on the host (see check.m).

set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
repo=$(cd "$here/../../../.." && pwd)
runs=${RUNS:-$(runs_folder arkit-nsobject-init)}
rm -rf "$runs"
mkdir -p "$runs"

sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
target="-target $(uname -m)-apple-ios14.0-macabi"
xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" -I "$here" \
    "$here/check.m" -framework Foundation -framework ARKit -framework SensorKit -o "$runs/check"
"$runs/check" | tee "$runs/host.txt"
grep -q '^VERDICT ok' "$runs/host.txt" || { echo "FAIL: the host half is not green"; exit 1; }

port=$repo/packages/a/apple-backports
awk -v rows="$here/rows.inc" '
  function selof(line,   s, n, t, i, out) {
    s = line; sub(/\{.*$/, "", s); sub(/;.*$/, "", s); gsub(/\([^)]*\)/, "", s); sub(/^[-+] */, "", s)
    n = split(s, t, " "); out = ""
    for (i = 1; i <= n; i++)
      if (index(t[i], ":") > 0) out = out substr(t[i], 1, index(t[i], ":"))
      else if (i == 1) out = t[i]
    return out
  }
  BEGIN {
    while ((getline line < rows) > 0)
      if (line ~ /^    \{"/) {
        split(line, f, "\"")
        kind = (f[3] ~ /1/) ? "+" : "-"
        want[f[2] "|" kind "|" f[4]] = 1
        classes[f[2]] = 1
        nrows++
      }
  }
  /^@implementation / { cur = $2; if (cur in classes) present[cur] = 1 }
  /^@end/ { cur = "" }
  /^[-+] \(/ && cur in classes {
    key = cur "|" substr($0, 1, 1) "|" selof($0)
    if (key in want) { print "  defined in port: " FILENAME ": " key; defined++ }
  }
  END {
    missing = 0
    for (c in classes) if (!(c in present)) { print "  no @implementation in the port: " c; missing++ }
    printf "port: %d rows, %d classes, %d definitions of the row selectors, %d classes missing\n", nrows, length(classes), defined + 0, missing
    print (defined == 0 && missing == 0) ? "VERDICT port ok" : "VERDICT port FAIL"
  }
' "$port"/ARKit/*.m "$port"/SensorKit/*.m | tee "$runs/port.txt"
grep -q '^VERDICT port ok' "$runs/port.txt" || { echo "FAIL: the port half is not green"; exit 1; }
echo "ok the 63 rows: the release answers each selector through its superclass, and the port defines none of them"
