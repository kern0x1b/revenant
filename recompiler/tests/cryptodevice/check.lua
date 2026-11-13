local EXPECTED = {
    "FIPS-197 C.1 AES-128 encrypt", "FIPS-197 C.1 AES-128 decrypt", "FIPS-197 C.3 AES-256 encrypt", "FIPS-197 C.3 AES-256 decrypt",
    "FIPS 180-4 SHA-256 of abc", "FIPS 180-4 SHA-1 of abc", "pmull.8h", "pmull.1q 3 x 3", "pmull.1q (x^63+1)^2", "pmull2.1q high halves"
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
    device.copy(o("xl/cryptodevice"), "/var/tmp/xl-cryptodevice")
    local output = try { function ()
        return device.run("chmod +x /var/tmp/xl-cryptodevice && /var/tmp/xl-cryptodevice; echo exit=$?; rm -f /var/tmp/xl-cryptodevice")
    end } or ""
    io.writefile(o("run.txt"), output)
    io.write(output)
    verify(corpus, output, "the translated program")
    if not output:find("exit=0", 1, true) then
        corpus.fail("the translated program did not exit with 0")
    end
    print("ok: the Crypto extension runs on the device as on this Mac (%d vectors)", #EXPECTED)
end
