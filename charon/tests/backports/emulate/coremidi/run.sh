#!/bin/sh
# run.sh - the CoreMIDI round trip on the emulated iPhone 4S at 6.1.3: the entry point, which runs the round trip as an
# application (run-app.sh, app/main.m and app/roundtrip.m). The release refuses a command-line process its virtual endpoints
# (-10844, facts/CoreMIDI/CoreMIDI.md), so the round trip has no command-line form and is measured only as an application.
#
# Usage: sh tests/backports/emulate/coremidi/run.sh [--minimum 6.1.3]
# The exit status and the verdict ("roundtrip: PASS") are run-app.sh's.
here=$(cd "$(dirname "$0")" && pwd)
exec sh "$here/run-app.sh" "$@"
