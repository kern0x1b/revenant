#!/bin/sh
# run.sh — two things, and both of them have to be able to fail.
#
# 1. The DEVICE side: what the system's WKWebView does for every case of device/webkit-cases.m, under Mac
#    Catalyst, written where the device test reads it, so the port over UIWebView is held to the same ones.
# 2. The HOST differentials, which are what hold the web-extension families to this machine's own WebKit:
#      - webextension.m          the 77 recorded answers of the extension, pattern, action and context families
#      - webextension-controller  the controller family, asked of the SYSTEM with no port code in the process
#                                and then asked of the PORT, with the two answers compared case by case
#      - contentrulelist          the content rule list store of iOS 11, the same shape again: the SYSTEM's
#                                answers recorded against one store directory, then the PORT asked the same
#                                questions against that same directory, which is also what holds the store's
#                                own persistence across the two processes
#
# The controller test exists because a row that says implemented has to be held to something. Neither program
# was built or run by this script before, so a wrong answer in the port could not fail anything: the
# programs are the evidence and they have to be in the loop, and the script's exit status is the whole verdict.
# Each host program is built, run, and its status taken; nothing here is allowed to pass by not running.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-webkit)}
# BUILD may come from the environment, and an environment-supplied directory does not exist yet the way
# mktemp's does; nothing here creates it, so the first link fails on a missing output path.
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
sources=${WEBEXT_SOURCES:-$here/../../../../packages/a/apple-backports/WebKit}
harness=${WEBEXT_HARNESS:-$here/../../device}
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework WebKit -framework UIKit -framework Foundation"
status=0
note() { printf '%s\n' "$*"; }
failed() { printf 'FAIL %s\n' "$*"; status=1; }

# ---------------------------------------------------------------- the device's expectations
xcrun clang $target -fobjc-arc -w -I"$device" \
    "$here/record.m" "$device/webkit-cases.m" -framework UIKit -framework WebKit -framework Foundation -o "$build/record"
(cd "$build" && ./record "$build/webkit.json" > "$build/webkit.log" 2>&1)
xmake l "$here/../../common/embed.lua" "$build/webkit.json" "$device/webkit-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/webkit_expectations/' "$device/webkit-expectations.h" && rm -f "$device/webkit-expectations.h.bak"
note "records: $(python3 -c "import json,sys; print(len(json.load(open('$build/webkit.json'))))")"

# ---------------------------------------------------------------- the extension families' 77 answers
# WEBEXT_MANIFEST must be ABSOLUTE: a relative one takes WebKit's extension loader down (exit 137) with no
# error, which is what webextension.m's own header is about. It is resolved here rather than left to the
# caller's shell so that a run from anywhere gets the same path.
manifest=$here/manifest/manifest.json
if [ ! -f "$manifest" ]; then
    failed "no manifest at $manifest: webextension.m cannot build an extension without one"
else
    xcrun clang $target -fobjc-arc -w "$here/webextension.m" $frameworks -o "$build/webextension"
    if WEBEXT_MANIFEST="$manifest" "$build/webextension" > "$build/webextension.log" 2>&1; then
        note "webextension: exit=0 cases=$(grep -c . "$build/webextension.log") log=$build/webextension.log"
    else
        result=$?
        grep -v '^ok ' "$build/webextension.log" | head -20 || true
        failed "webextension: exit=$result log=$build/webextension.log"
    fi
fi

# ---------------------------------------------------------------- the controller family, port against system
# The port is built in two passes, because renames.sh reads the classes out of the objects and the flags that
# rename them are needed to compile them. Pass one is plain -- with -DREVENANT_HOST_DIFFERENTIAL, so the port's
# own headers step aside and the host's declarations are used, which is what keeps the port's @implementation
# and the SDK's @interface from being two declarations of one name. Pass two adds the renames, and the test is
# compiled with the same flags, so the scenario's class names name the port's classes and not Apple's.
. "$here/renames.sh"
port_files="WKContentRuleList11.m WKWebExtension.m WKWebExtensionAction.m WKWebExtensionContext.m WKWebExtensionController.m WKWebExtensionMatchPattern.m"
port_headers="RevenantWebExtension.h RevenantWebExtensionController.h"
port_flags="-DREVENANT_HOST_DIFFERENTIAL=1 -fobjc-arc -fvisibility=hidden -w"
mkdir -p "$build/plain" "$build/port"
plain=""
for f in $port_files; do
    if ! xcrun clang $target $port_flags -I"$sources" -c "$sources/$f" -o "$build/plain/$f.o" 2> "$build/plain/$f.diagnostic"; then
        failed "the port's $f does not compile for the host"
        grep -m3 'error:' "$build/plain/$f.diagnostic" | sed 's|^|    |'
    fi
    plain="$plain $build/plain/$f.o"
