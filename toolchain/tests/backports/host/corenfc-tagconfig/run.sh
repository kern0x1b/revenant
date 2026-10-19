#!/bin/sh
# run.sh - the port's NFCTagCommandConfiguration and its two ISO15693 subclasses, against the host's
# CoreNFC through Mac Catalyst. The port's classes are built from packages/a/apple-backports/CoreNFC
# with their names prefixed, so the port's and the host's coexist in one process and every value is
# compared against what the host's own object answers (facts/CoreNFC/TagConfiguration.md).
#
# `--fail-first` is the mutation that proves the run bites: it makes the port's copyWithZone: drop the
# base's retry fields and its three-field initialiser drop the base's zero retries, so every check
# that reads a copy must then fail. The mutation is made on a COPY of the source under $build, so no
# test hook is compiled into the port's own file - the tree's other mutation (corenfc/run.sh
# --mutated) likewise leaves the port's source alone.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/CoreNFC}
harness=${TAGCONFIG_HARNESS:-$here/../../device}
# Built outside the tree, as the two neighbouring runs do: a build directory under the source
# is what a later `git add` picks up by accident (AGENTS.md, Conventions: build artifacts are
# never committed).
build=${TAGCONFIG_BUILD:-$(runs_folder revenant-corenfc-tagconfig-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
# NFCNDEFReaderSession and NFCISO15693ReaderSession are in the list because CoreNFC/NFCReaderSession.m implements them too, and a
# name left unprefixed here would collide with the host's own class of that name at load time.
classes="NFCTagCommandConfiguration NFCISO15693CustomCommandConfiguration NFCISO15693ReadMultipleBlocksConfiguration NFCReaderSession NFCNDEFReaderSession NFCISO15693ReaderSession"
renames=""
for name in $classes; do
    renames="$renames -D$name=RevenantHost$name"
done
renames="$renames -DNFCErrorDomain=RevenantHostNFCErrorDomain"
rm -rf "$build"
mkdir -p "$build"
cp "$port/NFCTagConfiguration11.m" "$build/NFCTagConfiguration11.m"
if [ "${1:-}" = "--fail-first" ]; then
    # A copy loses the base's retry fields, and a custom command configuration's three-field
    # initialiser reports one retry it was never given. Both are the sort of defect a differential
    # exists to catch, and both are made through the API the port itself uses so the mutation is a
    # change in behaviour rather than a change that fails to compile.
    sed -i '' -e 's|^    copy.maximumRetries = self.maximumRetries;$|    // MUTATED: maximumRetries dropped|' \
           -e 's|^        _customCommandCode = customCommandCode;$|        _customCommandCode = customCommandCode; self.maximumRetries = 1; // MUTATED|' \
           "$build/NFCTagConfiguration11.m"
    grep -q MUTATED "$build/NFCTagConfiguration11.m" || { echo "the mutation did not apply" >&2; exit 2; }
fi
objects=""
# The configurations under test, and the reader session the same library carries: the run checks
# that carrying a configuration grew no session, so the session the port really does carry has to be
# in the process for that check to mean anything.
xcrun clang $target -fobjc-arc -fvisibility=hidden -w $renames -I"$port" \
    -c "$build/NFCTagConfiguration11.m" -o "$build/NFCTagConfiguration11.o"
objects="$objects $build/NFCTagConfiguration11.o"
xcrun clang $target -fobjc-arc -fvisibility=hidden -w $renames \
    -I"$here/../../../../packages/a/apple-backports/Foundation" \
    -c "$here/../../../../packages/a/apple-backports/CoreNFC/NFCReaderSession.m" -o "$build/NFCReaderSession.o"
objects="$objects $build/NFCReaderSession.o"
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new \
    -I"$harness" -I"$here" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework CoreNFC -framework Foundation -o "$build/differential"
set +e
"$build/differential" > "$build/log" 2>&1
result=$?
set -e
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result