#!/bin/sh
# Disassemble one window of one image of a real dyld shared cache, at the address the release gives
# it, so a pc-relative reference (a literal, a `bl` inside the image) can be read as the address the
# release itself uses.
#
#   CHARON_ROOT=<worktree> sh tools/corpus/disasm.sh <cache> <image substring> <lo> <hi> [arch]
#
# `arch` is `armv7` (the default) or `arm64e`. It is the CACHE's architecture, not an instruction mode:
#
#   * On an `armv7` cache the mode of a window is the low bit of its own address, and that bit is the
#     release's own marker, not a convention this tool invented. A function start in the export trie
#     and in the function-starts table has bit 0 set when the code is Thumb and clear when it is ARM,
#     so `lo` is handed over as the release hands it over and the tool reads the bytes one lower and
#     prints the code's own (even) addresses:
#
#         lo odd   ->  Thumb, `-triple=thumbv7-apple-ios`, bytes from lo - 1
#         lo even  ->  ARM,   `-triple=armv7-apple-ios`,  bytes from lo
#
#     Getting this wrong is not a warning, it is plausible nonsense: the same twelve bytes at
#     0x392bbe6c of the 6.1.3 armv7 cache read as Thumb print `stm r0!, {r2}` and `b #-1218`, because
#     the first halfword 0xc004 is itself a valid 16-bit Thumb opcode, while as ARM they are the
#     `__picsymbolstub4` stub's own three instructions (`ldr r12, [pc, #4]`, `add r12, pc, r12`,
#     `ldr pc, [r12]`). Which of the two is true is the low bit, and the tool reads it rather than
#     guessing a width: no 16-vs-32-bit rule is written here.
#   * On an `arm64e` cache every instruction is four bytes and there is no Thumb, so an odd `lo` is
#     refused rather than quietly rounded down - a caller with an odd address there has a mistake and
#     hiding it would hand back a window one byte off the one it asked for.
#
# The route, and why each step is here:
#
#   * The bytes come from the project's own cache reader (skeleton-table.lua's `bytes`), never from a
#     disassembler pointed at the cache file -- a Mach-O at 0, with every segment at the wrong place,
#     decodes to something that looks like code and is not.
#   * They are disassembled by `llvm-mc --disassemble`, which takes a BYTE STREAM and decides per
#     instruction whether it is 16 or 32 bits wide. That is the whole reason it is used: Thumb-2 mixes
#     both widths, and nothing else here can decide. An assembler cannot (`error: cannot determine
#     Thumb instruction size, use inst.n/inst.w instead`), and objdump pointed at a synthetic object
#     reads it as ARM or pairs consecutive halfwords into one 32-bit instruction.
#   * `--show-encoding` puts each instruction's own bytes on its line, which is where the addresses come
#     from: llvm-mc prints no addresses, and an address is what this tool exists to produce.
#   * A branch prints an offset and the offset is relative to the instruction's own pc, which is the
#     instruction's address plus a bias that is the architecture's own: +8 on ARM (the pc reads eight
#     bytes ahead), +4 on Thumb (four), and on A64 the printed value already is the byte offset from
#     the instruction's address, so the bias is 0. The bias is printed with the mode, so a number in
#     the output can be read back into the arithmetic that made it.
#
# `<cache>` may be `@<hexfile>`, which takes the bytes from a file of hex digits instead of a cache.
# That is how tools/corpus/disasm-test.sh drives this exact path with a known instruction: a reader that
# only works on a cache cannot be given a control.
#
# Nothing is written outside the worktree's own scratch directory, and the cache is opened read only.

set -e

if [ -z "$CHARON_ROOT" ]; then
    echo "usage: CHARON_ROOT=<worktree> sh tools/corpus/disasm.sh <cache> <image> <lo> <hi> [armv7|arm64e]" >&2
    exit 2
fi
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "usage: CHARON_ROOT=<worktree> sh tools/corpus/disasm.sh <cache> <image> <lo> <hi> [armv7|arm64e]" >&2
    exit 2
fi

cache=$1
image=$2
lo=$3
hi=$4
arch=${5:-armv7}

case $arch in
    armv7|arm64e) ;;
    *) echo "disasm.sh: arch must be armv7 or arm64e, not $arch" >&2; exit 2 ;;
esac

# The mode, the triple, the pc bias and where the bytes really start. The low bit of the release's own
# address is the marker; nothing here decodes the stream to decide a width.
last=$((0x$lo % 2))
if [ "$arch" = arm64e ]; then
    if [ "$last" != 0 ]; then
        echo "disasm.sh: $lo has its low bit set, which is Thumb's marker; an arm64e cache has no Thumb" >&2
        exit 2
    fi
    mode=arm64e
    mc_triple=arm64e-apple-ios
    bias=0
    base=$((0x$lo))
else
    if [ "$last" = 1 ]; then
        mode=thumb
        mc_triple=thumbv7-apple-ios
        bias=4
        base=$((0x$lo - 1))
    else
        mode=arm
        mc_triple=armv7-apple-ios
        bias=8
        base=$((0x$lo))
    fi
fi

end=$((0x$hi - last))
size=$((end - base))
if [ "$size" -le 0 ]; then
    echo "disasm.sh: the window must be non-empty, got $lo .. $hi" >&2
    exit 2
fi

scratch=$CHARON_ROOT/.agent-work/runs/disasm
mkdir -p "$scratch"
# File names carry the address in hex, like everything else this tool prints: a decimal one reads as a
# different address from the one it holds.
tag=$(printf '%x' "$base")

