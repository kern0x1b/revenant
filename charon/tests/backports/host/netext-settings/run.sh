#!/bin/sh
# run.sh — the NEDNSSettings object, measured two ways, with a mutant per comparison.
#
#     sh tests/backports/host/netext-settings/run.sh [--mutation]
#
# Two binaries, because a host differential can only prove the port's code where the host does not
# answer the same name: linking the port's class into the same process as Apple's NEDNSSettings makes
# one implementation shadow the other, and a comparison that cannot say which one answered is a
# comparison that proves nothing. So:
#
#   host   the probe alone, with -framework NetworkExtension. Every answer is Apple's, and the probe
#          prints a dladdr line naming the image that answered each selector.
#   port   the probe TOGETHER WITH packages/a/apple-backports/NetworkExtension/NEDNSSettings.m, built
#          for the same Mac Catalyst target, with no NetworkExtension linked. Every answer is the
#          port's.
#
# The harness compares the names both sides answer - servers, searchDomains, matchDomains,
# matchDomainsNoSearch, the copy, and the keyed-archive round trip. The three names Apple's class does
# not carry (dnsProtocol, domainName, allowFailover) are not compared against it; they are checked
# against the iOS 26.2 header's own declarations, which run.sh greps, so their oracle is named.
#
# --mutation breaks one answer per comparison in the port's source and each has to go red naming it. A
# mutation that does not build is RUN FAILED and never counted as noticed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
W=${WORK:-$root/.agent-work/runs/netext-settings}
W=${W%./*}/$(basename "$W")
rm -rf "$W"
mkdir -p "$W"

sdk=$(xcrun --show-sdk-path --sdk macosx)
port="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -I$S/NetworkExtension"
# The 26.2 SDK tree the coordinator keeps for the corpus; IOS26_SDK overrides it.
header26="${IOS26_SDK:-$HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk}/System/Library/Frameworks/NetworkExtension.framework/Headers/NEDNSSettings.h"

echo "=== host: Apple's own answers, and the image that answered"
# shellcheck disable=SC2086
clang -fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -DHOST_SIDE=1 \
    "$here/probe.m" -framework NetworkExtension -framework Foundation -o "$W/host"
"$W/host" | tee "$W/host.txt"

echo "=== port: the port's own answers, Apple's framework not linked at all"
# shellcheck disable=SC2086
clang $port "$here/probe.m" "$S/NetworkExtension/NEDNSSettings.m" \
    -framework Foundation -o "$W/port"
"$W/port" | tee "$W/port.txt"

echo "=== compared, name by name: the six names both sides answer"
compared=0
failed=0
for name in fresh.servers fresh.searchDomains fresh.matchDomains fresh.matchDomainsNoSearch \
            copy.isSameObject copy.isKindOfClass archive.hasData archive.errorDomain \
            roundTrip.isKindOfClass roundTrip.servers; do
    h=$(grep "^$name	" "$W/host.txt" | cut -f2 || true)
    p=$(grep "^$name	" "$W/port.txt" | cut -f2 || true)
    compared=$((compared + 1))
    if [ -z "$h" ] || [ -z "$p" ]; then
        echo "FAIL  $name  host='$h' port='$p' (one side did not answer it)"
        failed=$((failed + 1))
    elif [ "$h" = "$p" ]; then
        echo "ok    $name  $h"
    else
        echo "FAIL  $name  host='$h' port='$p'"
        failed=$((failed + 1))
    fi
done

echo "=== the three names Apple's class does not carry, against the iOS 26.2 header"
if [ ! -f "$header26" ]; then
    echo "FAIL  the 26.2 header is not at $header26: the oracle for these three does not exist here"
    exit 1
fi
for name in dnsProtocol domainName allowFailover; do
    if grep -qE "^@property .*\b$name\b" "$header26"; then
        echo "ok    $name  declared in the 26.2 header ($(grep -E "^@property .*\b$name\b" "$header26" | sed 's/API_AVAILABLE.*//;s/  */ /g'))"
        compared=$((compared + 1))
    else
        echo "FAIL  $name  the 26.2 header does not declare it, so the port has no oracle for it"
        failed=$((failed + 1))
    fi
done
echo "=== the three names Apple's class does not carry: port-only, checked against the header"
# The host carries none of these three names, so there is nothing on that side to compare with. Each is
# therefore checked on the port side alone - the header's declared default, the setter round trip and
# the keyed-archive round trip - and the harness refuses to pass unless all three answers are there.
# Each port-only row ASSERTS the value the header and the object agree on. Printing whatever the port
# answered and calling it ok is what the review caught: an inverted getter or setter passes a run that
# only checks the lines exist.
port_only=$(grep -c "^portOnly\." "$W/port.txt" || true)
if [ "$port_only" -lt 8 ]; then
    echo "FAIL  the port-only lines are missing ($port_only of 8): the three uncompared names have no oracle"
    failed=$((failed + 1))
else
    assert_one() {
        # assert_one <name> <expected>
        compared=$((compared + 1))
        got=$(grep "^$1	" "$W/port.txt" | cut -f2 || true)
        if [ -z "$got" ]; then
            echo "FAIL  $1  expected=$2 got=(no answer)"
            failed=$((failed + 1))
        elif [ "$got" = "$2" ]; then
            echo "ok    $1  $got  (port-only: the host has no such name)"
        else
            echo "FAIL  $1  expected=$2 got=$got"
            failed=$((failed + 1))
        fi
    }
    assert_one portOnly.dnsProtocol.default      YES
    assert_one portOnly.dnsProtocol.afterSet     TLS
    assert_one portOnly.domainName.isNil         YES
    assert_one portOnly.domainName.afterSet      "example.com"
    assert_one portOnly.allowFailover.default    NO
    assert_one portOnly.allowFailover.afterSet   YES
    assert_one portOnly.coding.domainName        "example.com"
    assert_one portOnly.coding.allowFailover     YES
fi
echo "compared=$compared failed=$failed"
[ "$failed" -eq 0 ] || exit 1

if [ "${1:-}" = "--mutation" ]; then
    echo "=== one mutation per comparison: each must go red naming itself"
    mutations=0
    failed=0
    # name | the exact text to break | what replaces it
    set -- \
      "fresh.servers|_servers = [servers copy];|_servers = @[@\"planted\"];" \
      "fresh.searchDomains|_searchDomains = [searchDomains copy];|_searchDomains = @[@\"planted\"];" \
      "fresh.matchDomains|_matchDomains = [matchDomains copy];|_matchDomains = @[@\"planted\"];" \
      "fresh.matchDomainsNoSearch|_matchDomainsNoSearch = YES;|_matchDomainsNoSearch = NO;" \
      "copy.isSameObject|    return copy;|    return self;" \
      "copy.isKindOfClass|    return copy;|    return (id)@\"not an NEDNSSettings\";" \
      "roundTrip.servers|_servers = [[coder decodeObjectOfClass:[NSArray class] forKey:@\"servers\"] copy];|_servers = @[];"
    for mutation in "$@"; do
        name=$(printf '%s' "$mutation" | cut -d'|' -f1)
        was=$(printf '%s' "$mutation" | cut -d'|' -f2)
        now=$(printf '%s' "$mutation" | cut -d'|' -f3)
        mutant="$W/mutant-$name.m"
        if ! python3 - "$S/NetworkExtension/NEDNSSettings.m" "$mutant" "$was" "$now" <<'PYEOF'
import sys
source, target, was, now = sys.argv[1:5]
text = open(source).read()
if text.count(was) != 1:
    print("the text to break appears %d times, not once" % text.count(was))
    raise SystemExit(1)
open(target, "w").write(text.replace(was, now, 1))
PYEOF
        then
            echo "RUN FAILED $name: the mutation did not apply to the port's source" >&2
            failed=$((failed + 1))
            continue
        fi
        # shellcheck disable=SC2086
        if ! clang $port "$here/probe.m" "$mutant" -framework Foundation -o "$W/mutant-$name" > "$W/mutant-$name.build" 2>&1; then
            echo "RUN FAILED $name: the mutant does not build (see $W/mutant-$name.build)" >&2
            failed=$((failed + 1))
            continue
        fi
        "$W/mutant-$name" > "$W/mutant-$name.txt" 2>&1 || true
        if diff -q "$W/mutant-$name.txt" "$W/port.txt" >/dev/null 2>&1; then
            echo "NOT NOTICED $name: the mutant answered exactly as the port does" >&2
            failed=$((failed + 1))
        else
            echo "noticed $name: $(diff "$W/port.txt" "$W/mutant-$name.txt" | grep '^[<>]' | head -1 | cut -c1-90)"
            mutations=$((mutations + 1))
        fi
    done
    echo "mutations noticed: $mutations, failures: $failed"
    [ "$failed" -eq 0 ] || exit 1
fi
echo "PASS: the port's answers agree with Apple's, and the three names it does not carry have the 26.2 header"