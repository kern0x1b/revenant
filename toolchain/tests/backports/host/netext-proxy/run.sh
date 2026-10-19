#!/bin/sh
# run.sh - the proxy and the IPv4 and IPv6 settings objects, compared against Apple's own answers in two binaries.
#
#     sh tests/backports/host/netext-proxy/run.sh [--mutation]
#
# Same shape as the NEDNSSettings differential, for a reason that is measured rather than assumed: the
# property names of these six classes are carried by the host's own NetworkExtension, so they can be
# compared. The two names that cannot - +settingsWithAutomaticAddressing and
# +settingsWithLinkLocalAddressing, which the 26.2 header marks API_UNAVAILABLE on every platform - are
# checked against this package's own header below, which is the oracle the README names for a name no
# host carries.
#
#   host   the probe alone with -framework NetworkExtension: every answer Apple's, and a dladdr line per
#          class naming the image that answered.
#   port   the probe together with the port's two objects, built for the same Mac Catalyst target, with
#          Apple's framework not linked: every answer the port's.
#
# --mutation breaks one answer per comparison in the port's own source; each has to go red naming its
# comparison, and a mutation that does not build is RUN FAILED, never counted as noticed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
W=${WORK:-$root/.agent-work/runs/netext-proxy}
W=${W%./*}/$(basename "$W")
rm -rf "$W"
mkdir -p "$W"

sdk=$(xcrun --show-sdk-path --sdk macosx)
port="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -I$S/NetworkExtension"

echo "=== host: Apple's own answers, and the image that answered"
# shellcheck disable=SC2086
clang -fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -DHOST_SIDE=1 \
    "$here/probe.m" -framework NetworkExtension -framework Foundation -o "$W/host"
"$W/host" | tee "$W/host.txt"

echo "=== port: the port's own answers, Apple's framework not linked at all"
# shellcheck disable=SC2086
clang $port "$here/probe.m" "$S/NetworkExtension/NEProxySettings.m" "$S/NetworkExtension/NEIPv4Settings.m" \
    "$S/NetworkExtension/NEIPv4Route9.m" "$S/NetworkExtension/NEIPv6Settings.m" \
    "$S/NetworkExtension/NEIPv6Route9.m" -framework Foundation -o "$W/port"
"$W/port" | tee "$W/port.txt"

echo "=== compared, name by name"
compared=0
failed=0
NAMES="NEProxyServer.dladdr NEProxySettings.dladdr NEIPv4Settings.dladdr NEIPv4Route.dladdr NEIPv6Settings.dladdr NEIPv6Route.dladdr NEProxyServer.username NEProxyServer.password NEProxyServer.authenticationRequired NEProxySettings.autoProxyConfigurationEnabled NEProxySettings.proxyAutoConfigurationURL NEProxySettings.proxyAutoConfigurationJavaScript NEProxySettings.HTTPEnabled NEProxySettings.HTTPServer NEProxySettings.HTTPSEnabled NEProxySettings.HTTPSServer NEProxySettings.excludeSimpleHostnames NEProxySettings.exceptionList NEProxySettings.matchDomains NEIPv4Settings.addresses NEIPv4Settings.subnetMasks NEIPv4Settings.router NEIPv4Settings.includedRoutes NEIPv4Settings.excludedRoutes NEIPv4Route.destinationAddress NEIPv4Route.destinationSubnetMask NEIPv4Route.gatewayAddress NEIPv6Settings.addresses NEIPv6Settings.networkPrefixLengths NEIPv6Settings.includedRoutes NEIPv6Settings.excludedRoutes NEIPv6Route.destinationAddress NEIPv6Route.destinationNetworkPrefixLength NEIPv6Route.gatewayAddress NEIPv6Route.defaultRoute.destinationAddress NEIPv6Route.defaultRoute.prefixLength NEIPv6Route.defaultRoute.gatewayAddress NEIPv6Settings.automatic.addresses NEIPv6Settings.automatic.networkPrefixLengths NEIPv6Settings.linkLocal.addresses serverRoundTrip.username serverRoundTrip.password serverRoundTrip.authenticationRequired roundTrip.matchDomains v6RoundTrip.includedRoutes v6RoundTrip.route.destination v6RoundTrip.route.prefix v6Copy.isSameObject v6Archive.hasData v6Archive.errorDomain roundTrip.HTTPEnabled roundTrip.exceptionList copy.isSameObject archive.hasData archive.errorDomain"
for name in $NAMES; do
    h=$(grep "^$name	" "$W/host.txt" | cut -f2 || true)
    p=$(grep "^$name	" "$W/port.txt" | cut -f2 || true)
    case "$name" in
        *.dladdr)
            # a proof line is not a comparison: the two sides must name DIFFERENT implementations, or
            # one of them is answering for both. That is the whole point of the two binaries.
            compared=$((compared + 1))
            if [ -z "$h" ] || [ -z "$p" ]; then
                echo "FAIL  $name  the proof is empty: host='$h' port='$p'"
                failed=$((failed + 1))
            elif [ "$h" = "$p" ]; then
                echo "FAIL  $name  both sides name '$h': one implementation is answering for both"
                failed=$((failed + 1))
            else
                echo "ok    $name  host='$h' port='$p' (different implementations, as it must be)"
            fi
            ;;
        *)
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
            ;;
    esac
done
echo "compared=$compared failed=$failed"

# The two names Apple's class cannot answer, checked against the header the port compiles against,
# which is the oracle the registry README names for a name no host carries. A rename in the header that
# drops one of them goes red here rather than quietly leaving the row with no declaration.
header=$S/NetworkExtension/CharonNetworkExtensionSettings.h
for name in settingsWithAutomaticAddressing settingsWithLinkLocalAddressing; do
    compared=$((compared + 1))
    if grep -q "$name" "$header" && grep -q "$name" "$W/port.txt"; then
        echo "ok    $name  declared in CharonNetworkExtensionSettings.h and answered by the port"
    else
        echo "FAIL  $name  not declared in the header, or not answered by the port"
        failed=$((failed + 1))
    fi
done
[ "$failed" -eq 0 ] || exit 1

if [ "${1:-}" = "--mutation" ]; then
    echo "=== one mutation per comparison: each must go red naming itself"
    failed=0
    set -- "NEProxyServer.username|_username = [username copy];|_username = @[@\"planted\"];" "roundTrip.exceptionList|_exceptionList = [list copy];|_exceptionList = @[@\"planted\"];" "NEProxySettings.HTTPEnabled|_httpEnabled = flag;|_httpEnabled = !flag;" "copy.isSameObject|    NEProxySettings *copy = [[NEProxySettings allocWithZone:zone] init];|    NEProxySettings *copy = (NEProxySettings *)self; (void)zone;" "NEIPv6Settings.addresses|    return [self initWithAddresses:@[] networkPrefixLengths:@[]];|    return [self initWithAddresses:@[@\"planted\"] networkPrefixLengths:@[]];" "NEIPv6Route.defaultRoute.destinationAddress|initWithDestinationAddress:@\"::\" networkPrefixLength:@0|initWithDestinationAddress:@\"::1\" networkPrefixLength:@0"
    for mutation in "$@"; do
        name=$(printf '%s' "$mutation" | cut -d'|' -f1)
        was=$(printf '%s' "$mutation" | cut -d'|' -f2)
        now=$(printf '%s' "$mutation" | cut -d'|' -f3)
        mutant="$W/mutant-$name.m"
        found=0
        original=""
        for source in "$S/NetworkExtension/NEProxySettings.m" "$S/NetworkExtension/NEIPv4Settings.m" \
                      "$S/NetworkExtension/NEIPv4Route9.m" "$S/NetworkExtension/NEIPv6Settings.m" \
                      "$S/NetworkExtension/NEIPv6Route9.m"; do
            if grep -qF "$was" "$source"; then
                python3 - "$source" "$mutant" "$was" "$now" <<'PYEOF'
import sys
source, target, was, now = sys.argv[1:5]
text = open(source).read()
if text.count(was) != 1:
    raise SystemExit("the text to break appears %d times, not once" % text.count(was))
open(target, "w").write(text.replace(was, now, 1))
PYEOF
                found=1
                original="$source"
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "RUN FAILED $name: the mutation did not apply to any of the port's sources" >&2
            failed=$((failed + 1))
            continue
        fi
        # The mutant stands in for the ONE file it was taken from, and every other source of the library
        # is linked beside it: a build that left a file out failed to link and the harness read the failed
        # build as "noticed", which is how four of these mutations passed without ever answering.
        others=""
        for source in "$S/NetworkExtension/NEProxySettings.m" "$S/NetworkExtension/NEIPv4Settings.m" \
                      "$S/NetworkExtension/NEIPv4Route9.m" "$S/NetworkExtension/NEIPv6Settings.m" \
                      "$S/NetworkExtension/NEIPv6Route9.m"; do
            if [ "$source" = "$original" ]; then
                others="$others $mutant"
            else
                others="$others $source"
            fi
        done
        # shellcheck disable=SC2086
        if ! clang $port "$here/probe.m" $others -framework Foundation -o "$W/mutant-$name" \
             > "$W/mutant-$name.build" 2>&1; then
            echo "RUN FAILED $name: the mutant does not build (see $W/mutant-$name.build)" >&2
            failed=$((failed + 1))
            continue
        fi
        "$W/mutant-$name" > "$W/mutant-$name.txt" 2>&1 || true
        # The two binaries are different files, so their dladdr lines name different paths by
        # construction: comparing those would call every mutation noticed without one answer moving.
        # They are filtered out and the rest of the lines are compared, so "noticed" means an answer
        # changed.
        grep -v '\.dladdr	' "$W/mutant-$name.txt" > "$W/mutant-$name.answers" || true
        grep -v '\.dladdr	' "$W/port.txt" > "$W/port.answers" || true
        if diff -q "$W/mutant-$name.answers" "$W/port.answers" >/dev/null 2>&1; then
            echo "NOT NOTICED $name: the mutant answered exactly as the port does" >&2
            failed=$((failed + 1))
        else
            echo "noticed $name: $(diff "$W/port.answers" "$W/mutant-$name.answers" | grep '^[<>]' | head -1 | cut -c1-88)"
        fi
    done
    echo "mutations: 6, failures: $failed"
    [ "$failed" -eq 0 ] || exit 1
fi
echo "PASS: the port's answers agree with Apple's, name by name"
