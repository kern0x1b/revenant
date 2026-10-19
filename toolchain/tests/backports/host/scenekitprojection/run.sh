#!/bin/sh
# The port's SCNSceneRenderer.projectPoint / unprojectPoint arithmetic, against macOS SceneKit's own
# answers for the same camera, viewport and points.
#
# The backports carry neither method (measured 2026-09-28: `grep -rn projectPoint
# packages/a/apple-backports/` is empty, while the SDK declares both at
# SCNSceneRenderer.h:129-142), so this states the arithmetic the port is given and holds it against
# the system's. It is red, and says so: a view that has not rendered a frame gives the host's
# projectPoint its input back unchanged, so the oracle is not a projection yet. The rendering setup
# this needs is the one tests/backports/host/scenekit/render.swift already has, and the case is
# committed red rather than deleted, because a red case with a verdict is information and a deleted
# one is not.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
# In the worktree, not /tmp: the brief's rule is that nothing of a band goes in the system temp
# path, which is wiped. The case is rebuilt every run and the log it keeps is the evidence.
here_root=$(cd "$here/../../../.." && pwd)
build=${BUILD:-$here_root/.agent-work/runs/host-scenekitprojection}
swiftc=${SWIFTC:-swiftc}
sdk=${SDK:-$(xcrun --show-sdk-path)}
mkdir -p "$build"
"$swiftc" -O -target "$(uname -m)-apple-macos14" -sdk "$sdk" -swift-version 5 \
    -framework Metal -o "$build/project" "$here/project.swift"
# The device test's header: the host's own answers, recorded here so the port is held to them.
DEVICE=${DEVICE:-$here/../../device}
"$build/project" "$DEVICE/scenekitprojection-expectations.h" | tee "$build/log"
grep -qE "scenekitprojection: OK" "$build/log"