done
rename_inputs=""
for f in $port_headers $port_files; do rename_inputs="$rename_inputs $sources/$f"; done
renames "$rename_inputs" $plain > "$build/renames.flags"
note "renamed: $(grep -c "" "$build/renames.flags" | tr -d ' ') class and symbol names"
built=""
for f in $port_files; do
    if xcrun clang $target $port_flags -I"$sources" $(cat "$build/renames.flags") -c "$sources/$f" -o "$build/port/$f.o" 2> "$build/port/$f.diagnostic"; then
        built="$built $build/port/$f.o"
    else
        failed "the port's $f does not compile with the renames"
        grep -m3 'error:' "$build/port/$f.diagnostic" | sed 's|^|    |'
    fi
done

expected="$build/controller.expected"
# The scenario asks two cases of a REAL extension, and it asks them the same way on both sides or the
# comparison would be of two different question lists. WEBEXT_MANIFEST is exported rather than passed to
# one program, for that reason.
WEBEXT_MANIFEST="$manifest"
export WEBEXT_MANIFEST
# the system side first, and in a process with none of the port's code: this is what the port is held to
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" "$here/webextension-controller_system.m" "$harness/check.m" $frameworks -o "$build/controller-system"
if REVENANT_EXPECTED="$expected" "$build/controller-system" > "$build/controller-system.log" 2>&1; then
    # the recorder's own count, not wc -l: the file is N records joined by N-1 newlines
    note "controller-system: exit=0 answers=$(grep -c '^case ' "$expected" | tr -d ' ') log=$build/controller-system.log"
else
    result=$?
    failed "controller-system: exit=$result log=$build/controller-system.log"
fi
# then the port, against those answers
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
    "$here/webextension-controller_test.m" "$harness/check.m" $built $frameworks -o "$build/controller-port"
if REVENANT_EXPECTED="$expected" "$build/controller-port" > "$build/controller-port.log" 2>&1; then
    result=0
else
    result=$?
fi
grep -v '^ok ' "$build/controller-port.log" || true
note "controller-port: exit=$result log=$build/controller-port.log"
[ "$result" = 0 ] || failed "the port's controller family does not answer what this host answers"

# ---------------------------------------------------------------- the extension family, port against system
# The same shape as the controller family above, and last because it needs what that section built: the
# port's objects, the renames, and WEBEXT_MANIFEST exported. The questions are in one header, the system's
# answers are recorded with no port code in the process, and the port is then asked the same questions.
mkdir -p "$build/ext"
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" "$here/webextension-extension_system.m" "$harness/check.m" $frameworks -o "$build/ext/system"
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
    "$here/webextension-extension_test.m" "$harness/check.m" $built $frameworks -o "$build/ext/port"
ext_expected="$build/extension.expected"
if REVENANT_EXPECTED="$ext_expected" "$build/ext/system" > "$build/ext/system.log" 2>&1; then
    note "extension-system: exit=0 answers=$(grep -c '^case ' "$ext_expected" | tr -d ' ') log=$build/ext/system.log"
else
    failed "extension-system: exit=$? log=$build/ext/system.log"
fi
if REVENANT_EXPECTED="$ext_expected" "$build/ext/port" > "$build/ext/port.log" 2>&1; then
    result=0
else
    result=$?
fi
grep -v '^ok ' "$build/ext/port.log" || true
note "extension-port: exit=$result log=$build/ext/port.log"
[ "$result" = 0 ] || failed "the port's extension family does not answer what this host answers"

