function main(checkout, cachefile, dylib, runtime, libcxx)
    assert(checkout and cachefile and dylib and runtime and libcxx, "usage: import_check.lua <checkout> <cachefile> <dylib> <runtime lib/swift/iphoneos> <libcxx lib>")
    local dyld = import("apple.dyld", {rootdir = path.join(checkout, "modules"), anonymous = true})
    local providers = {}
    for _, name in ipairs({"libswiftCore.dylib", "libswiftDarwin.dylib", "libswiftObjectiveC.dylib", "libswiftDispatch.dylib",
                           "libswift_Concurrency.dylib", "libswiftSwiftOnoneSupport.dylib"}) do
        table.insert(providers, path.join(runtime, name))
    end
    for _, name in ipairs({"libc++.1.dylib", "libc++abi.1.dylib"}) do
        table.insert(providers, path.join(libcxx, name))
    end
    local binaries = table.join({dylib}, providers)
    dyld.check(cachefile, binaries, nil, {exempt = providers})
    return true
end
