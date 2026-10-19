#!/bin/sh
# run.sh - what the host's own NSURLSession does with a task's delegate, measured against SDK 16.4
# NSURLSession.h:296-304.
#
#   tasksession.m   the probe: four runs, the control first, then the three rules the header states
#   <this runner>   the build, the run, and the verdict
#
# Why the port is not in this program: the questions are about what the SYSTEM does with a task's
# delegate, and the port's objects are armv7 iOS 6.1.3 that no macOS process can load. The port's
# side of each rule is proven by its own compile and by the registry's rows, not here.
#
# Nothing leaves the machine. Every task is http://127.0.0.1:1/, which the loopback stack refuses at
# once, so the completion is delivered locally and no name is resolved.
#
#   sh tests/backports/host/tasksession/run.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
BUILD=${BUILD:-$root/.agent-work/build/tasksession}
rm -rf "$BUILD"
mkdir -p "$BUILD"

# -Wall and no -Werror: the harness reaches API_UNAVAILABLE(macos) names through the protocol, and a
# warning here is not a defect in what is measured. Everything is ARC, as the tree's tests are.
xcrun clang -fobjc-arc -Wall "$here/tasksession.m" -framework Foundation -o "$BUILD/tasksession"

echo "host   $(sw_vers -productVersion) build $(sw_vers -buildVersion), $(uname -m)"
"$BUILD/tasksession"
echo "tasksession: ->  PASS"