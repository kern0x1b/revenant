local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "cseam", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-Onone"}, args))
end

function main()
    local boringssl = workspace.package_of("boringssl", true)
    assert(os.isfile(path.join(boringssl, "include", "openssl", "err.h")), "the macOS BoringSSL install has no headers: " .. boringssl)
    local out = workspace.run("backports-tests", "NetworkCSeam")
    swiftc({"-c", fixture, "-o", path.join(out, "host.o")})

    local modules = path.join(out, "modules")
    os.mkdir(modules)
    local network = table.join({"-emit-module", "-emit-module-path", path.join(modules, "Network.swiftmodule"), "-module-name", "Network",
                                "-parse-as-library", "-D", "REVENANT_BACKPORT", "-I", path.join(backports, "src", "TLS", "RevenantTLS"),
                                "-I", path.join(src, "RevenantNetworkC"), "-Xcc", "-I" .. path.join(boringssl, "include")},
                               os.files(path.join(src, "*.swift")))
    swiftc(network)

    local consumer = {"-I", modules, "-I", path.join(src, "RevenantNetworkC"), fixture}
    swiftc(table.join({"-c"}, consumer, {"-o", path.join(out, "backport.o")}))
    local ir = path.join(out, "backport.ll")
    swiftc(table.join({"-emit-ir"}, consumer, {"-o", ir}))
    assert(not io.readfile(ir):find('!"Network"', 1, true),
           "the backport's consumer of import Network carries -framework Network in llvm.linker.options: " .. ir)

    local probe = path.join(out, "sdk_network_probe.swift")
    io.writefile(probe, "import Network\nimport RevenantNetworkC\nlet domain = nw_error_domain_posix\n_ = domain\n")
    os.vrunv("xcrun", {"swiftc", "-typecheck", "-sdk", workspace.sdk(), "-target", "arm64-apple-ios12.0",
                       "-I", path.join(src, "RevenantNetworkC"), probe})
end
