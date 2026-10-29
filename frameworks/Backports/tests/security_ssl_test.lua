local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local tls = path.join(backports, "src", "TLS")
local security = path.join(backports, "src", "Security")
local transport = path.join(security, "SecureTransport")
local fixture = path.join(backports, "tests", "Security", "securetransport", "main.c")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local variants = {
    {name = "veneer", probe = "RevenantAbsentSystemSymbol", lines = {
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
        "^client option status %-4$",
        "^server context created$",
    }},
    {name = "system", io = true, lines = {
        "^strict untrusted handshake status %-9807$",
        "^break on server auth status %-9841$",
        "^anchored trust evaluation trusted$",
        "^second handshake status 0$",
        "^negotiated protocol %d+$",
        "^negotiated cipher 0x%x+$",
        "^client received pong$",
        "^rejecting break on server auth status %-9841$",
        "^rejected untrusted evaluation not trusted$",
        "^client option status 0$",
        "^server context created$",
    }},
}

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

function main()
    local out = workspace.run("backports-tests", "SecureTransport")
    local boringssl = workspace.package_of("boringssl", true)
    assert(os.isfile(path.join(boringssl, "include", "openssl", "err.h")), "the macOS BoringSSL install has no headers: " .. boringssl)
    local include = {"-I" .. path.join(boringssl, "include")}
    local function compile(source, args, folder)
        local object = path.join(folder, path.basename(source) .. ".o")
        clang(table.join({"-c", "-Wno-deprecated-declarations"}, args, {source, "-o", object}))
        return object
    end
    local shared = {}
    table.insert(shared, compile(path.join(tls, "RevenantTLSEngine.m"), table.join({"-fobjc-arc"}, include), out))
    for _, file in ipairs({"SecProtocolOptions13_0.m", "SecProtocolMetadata13_0.m", "SecObjectWrappers12_0.m", "SecObjectWrappersIdentity12_0.m"}) do
        table.insert(shared, compile(path.join(tls, file), {"-fobjc-arc"}, out))
    end
    local libraries = {path.join(boringssl, "lib", "libssl.a"), path.join(boringssl, "lib", "libcrypto.a"),
                       "-framework", "Foundation", "-framework", "Security", "-framework", "CoreFoundation", "-lc++"}
    for _, variant in ipairs(variants) do
        local folder = path.join(out, variant.name)
        os.mkdir(folder)
        local defines = variant.probe and {"-DREVENANT_SYSTEM_PROBE=\"" .. variant.probe .. "\""} or {}
        local object = compile(path.join(transport, "RevenantSecureTransport.m"), table.join({"-fobjc-arc"}, include, defines), folder)
        local fixtureDefines = variant.io and {"-DREVENANT_FIXTURE_IO_FUNCS=1"} or {}
        local fixtureObject = compile(fixture, table.join(include, fixtureDefines), folder)
        local program = path.join(folder, "securetransport")
        clang(table.join(shared, {object, fixtureObject}, libraries, {"-o", program}))
        os.execv(program, {identity}, {stdout = program .. ".out"})
        local lines = {}
        for line in io.lines(program .. ".out") do
            table.insert(lines, line)
        end
        assert(#lines == #variant.lines, variant.name .. ": the SecureTransport program printed " .. #lines .. " lines, expected " .. #variant.lines)
        for index, pattern in ipairs(variant.lines) do
            assert(lines[index]:match(pattern), variant.name .. ": line " .. index .. " is '" .. lines[index] .. "', expected " .. pattern)
        end
    end
end
