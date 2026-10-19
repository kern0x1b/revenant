#!/bin/sh
# run.sh — a host differential for SFCertificatePresentation, the one family of this delivery the host
# can be the oracle for.
#
# The host's own Security framework builds the trust and answers it; the port's sheet is asked for the
# same trust and must produce the same lines. The port's classes are compiled under names of their own
# (SFCertificatePresentation becomes CharonSFCertificatePresentation, from the registry's own class
# entries) so that a build which never links the host's SecurityUI still builds, and so the two builds
# are never confused for one another. The host has no SecurityUI of its own in this SDK to compare
# against, which is why the oracle is the trust: every line the sheet shows is read out of the trust
# with Security calls that have been public since iOS 2, so the host's answer to those calls is the
# answer the sheet must reproduce.
#
# Nothing here touches a keychain, fetches a certificate or opens a network: the certificate is a
# self-signed one written into tests/backports/device/certificate-selfsigned.inc, byte for byte, so both
# builds see the same one. The sheet is never presented either - the lines are asked for through the
# very call the presentation makes - so this runs as a plain Catalyst binary with no window and no app
# context, and nothing about the host's own state is involved.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
securityui=${SECURITYUI:-$here/../../../../packages/a/apple-backports/SecurityUI}
registry=${REGISTRY:-$here/../../../../packages/a/apple-backports/registry/SecurityUI/ios18.json}
build=${BUILD:-$(runs_fresh charon-certificatepresentation)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
frameworks="-iframework $sdk/System/iOSSupport/System/Library/Frameworks"
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk $frameworks -fobjc-arc -w"
libs="-framework Foundation -framework Security -framework CoreGraphics -framework UIKit"

xcrun clang $common -I"$device" "$here/record.m" "$device/certificate-cases.m" $libs -o "$build/system"
CERTIFICATE_RECORDS="$build/system.json" "$build/system"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/system.json'))))")"

python3 "$here/rename.py" "$registry" "$build/rename.h"

port() {
    dir=$1
    xcrun clang $common -DCHARON_CERTIFICATE_PORT=1 -DCHARON_HOST_DIFFERENTIAL=1 -include "$build/rename.h" -I"$device" -I"$securityui" \
        "$here/record.m" "$device/certificate-cases.m" "$dir"/*.m $libs -o "$dir/run"
}
rm -rf "$build/port"; mkdir -p "$build/port"
cp "$securityui"/*.m "$securityui"/*.h "$build/port/"
port "$build/port"
CERTIFICATE_RECORDS="$build/port.json" "$build/port/run"
python3 "$here/compare.py" "$build/system.json" "$build/port.json"
echo "port: agrees with the host's trust on every line the sheet builds"

# A differential that cannot tell a mutation from itself guards nothing, so each mutation of the sheet's
# own line-building must change a record. The list is the three ways the sheet can be wrong: a different
# certificate, a verdict that is not the trust's, and a chain line that is not marked.
survived=0
mutant() {
    from=$1; to=$2
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$securityui"/*.m "$securityui"/*.h "$build/mutant/"
    python3 "$here/mutate.py" "$build/mutant/SFCertificatePresentation.m" "$from" "$to"
    port "$build/mutant"
    rm -f "$build/mutant.json"
    CERTIFICATE_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/run" > /dev/null 2>&1 || true
    if cmp -s "$build/port.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $from -> $to"; survived=$((survived + 1)); fi
}
mutant "        [lines addObject:(__bridge_transfer NSString *)subject];" "        [lines addObject:@\"mutated\"];"
mutant "[lines addObject:NSLocalizedString(@\"Not trusted yet\", nil)];" "[lines addObject:NSLocalizedString(@\"mutated\", nil)];"
mutant "[lines addObject:[NSString stringWithFormat:@\"- %@\", (__bridge_transfer NSString *)subject]];" "[lines addObject:(__bridge_transfer NSString *)subject];"
if [ "$survived" -ne 0 ]; then echo "$survived mutants of the sheet's lines survived; the differential is not holding"; exit 1; fi
echo "mutants: all caught"
