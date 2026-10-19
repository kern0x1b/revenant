#!/bin/sh
# disasm.sh's modes and its branch arithmetic, checked on the release's own bytes and on three
# encodings the ARM architecture fixes, so a reading taken out of a real cache can be trusted to be the
# instruction it claims to be.
#
#   CHARON_ROOT=<worktree> sh tools/corpus/disasm-test.sh
#
# Why a self-test at all: the tool exists to turn bytes into instructions, and the way it can be wrong
# without anyone noticing is to read a window in the wrong mode. That is not a warning here, it is
# plausible nonsense: the same twelve bytes at 0x392bbe6c read as Thumb print `stm r0!, {r2}` and
# `b #-1218`, because the first halfword 0xc004 is itself a valid 16-bit Thumb opcode, and read as ARM
# they are the __picsymbolstub4 stub's own three instructions. Which one is true is the low bit of the
# address, and that is what the tool reads.
#
# The controls, and what each one is:
#
#   1. 0x392bbe6c, the 6.1.3 armv7 cache's libdispatch __picsymbolstub4 for `_dispatch_release`. Even,
#      so ARM: ldr r12,[pc,#4] / add r12,pc,r12 / ldr pc,[r12]. The coordinator measured these three out
#      of this cache before the tool read the low bit at all.
#   2. 0x392a238c, the same cache's libdispatch __text. Odd, so Thumb: push {r4, r7, lr} / movw / add,
#      from the release's own bytes.
#   3. 0x38e883a2, the same cache's libobjc `_object_dispose`: `bl #-758` whose target the cache's own
#      export trie names `_objc_destructInstance`. This is the arithmetic, not the decode: the number
#      the tool prints has to be the release's address of a symbol the release itself exports, or the
#      mode rule above would be right and every branch target still wrong.
#   4. 0x18e177b58, the 16.0 arm64e cache's libdispatch: `b #-32` back to an instruction in the same
#      window. On A64 the printed value is already the byte offset from the instruction's address, so
#      the bias is 0 and not the 4 the armv7 modes need.
#
# and three encodings the architecture fixes, which need no cache:
#
#   00 b5    push {r7, lr}          the Thumb-1 prologue: halfword 0xb500, so the bytes are 00 b5.
#                                   A Thumb window is asked for with its low bit set, because that is
#                                   what tells the tool the code is Thumb - the same way the release's
#                                   own function-starts table says so.
#   70 47    bx lr                  halfword 0x4770
#   00 bf    nop                    halfword 0xbf00
#   1f 20 03 d5  nop                the A64 encoding of `nop`, the architecture's own answer
#   00 00 00 14  b #0               a branch to itself: target = its own address, which is the bias 0
#
# The A64 nop is here because the first version of this file used 1e ff 2f e1, which is the *ARM* NOP
# encoding and not an A64 instruction at all: assembled as arm64e it disassembles to `<unknown>`, and a
# control that prints `<unknown>` cannot tell a broken reader from a wrong control.

set -e

if [ -z "$CHARON_ROOT" ]; then
    echo "usage: CHARON_ROOT=<worktree> sh tools/corpus/disasm-test.sh" >&2
    exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
CHARON_ROOT=${CHARON_ROOT:-$root}
scratch=$CHARON_ROOT/.agent-work/runs/disasm-test
mkdir -p "$scratch"

checks=0
failures=0

# expect NAME HAYSTACK NEEDLE -- a substring, so a mnemonic can be looked for without pinning the
# register allocation llvm-mc chooses for an alias.
expect() {
    checks=$((checks + 1))
    case $2 in
        *"$3"*) ;;
        *) failures=$((failures + 1)); printf 'FAIL  %s: no %s in:\n%s\n' "$1" "$3" "$2" ;;
    esac
}

refuse() {
    checks=$((checks + 1))
    case $2 in
        *"$3"*) failures=$((failures + 1)); printf 'FAIL  %s: found %s, which must not be there:\n%s\n' "$1" "$3" "$2" ;;
        *) ;;
    esac
}

# --- the Thumb-1 encodings above, on bytes of this file's own.
printf '00b5704700bf' > "$scratch/thumb.hex"
out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/thumb.hex" - 1 7 armv7)
expect "thumb: push" "$out" "push"
expect "thumb: bx lr" "$out" "bx"
expect "thumb: nop" "$out" "nop"
expect "thumb: the mode is the address's low bit" "$out" "mode thumb"
refuse "thumb: not read as ARM" "$out" "stm"
refuse "thumb: nothing decoded at all" "$out" "<unknown>"
# A lo that is not zero, so the number printed is the release's address and not an offset into a block
# that sits at 0. lo is HEX, as disasm.sh reads it, so 1000 is 0x1000 and the second halfword is 0x1002.
printf '00b57047' > "$scratch/thumb2.hex"
out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/thumb2.hex" - 1001 1005 armv7)
expect "thumb: the address is the release's, low bit and all" "$out" "0x1002"

