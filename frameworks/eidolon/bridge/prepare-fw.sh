#!/bin/bash
# prepare-fw.sh: make fw/, a copy of the SwiftUI framework of the iOS 16.4 SDK with one statement of its interface
# changed (an os_log call with string interpolation that the current compiler will not rebuild from the interface).
# The copy is used only to compile the sample app and to dump Apple's API with swift-api-digester on this machine.
# It is Apple's SDK content: it is git-ignored and must never be committed or passed on.
set -e
cd "$(dirname "$0")"
source ../pkg-env.sh
rm -rf fw
mkdir -p fw
cp -R "$SDK/System/Library/Frameworks/SwiftUI.framework" fw/SwiftUI.framework
xmake l patch-interface.lua fw/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-ios.swiftinterface
echo "fw/ ready"
