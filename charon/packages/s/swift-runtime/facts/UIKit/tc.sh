#!/bin/sh
# swiftc -typecheck for one file at armv7-apple-ios6.1.3, with the port's own flags.
#
# The resource directory is an installed charon@swift-runtime's own lib/swift, which is where the
# armv7 standard library, the swiftmodules the port's overlays are built against and the toolchain's
# clang include (so stdarg.h resolves) all live. The SDK is the real 26.2 under the runtime's port
# overlay, and the swiftmodules come from the same install. Every path from the environment, so this
# file carries none of this machine's.
: "${CHARON_SWIFT_RUNTIME:?an installed charon@swift-runtime}"
: "${CHARON_SWIFTC:?the swift compiler}"
: "${CHARON_SDK26:?the 26.2 SDK}"
: "${CHARON_PORT_VFS:?the lift vfs.yaml}"
RES="$CHARON_SWIFT_RUNTIME/lib/swift"
exec "$CHARON_SWIFTC" -typecheck -target armv7-apple-ios6.1.3 -sdk "$CHARON_SDK26" \
  -resource-dir "$RES" \
  -I "$RES/iphoneos" \
  -Xcc "-fmodule-map-file=$RES/shims/module.modulemap" \
  -Xcc -ivfsoverlay -Xcc "$CHARON_PORT_VFS" \
  "$@"