# --- the arm64e encodings: the A64 nop, and a branch to itself, which is the bias 0.
printf '1f2003d500000014' > "$scratch/arm.hex"
out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/arm.hex" - 1000 1008 arm64e)
expect "arm64e: still decodes" "$out" "nop"
expect "arm64e: the mode is named, not arm or thumb" "$out" "mode arm64e"
expect "arm64e: a branch to itself is its own address" "$out" "branch target 0x1004"
refuse "arm64e: nothing decoded at all" "$out" "<unknown>"
refuse "arm64e: not marked as thumb" "$out" "push"

# --- the release's own bytes. Meaningless without that cache, so they are skipped, loudly, when it is
# not held; the synthetic checks above are the ones that must hold anywhere.
armv7=${DISASM_TEST_ARMv7_CACHE:-$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7}
arm64e=${DISASM_TEST_ARM64E_CACHE:-$HOME/.charon/dyld/16.0/dyld_shared_cache_arm64e}
if [ -f "$armv7" ]; then
    # 1. the __picsymbolstub4: an even address is ARM, and these three instructions are the stub's own.
    out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "$armv7" libdispatch 392bbe6c 392bbe7c armv7 2>&1)
    expect "armv7 stub: an even address is ARM" "$out" "mode arm"
    expect "armv7 stub: ldr r12, [pc, #4]" "$out" "ldr	r12, [pc, #4]"
    expect "armv7 stub: add r12, pc, r12" "$out" "add	r12, pc, r12"
    expect "armv7 stub: ldr pc, [r12]" "$out" "ldr	pc, [r12]"
    refuse "armv7 stub: not decoded at all" "$out" "<unknown>"
    refuse "armv7 stub: not read as Thumb" "$out" "stmdb"

    # 2. the same cache's __text: an odd address is Thumb, and these are the release's own bytes.
    out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "$armv7" libdispatch 392a238d 392a239c armv7 2>&1)
    expect "armv7 text: an odd address is Thumb" "$out" "mode thumb"
    expect "armv7 text: push {r4, r7, lr}" "$out" "push	{r4, r7, lr}"
    expect "armv7 text: the 32-bit movw that follows" "$out" "movw"
    expect "armv7 text: and the add after it" "$out" "add	r7, sp, #4"
    refuse "armv7 text: nothing decoded" "$out" "<unknown>"

    # 3. the arithmetic, against a name the release's own export trie carries: libobjc's
    # _object_dispose does `bl #-758` and the target is _objc_destructInstance.
    out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "$armv7" libobjc 38e88399 38e883b1 armv7 2>&1)
    expect "armv7 bl: the target is the release's address" "$out" "branch target 0x38e880b0"
    named=$(CHARON_ROOT="$CHARON_ROOT" xmake l "$here/probe-arch.lua" "$armv7" libobjc 2>&1 |
        awk -F'\t' '$1 == "0x38e880b1" {print $2; exit}')
    expect "armv7 bl: and the release names that address" "${named:-<probe-arch named nothing>}" \
        "_objc_destructInstance"
else
    echo "note  DISASM_TEST_ARMv7_CACHE is not held, so the release's own armv7 bytes were not read"
fi

if [ -f "$arm64e" ]; then
    # 4. on arm64e the printed offset is already measured from the instruction, so the bias is 0: this
    # branch goes back to an instruction in its own window.
    out=$(CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "$arm64e" libdispatch 18e177b38 18e177b5c arm64e 2>&1)
    expect "arm64e: the bias is 0, the branch lands on its own instruction" "$out" "branch target 0x18e177b38"
    expect "arm64e: and that address is a printed instruction" "$out" "0x18e177b38:"
else
    echo "note  DISASM_TEST_ARM64E_CACHE is not held, so the release's own arm64e branch was not read"
fi

# --- a window whose length and the reader's answer must agree, so an empty answer is not a function
# with no instructions in it.
printf '00b5' > "$scratch/short.hex"
if CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/short.hex" - 0 4 armv7 > /dev/null 2>&1; then
    failures=$((failures + 1))
    checks=$((checks + 1))
    echo "FAIL  a two-byte file read as a four-byte window was accepted"
else
    checks=$((checks + 1))
fi

# --- an odd address on an arm64e cache is refused rather than quietly rounded down: there is no Thumb
# there, and clearing the bit would hand back a window one byte off the one that was asked for.
if CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/arm.hex" - 1001 1009 arm64e > /dev/null 2>&1; then
    failures=$((failures + 1))
    checks=$((checks + 1))
    echo "FAIL  an odd address on an arm64e cache was accepted"
else
    checks=$((checks + 1))
fi

# --- an unknown architecture is refused rather than assembled with the assembler's default.
if CHARON_ROOT="$CHARON_ROOT" sh "$here/disasm.sh" "@$scratch/thumb.hex" - 1 7 armv8 > /dev/null 2>&1; then
    failures=$((failures + 1))
    checks=$((checks + 1))
    echo "FAIL  an unknown architecture was accepted"
else
    checks=$((checks + 1))
fi

printf '%d checks, %d failures\n' "$checks" "$failures"
[ "$failures" -eq 0 ]