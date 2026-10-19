#!/bin/sh
# check-access-mutation.sh - the mutation that must go red, for the access keys.
#
#     sh tests/backports/host/air2cpu/check-access-mutation.sh
#
# What it does, and why it is here rather than a note: the writer reads an argument's access from
# anywhere in its key stream, because air.read, air.write and air.read_write are BARE keys - no value
# of their own - and a reader that looked at the node's first operand only (which is where the older
# sum.ll shape puts the access) passes the older fixture and reads NO access from a real library. That
# is not a hypothetical: it is what the real modules showed, 19 arguments and 0 accesses.
#
# So the mutation is the writer that reads only the first operand, built from a SCRATCH COPY of the
# real one under .agent-work/runs/ - the checkout is never edited - and run against accesses.ll, whose
# kernels carry the three measured spellings and one argument with none. The mutant must write NO
# access where the real writer writes read-only, write-only and read-write. If the mutant ever agrees
# with the real writer, this check fails and says so, because then the check is no longer testing
# anything.
#
# What this is NOT: it does not check that the mapping is right. The mapping is the header's own
# enumerators - MTLArgument.h:214, MTLArgumentAccessReadOnly = 0, ReadWrite = 1, WriteOnly = 2, and
# :296 documents all three as "read, write, read-write" - and the real writer's mapping is read in
# fixtures/accesses.ll by run-compare below, not here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/air2cpu/access-mutation}
llvm=${LLVM:-$(brew --prefix llvm)}
rm -rf "$work"
mkdir -p "$work"

# The real writer, and the mutant: identical except that the mutant reads the access from the node's
# FIRST operand, which is the defect this check exists to keep from coming back.
cp "$root/tools/air2cpu/air2cpu.cpp" "$work/mutant.cpp"
python3 - "$work/mutant.cpp" <<'PY'
import sys
path = sys.argv[1]
source = open(path).read()
start = source.index("    // A key may be BARE")
end = source.index("        if (name == \"air.arg_name\")")
# the mutant: no key-stream scan at all, and the access read only from operand 0
source = source[:start] + '''    for (unsigned i = start; i + 1 < node->getNumOperands(); i += 2) {
        auto *key = dyn_cast<MDString>(node->getOperand(i));
        if (!key)
            continue;
        std::string name = key->getString().str();
''' + source[end:]
# and the access comes from operand 0 only
source = source.replace('''        const char *access = nullptr;''',
'''        const char *access = nullptr;
        if (metadata.access == "air.read") access = "read-only";
        else if (metadata.access == "air.write") access = "write-only";
        else if (metadata.access == "air.read_write") access = "read-write";''')
open(path, "w").write(source)
PY

# The generated source includes the call convention by a path relative to ITSELF, so a mutant that
# lives outside the tree needs the header at the same relative place. Copied, not symlinked: the run
# directory is wiped and a symlink into the checkout would outlive it.
mkdir -p "$work/../../packages/a/apple-backports"
cp "$root/packages/a/apple-backports/air2cpu-abi.h" "$work/../../packages/a/apple-backports/air2cpu-abi.h"

build() {
    "$llvm/bin/clang++" -std=c++17 "-DCHAIR_AIR2CPU_ABI=\"$root/packages/a/apple-backports/air2cpu-abi.h\"" \
        $($llvm/bin/llvm-config --cxxflags | sed 's/-fno-exceptions//') \
        "$1" -o "$2" $($llvm/bin/llvm-config --ldflags --libs core irreader bitreader support) \
        -Wl,-rpath,"$llvm/lib" 2>"$3"
}
build "$root/tools/air2cpu/air2cpu.cpp" "$work/real" "$work/real.build" || {
    echo "the real writer does not build:"; cat "$work/real.build"; exit 1; }
build "$work/mutant.cpp" "$work/mutant" "$work/mutant.build" || {
    echo "the MUTANT does not build, so it cannot go red:"; cat "$work/mutant.build"; exit 1; }

"$llvm/bin/llvm-as" "$here/fixtures/accesses.ll" -o "$work/accesses.bc"
"$work/real" "$work/accesses.bc" "$work/real.c" "$work/real.plist" >"$work/real.out" 2>&1 || true
"$work/mutant" "$work/accesses.bc" "$work/mutant.c" "$work/mutant.plist" >"$work/mutant.out" 2>&1 || true

accesses() { grep -A1 '<key>access</key>' "$1" 2>/dev/null | grep -c '<string>' || true; }
real_count=$(accesses "$work/real.plist")
mutant_count=$(accesses "$work/mutant.plist")
echo "accesses written by the real writer:   $real_count"
echo "accesses written by the mutant:       $mutant_count"
if [ "$real_count" -eq 0 ]; then
    echo "FAIL: the real writer wrote no access at all, so there is nothing to protect."
    exit 1
fi
if [ "$mutant_count" -ne 0 ]; then
    echo "FAIL: the mutant wrote $mutant_count access(es) where the real writer writes $real_count."
    echo "      The mutation no longer fails, so this check is no longer testing anything."
    exit 1
fi
echo "PASS: the mutant is RED. It reads only the first operand and misses every bare access key,"
echo "      which is the defect this check keeps from coming back."
