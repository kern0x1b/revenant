local EXPECTED = {
    "sha256 abc", "sha256 1000 bytes", "sha1 abc",
    "aes-128-gcm 16 zero bytes ciphertext", "aes-128-gcm 16 zero bytes tag", "aes-128-gcm 16 zero bytes open", "aes-128-gcm 16 zero bytes tamper",
    "aes-256-gcm 16 zero bytes ciphertext", "aes-256-gcm 16 zero bytes tag", "aes-256-gcm 16 zero bytes open", "aes-256-gcm 16 zero bytes tamper",
    "aes-256-gcm 1000 bytes ciphertext", "aes-256-gcm 1000 bytes tag", "aes-256-gcm 1000 bytes open", "aes-256-gcm 1000 bytes tamper",
    "chacha20-poly1305 rfc 8439 ciphertext", "chacha20-poly1305 rfc 8439 tag", "chacha20-poly1305 rfc 8439 open", "chacha20-poly1305 rfc 8439 wrong aad",
    "chacha20-poly1305 rfc 8439 tamper",
    "chacha20-poly1305 16 zero bytes ciphertext", "chacha20-poly1305 16 zero bytes tag", "chacha20-poly1305 16 zero bytes open", "chacha20-poly1305 16 zero bytes tamper",
    "chacha20-poly1305 1000 bytes ciphertext", "chacha20-poly1305 1000 bytes tag", "chacha20-poly1305 1000 bytes open", "chacha20-poly1305 1000 bytes tamper"
}

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
    e, out = corpus.setup("cryptoboringssl", out)
    local libs = os.getenv("XL_SWIFTCRYPTO_LIBS")
    local headers = os.getenv("XL_BORINGSSL_INCLUDE")
    if not device_only and (not libs or not os.isdir(libs)) then
        raise("XL_SWIFTCRYPTO_LIBS must name the folder with libswiftCryptoKit.dylib (the arm64 build of revenant@swift-crypto), libswiftCore.dylib (revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
    end
    if not device_only and (not headers or not os.isdir(headers)) then
        raise("XL_BORINGSSL_INCLUDE must name the folder with CCryptoBoringSSL_aead.h and CCryptoBoringSSL_sha.h (Sources/CCryptoBoringSSL/include of the revenant@swift-crypto sources)")
    end
    local function o(file)
        return path.join(out, file)
    end
    if not device_only then
        corpus.ios(e, {"-O2", "-w", "-fno-stack-protector", "-D_FORTIFY_SOURCE=0", "-I", headers, path.join(os.scriptdir(), "main.c"),
                       path.join(libs, "libswiftCryptoKit.dylib"), "-o", o("cryptoboringssl-arm64")})
        local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib"),
                        path.join(libs, "libswiftCryptoKit.dylib")}
        translate.translate(o("cryptoboringssl-arm64"), path.join(e.recompiler, "include", "swiftdemo-includes.h"), o("xl"), images,
                            {XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"})
    end
    if host_only then
        print("ok (host part)")
        return
    end
    local device = corpus.device()
    local remote = device.scratch .. "/xl-cryptoboringssl"
    device.copy(o("xl/cryptoboringssl"), remote)
    local output = try { function ()
        return device.run(string.format("chmod +x %s && %s 2>&1; echo exit=$?; rm -f %s", remote, remote, remote))
    end } or ""
    io.writefile(o("run.txt"), output)
    io.write(output)
    local text = "\n" .. output:gsub("\r", "")
    for _, name in ipairs(EXPECTED) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            corpus.fail("the translated program did not report ok for %s", name)
        end
    end
    if text:find("\nFAIL ", 1, true) or not text:find("\ndone failures=0\nexit=0", 1, true) then
        corpus.fail("the translated program reported a failure or did not run to its end")
    end
    print("ok: BoringSSL's SHA-1, SHA-256, AES-GCM and ChaCha20-Poly1305 take their ARMv8 paths on the device (%d vectors)", #EXPECTED)
end
