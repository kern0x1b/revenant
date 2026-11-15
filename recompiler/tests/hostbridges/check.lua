function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local translate = import("translate", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("hostbridges", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local expected = path.join(here, "..", "data", "hostbridges", "expected.txt")
    local source = path.join(here, "main.m")
    local libraries = {"-framework", "Foundation", "-framework", "CoreGraphics"}

    os.execv("xcrun", table.join({"clang", "-arch", "arm64", "-O2", "-w", source}, libraries, {"-o", o("HostBridges-mac")}))
    os.execv(o("HostBridges-mac"), {}, {stdout = o("run-mac.txt")})
    corpus.same(expected, o("run-mac.txt"), "the Objective-C runtime and libc on this Mac print something else than expected.txt")

    corpus.ios(e, table.join({"-fuse-ld=" .. e.ld, "-O2", "-w", "-D_FORTIFY_SOURCE=0", source}, libraries, {"-o", o("HostBridges-arm64")}))
    translate.translate(o("HostBridges-arm64"), path.join(here, "includes.h"), o("xl"))
    local imports = os.iorunv("nm", {"-u", o("HostBridges-arm64")})
    for _, name in ipairs({"getaddrinfo", "freeaddrinfo", "vsscanf", "sscanf", "class_copyMethodList", "class_getMethodImplementation",
                           "method_getImplementation", "method_setImplementation", "class_addMethod", "class_replaceMethod",
                           "imp_implementationWithBlock", "imp_getBlock", "imp_removeBlock", "CGColorCreate", "CGColorGetComponents",
                           "CGImageCreateWithMaskingColors", "_NSGetArgv", "_NSGetArgc", "_progname", "getifaddrs", "freeifaddrs", "getservbyname",
                           "localeconv_l", "class_copyIvarList", "malloc_default_zone", "malloc_zone_from_ptr", "malloc_zone_malloc",
                           "malloc_zone_free", "catopen", "swprintf", "NSDataDeallocatorFree", "NSDataDeallocatorUnmap", "NSDataDeallocatorVM",
                           "_dispatch_source_type_vm", "dispatch_sync", "dispatch_async", "copyfile_state_alloc", "copyfile_state_free", "fcopyfile",
                           "dispatch_once_f", "dispatch_sync_f", "dispatch_async_f", "objc_getAssociatedObject", "objc_setAssociatedObject",
                           "dispatch_queue_set_specific", "dispatch_queue_get_specific", "dispatch_get_specific"}) do
        if not imports:find("_" .. name .. "\n", 1, true) then
            corpus.fail("the program does not import %s, so the check proves nothing about it", name)
        end
    end
    local host_source = io.readfile(o("xl/host.m"))
    for _, case in ipairs({{"dispatch_once_f", "XL_CALLBACK_CALL", true}, {"dispatch_sync_f", "XL_CALLBACK_CALL", true}, {"dispatch_async_f", "XL_CALLBACK_ONCE", false}}) do
        local name, life, released = case[1], case[2], case[3]
        local wrapper = host_source:match("void xl_h_" .. name .. "%b()%s*(%b{})")
        if not wrapper then
            corpus.fail("the translation has no host wrapper for %s, so the check of the slots of a function pointer proves nothing", name)
        end
        if not wrapper:find("_hold(", 1, true) or not wrapper:find(life, 1, true) then
            corpus.fail("the host wrapper of %s does not hold the slot of its function pointer as %s, so every distinct function the guest passes takes a slot of the pool for good", name, life)
        end
        if released and not wrapper:find("xl_callback_release(", 1, true) then
            corpus.fail("the host wrapper of %s does not release the slot of its function pointer when the call returns, though the host runs the function only during the call", name)
        end
    end
    for _, name in ipairs({"objc_getAssociatedObject", "objc_setAssociatedObject", "dispatch_queue_set_specific", "dispatch_queue_get_specific", "dispatch_get_specific"}) do
        local wrapper = host_source:match("xl_h_" .. name .. "%b()%s*(%b{})")
        if not wrapper or not wrapper:find("xl_narrow_key(", 1, true) then
            corpus.fail("the host wrapper of %s does not narrow its key as an identity, so a key the guest builds from a 64-bit constant stops the program", name)
        end
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/HostBridges"
    device.copy(o("xl/HostBridges"), remote)
    io.writefile(o("run.txt"), device.run(string.format("cd %s && chmod +x %s && %s 2>/dev/null; rm -f %s", device.scratch, remote, remote, remote)))
    corpus.same(expected, o("run.txt"), "the translated program prints something else than the Mac does")
    print("ok")
end
