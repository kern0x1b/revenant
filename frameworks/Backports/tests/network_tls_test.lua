local aliases = import("host_alias", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local tls = path.join(backports, "src", "TLS")
local fixture = path.join(backports, "tests", "Network", "tls", "main.swift")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local OPTION_SOURCES = {"SecProtocolOptions13_0.m", "SecProtocolMetadata13_0.m", "SecObjectWrappers12_0.m", "SecObjectWrappersIdentity12_0.m"}

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
    local bridge = path.join(out, "RevenantTLSEngine.o")
    local options = {}
    local sources = {}
    for _, file in ipairs(OPTION_SOURCES) do
        table.insert(sources, path.join(tls, file))
    end
    local renamed = aliases.swift_flags(sources)
    clang({"-c", "-fobjc-arc", "-Wno-deprecated-declarations", "-I" .. path.join(boringssl, "include"), path.join(tls, "RevenantTLSEngine.m"), "-o", bridge})
    for _, file in ipairs(OPTION_SOURCES) do
        local object = path.join(out, path.basename(file) .. ".o")
        clang({"-c", "-fobjc-arc", "-Wno-deprecated-declarations", path.join(tls, file), "-o", object})
        table.insert(options, object)
    end
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT", "-I", path.join(tls, "RevenantTLS"), "-I", path.join(src, "RevenantNetworkC"), "-Xcc", "-I" .. path.join(boringssl, "include")},
                      os.files(path.join(src, "*.swift")),
                      {fixture, bridge},
                      options,
                      renamed,
                      {path.join(boringssl, "lib", "libssl.a"), path.join(boringssl, "lib", "libcrypto.a"), "-lc++", "-o", backport}))
    os.execv(host, {identity}, {stdout = host .. ".out"})
    os.execv(backport, {identity}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network TLS program printed nothing")
    assert(expected == got, "the backport Network TLS differs from the host in " .. out)
end
