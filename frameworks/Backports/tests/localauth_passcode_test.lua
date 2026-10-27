local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local tests = path.join(backports, "tests")
local passcode = path.join(tests, "LocalAuthentication", "passcode")
local localauth = path.join(backports, "src", "LocalAuthentication")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-Wno-deprecated-declarations", "-fblocks"}, args))
end

local function run(program)
    os.execv(program, {}, {stdout = program .. ".out"})
    return io.readfile(program .. ".out")
end

local contract = table.concat({
    "map 0=accepted -2=unavailable -1=rejected -3=rejected -8=rejected -9=rejected",
    "style 0=simple 1=simple 2=complex 7=complex current=complex",
    "valid simple 1234=1 123=0 12a4=0 12345=1 empty=0",
    "valid complex abc!=1 empty=0",
    "verify accepted accepted calls=1 bytes=1234",
    "verify refused unavailable calls=1 bytes=1234",
    "verify rejected rejected calls=1 bytes=1234",
    "verify rejected-3 rejected calls=1 bytes=1234",
    "verify unreachable unavailable calls=1 bytes=1234",
    "verify short rejected calls=0 bytes=-",
    "verify letters rejected calls=0 bytes=-",
    "outcome cancelled=cancelled",
    "outcome ok=accepted",
    "la evaluate=0 code=-1004",
    "present unavailable",
}, "\n") .. "\n"

function main()
    local out = workspace.run("backports-tests", "LocalAuthPasscode")
    local program = path.join(out, "passcode")
    local sources = {
        path.join(passcode, "main.m"),
        path.join(localauth, "RevenantPasscode.m"),
        path.join(localauth, "LAContext.m"),
        path.join(localauth, "LAErrorDomain.m"),
    }
    local frameworks = {"-framework", "Foundation", "-framework", "CoreFoundation"}
    clang(table.join({"-fobjc-arc", "-I", localauth, "-o", program}, sources, frameworks))
    local result = run(program)
    assert(result == contract, "the passcode contract differs in " .. out .. ":\n" .. result)
end
