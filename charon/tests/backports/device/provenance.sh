#!/bin/sh
# provenance.sh — prove that a binary in the emulator image is the build this worktree made.
#
# The failure this is for is a stale install, and the method is the one in
# coordination/reviews/2026-09-28-install-stale.md: a Mach-O carries an LC_UUID that is its build's,
# two real builds differ in it, and a *copy* of one build keeps that build's — so the UUID is a
# provenance check and not a size. `otool -l` is the reader, because the byte order of a uuid line
# belongs to otool and not to a reader that parses the load command itself.
#
#   provenance.sh uuid <binary>                       print the LC_UUID
#   provenance.sh same <expected> <got>              pass when the two are one build
#   provenance.sh prefix <expected> <got>            pass when the bytes up to LC_CODE_SIGNATURE match
#   provenance.sh check <expected> <got>             both, which is what a run should use
#
# The prefix check is the stronger of the two and the UUID check is the one that survives a strip: it
# compares everything the linker wrote before the code signature, so a binary that is byte-for-byte
# the build is the build, and a UUID is kept by a copy and changed by a rebuild (measured in the
# review: `strip` and a signature leave it alone).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
otool=${OTOOL:-otool}

macho_uuid() {
    # the uuid line of the LC_UUID load command, upper case, no dashes: two builds never share one,
    # and a copy of a build keeps it
    "$otool" -l "$1" 2>/dev/null | awk '
        /^ *cmd LC_UUID$/ { want = 1; next }
        want && $1 == "uuid" { print $2; exit }
    ' | tr -d '-' | tr 'a-f' 'A-F'
}

# the bytes up to the code signature: everything the linker wrote, and nothing that a later sign or
# copy may touch
macho_prefix() {
    python3 - "$1" "$2" <<'PY'
import struct, sys

def load_commands(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] not in (b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
        sys.exit("provenance.sh: %s is not a Mach-O" % path)
    little = data[:4] in (b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe")
    endian = "<" if little else ">"
    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack_from(endian + "IiiIIII", data, 0)
    at = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from(endian + "II", data, at)
        if cmd == 0x1D:  # LC_CODE_SIGNATURE
            return data[:at]
        at += cmdsize
    return data[:at]

a, b = load_commands(sys.argv[1]), load_commands(sys.argv[2])
print(len(a), len(b), "same" if a == b else "differ")
PY
}

case "${1:-}" in
uuid)
    [ -n "${2:-}" ] || { echo "usage: provenance.sh uuid <binary>"; exit 2; }
    got=$(macho_uuid "$2")
    [ -n "$got" ] || { echo "provenance.sh: $2 carries no LC_UUID"; exit 1; }
    echo "$got"
    ;;
same)
    [ -n "${3:-}" ] || { echo "usage: provenance.sh same <expected> <got>"; exit 2; }
    wanted=$(macho_uuid "$2"); got=$(macho_uuid "$3")
    if [ "$wanted" = "$got" ] && [ -n "$wanted" ]; then
        echo "provenance: same build, LC_UUID $wanted"
    else
        echo "provenance: NOT the same build - $3 carries ${got:-no LC_UUID}, $2 carries ${wanted:-no LC_UUID}"
        exit 1
    fi
    ;;
prefix)
    [ -n "${3:-}" ] || { echo "usage: provenance.sh prefix <expected> <got>"; exit 2; }
    result=$(macho_prefix "$2" "$3")
    case "$result" in
        *same) echo "provenance: the bytes up to LC_CODE_SIGNATURE match ($result)" ;;
        *) echo "provenance: the bytes up to LC_CODE_SIGNATURE differ ($result)"; exit 1 ;;
    esac
    ;;
check)
    [ -n "${3:-}" ] || { echo "usage: provenance.sh check <expected> <got>"; exit 2; }
    "$here/provenance.sh" same "$2" "$3"
    "$here/provenance.sh" prefix "$2" "$3"
    echo "provenance: OK - $3 is the build of $2"
    ;;
*)
    echo "usage: provenance.sh uuid <binary> | same <expected> <got> | prefix <expected> <got> | check <expected> <got>"
    exit 2
    ;;
esac
