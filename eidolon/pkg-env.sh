# pkg-env.sh: sourced by the build scripts: the toolchain, charon@swift-runtime, libc++, apple-compat and Styx (charon@styx, built against the same runtime) that ../rtpkg requires, from the shared xmake store
STUDY=${STUDY:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}
# every package is the one ../rtpkg requires, in the shared xmake store, named by xmake itself (charon's `xmake where`)
pkg_where() {
    local d
    d=$(cd "$STUDY/rtpkg" && xmake where "$1") && d=${d##*$'\n'} && [ -d "$d" ] && echo "$d" && return 0
    echo "pkg-env: ../rtpkg names no installed $1; install its packages with (cd rtpkg && xmake f -p iphoneos -a armv7 -y)" >&2
    return 1
}
# sourced, a failure returns to the script; run on its own, it exits
ST=$(pkg_where styx) && RT=$(pkg_where swift-runtime) && LIBCXX=$(pkg_where libcxx) && COMPAT=$(pkg_where apple-compat) &&
    SDKPKG=$(pkg_where iphoneos-sdk) && LLVM=$(pkg_where llvm) && LD=$(pkg_where ld64)/bin/ld && LDID=$(pkg_where ldid)/bin/ldid ||
    { return 1 2>/dev/null || exit 1; }
SWIFTC=$(grep -A1 'SWIFT_EXEC' $RT/manifest.txt | tail -1 | tr -d ' "')
# the manifest records the compiler by absolute path, which is whatever machine built the package; if that one is gone, the
# compiler is a package of ours too, so take it from the store the runtime came from -- the same layout one level out
[ -x "$SWIFTC" ] || SWIFTC=$(ls -td "${RT%%/s/swift-runtime/*}"/s/swift/*/*/bin/swiftc 2>/dev/null | head -1)
[ -x "$SWIFTC" ] || { echo "pkg-env: no swiftc for the runtime at $RT" >&2; return 1 2>/dev/null || exit 1; }
SWIFTHOME=$(dirname $(dirname $SWIFTC))
OCFLAGS="-I $ST/lib/swift/iphoneos -I $ST/include/CombineHelpers"
OCLINK="-L$ST/lib -lCombine -lCombineHelpers"
SDK=$(ls -d $SDKPKG/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk)
MARK=$(grep -A1 'CHARON_SWIFT_RUNTIME_MARK' $RT/manifest.txt | tail -1 | tr -d ' "')
T=armv7-apple-ios6.0
PKGFLAGS="-target $T -clang-target $T -sdk $SDK -resource-dir $RT/lib/swift -Xfrontend -bundled-swift-runtime -runtime-compatibility-version none -plugin-path $SWIFTHOME/lib/swift/host/plugins"
RTLIBS="swiftCore swiftSwiftOnoneSupport swift_Concurrency swiftDarwin swiftObjectiveC swiftDispatch swiftCoreFoundation swiftCoreGraphics swiftFoundation swiftQuartzCore swiftUIKit swiftCoreData swiftSynchronization swift_RegexParser swift_StringProcessing swiftRegexBuilder swiftObservation"
PKGLINK="-L$RT/lib/swift/iphoneos -L$LIBCXX/lib -L$COMPAT/lib $(for l in $RTLIBS; do printf -- '-l%s ' $l; done) -lc++ -lc++abi -lapple-compat -nostdlib++ -Wl,-u,_$MARK -Wl,-rpath,@executable_path"
bundle_runtime() {
    cp $RT/lib/swift/iphoneos/*.dylib $LIBCXX/lib/libc++.1.dylib $LIBCXX/lib/libc++abi.1.dylib "$1"/
    chmod u+w "$1"/*.dylib
    for f in "$1"/*.dylib; do
        install_name_tool -id @executable_path/$(basename $f) $f 2>/dev/null
        relink_runtime $f
    done
}
relink_runtime() {
    local changes=""
    for d in $(otool -L "$1" | awk '/@rpath\//{print $1}'); do changes="$changes -change $d @executable_path/${d#@rpath/}"; done
    [ -n "$changes" ] && install_name_tool $changes "$1" 2>/dev/null
    true
}
