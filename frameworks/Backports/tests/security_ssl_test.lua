local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local network = path.join(backports, "src", "Network")
local security = path.join(backports, "src", "Security")
local transport = path.join(security, "SecureTransport")
local fixture = path.join(backports, "tests", "Security", "securetransport", "main.c")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local expected = {
    "^strict untrusted handshake status %-9807$",
    "^break on server auth status %-9841$",
    "^write before server auth accepted status %-9800$",
    "^anchored trust evaluation trusted$",
    "^second handshake status 0$",
    "^negotiated protocol 10$",
    "^negotiated cipher 0x130[12]$",
    "^client received pong$",
    "^rejecting break on server auth status %-9841$",
    "^rejected untrusted evaluation not trusted$",
}

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

function main()
    local out = workspace.run("backports-tests", "SecureTransport")
    local boringssl = workspace.package_of("boringssl", true)
    assert(os.isfile(path.join(boringssl, "include", "openssl", "err.h")), "the macOS BoringSSL install has no headers: " .. boringssl)
    local include = {"-I" .. path.join(boringssl, "include")}
    local objects = {}
    local function compile(source, args)
        local object = path.join(out, path.basename(source) .. ".o")
        clang(table.join({"-c", "-Wno-deprecated-declarations"}, args, {source, "-o", object}))
        table.insert(objects, object)
    end
    compile(path.join(network, "RevenantTLSEngine.m"), table.join({"-fobjc-arc"}, include))
    for _, file in ipairs({"SecProtocolOptions13_0.m", "SecProtocolMetadata13_0.m", "SecObjectWrappers12_0.m", "SecObjectWrappersIdentity12_0.m"}) do
        compile(path.join(security, file), {"-fobjc-arc"})
    end
    compile(path.join(transport, "RevenantSecureTransport.m"), table.join({"-fobjc-arc", "-I" .. security, "-I" .. network}, include))
    compile(fixture, include)
    local program = path.join(out, "securetransport")
    clang(table.join(objects, {path.join(boringssl, "lib", "libssl.a"), path.join(boringssl, "lib", "libcrypto.a"),
                               "-framework", "Foundation", "-framework", "Security", "-framework", "CoreFoundation",
                               "-lc++", "-o", program}))
    os.execv(program, {identity}, {stdout = program .. ".out"})
    local lines = {}
    for line in io.lines(program .. ".out") do
        table.insert(lines, line)
    end
    assert(#lines == #expected, "the SecureTransport program printed " .. #lines .. " lines, expected " .. #expected)
    for index, pattern in ipairs(expected) do
        assert(lines[index]:match(pattern), "line " .. index .. " is '" .. lines[index] .. "', expected " .. pattern)
    end
end