# ---------------------------------------------------------------- the content rule list store, port against system
# The same shape as the two sections above, and it needs what they built: the port's objects and the
# renames. The store both sides are given is ONE directory under $build, and the system side runs first
# and the port side second against it, so a list the system compiled is still in the store when the port
# is asked -- which is what makes "a compiled list survives the process" a thing this comparison holds
# rather than a thing it assumes.
mkdir -p "$build/rules"
rule_store="$build/rules/store"
rule_expected="$build/rules/expected"
export REVENANT_RULE_STORE="$rule_store"
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" "$here/contentrulelist_system.m" "$harness/check.m" $frameworks -o "$build/rules/system"
if REVENANT_EXPECTED="$rule_expected" "$build/rules/system" > "$build/rules/system.log" 2>&1; then
    note "rules-system: exit=0 answers=$(grep -c '^case ' "$rule_expected" | tr -d ' ') log=$build/rules/system.log"
else
    failed "rules-system: exit=$? log=$build/rules/system.log"
fi
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
    "$here/contentrulelist_test.m" "$harness/check.m" $built $frameworks -o "$build/rules/port"
if REVENANT_EXPECTED="$rule_expected" "$build/rules/port" > "$build/rules/port.log" 2>&1; then
    result=0
else
    result=$?
fi
grep -v '^ok ' "$build/rules/port.log" || true
note "rules-port: exit=$result log=$build/rules/port.log"
[ "$result" = 0 ] || failed "the port's content rule list store does not answer what this host answers"

# The red control for THIS family, on the same principle as the one below: a copy of the port's own
# source with one refusal taken out, so every case that case was refusing has to go red. The mutation is
# a copy, so the tree is never edited, and the sed asserts its own landing: str.replace on a missing
# needle is a silent no-op and a planted run over an unplanted file would report the mutant as applied.
rule_mutant="$build/rules/mutant"
mkdir -p "$rule_mutant"
sed 's|NSError \*refusal = revenant_rule_refusal(rule);|NSError *refusal = nil; /* PLANTED */|' \
    "$sources/WKContentRuleList11.m" > "$rule_mutant/WKContentRuleList11.m"
if grep -q PLANTED "$rule_mutant/WKContentRuleList11.m"; then
    xcrun clang $target $port_flags -I"$sources" $(cat "$build/renames.flags") -c "$rule_mutant/WKContentRuleList11.m" \
        -o "$rule_mutant/WKContentRuleList11.o" 2> "$rule_mutant/compile.log"
    rule_objects=""
    for o in $built; do
        if [ "$o" = "$build/port/WKContentRuleList11.m.o" ]; then
            rule_objects="$rule_objects $rule_mutant/WKContentRuleList11.o"
        else
            rule_objects="$rule_objects $o"
        fi
    done
    xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
        "$here/contentrulelist_test.m" "$harness/check.m" $rule_objects $frameworks -o "$build/rules/port-mutant"
    if REVENANT_EXPECTED="$rule_expected" "$build/rules/port-mutant" > "$build/rules/port-mutant.log" 2>&1; then
        failed "RED CONTROL: the rule list comparison is green with a planted refusal, so it is reading nothing"
    else
        note "rules red control: exit=$? with a planted refusal, and the cases that moved are:"
        grep -E '^ +(port|system) +case' "$build/rules/port-mutant.log" | sed 's/^ */    /' | head -6
    fi
else
    failed "RED CONTROL: the rule list mutation did not land, so no mutant was built and nothing was proven"
fi

# ---------------------------------------------------------------- the three value holders, port against system
# The same shape once more, for the classes the web-extension family HANDS an application: a tab's
# configuration, a window's configuration and a message port. Nothing in the SDK returns any of them, so
# both sides are asked about the only object a program can make -- one WebKit made and a program
# initialised -- and the answers are the release's answers for that object.
config_expected="$build/configuration.expected"
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" "$here/webextension-configuration_system.m" "$harness/check.m" $frameworks -o "$build/configuration-system"
if REVENANT_EXPECTED="$config_expected" "$build/configuration-system" > "$build/configuration-system.log" 2>&1; then
    note "configuration-system: exit=0 answers=$(grep -c '^case ' "$config_expected" | tr -d ' ') log=$build/configuration-system.log"
else
    failed "configuration-system: exit=$? log=$build/configuration-system.log"
fi
xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
    "$here/webextension-configuration_test.m" "$harness/check.m" $built $frameworks -o "$build/configuration-port"
if REVENANT_EXPECTED="$config_expected" "$build/configuration-port" > "$build/configuration-port.log" 2>&1; then
    result=0
else
    result=$?
