local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local tests = path.join(backports, "tests")
local items = path.join(tests, "Security", "items")
local security = path.join(backports, "src", "Security")
local localauth = path.join(backports, "src", "LocalAuthentication")
local webauth = path.join(backports, "src", "CloudKit", "webauth")
local micro_ecc = import("Security.micro_ecc", {rootdir = tests, anonymous = true})

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-Wno-deprecated-declarations", "-fblocks"}, args))
end

local function run(program)
    os.execv(program, {}, {stdout = program .. ".out"})
    return io.readfile(program .. ".out")
end

local frameworks = {"-framework", "Foundation", "-framework", "CoreFoundation", "-framework", "Security"}
local emulate = "-DREVENANT_SECURITY_EMULATE_ACCESS_CONTROL=1"

function main()
    local out = workspace.run("backports-tests", "SecurityItems")
    local source = micro_ecc.fetch(out)
    local library = {
        path.join(security, "SecItemAccessControl8.m"),
        path.join(security, "SecAccessControl8.m"),
        path.join(security, "SecureEnclaveKey9.m"),
        path.join(security, "RevenantSecKeyFail.m"),
        path.join(localauth, "LAContext.m"),
        path.join(localauth, "LAErrorDomain.m"),
        path.join(webauth, "RevenantCKWebAuth.c"),
        path.join(source, "uECC.c"),
    }
    local include = {"-I", webauth, "-I", source}
    local host = path.join(out, "host")
    local passthrough = path.join(out, "passthrough")
    local emulated = path.join(out, "emulated")
    local contract = path.join(out, "contract")
    local fixture = path.join(items, "main.c")
    clang({"-o", host, fixture, "-framework", "CoreFoundation", "-framework", "Security"})
    clang(table.join({"-fobjc-arc", "-o", passthrough, fixture}, include, library, frameworks))
    clang(table.join({"-fobjc-arc", emulate, "-o", emulated, fixture}, include, library, frameworks))
    clang(table.join({"-fobjc-arc", emulate, "-o", contract, path.join(items, "contract.c")}, include, library, frameworks))
    local expected = run(host)
    assert(#expected > 0, "the host keychain program printed nothing")
    assert(expected == run(passthrough), "the backport keychain items differ from the host in " .. out .. " (pass-through)")
    assert(expected == run(emulated), "the backport keychain items differ from the host in " .. out .. " (emulated)")
    assert(run(contract) == "add presence status=0\ncopy presence no-ui status=-25308\nupdate presence no-ui status=-25308\ncleanup status=0\n",
        "the access-control contract differs in " .. out)
end
