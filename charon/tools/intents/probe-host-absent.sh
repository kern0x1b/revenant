#!/bin/sh
# probe-host-absent.sh - what the host's own Intents answers for the rows a registry file does not
# carry, beside a control of the rows it does.
#
#   probe-host-absent.m   the probe: one line per row, asked of /System/Library/Frameworks
#                         /Intents.framework, the framework Siri and Shortcuts are built on
#   <this runner>         the rows, read out of a registry file together with the kind and the file
#                         the registry itself gives each, and the control the reader is certified by
#
# Why a control and not just the zeros. A row's claim is about the release, and the release that
# carries Intents is the system's own framework - so a run that saw nothing would report every row
# as absent and mean nothing. The implemented rows of the same file are therefore probed in the
# same process and tallied in the same process, and the digest prints both numbers: a reader that
# found `control` of them saw the framework, and a zero on a row beside a non-zero control is the
# release's answer and not the reader's.
#
# The macOS SDK is the one to bind, and the reason is measured (tests/backports/callgen/README.md,
# 2026-09-27): a Mac Catalyst binary binds the Command Line Tools' MacOSX.sdk/System/iOSSupport,
# which carries IntentsUI and **not** Intents, so a Catalyst run cannot be the oracle for this
# framework. What the macOS run does not carry is the iOS-only classes, and the digest's per-file
# found count says how many, so a reader can tell a class the release does not have from a reader
# that was blind.
#
# Usage:
#   sh tools/intents/probe-host-absent.sh [registry-file ...]   default: this framework's files
#
# Environment:
#   OUT       the digest to write, default $WORK/probe.log
#   WORK      the scratch directory, default $(mktemp -d)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
files=${*:-$root/packages/a/apple-backports/registry/Intents/*.json}
work=${WORK:-$(mktemp -d)}
out=${OUT:-$work/probe.log}
rows=$work/rows.txt
mkdir -p "$work"
: > "$rows"

sdk=$(xcrun --show-sdk-path)
xcrun clang -target arm64-apple-macos14.0 -isysroot "$sdk" \
    -fobjc-arc -Wall -Wno-unused-function \
    "$here/probe-host-absent.m" -framework Foundation -framework Intents \
    -o "$work/probe" 2>"$work/build.log" || {
        echo "the probe did not build; $work/build.log says why" >&2
        tail -20 "$work/build.log" >&2
        exit 1
    }

# The rows, with the file and the kind the registry itself gives each, the absent ones of a file
# first and its whole implemented set after: one process, one tally, and the two numbers the
# digest prints are the two halves of it.
for file in $files; do
    python3 - "$file" >> "$rows" <<'PY'
import json, sys
document = json.load(open(sys.argv[1]))
# A registry file of this framework holds its entries under "entries"; anything else in the
# directory (the constants file) is not one, and the runner passes over it rather than reading
# nothing and printing a tally that looks like a result.
if isinstance(document, dict) and "entries" not in document:
    sys.exit(0)
entries = document["entries"] if isinstance(document, dict) else document
name = sys.argv[1].rsplit("/", 1)[-1]
for absent, kind, api in sorted(((e.get("status") == "absent", e["kind"], e["api"]) for e in entries),
                                key=lambda row: (not row[0], row[2])):
    print("%s\t%s\t%s\t%s" % (name, "absent" if absent else "control", kind, api))
PY
done

# Three tab-separated fields for the probe - file, kind, api - out of the four rows.txt keeps, so
# the tally columns stay out of the argument and nothing has to be quoted past a shell.
awk -F'\t' '{ printf "%s\t%s\t%s\n", $1, $3, $4 }' "$rows" | tr '\n' '\0' \
    | xargs -0 "$work/probe" > "$out"

absent=$(awk -F'\t' '$2 == "absent"' "$rows" | wc -l | tr -d ' ')
control=$(awk -F'\t' '$2 == "control"' "$rows" | wc -l | tr -d ' ')
{
    echo "# absent rows: $absent, control rows: $control implemented rows of the same files"
    cat "$out"
} > "$out.new"
mv "$out.new" "$out"
echo "probe digest: $out"
tail -1 "$out"
