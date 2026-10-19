#!/bin/sh
# run.sh - the HomeKit checks that run on this machine, in the shape hapcrypto's is.
#
# There is no HomeKit framework in any macOS SDK here, and the SDK's own HomeKit types are marked
# API_UNAVAILABLE(macos), so nothing of the model compiles for this host and there is no host to compare
# with. Two checks run instead, and what each is worth is said:
#
#   1. ast_check.py - the CONTRACT, from the 26.2 SDK's own headers: for every class the piece carries,
#      every property the header declares exists in the port with the same type, the same nullability and
#      the same attributes, each comparison naming the header line it came from. Derived from the header
#      rather than hand-written, and it carries a control: a scratch copy with an attribute flipped must be
#      caught, or the check is not a check.
#
#   2. oracle.py - a STRUCTURAL oracle: selector presence per class in the 12.0 and 16.0 arm64 caches,
#      counted with a boundary and with a positive and a negative control. This dates a NAME's first
#      appearance and is NOT a behaviour oracle; nothing is concluded about behaviour from it.
#
# What is NOT here is the runtime half - whether the library answers what the header declares. That needs
# an armv7 emulator, which is a heavy job to be run when a slot is free, and it is recorded in
# coordination/crutches.md as the native fix.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
charon=${CHARON:-$here/../../../..}
# absolute, because anything resolved against a build directory rather than the working directory
charon=$(cd "$charon" && pwd)

status=0
python3 "$here/ast_check.py" || status=1
python3 "$here/oracle.py" || status=1
exit $status
