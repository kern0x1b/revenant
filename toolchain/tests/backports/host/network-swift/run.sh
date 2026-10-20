#!/bin/sh
# run.sh - the host differentials of the Swift Network values (packages/runtimes/swift-runtime/files/Network): NWInterface, IPv4Address
# and IPv6Address.
#
# Each compares two outputs over the same questions, Apple's Network from the macOS SDK and this tree's:
#
#   the host half is the test built against Apple's Network (interfaces-apple.swift, ipv4/ and ipv6/ report.swift and main.swift);
#
#   the port half builds NWInterface.swift, IPv4Address.swift, IPv6Address.swift and enumerate-helper.swift as the Network module,
#   the way the runtime's recipe builds its overlays (-import-underlying-module, so the C calls are visible, and -I to the seam
#   module of files/Network/seam), then runs the same test against it. enumerate-helper.swift is test-only: it reads the interfaces
#   through the C monitor, because NWInterface's initialiser is internal, and it defines the zone lookup the seam is on the device,
#   and it is built into the test's module and nothing that ships.
#
# The outputs are compared with diff. Nothing here runs python. The compiler is the host's, unless SWIFTC is set.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
files=${NETWORK_SWIFT_FILES:-$root/packages/runtimes/swift-runtime/files/Network}
build=${NETWORK_SWIFT_BUILD:-$(runs_folder host-network-swift)}
swiftc=${SWIFTC:-swiftc}
target=${NETWORK_SWIFT_TARGET:-$(uname -m)-apple-macos26.0}
rm -rf "$build"
mkdir -p "$build/ours"

"$swiftc" -target "$target" -O -o "$build/apple" "$here/interfaces-apple.swift" 2> "$build/apple.err" || {
    echo "FAIL interfaces-apple.swift does not build against Apple's Network:"; grep "error:" "$build/apple.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -o "$build/ipv4-apple" "$here/ipv4/report.swift" "$here/ipv4/main.swift" 2> "$build/ipv4-apple.err" || {
    echo "FAIL the IPv4 report does not build against Apple's Network:"; grep "error:" "$build/ipv4-apple.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -o "$build/ipv6-apple" "$here/ipv6/report.swift" "$here/ipv6/main.swift" 2> "$build/ipv6-apple.err" || {
    echo "FAIL the IPv6 report does not build against Apple's Network:"; grep "error:" "$build/ipv6-apple.err" | head -6; exit 1; }

"$swiftc" -target "$target" -O -wmo -parse-as-library -module-name Network -Xfrontend -import-underlying-module \
    -I "$files/seam" -emit-module -emit-module-path "$build/ours/Network.swiftmodule" \
    "$files/NWInterface.swift" "$files/IPv4Address.swift" "$files/IPv6Address.swift" "$files/NWEndpoint.swift" "$here/enumerate-helper.swift" 2> "$build/ours.err" || {
    echo "FAIL emitting the Network module:"; grep "error:" "$build/ours.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -wmo -parse-as-library -module-name Network -Xfrontend -import-underlying-module \
    -I "$files/seam" -emit-object -o "$build/ours/Network.o" \
    "$files/NWInterface.swift" "$files/IPv4Address.swift" "$files/IPv6Address.swift" "$files/NWEndpoint.swift" "$here/enumerate-helper.swift" 2>> "$build/ours.err" || {
    echo "FAIL building the Network module:"; grep "error:" "$build/ours.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -I "$build/ours" -o "$build/ours/interfaces" "$build/ours/Network.o" \
    "$here/interfaces-port.swift" 2> "$build/port.err" || {
    echo "FAIL interfaces-port.swift does not build against this tree's Network:"; grep "error:" "$build/port.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -I "$build/ours" -o "$build/ours/ipv4" "$build/ours/Network.o" \
    "$here/ipv4/report.swift" "$here/ipv4/main.swift" 2> "$build/port-ipv4.err" || {
    echo "FAIL the IPv4 report does not build against this tree's Network:"; grep "error:" "$build/port-ipv4.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -I "$build/ours" -o "$build/ours/ipv6" "$build/ours/Network.o" \
    "$here/ipv6/report.swift" "$here/ipv6/main.swift" 2> "$build/port-ipv6.err" || {
    echo "FAIL the IPv6 report does not build against this tree's Network:"; grep "error:" "$build/port-ipv6.err" | head -6; exit 1; }

