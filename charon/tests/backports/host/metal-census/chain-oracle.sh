#!/bin/sh
# chain-oracle.sh - record Apple's OWN answers for the live Metal 4 command chain, into a table.
#
#     sh tests/backports/host/metal-census/chain-oracle.sh > tests/backports/host/metal-census/chain-expectations.txt
#
# WHY A SCRIPT THAT WRITES A FILE IN THE TREE. The port's chain is verified on a DEVICE, where Apple's
# framework does not exist, so the answers it is checked against have to be captured HERE and committed.
# That makes the oracle a table in the repository rather than a claim in a commit message, and it means
# the table can be regenerated and diffed: if a future SDK changes an answer, `git diff` on the table is
# the change, and a reviewer reads the diff rather than taking the numbers on trust.
#
# EVERY SELECTOR BELOW IS SPELLED AS THE 26.2 HEADERS SPELL IT, with the header line beside it, because
# the first version of this probe asked -newCommandQueueWithDescriptor: (METAL 3's factory) and sent
# -beginCommandBufferWithAllocator: to a QUEUE (it is a method of the command buffer), and drew two
# walls from its own mistakes. facts/Metal/CommandChain26.md carries the retraction.
#
# NOTHING HERE CREATES A BUFFER TO COMMIT: -[MTL4CommandQueue commit:count:] with a buffer that has
# already been ended takes Apple's own framework down, measured, so that row is recorded as not
# answerable and is not asked - asking it would lose every row above it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/chain-oracle}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -f "$work/chain-oracle"
mkdir -p "$work"

# macOS 26.0: the release that declares Metal 4, and the honest target for a case about it. At a lower
# one every Metal 4 selector is undeclared and this file could not be written at all.
xcrun clang -target arm64-apple-macos26.0 -isysroot "$(xcrun --show-sdk-path --sdk macosx)" \
    -fobjc-arc -Wno-unguarded-availability -O0 -o "$work/chain-oracle" "$here/chain-oracle.m" \
    -framework Foundation -framework Metal || {
    echo "RUN FAILED  the oracle does not build" >&2
    exit 1
}
timeout 300 "$work/chain-oracle"
status=$?
rm -f "$work/chain-oracle"
[ "$status" -eq 0 ] || { echo "FAIL: the oracle exited $status - a row it records is not answerable" >&2; exit 1; }
