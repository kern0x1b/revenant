local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local security = path.join(backports, "src", "Security")
local fixture = path.join(backports, "tests", "Network", "tls", "main.swift")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

function main()
    local out = workspace.run("backports-tests", "NetworkTLS")
    local boringssl = workspace.package_of("boringssl", true)
    assert(os.isfile(path.join(boringssl, "include", "openssl", "err.h")), "the macOS BoringSSL install has no headers: " .. boringssl)
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local bridge = path.join(out, "RevenantTLSBridge.o")
    local options = path.join(out, "SecProtocolOptions.o")
    clang({"-c", path.join(src, "CBoringSSL", "RevenantTLSBridge.c"), "-o", bridge})
    clang({"-c", "-fobjc-arc", "-Wno-deprecated-declarations", path.join(security, "SecProtocolOptions13_0.m"), "-o", options})
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT", "-I", path.join(src, "CBoringSSL"), "-Xcc", "-I" .. path.join(boringssl, "include")},
                      os.files(path.join(src, "*.swift")),
                      {fixture, bridge, options, path.join(boringssl, "lib", "libssl.a"), path.join(boringssl, "lib", "libcrypto.a"), "-lc++", "-o", backport}))
    os.execv(host, {identity}, {stdout = host .. ".out"})
    os.execv(backport, {identity}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network TLS program printed nothing")
    assert(expected == got, "the backport Network TLS differs from the host in " .. out)
end
