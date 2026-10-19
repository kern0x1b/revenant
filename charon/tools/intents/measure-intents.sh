#!/bin/sh
# The release each Intents class symbol first appears exporting, walked the real armv7 cache
# ladder with the same modules/apple/dyld.lua the build measures with.
#
# The band machinery places an object by the release its exported API arrived in
# (modules/apple/backports.lua's introduced_in -> dyld.first_releases) and not by the
# availability annotation the SDK's header carries, so the object files of this package are
# grouped by what this measures. On the framework's own 136 classes it corrects the header once:
# INPaymentStatusResolutionResult is exported by iOS 10.3 and the header says 10.0.
#
# Usage: sh tools/intents/measure-intents.sh <classes> <sdkdir> <output> [modules]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
modules=${5:-$(cd "$here/../../.." && pwd)/modules}
script=$(mktemp "${TMPDIR:-/tmp}/charon-intents-measure.XXXXXX.lua")
cp "$here/measure-intents.lua" "$script"
trap 'rm -f "$script"' EXIT
exec xmake lua "$script" "$1" "$2" "$3" "$modules"