# llvm-mc is resolved rather than taken from PATH, and which binary ran is printed: a caller whose PATH
# does not carry the toolchain's bin directory got "command not found" and an empty answer, which reads
# as a window with no instructions in it rather than as a missing tool.
resolve() {
    found=$(xcrun -f "$1" 2>/dev/null || true)
    if [ -z "$found" ]; then
        found=$(command -v "$1" 2>/dev/null || true)
    fi
    printf '%s' "$found"
}
mc=$(resolve llvm-mc)
if [ -z "$mc" ] || [ ! -x "$mc" ]; then
    mc=/opt/homebrew/opt/llvm/bin/llvm-mc
fi
if [ -z "$mc" ] || [ ! -x "$mc" ]; then
    echo "disasm.sh: no llvm-mc found (xcrun -f, PATH and /opt/homebrew/opt/llvm/bin all came up empty)" >&2
    exit 1
fi

raw=$scratch/bytes-$mode-$tag.txt
case $cache in
    @*) cp "${cache#@}" "$raw" ;;
    *)  xmake l "$CHARON_ROOT/tools/corpus/skeleton-table.lua" "$cache" "$image" \
            bytes "$(printf '%x' "$base")" "$size" > "$raw" ;;
esac

# The reader prints its own header lines first (`#...`); the byte lines are the rest. A run with no byte
# lines is a read that failed, and nothing would be disassembled -- which looks like a function with no
# instructions in it.
grep -v '^#' "$raw" > "$scratch/hex-$mode-$tag.txt" || true
if [ ! -s "$scratch/hex-$mode-$tag.txt" ]; then
    echo "disasm.sh: the reader returned no bytes for $(printf '%#x' "$base") in $image" >&2
    exit 1
fi

expected=$(printf '%s' "$(tr -d '\n' < "$scratch/hex-$mode-$tag.txt")" | wc -c | tr -d ' ')
if [ "$expected" != "$((size * 2))" ]; then
    echo "disasm.sh: asked for $size bytes, the reader returned $((expected / 2))" >&2
    exit 1
fi

# The byte stream as llvm-mc wants it: one 0x.. token per byte, on its standard input. Not as an argument
# - llvm-mc takes at most one positional and reads the tokens from stdin, so a stream passed as arguments
# is `Too many positional arguments specified`, and one argument is `No such file or directory`.
hex=$(tr -d ' \n' < "$scratch/hex-$mode-$tag.txt")
stream=""
i=0
while [ $i -lt ${#hex} ]; do
    stream="$stream 0x${hex:$i:2}"
    i=$((i + 2))
done

# The mode, the triple, the binary that ran, the window and the pc bias are printed with the
# instructions: a branch target in the output is only readable if the arithmetic that made it is
# beside it, and a reader cannot see the triple from the mnemonics.
printf '#%#x .. %#x   mode %s   triple %s   llvm-mc %s   branch target = address + %d + offset\n' \
    "$base" "$end" "$mode" "$mc_triple" "$mc" "$bias"

# One line per instruction, each with its own bytes, from which the address follows.
printf '%s\n' "$stream" | "$mc" --disassemble -triple="$mc_triple" --show-encoding \
    > "$scratch/mc-$mode-$tag.txt" 2>&1 || {
    echo "disasm.sh: llvm-mc ($mc) refused the window:" >&2
    cat "$scratch/mc-$mode-$tag.txt" >&2
    exit 1
}

awk -v base="$base" -v bias="$bias" '
    # macOS awk has no strtonum, so a hex number is converted here rather than by the shell.
    function hexvalue(text,   i, c, n) {
        n = 0
        for (i = 1; i <= length(text); i++) {
            c = tolower(substr(text, i, 1))
            n = n * 16 + index("0123456789abcdef", c) - 1
        }
        return n
    }
    # How wide this instruction is: the number of bytes its own encoding lists. That is where the next
    # address comes from, so nothing here decodes the stream.
    # The marker is not the same on both targets -- llvm-mc writes "@ encoding: [...]" for armv7 and
    # "; encoding: [...]" for arm64e -- so it is found by the word and the list starts at the bracket.
    function width(text,   at, count) {
        at = index(text, "encoding: [")
        if (at == 0) return 0
        count = split(substr(text, at + 11), bytes, ",")
        return count
    }
    # A branch with an immediate operand: b, bl, blx, with or without a condition code and with or
    # without the `.w` the 32-bit Thumb forms carry. bx and blx in their register forms print no
    # number, so they never reach the arithmetic. The condition codes are spelled out rather than
    # matched on two letters, because two letters would also take bic and bkpt.
    function branch(mnemonic) {
        return mnemonic ~ /^(b|bl|blx)(eq|ne|cs|hs|cc|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le|al|nv)?(\.w)?$/
    }
    /encoding: \[/ {
        here = base + offset
        line = $0
        sub(/[ \t]*[@;] encoding: \[.*/, "", line)
        printf "%#x:\t%s\n", sprintf("%#x", here), line
        # The mnemonic is the first field, not what follows the first tab: llvm-mc separates them with
        # a TAB, so stripping from the first tab leaves an empty string.
        mnemonic = $1
        # The printed offset is relative to the pc, which the architecture puts a fixed distance ahead
        # of the instruction; bias carries that distance and is printed with the mode above, so the
        # number here can be read back into the arithmetic.
        if (branch(mnemonic) && match(line, /#[-]?[0-9]+/)) {
            delta = substr(line, RSTART + 1, RLENGTH - 1) + 0
            printf "\t; branch target %#x\n", here + bias + delta
        }
        offset += width($0)
    }
' "$scratch/mc-$mode-$tag.txt"