local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local tests = path.join(backports, "tests")
local keys = path.join(tests, "Security", "keys")
local security = path.join(backports, "src", "Security")
local localauth = path.join(backports, "src", "LocalAuthentication")
local webauth = path.join(backports, "src", "CloudKit", "webauth")
local micro_ecc = import("Security.micro_ecc", {rootdir = tests, anonymous = true})
local spki_header = {0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
                     0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00}

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-Wno-deprecated-declarations", "-fblocks"}, args))
end

local function run(program, args)
    os.execv(program, args or {}, {stdout = program .. ".out"})
    return io.readfile(program .. ".out")
end

local function verify_with_openssl(emit)
    local point = io.readfile(path.join(emit, "public.point"), {encoding = "binary"})
    assert(#point == 65 and point:byte(1) == 4, "the emulated public key is not an uncompressed P-256 point")
    local der = path.join(emit, "public.der")
    local pem = path.join(emit, "public.pem")
    io.writefile(der, string.char(table.unpack(spki_header)) .. point, {encoding = "binary"})
    os.vrunv("openssl", {"pkey", "-pubin", "-inform", "DER", "-in", der, "-out", pem})
    local signature = path.join(emit, "signature.der")
    local verdict = os.iorunv("openssl", {"dgst", "-sha256", "-verify", pem, "-signature", signature, path.join(emit, "message.bin")})
    assert(verdict:find("Verified OK", 1, true), "openssl rejects the emulated signature: " .. verdict)
    local changed = path.join(emit, "changed.bin")
    io.writefile(changed, "messagf", {encoding = "binary"})
    local accepted = try {
        function ()
            os.iorunv("openssl", {"dgst", "-sha256", "-verify", pem, "-signature", signature, changed})
            return true
        end,
        catch {
            function ()
                return false
            end
        }
    }
    assert(not accepted, "openssl accepts the emulated signature over a changed message")
end

local contract = table.concat({
    "first create ok",
    "second create ok",
    "public first=ok second=ok",
    "first public export length=65 prefix=04",
    "first private error=-4",
    "sign ok",
    "verify own=1",
    "verify other=0",
    "verify tampered=0",
    "ecdh length=32 symmetric=1",
}, "\n") .. "\n"

function main()
    local out = workspace.run("backports-tests", "SecurityKeys")
    local source = micro_ecc.fetch(out)
    local program = path.join(keys, "main.c")
    local frameworks = {"-framework", "Foundation", "-framework", "CoreFoundation", "-framework", "Security"}
    local library = {
        path.join(security, "SecurityFunctions10_0_1.m"),
        path.join(security, "SecKey100.m"),
        path.join(security, "SecKeyElliptic10.m"),
        path.join(security, "SecureEnclaveKey9.m"),
        path.join(security, "RevenantSecKeyFail.m"),
        path.join(security, "SecItemAccessControl8.m"),
        path.join(security, "SecAccessControl8.m"),
        path.join(localauth, "LAContext.m"),
        path.join(localauth, "LAErrorDomain.m"),
        path.join(localauth, "RevenantPasscode.m"),
        path.join(localauth, "RevenantPasscodeKeyBag.m"),
        path.join(webauth, "RevenantCKWebAuth.c"),
        path.join(source, "uECC.c"),
    }
    local oracle = path.join(out, "oracle")
    local emulated = path.join(out, "emulated")
    clang({"-o", oracle, program, "-framework", "CoreFoundation", "-framework", "Security"})
    clang(table.join({"-fobjc-arc", "-DREVENANT_SECURITY_EMULATE_ACCESS_CONTROL=1", "-include", path.join(keys, "host_private.h"),
                      "-I", webauth, "-I", source, "-o", emulated, program},
                     library, frameworks, {"-Wl,-undefined,dynamic_lookup"}))
    local expected = run(oracle)
    assert(expected == contract, "the macOS Secure Enclave oracle differs from the contract in " .. out)
    local emit = path.join(out, "emit")
    os.mkdir(emit)
    assert(run(emulated, {emit}) == expected, "the emulated Secure Enclave keys differ from the macOS oracle in " .. out)
    verify_with_openssl(emit)
end
