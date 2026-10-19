#!/bin/sh
# chain-commit.sh - ONE Metal 4 commit per process, EXECed, and whatever that process wrote and how it
# died recorded as they are.
#
#     sh tests/backports/host/metal-census/chain-commit.sh
#
# WHY A SEPARATE PROCESS PER FORM, and not a child of the oracle. Metal is NOT fork-safe: a process
# forked after it has created a device, a queue, an allocator and a buffer dies on a signal that says
# something about the fork and nothing about the commit. Two earlier attempts did exactly that and their
# answers are retracted in facts/Metal/CommandChain26.md. So each form gets a process of its own, created
# by exec - which is what descriptors26-samplebounds.sh does for the sample-position bounds, and for the
# same reason.
#
# WHAT IS RECORDED, AND WHAT IS NOT TOUCHED. The process's own stdout AND its stderr, byte for byte, and
# its exit status or the signal that killed it. Nothing is reformatted, summarised or completed: an earlier
# version of this family printed a line beginning "Assertion failed:" from a FIXED STRING on any signal,
# which is typing Apple's words and calling them a capture, and it is gone.
#
# The two forms are "ended" - the header's own path: allocator, queue, buffer, begin, end, commit, wait -
# and "open", begun and committed without an end, so that a reader who commits a buffer they forgot to
# end can see which question Metal answers. The allocator is a local in the child that outlives the commit
# and is read after it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/chain-commit}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -f "$work/chain-commit"
mkdir -p "$work"

# macOS 26.0: the release that declares Metal 4, and the honest target for a case about it.
xcrun clang -target arm64-apple-macos26.0 -isysroot "$(xcrun --show-sdk-path --sdk macosx)" \
    -fobjc-arc -Wno-unguarded-availability -O0 -o "$work/chain-commit" "$here/chain-commit.m" \
    -framework Foundation -framework Metal || {
    echo "RUN FAILED  the commit case does not build" >&2
    exit 1
}

one_form() {   # $1 the form
    printf '\n===== form %s =====\n' "$1"
    # BOTH STREAMS GO TO ONE FILE, and the file is printed UNCHANGED afterwards. Redirecting them
    # together is what makes the framework's own stderr part of the record rather than something this
    # script has to summarise.
    set +e
    "$work/chain-commit" "$1" > "$work/$1.log" 2>&1
    status=$?
    set -e
    sed 's/^/  | /' "$work/$1.log"
    if [ "$status" -eq 0 ]; then
        printf '  the process exited 0\n'
    elif [ "$status" -gt 128 ]; then
        printf '  the process was killed by signal %d\n' "$((status - 128))"
    else
        printf '  the process exited %d\n' "$status"
    fi
    # AND THE ANSWER IS LEFT WHERE A READER CAN FIND IT: the log is the record.
    printf '  the whole of that process, its stderr included, is in %s\n' "$work/$1.log"
}

echo "one Metal 4 commit per process, each EXECed, each recorded whole:"
one_form ended
one_form open
echo
echo "chain-commit: both forms are recorded above; the harness does not interpret them"
# THE LOGS ARE THE EVIDENCE and they are kept.
