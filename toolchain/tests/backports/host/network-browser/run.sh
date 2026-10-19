#!/bin/sh
# run.sh - the browser of Network, compared against Apple's own nw_browser on a live link.
#
#     sh tests/backports/host/network-browser/run.sh [--mutation]
#
# One instance name for the whole run, so that the two processes register and browse for the same service
# and every line of the comparison is a comparison: each side used to register its own pid-named service,
# which made `endpoint.name` answer two different names by construction. The name carries this shell's pid
# so two runs on one machine never collide, and each side withdraws its registration before it leaves, so
# the second process of a run finds the name free.
#
# Two binaries, because a browser is asynchronous and the two implementations must not see each other:
#
#   host   the probe alone with -framework Network: it registers a Bonjour service through the release's
#          own DNSServiceRegister and browses for it with Apple's nw_browser.
#   port   the probe together with the port's Network/ objects and the Foundation path monitor, every
#          name they define renamed to charonhost_*, and Apple's Network.framework NOT linked: it
#          registers the same service and browses for it with the port's browser.
#
# The rename set is read out of the compiled objects rather than written down, so a call the port adds
# is renamed with it and one the port stops defining drops out of it. The Charon classes are renamed the
# same way, so the port's objects are not the host's.
#
# --mutation breaks one answer per comparison in the port's own source; each has to go red naming its
# comparison, and a mutation that does not build is RUN FAILED and never counted as noticed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
W=${WORK:-$root/.agent-work/runs/network-browser}
W=${W%./*}/$(basename "$W")
rm -rf "$W"
mkdir -p "$W"
instance="charon-diff-$$"
echo "instance: $instance"

sources=$(ls "$S"/Network/*.m "$S"/Foundation/NWPathMonitor.m "$S"/Foundation/NWPathMonitor14.m | sort)
mkdir -p "$W/plain"
for source in $sources; do
    xcrun clang -fobjc-arc -w -c "$source" -o "$W/plain/$(basename "$source" .m).o"
done
xcrun clang -fobjc-arc -w -c "$S/Network/CharonNWSupport.c" -o "$W/plain/CharonNWSupport.o"

renames=""
for name in $(nm -gU "$W/plain"/*.o | awk '$2=="T"||$2=="D"||$2=="S"{print $3}' | sed 's/^_//' | grep -E '^_?nw_' | sort -u); do
    renames="$renames -D$name=charonhost_$name"
done
for class in $(nm -gU "$W/plain"/*.o | awk '$2=="S"||$2=="D"{print $3}' | sed -n -e 's/^_OBJC_CLASS_\$_//p' -e 's/^_OBJC_METACLASS_\$_//p' | grep -E '^Charon' | sort -u); do
    renames="$renames -D$class=CharonHost$class"
done
rm -rf "$W/plain"
echo "renamed $(echo "$renames" | wc -w | tr -d ' ') names"

echo "=== host: Apple's own nw_browser, and the service it is about to find"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -DHOST_SIDE=1 "$here/probe.m" \
    -framework Network -framework Foundation -o "$W/host"
"$W/host" "$instance" > "$W/host.txt" 2>&1 || true
cat "$W/host.txt"

echo "=== port: the port's own browser, Apple's Network.framework not linked at all"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w $renames -I"$S/Network" -I"$S/Foundation" "$here/probe.m" $sources \
    "$S/Network/CharonNWSupport.c" -framework Foundation -framework Security -framework SystemConfiguration -o "$W/port"
"$W/port" "$instance" > "$W/port.txt" 2>&1 || true
cat "$W/port.txt"

echo "=== compared, name by name"
# Every line both sides print, compared name by name. $1 the answers file, $2 what to call that side in
# the lines, $3 the prefix ("FAIL  " for a mutant, "ok    "/"FAIL  " for the port itself). Sets
# `compared` and `failed`, and the run's own instance is required of both sides wherever the name is
# compared: two sides agreeing about some other service of the same type that happens to be on the link is
# not this differential, so a machine with another publisher of the type says so rather than passing on it.
NAMES="found endpoint.type endpoint.name endpoint.serviceType endpoint.domain endpoint.port record.keys record.isDictionary changes.added interfaces.count"
compare_against() {
    compared=0
    failed=0
    for line in $NAMES; do
        h=$(grep "^$line	" "$W/host.txt" | cut -f2 || true)
        m=$(grep "^$line	" "$1" | cut -f2 || true)
        compared=$((compared + 1))
        if [ "$line" = endpoint.name ] && { [ "$h" != "$instance" ] || [ "$m" != "$instance" ]; }; then
            echo "FAIL  $line  this run registered '$instance', the host answered '$h' and $2 '$m'"
            failed=$((failed + 1))
            continue
        fi
        if [ -z "$h" ]; then
            echo "FAIL  $line  the host did not answer it: this comparison has no oracle"
            failed=$((failed + 1))
        elif [ -z "$m" ]; then
            echo "FAIL  $line  $2 did not answer it"
            failed=$((failed + 1))
        elif [ "$h" = "$m" ]; then
            echo "ok    $line  $m"
        else
            echo "FAIL  $line  host='$h' $2='$m'"
            failed=$((failed + 1))
        fi
    done
}

compare_against "$W/port.txt" the-port
echo "compared=$compared failed=$failed"
[ "$failed" -eq 0 ] || exit 1

if [ "${1:-}" = "--mutation" ]; then
    echo "=== one mutation per comparison: each must go red naming itself"
    # name|file|was|now. Every mutation is one value the port hands over, so the only thing it can move is
    # the line it names; `found` is the one line no single value can move, because a browser that reports
    # no result at all reports no result in every line, so that mutation takes the other nine with it and
    # is asked only to make `found` red.
    set -- \
    "endpoint.type|Network/nw12-browser.m|endpoint->_type = nw_endpoint_type_bonjour_service;|endpoint->_type = nw_endpoint_type_host;" \
    "endpoint.name|Network/nw12-browser.m|endpoint->_bonjourName = lookup->_name;|endpoint->_bonjourName = nil;" \
    "endpoint.serviceType|Network/nw12-browser.m|endpoint->_bonjourType = lookup->_type;|endpoint->_bonjourType = nil;" \
    "endpoint.domain|Network/nw12-browser.m|endpoint->_bonjourDomain = lookup->_domain;|endpoint->_bonjourDomain = nil;" \
    "endpoint.port|Network/nw12-browser.m|endpoint->_txtRecord = lookup->_txt;|endpoint->_txtRecord = lookup->_txt; endpoint->_port = @\"1\";" \
    "record.keys|Network/nw13-txtrecord.m|return value ? value->_keys.count : 0;|return 0;" \
    "record.isDictionary|Network/nw13-txtrecord.m|return value ? value->_dictionary : false;|return value ? !value->_dictionary : false;" \
    "changes.added|Network/nw16-browser.m|return nw_browse_result_change_result_added;|return nw_browse_result_change_result_removed;" \
    "interfaces.count|Network/nw16-browser.m|return value ? value->_interfaces.count : 0;|return 0;" \
    "found|Network/nw12-browser.m|nw_browser_browse_results_changed_handler_t handler = browser->_results;|nw_browser_browse_results_changed_handler_t handler = nil;"
    mut_failed=0
    for mutation in "$@"; do
        line=$(printf '%s' "$mutation" | cut -d'|' -f1)
        file=$(printf '%s' "$mutation" | cut -d'|' -f2)
        was=$(printf '%s' "$mutation" | cut -d'|' -f3)
        now=$(printf '%s' "$mutation" | cut -d'|' -f4)
        source="$S/$file"
        mutant="$W/mutant-$line-$(basename "$file")"
        if ! python3 - "$source" "$mutant" "$was" "$now" <<'PYEOF'
import sys
source, target, was, now = sys.argv[1:5]
text = open(source).read()
if text.count(was) != 1:
    raise SystemExit("the text to break appears %d times in %s, not once" % (text.count(was), source))
open(target, "w").write(text.replace(was, now, 1))
PYEOF
        then
            echo "RUN FAILED $line: the text to break is not in $file exactly once" >&2
            mut_failed=$((mut_failed + 1))
            continue
        fi
        # The mutant stands in for the ONE file it was taken from and every other source of the library is
        # linked beside it, so a build that left a file out failed to link and the harness read the failed
        # build as "noticed".
        standin=""
        for source in $sources; do
            if [ "$source" = "$S/$file" ]; then
                standin="$standin $mutant"
            else
                standin="$standin $source"
            fi
        done
        # shellcheck disable=SC2086
        if ! xcrun clang -fobjc-arc -w $renames -I"$S/Network" -I"$S/Foundation" "$here/probe.m" $standin \
             "$S/Network/CharonNWSupport.c" -framework Foundation -framework Security -framework SystemConfiguration \
             -o "$W/mutant-$line" > "$W/mutant-$line.build" 2>&1; then
            echo "RUN FAILED $line: the mutant does not build (see $W/mutant-$line.build)" >&2
            mut_failed=$((mut_failed + 1))
            continue
        fi
        "$W/mutant-$line" "$instance" > "$W/mutant-$line.txt" 2>&1 || true
        # the same comparison the plain run above makes, and it must name this mutation's own line
        verdict=$(compare_against "$W/mutant-$line.txt" the-mutant | grep "^FAIL  $line  " | head -1)
        if [ -n "$verdict" ]; then
            echo "noticed $line: $(printf '%s' "$verdict" | cut -c1-90)"
        else
            echo "NOT NOTICED $line: the mutant still answers what Apple answers for $line" >&2
            mut_failed=$((mut_failed + 1))
        fi
    done
    echo "mutations: 10, failures: $mut_failed"
    [ "$mut_failed" -eq 0 ] || exit 1
fi
echo "PASS: the port's browser finds on a live link what Apple's finds"
