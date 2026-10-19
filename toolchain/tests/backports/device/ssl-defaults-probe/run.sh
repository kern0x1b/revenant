#!/bin/sh
# The SSL defaults probe, on an emulated 6.1.3, through the port's own emulator.
#
# WHAT IT MEASURES: what the RELEASE's stack negotiates by default, so the four
# sec_protocol_options_get_default_*_protocol_version rows answer a measurement instead of a decision.
# The values those rows carry are a crutch until this runs; see
# packages/a/apple-backports/facts/Security/SecProtocolWorklist.md.
#
# One heavy job, so it runs in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/ssl-defaults-probe/run.sh
#
# NOTHING HERE TOUCHES A KEYCHAIN, AN IDENTITY OR A NETWORK: the program creates a client-side
# SSLContext and asks it for its protocol range, and a context needs none of those.
#
# The mapping the run prints, from the SDK's own enumerators (SecProtocolTypes.h:156-165):
#     kSSLProtocol3 = 2   kTLSProtocol1 = 4   kTLSProtocol11 = 7   kTLSProtocol12 = 8
#     kDTLSProtocol1 = 9
# to the values the four rows answer:
#     TLSv10 = 0x0301     TLSv12 = 0x0303     DTLSv10 = 0xfeff
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
minimum=${SSLDEFAULTS_MINIMUM:-6.1.3}
work=${WORK:-$root/.agent-work/ssl-defaults}
mkdir -p "$work/runs"
stamp=$(date +%Y%m%d-%H%M%S)
out=$work/runs/defaults-$minimum-$stamp
mkdir -p "$out"
cd "$here"

# No charon@apple-backports in the graph, so the binary links the RELEASE's Security.framework and its
# answer is the release's. A dependency here would make the probe measure the port it is meant to measure.
xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the probe did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
xmake emulate -r "$minimum" install >"$out/install.log" 2>&1 || {
    echo "the probe did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
# /usr/libexec/<name> is where the daemon rule installs it, and it is what the tree's other emulator
# checks run (tests/backports/device/display-probe/run.sh runs /usr/libexec/display-probe).
xmake emulate -r "$minimum" run /usr/libexec/ssl-defaults-probe >"$out/run.log" 2>&1 || true
xmake emulate -r "$minimum" log >"$out/emulate.log" 2>&1 || true

report=$out/report.txt
sed 's/\x1b\[[0-9;]*m//g' "$out/run.log" | grep -aE '^(ssl-defaults-probe|context|min|max|enabled-)' > "$report" || true
if ! grep -q '^ssl-defaults-probe[[:space:]]*start' "$report"; then
    echo "NO REPORT: the probe printed nothing of its own; $out/run.log is what happened" >&2
    tail -20 "$out/run.log" >&2
    exit 1
fi
echo "== what the release's stack answers on $minimum =="
cat "$report"
echo "== logs=$out"
# The rows want the answer, not a verdict: this script reports and does not judge, because a measured
# value that disagrees with the crutch is a finding to be READ, not a failure to be hidden.