"$build/apple" > "$build/apple.txt" 2>&1 || { echo "FAIL the host binary"; head -5 "$build/apple.txt"; exit 1; }
"$build/ours/interfaces" > "$build/ours.txt" 2>&1 || { echo "FAIL the port binary"; tail -5 "$build/ours.txt"; exit 1; }
"$build/ipv4-apple" > "$build/ipv4-apple.txt" 2>&1 || { echo "FAIL the host IPv4 binary"; head -5 "$build/ipv4-apple.txt"; exit 1; }
"$build/ours/ipv4" > "$build/ipv4-ours.txt" 2>&1 || { echo "FAIL the port IPv4 binary"; tail -5 "$build/ipv4-ours.txt"; exit 1; }
"$build/ipv6-apple" > "$build/ipv6-apple.txt" 2>&1 || { echo "FAIL the host IPv6 binary"; head -5 "$build/ipv6-apple.txt"; exit 1; }
"$build/ours/ipv6" > "$build/ipv6-ours.txt" 2>&1 || { echo "FAIL the port IPv6 binary"; tail -5 "$build/ipv6-ours.txt"; exit 1; }

echo "apple lines: $(wc -l < "$build/apple.txt"), ours lines: $(wc -l < "$build/ours.txt")"
if diff "$build/apple.txt" "$build/ours.txt"; then
    echo "NWInterface differential: identical"
else
    echo "NWInterface differential: DIFFER"
    exit 1
fi
echo "ipv4 lines: $(wc -l < "$build/ipv4-apple.txt"), ours: $(wc -l < "$build/ipv4-ours.txt")"
if diff -a "$build/ipv4-apple.txt" "$build/ipv4-ours.txt"; then
    echo "IPv4Address differential: identical"
else
    echo "IPv4Address differential: DIFFER"
    exit 1
fi
echo "ipv6 lines: $(wc -l < "$build/ipv6-apple.txt"), ours: $(wc -l < "$build/ipv6-ours.txt")"
if diff -a "$build/ipv6-apple.txt" "$build/ipv6-ours.txt"; then
    echo "IPv6Address differential: identical"
else
    echo "IPv6Address differential: DIFFER"
    exit 1
fi

# NWEndpoint.Host and NWEndpoint.Port: the endpoint report, built the same two ways.
"$swiftc" -target "$target" -O -o "$build/endpoint-apple" "$here/endpoint/report.swift" "$here/endpoint/main.swift" 2> "$build/endpoint-apple.err" || {
    echo "FAIL the endpoint report does not build against Apple's Network:"; grep "error:" "$build/endpoint-apple.err" | head -6; exit 1; }
"$swiftc" -target "$target" -O -I "$build/ours" -o "$build/ours/endpoint" "$build/ours/Network.o" \
    "$here/endpoint/report.swift" "$here/endpoint/main.swift" 2> "$build/port-endpoint.err" || {
    echo "FAIL the endpoint report does not build against this tree's Network:"; grep "error:" "$build/port-endpoint.err" | head -6; exit 1; }
"$build/endpoint-apple" > "$build/endpoint-apple.txt" 2>&1 || { echo "FAIL the host endpoint binary"; head -5 "$build/endpoint-apple.txt"; exit 1; }
"$build/ours/endpoint" > "$build/endpoint-ours.txt" 2>&1 || { echo "FAIL the port endpoint binary"; tail -5 "$build/endpoint-ours.txt"; exit 1; }
echo "endpoint lines: $(wc -l < "$build/endpoint-apple.txt"), ours: $(wc -l < "$build/endpoint-ours.txt")"
if diff -a "$build/endpoint-apple.txt" "$build/endpoint-ours.txt"; then
    echo "NWEndpoint differential: identical"
else
    echo "NWEndpoint differential: DIFFER"
    exit 1
fi
