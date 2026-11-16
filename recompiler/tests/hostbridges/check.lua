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
                           "dispatch_queue_set_specific", "dispatch_queue_get_specific", "dispatch_get_specific",
                           "dispatch_barrier_sync_f", "dispatch_barrier_async_f", "dispatch_after_f", "dispatch_apply_f",
                           "dispatch_group_async_f", "dispatch_group_notify_f", "dispatch_set_context", "dispatch_get_context",
                           "pthread_setspecific", "pthread_getspecific", "pthread_create", "pthread_join", "pthread_exit",
                           "qsort_r", "CFDictionarySetValue", "CFDictionaryGetValue", "CFDictionaryContainsKey",
                           "CFDictionaryContainsValue", "CFDictionaryGetValueIfPresent", "CFDictionaryApplyFunction",
                           "CFDictionaryCreate", "CFSetAddValue", "CFSetContainsValue", "CFSetGetValue", "CFArrayAppendValue",
                           "CFArrayGetValueAtIndex", "CFArrayGetFirstIndexOfValue", "CFArrayContainsValue", "CFArrayCreate",
                           "NSMapInsert", "NSMapGet", "NSHashInsert", "NSHashGet", "CFRunLoopTimerCreate",
                           "CFRunLoopTimerGetContext", "sysctl", "sysctlbyname"}) do
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
    for _, case in ipairs({{"objc_getAssociatedObject", "xl_narrow_word("}, {"objc_setAssociatedObject", "xl_narrow_word("},
                           {"dispatch_queue_set_specific", "xl_narrow_word("}, {"dispatch_queue_get_specific", "xl_narrow_word("},
                           {"dispatch_get_specific", "xl_narrow_word("}, {"dispatch_once_f", "xl_narrow_word("},
                           {"dispatch_after_f", "xl_narrow_word("}, {"dispatch_set_context", "xl_narrow_word("},
                           {"pthread_setspecific", "xl_narrow_word("}, {"pthread_create", "xl_narrow_word("},
                           {"qsort_r", "xl_narrow_word("}, {"CFDictionarySetValue", "xl_narrow_word("},
                           {"CFArrayCreate", "xl_narrow_word("}, {"NSMapInsert", "xl_narrow_word("}}) do
        local name, call = case[1], case[2]
        local wrapper = host_source:match("xl_h_" .. name .. "%b()%s*(%b{})")
        if not wrapper or not wrapper:find(call, 1, true) then
            corpus.fail("the host wrapper of %s does not narrow its opaque word with %s, so a word the guest builds from a 64-bit constant stops the program", name, call)
        end
    end
    local timer = host_source:match("xl_g_CFRunLoopTimerContext_to_host%b()%s*(%b{})")
    if not timer or not timer:find("h.info = (void *)xl_narrow_word(", 1, true) then
        corpus.fail("the conversion of CFRunLoopTimerContext does not narrow its info as an opaque word, so a timer whose info is a 64-bit word stops the program")
    end
    local timer_create = host_source:match("xl_h_CFRunLoopTimerCreate%b()%s*(%b{})")
    if not timer_create or not timer_create:find("_to_host(", 1, true) or timer_create:find("memset", 1, true) then
        corpus.fail("the host wrapper of CFRunLoopTimerCreate does not convert the context of the guest to the host (the SDK declares it without const but only reads it), so the timer gets info == NULL")
    end
    local join = host_source:match("xl_h_pthread_join%b()%s*(%b{})")
    if not join or not join:find("= 0;", 1, true) then
        corpus.fail("the host wrapper of pthread_join reads the result slot of the guest, which holds garbage before the call, instead of only writing it")
    end
    local function word_records(report)
        local lines = {}
        for line in report:gmatch("[^\n]+") do
            if line:find("opaque word table", 1, true) then
                table.insert(lines, line)
            end
        end
        return lines
    end
    local report = io.readfile(o("xl/report.txt"))
    for _, name in ipairs({"sysctl", "sysctlbyname"}) do
        local wrapper = host_source:match("void xl_h_" .. name .. "%b()%s*(%b{})")
        if not wrapper or not wrapper:find("xl_manual_" .. name .. "(", 1, true) then
            corpus.fail("the host wrapper of %s is not the manual bridge, so the value of an mib is handed to the guest in the layout of the host (a timeval of 8 bytes where the guest reads 16, a kinfo_proc of 492 bytes where it reads 648)", name)
        end
    end
    local bad = word_records(report)
    if #bad > 0 then
        corpus.fail("a row of the table of opaque words does not match the SDK declaration:\n%s", table.concat(bad, "\n"))
    end
    local setter = host_source:match("xl_h_objc_setAssociatedObject%b()%s*(%b{})")
    if not setter or not setter:find("xl_object_in_word(", 1, true) then
        corpus.fail("the host wrapper of objc_setAssociatedObject does not take its value as a word that may be no object, so a plain word with the policy assign (a flag of 1) stops the program with \"not an object pointer\"")
    end
    local getter = host_source:match("xl_h_objc_getAssociatedObject%b()%s*(%b{})")
    if not getter or not getter:find("xl_object_out_word(", 1, true) then
        corpus.fail("the host wrapper of objc_getAssociatedObject does not give back a plain word as it is, so a flag stored with the policy assign is looked up as an object")
    end
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/HostBridges"
    device.copy(o("xl/HostBridges"), remote)
    io.writefile(o("run.txt"), device.run(string.format("cd %s && chmod +x %s && %s 2>/dev/null", device.scratch, remote, remote)))
    local unmapped = device.run(string.format("cd %s && %s sysctl-unmapped 2>&1", device.scratch, remote))
    io.writefile(o("sysctl-unmapped.txt"), unmapped)
    local log = device.scratch .. "/word-overflow.txt"
    local overflow = device.run(string.format(
        "cd %s && (%s word-overflow > %s 2>&1 & pid=$!; i=0; while kill -0 $pid 2>/dev/null && [ $i -lt 120 ]; do sleep 1; i=$((i+1)); done; " ..
        "if kill -0 $pid 2>/dev/null; then kill -9 $pid; echo watchdog=killed; fi; wait $pid; echo status=$?); cat %s; " ..
        "killall HostBridges 2>&1; rm -f %s %s", device.scratch, remote, log, log, log, remote))
    io.writefile(o("overflow.txt"), overflow)
    corpus.same(expected, o("run.txt"), "the translated program prints something else than the Mac does")
    if not unmapped:find("sysctl net.inet.tcp.pcblist exists on this system but the bridge has no arm64 layout", 1, true) or
       not unmapped:find("sysctlbyname net.inet.tcp.pcblist status -1 errno 45", 1, true) then
        corpus.fail("a sysctl of a structure the bridge has no arm64 layout for is not refused with a message that names it and ENOTSUP:\n%s", unmapped)
    end
    if not overflow:find("holds 262144 distinct words and is full", 1, true) or overflow:find("did not overflow", 1, true) or
       overflow:find("status=0", 1, true) or overflow:find("watchdog=killed", 1, true) then
        corpus.fail("the program that hands the guest's table of opaque words 300000 distinct words does not stop with the message that the table is full:\n%s", overflow)
    end
    if not overflow:find("No matching processes", 1, true) then
        corpus.fail("a process of HostBridges is left on the phone after the overflow run:\n%s", overflow)
    end
    print("ok")
end
