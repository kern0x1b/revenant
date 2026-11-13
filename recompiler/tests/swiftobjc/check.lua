local EXPECTED = {
    "client.bump", "client.make", "client.block", "client.dyncast", "client.sametype", "objc.responds", "objc.perform", "objc.kind",
    "objc.hash", "sub.vtable", "sub.dispatch", "sub.dyncast", "sub.superclass", "ivars.released", "ivars.released.sub",
    "host.create", "host.dispatch", "host.subtype", "host.init", "name.plain", "name.client",
    "anycollection.int", "anycollection.string", "mirror.children", "describe.struct", "describe.class"
}

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("swiftobjc", out)
    local libs = os.getenv("XL_SWIFTOBJC_LIBS")
    if not libs or not os.isdir(libs) then
        raise("XL_SWIFTOBJC_LIBS must name the folder with libswiftCore.dylib (the arm64 runtime of revenant@swift-runtime), libc++.1.dylib and libc++abi.1.dylib the fixture is translated with")
    end
    local swift, layouts = corpus.swift()
    os.execv(path.join(swift, "bin", "swiftc"), {"-target", "arm64-apple-ios12.0", "-sdk", e.sdk, "-Xfrontend", "-read-legacy-type-info-path=" .. layouts,
                                                 "-runtime-compatibility-version", "none", "-o", path.join(out, "fixture-arm64"), path.join(os.scriptdir(), "fixture.swift")})
    local includes = path.join(e.recompiler, "include", "swiftdemo-includes.h")
    local images = {path.join(libs, "libswiftCore.dylib"), path.join(libs, "libc++.1.dylib"), path.join(libs, "libc++abi.1.dylib")}
    translate.translate(path.join(out, "fixture-arm64"), includes, path.join(out, "xl"), images,
                        {XL_REPLACES = "/usr/lib/libc++.1.dylib=" .. path.join(libs, "libc++.1.dylib"), XL_SWIFT_HOST_ANCESTORS = "1"})

    local device = corpus.device()
    device.copy(path.join(out, "xl", "fixture"), "/var/tmp/xl-fixture-swiftobjc")
    local output = try { function ()
        return device.run("chmod +x /var/tmp/xl-fixture-swiftobjc && /var/tmp/xl-fixture-swiftobjc; echo exit=$?; rm -f /var/tmp/xl-fixture-swiftobjc")
    end } or ""
    io.writefile(path.join(out, "run.txt"), output)
    local text = "\n" .. output:gsub("\r", "")
    for _, name in ipairs(EXPECTED) do
        if not text:find("\nok " .. name .. "\n", 1, true) then
            io.write(output)
            corpus.fail("the fixture did not report ok for %s", name)
        end
    end
    if text:find("\nFAIL ", 1, true) then
        io.write(output)
        corpus.fail("the fixture reported a failure")
    end
    if not text:find("\ndeinit Token 9\n", 1, true) then
        io.write(output)
        corpus.fail("the Swift deinit of a Token (reached through the host's dealloc) did not run")
    end
    if not text:find("\ndone\nexit=0\n", 1, true) then
        io.write(output)
        corpus.fail("the fixture did not run to its end with exit 0")
    end
    print("ok: Swift classes with an NSObject ancestor construct, dispatch, subclass and deinit (%d checks)", #EXPECTED)
end
