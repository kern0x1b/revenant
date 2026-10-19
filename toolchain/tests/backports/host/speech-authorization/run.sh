#!/bin/sh
# The host's answers for the speech recognizer before a permission is requested (facts/Speech/Authorization.md).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${SPEECH_AUTH_BUILD:-$(runs_folder revenant-speech-authorization-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/speech.m" \
    -framework Foundation -framework Speech -o "$build/speech"
"$build/speech" > "$build/log" 2>&1
diff "$here/expected.txt" "$build/log"
echo "speech authorization: host answers match expected.txt"
