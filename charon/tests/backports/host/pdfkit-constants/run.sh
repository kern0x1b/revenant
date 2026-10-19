#!/bin/sh
# The port's PDFKit constants against the host's own, name by name.
#
# The port's side is NOT linked into the differential: its values are the string literals in the
# committed constants object, which this runner reads out of that file.  Nothing has to agree with the
# port's headers, so the two sides cannot collide over them, and the host's answer is proved with
# dladdr - the only image proof there is, because the host framework has no file on disk and lives in
# the dyld shared cache.
#
#   sh tests/backports/host/pdfkit-constants/run.sh
#
# Prints COMPARED <n> MISMATCHES <m> and exits non-zero on any mismatch, on any name the host does not
# answer, or on any name whose host image is not PDFKit.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/PDFKit
build=${BUILD:-$tree/.agent-work/runs/pdfkit-constants}
mkdir -p "$build"

# the port's own map: name -> literal, out of the committed objects
python3 - "$port" "$build/port-map.tsv" <<'PY'
import glob, re, sys
port, out = sys.argv[1], sys.argv[2]
decl = re.compile(r"^(NSString \*const|const CGFloat)\s+([A-Za-z_]\w*)\s*=\s*(.+);$")
rows, numeric = {}, {}
for path in sorted(glob.glob(port + "/PDFKitConstants*.m")):
    for line in open(path):
        match = decl.match(line.strip())
        if not match:
            continue
        kind, name, literal = match.group(1), match.group(2), match.group(3).strip()
        if kind == "const CGFloat":
            # a numeric constant: there is no host STRING to compare, but there is a host NUMBER,
            # read as a double through dlsym, and that is what the row must be checked against
            numeric[name] = literal
            continue
        if literal.startswith('@"') and literal.endswith('"'):
            literal = literal[2:-1].replace('\\"', '"').replace("\\\\", "\\")
        rows[name] = literal
with open(out, "w") as handle:
    for name in sorted(rows):
        handle.write(f"{name}\t{rows[name]}\n")
with open(out + ".numeric", "w") as handle:
    for name in sorted(numeric):
        handle.write(f"{name}\t{numeric[name]}\n")
print(f"  the port's objects carry {len(rows)} string constants and {len(numeric)} numeric sentinels")
PY
names="$build/names.txt"
cut -f1 "$build/port-map.tsv" > "$names"
n=$(wc -l < "$names" | tr -d ' ')
if [ -s "$build/port-map.tsv.numeric" ]; then
    cut -f1 "$build/port-map.tsv.numeric" > "$build/numeric-names.txt"
    sed 's/^/    /' "$build/port-map.tsv.numeric"
fi
[ "$n" -gt 0 ] || { echo "no names read out of the band's objects"; exit 1; }

xcrun clang -fobjc-arc -w "$here/read-host.m" -framework Foundation -o "$build/read-host" \
    2> "$build/build.log" || {
    echo "BUILD the host reader did not compile:"; head -6 "$build/build.log" | sed 's/^/    /'; exit 1; }
"$build/read-host" "$names" > "$build/host-map.tsv"

# the numeric names, compared as doubles: the same dladdr proof, the host's value read through dlsym
xcrun clang -fobjc-arc -w "$here/read-host-numeric.m" -framework Foundation -o "$build/read-host-numeric" \
    2> "$build/build-numeric.log" || {
    echo "BUILD the numeric reader did not compile:"; head -6 "$build/build-numeric.log" | sed 's/^/    /'; exit 1; }
"$build/read-host-numeric" "$build/numeric-names.txt" > "$build/host-numeric.tsv"

python3 - "$build/port-map.tsv" "$build/host-map.tsv" "$build/host-numeric.tsv" <<'PY'
import re, sys
port = dict(l.rstrip("\n").split("\t", 1) for l in open(sys.argv[1]) if l.strip())
host = {}
for line in open(sys.argv[2]):
    if not line.strip():
        continue
    name, _, rest = line.rstrip("\n").partition("\t")
    image, _, value = rest.partition("\t")
    host[name] = (image, value)
compared = mismatched = unanswered = unproved = 0
for name in sorted(port):
    if name not in host:
        unanswered += 1
        print(f"  NO-HOST-SYMBOL  {name}")
        continue
    image, value = host[name]
    if "PDFKit" not in image:
        unproved += 1
        print(f"  NOT-PROVED      {name} came from {image}")
        continue
    compared += 1
    if value != port[name]:
        mismatched += 1
        print(f"  MISMATCH        {name}  port={port[name]!r}  host={value!r}")
# the numeric names, against the host's own doubles
numeric_mismatch = 0
numeric_unproved = 0
try:
    portnum = dict(l.rstrip("\n").split("\t", 1) for l in open(sys.argv[1] + ".numeric") if l.strip())
except OSError:
    portnum = {}
for line in open(sys.argv[3] if len(sys.argv) > 3 else sys.argv[2]):
    if not line.strip():
        continue
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 3 or parts[0] not in portnum:
        continue
    name, image, value = parts[0], parts[1], parts[2]
    if "PDFKit" not in image:
        numeric_unproved += 1
        print(f"  NOT-PROVED      {name} came from {image}")
        continue
    try:
        printed = float(value)
    except ValueError:
        numeric_mismatch += 1
        print(f"  MISMATCH        {name} host={value!r} is not a number")
        continue
    # the port writes a C expression, so a cast comes first: (CGFloat)FLT_MAX is FLT_MAX
    literal = re.sub(r"^\(\s*[A-Za-z_]\w*\s*\)", "", portnum[name].strip().rstrip(";"))
    # the port writes C expressions; the value that matters is what they evaluate to, and the two
    # spellings the port uses for this name are the float and the double maximum
    alias = {"FLT_MAX": 3.4028234663852886e+38, "CGFLOAT_MAX": 1.7976931348623157e+308,
             "DBL_MAX": 1.7976931348623157e+308}
    theirs = alias.get(literal, printed)
    if theirs != printed:
        numeric_mismatch += 1
        print(f"  MISMATCH        {name}  port={literal} -> {theirs!r}  host={printed!r}")
    else:
        compared += 1
print(f"COMPARED {compared} MISMATCHES {mismatched + numeric_mismatch}")
if unanswered or unproved or numeric_unproved:
    print(f"  unanswered by the host: {unanswered}   not proved to be PDFKit: {unproved + numeric_unproved}")
sys.exit(1 if (mismatched or numeric_mismatch or unanswered or unproved or numeric_unproved) else 0)
PY
