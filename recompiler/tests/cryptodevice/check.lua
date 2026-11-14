local EXPECTED = {
    "FIPS-197 C.1 AES-128 encrypt", "FIPS-197 C.1 AES-128 decrypt", "FIPS-197 C.3 AES-256 encrypt", "FIPS-197 C.3 AES-256 decrypt",
    "FIPS 180-4 SHA-256 of abc", "FIPS 180-4 SHA-1 of abc", "pmull.8h", "pmull.1q 3 x 3", "pmull.1q (x^63+1)^2", "pmull2.1q high halves",
    "sli.16b #3", "sli.4s #12", "sli.2d #40", "sli d #17", "sri.16b #3", "sri.4s #12", "sri.4s #32 keeps the destination", "sri.2d #40",
    "uaddlv.16b", "saddlv.16b", "uaddlv.8b", "uaddlv.8h", "saddlv.8h", "uaddlv.4s", "saddlv.4s",
    "fcvt s, h of 1.0", "fcvt s, h of the largest half", "fcvt s, h of the smallest subnormal", "fcvt s, h of -infinity", "fcvt s, h of a signaling NaN",
    "fcvt d, h of -2.0", "fcvt d, h of the smallest subnormal", "fcvt h, s of 1.0", "fcvt h, s rounds 65519.0 down", "fcvt h, s rounds 65520.0 to infinity",
    "fcvt h, s ties to even below", "fcvt h, s ties to even above", "fcvt h, s of 2^-25 is zero", "fcvt h, s of a signaling NaN", "fcvt h, d of 0.1",
    "fcvt h, d rounds once",
    "adcs of all ones with the carry set", "adcs of all ones with the carry set, flags", "sbcs of an all-ones operand with the borrow set",
    "sbcs of an all-ones operand with the borrow set, flags", "sbcs w of an all-ones operand with the borrow set, flags", "sbcs of zero with the borrow set",
    "sbcs of zero with the borrow set, flags", "poly1305 reduction keeps a value below p with the top limb 3",
    "poly1305 reduction subtracts p from p plus 2", "poly1305 reduction subtracts p from p plus 2, middle limb"
}

local function verify(corpus, text, where)
    text = "\n" .. text:gsub("\r", "")
    for _, name in ipairs(EXPECTED) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            io.write(text)
            corpus.fail("%s did not report ok for %s", where, name)
        end
    end
    if text:find("\nFAIL ", 1, true) then
        io.write(text)
        corpus.fail("%s reported a failure", where)
    end
    if not text:find("\ndone\n", 1, true) then
        io.write(text)
        corpus.fail("%s did not run to its end", where)
    end
end

function main(out, ...)
    local host_only, device_only = false, false
    for _, argument in ipairs({...}) do
        if argument == "--host-only" then
            host_only = true
        elseif argument == "--device-only" then
            device_only = true
        end
    end
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("cryptodevice", out)
    local function o(file)
        return path.join(out, file)
    end
    local source = path.join(os.scriptdir(), "main.c")
    if not device_only then
        os.execv("cc", {"-O2", "-march=armv8-a+crypto", "-w", source, "-o", o("cryptodevice-mac")})
        local native = os.iorunv(o("cryptodevice-mac"), {})
        verify(corpus, native, "the program on this Mac")
        io.write(native)
        corpus.ios(e, {"-march=armv8-a+crypto", "-O2", "-w", "-fno-stack-protector", "-D_FORTIFY_SOURCE=0", "-o", o("cryptodevice-arm64"), source})
        translate.translate(o("cryptodevice-arm64"), path.join(e.recompiler, "include", "common-includes.h"), o("xl"))
    end
    if host_only then
        print("ok (host part)")
        return
    end
    local device = corpus.device()
    local remote = device.scratch .. "/xl-cryptodevice"
    device.copy(o("xl/cryptodevice"), remote)
    local output = try { function ()
        return device.run(string.format("chmod +x %s && %s; echo exit=$?; rm -f %s", remote, remote, remote))
    end } or ""
    io.writefile(o("run.txt"), output)
    io.write(output)
    verify(corpus, output, "the translated program")
    if not output:find("exit=0", 1, true) then
        corpus.fail("the translated program did not exit with 0")
    end
    print("ok: the Crypto extension, SLI, SRI, SADDLV, UADDLV, the half-precision FCVT and the flags of ADCS and SBCS run on the device as on this Mac (%d checks)", #EXPECTED)
end
