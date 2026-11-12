function main(out, opt)
    opt = type(opt) == "table" and opt or {}
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("hostbridges", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local expected = path.join(here, "..", "data", "hostbridges", "expected.txt")
    local source = path.join(here, "main.m")
    local libraries = {"-framework", "Foundation"}

    os.execv("xcrun", table.join({"clang", "-arch", "arm64", "-O2", "-w", source}, libraries, {"-o", o("HostBridges-mac")}))
    os.execv(o("HostBridges-mac"), {}, {stdout = o("run-mac.txt")})
    corpus.same(expected, o("run-mac.txt"), "the Objective-C runtime and libc on this Mac print something else than expected.txt")

    corpus.ios(e, table.join({"-fuse-ld=" .. e.ld, "-O2", "-w", "-D_FORTIFY_SOURCE=0", source}, libraries, {"-o", o("HostBridges-arm64")}))
    translate.translate(o("HostBridges-arm64"), path.join(here, "includes.h"), o("xl"))
    local imports = os.iorunv("nm", {"-u", o("HostBridges-arm64")})
    for _, name in ipairs({"getaddrinfo", "freeaddrinfo", "vsscanf", "sscanf", "class_copyMethodList", "class_getMethodImplementation",
                           "method_getImplementation", "method_setImplementation", "class_addMethod", "class_replaceMethod",
                           "imp_implementationWithBlock", "imp_getBlock", "imp_removeBlock"}) do
        if not imports:find("_" .. name .. "\n", 1, true) then
            corpus.fail("the program does not import %s, so the check proves nothing about it", name)
        end
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    device.copy(o("xl/HostBridges"), "/var/tmp/HostBridges")
    io.writefile(o("run.txt"), device.run("chmod +x /var/tmp/HostBridges && /var/tmp/HostBridges 2>/dev/null; rm -f /var/tmp/HostBridges"))
    corpus.same(expected, o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end
