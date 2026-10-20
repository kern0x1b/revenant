function main(checkout, cachefile, dylib, backports, libcxx)
    assert(checkout and cachefile and dylib and backports and libcxx, "usage: import_check.lua <checkout> <cachefile> <dylib> <Backports lib> <libcxx lib>")
    local dyld = import("apple.dyld", {rootdir = path.join(checkout, "modules"), anonymous = true})
    local providers = {}
    for _, name in ipairs({"libNetworkBackports.dylib", "libFoundationBackports.dylib", "libSecurityBackports.dylib", "libCommonCryptoBackports.dylib", "libCoreBluetoothBackports.dylib"}) do
        table.insert(providers, path.join(backports, name))
    end
    for _, name in ipairs({"libc++.1.dylib", "libc++abi.1.dylib"}) do
        table.insert(providers, path.join(libcxx, name))
    end
    local binaries = table.join({dylib}, providers)
    dyld.check(cachefile, binaries, nil, {exempt = providers})
    return true
end
