-- Checks the armv7 libMatterBackports.dylib against the iOS 6.1.3 shared cache with modules/apple/dyld.lua's own check, the function
-- the 6.1.3 gate calls: every non-weak import must resolve against the cache's exports, and the weak ones are reported. The
-- backports and the C++ runtime the dylib links are given as its providers (checked, reported, not refused), the way the gate
-- gives another package's images. dyld.check prints the verdict line itself: "imports: every non-weak import of ...".
--
-- Usage: xmake l packages/m/matter/tests/import_check.lua <checkout> <cachefile> <libMatterBackports.dylib> <apple-backports lib> <charon@libcxx lib>
-- The cache is passed by path and read only by dyld.check; this test does not open it.
function main(checkout, cachefile, dylib, backports, libcxx)
    assert(checkout and cachefile and dylib and backports and libcxx, "usage: import_check.lua <checkout> <cachefile> <dylib> <apple-backports lib> <libcxx lib>")
    local dyld = import("apple.dyld", {rootdir = path.join(checkout, "modules"), anonymous = true})
    local providers = {}
    -- The backports the dylib links (packages/m/matter/xmake.lua, the -l list of its link): the network and foundation ones, and the
    -- security, commoncrypto and corebluetooth ones that carry SecKeyCopyExternalRepresentation, CCRandomGenerateBytes and
    -- CBAdvertisementDataIsConnectable on 6.1.3.
    for _, name in ipairs({"libNetworkBackports.dylib", "libFoundationBackports.dylib", "libSecurityBackports.dylib", "libCommonCryptoBackports.dylib", "libCoreBluetoothBackports.dylib"}) do
        table.insert(providers, path.join(backports, name))
    end
    -- The C++ runtime the link names by its packaged install name; libc++abi also provides os_unfair_lock_* (process-wide).
    for _, name in ipairs({"libc++.1.dylib", "libc++abi.1.dylib"}) do
        table.insert(providers, path.join(libcxx, name))
    end
    local binaries = table.join({dylib}, providers)
    dyld.check(cachefile, binaries, nil, {exempt = providers})
    return true
end