fi
grep -v '^ok ' "$build/configuration-port.log" || true
note "configuration-port: exit=$result log=$build/configuration-port.log"
[ "$result" = 0 ] || failed "the port's three value holders do not answer what this host answers"

# Its red control: one default in a COPY of the port's own controller object, which is where the three
# classes are defined. -index stops answering the index it was built with and answers 1.
config_mutant="$build/configuration-mutant"
mkdir -p "$config_mutant"
sed 's|^    return _index;$|    return 1; /* PLANTED */|' "$sources/WKWebExtensionController.m" > "$config_mutant/WKWebExtensionController.m"
if grep -q PLANTED "$config_mutant/WKWebExtensionController.m"; then
    xcrun clang $target $port_flags -I"$sources" $(cat "$build/renames.flags") -c "$config_mutant/WKWebExtensionController.m" \
        -o "$config_mutant/WKWebExtensionController.o" 2> "$config_mutant/compile.log"
    config_objects=""
    for o in $built; do
        if [ "$o" = "$build/port/WKWebExtensionController.m.o" ]; then
            config_objects="$config_objects $config_mutant/WKWebExtensionController.o"
        else
            config_objects="$config_objects $o"
        fi
    done
    xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
        "$here/webextension-configuration_test.m" "$harness/check.m" $config_objects $frameworks -o "$build/configuration-port-mutant"
    if REVENANT_EXPECTED="$config_expected" "$build/configuration-port-mutant" > "$build/configuration-port-mutant.log" 2>&1; then
        failed "RED CONTROL: the configuration comparison is green with a planted index, so it is reading nothing"
    else
        note "configuration red control: exit=$? with a planted index, and the case that moved is:"
        grep -E '^ +(port|system) +case' "$build/configuration-port-mutant.log" | sed 's/^ */    /' | head -2
    fi
else
    failed "RED CONTROL: the configuration mutation did not land, so no mutant was built and nothing was proven"
fi

# The red control, IN the harness: one answer of the port is changed, and this comparison has to go red on
# it. A comparison that has only ever been green is not evidence -- it would be equally green with the cases
# reading nothing -- and the twenty-two rows this section holds are exactly the class of evidence that has
# bitten this series twice.
#
# The mutation is a COPY of the port's own source, so the tree is never edited, and it is one accessor
# rather than a code path: -displayName stops reading the manifest's "name" and answers a planted string,
# so the case extension.displayName has to go red.
#
# A mutation has to touch an answer THIS section compares. The first version of this block mutated
# WKWebExtensionDataTypeLocal and proved the wrong thing twice over: that constant is defined in
# WKWebExtensionController.m, so the mutation did not land at all, and once it was pointed at the right file
# it reached the CONTROLLER's case constant.DataTypeLocal and left every extension case green -- a red light
# in the wrong building.
mutant="$build/mutant"
mkdir -p "$mutant"
sed 's|return \[self revenant_manifestString:@"name"\];|return @"PLANTED_name";|' \
    "$sources/WKWebExtension.m" > "$mutant/WKWebExtension.m"
if grep -q PLANTED_name "$mutant/WKWebExtension.m"; then
    xcrun clang $target $port_flags -I"$sources" $(cat "$build/renames.flags") -c "$mutant/WKWebExtension.m" -o "$mutant/WKWebExtension.o" 2> "$mutant/compile.log"
    mutant_objects=""
    for o in $built; do
        if [ "$o" = "$build/port/WKWebExtension.m.o" ]; then
            mutant_objects="$mutant_objects $mutant/WKWebExtension.o"
        else
            mutant_objects="$mutant_objects $o"
        fi
    done
    xcrun clang $target -fobjc-arc -w -I"$harness" -I"$here" -I"$sources" -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") \
        "$here/webextension-extension_test.m" "$harness/check.m" $mutant_objects $frameworks -o "$build/ext/port-mutant"
    if REVENANT_EXPECTED="$ext_expected" "$build/ext/port-mutant" > "$build/ext/port-mutant.log" 2>&1; then
        failed "RED CONTROL: the comparison is green with a planted displayName, so it is reading nothing"
    else
        note "red control: exit=$? with a planted displayName, and the case that moved is:"
        grep -E '^ +(port|system) +case' "$build/ext/port-mutant.log" | sed 's/^ */    /' | head -4
    fi
else
    failed "RED CONTROL: the mutation did not land, so no mutant was built and nothing was proven"
fi

exit $status
