function failures(opt)
    local swift = import("apple.swift", {rootdir = opt.modules, anonymous = true})
    local architectures = import("apple.architectures", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local base = {architecture = "armv7", deployment = "6.0", sdk = "iPhoneOS26.2.sdk", resources = "runtime/lib/swift", module = "Consumer"}
    local cxx = swift.runtime_flags(table.join(base, {cxx_headers = "libcxx/include/c++/v1", emulated_tls = true}))
    if not table.contains(cxx, "-cxx-interoperability-mode=default") then
        table.insert(found, "a Swift target given C++ headers must compile with -cxx-interoperability-mode=default, or a header module that requires cplusplus is refused")
    end
    if not table.contains(cxx, "-femulated-tls") then
        table.insert(found, "a Swift target given emulated_tls must pass -femulated-tls to the importer")
    end
    if table.contains(swift.runtime_flags(base), "-cxx-interoperability-mode=default") then
        table.insert(found, "a Swift target without C++ headers must not turn C++ interoperability on")
    end
    for _, case in ipairs({{"armv7", "6.0", true}, {"armv7", "9.0", false}, {"arm64", "7.0", true}, {"arm64", "8.0", false}}) do
        local emulated = architectures.emulated_tls(case[1], case[2])
        if emulated ~= case[3] then
            table.insert(found, string.format("%s iOS %s: emulated TLS must be %s, since native thread-local storage starts at %s",
                                              case[1], case[2], tostring(case[3]), case[1] == "arm64" and "iOS 8.0" or "iOS 9.0"))
        end
    end
    if table.concat(swift.runtime_flags(base), " "):find("-import-underlying-module", 1, true) then
        table.insert(found, "a Swift target without an underlying clang module must not pass -import-underlying-module: the compiler "
                            .. "refuses it when no clang module of the Swift module's name exists")
    end
    if not table.concat(swift.runtime_flags(table.join(base, {underlying = true})), " "):find("-Xfrontend -import-underlying-module", 1, true) then
        table.insert(found, "a Swift target whose module has an underlying clang module must pass -Xfrontend -import-underlying-module, "
                            .. "as Xcode does for a framework target")
    end
    local tests = path.join(opt.modules, "..", "tests", "swift_cxx", "std")
    if not swift.underlying_module("ProbeCxx", {tests}) or swift.underlying_module("Consumer", {tests}) then
        table.insert(found, "a module map on the Swift search path declares the Swift module's clang module only when it names it")
    end
    return found
end
