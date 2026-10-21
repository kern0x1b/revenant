import("async.runjobs")
import("fixtures")

local IOS6 = {"-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot"}

local PROCESS_WIDE = {"os_unfair_lock_lock", "os_unfair_lock_trylock", "os_unfair_lock_unlock",
                      "os_unfair_recursive_lock_lock_with_options", "os_unfair_recursive_lock_unlock"}

local CALLED = {
    {"clock_gettime", "struct timespec t; return clock_gettime(CLOCK_MONOTONIC, &t);", "time.h"},
    {"fdopendir", "return fdopendir(3) != 0;", "dirent.h"},
    {"openat", "return openat(3, \"x\", 0);", "fcntl.h"},
    {"fchmodat", "return fchmodat(3, \"x\", 0600, 0);", "sys/stat.h"},
    {"unlinkat", "return unlinkat(3, \"x\", 0);", "unistd.h"},
    {"clock_getres", "struct timespec t; return clock_getres(CLOCK_MONOTONIC, &t);", "time.h"},
    {"clock_gettime_nsec_np", "return clock_gettime_nsec_np(CLOCK_MONOTONIC) != 0;", "time.h"},
    {"dispatch_get_global_queue", "return dispatch_get_global_queue(0x19, 0) != 0;", "dispatch/dispatch.h"},
    {"dispatch_async", "dispatch_async(dispatch_get_main_queue(), ^{ }); return 0;", "dispatch/dispatch.h"},
    {"dispatch_sync", "dispatch_sync(dispatch_get_main_queue(), ^{ }); return 0;", "dispatch/dispatch.h"},
    {"dispatch_group_async", "dispatch_group_async(0, dispatch_get_main_queue(), ^{ }); return 0;", "dispatch/dispatch.h"},
    {"dispatch_group_notify", "dispatch_group_notify(0, dispatch_get_main_queue(), ^{ }); return 0;", "dispatch/dispatch.h"},
    {"dispatch_after", "dispatch_after(0, dispatch_get_main_queue(), ^{ }); return 0;", "dispatch/dispatch.h"}
}

local LINKED = {"__sincos_stret", "__sincosf_stret", "__strlcpy_chk", "__strlcat_chk"}

local LATER = {"memset_s", "__progname", "arc4random_buf", "voucher_copy", "voucher_adopt", "qos_class_self", "clock_getres",
               "dispatch_get_global_queue", "dispatch_activate", "dispatch_assert_queue$V2"}

local BLOCKS = {"dispatch_block_create", "dispatch_block_create_with_qos_class", "dispatch_block_perform", "dispatch_block_wait",
                "dispatch_block_notify", "dispatch_block_cancel", "dispatch_block_testcancel"}

local SUBMITS = {"dispatch_async", "dispatch_sync", "dispatch_group_async", "dispatch_group_notify", "dispatch_after"}

local ASSERTS = {"os_unfair_lock_assert_owner", "os_unfair_lock_assert_not_owner"}

local QUEUES = {"dispatch_assert_queue_not$V2", "dispatch_assert_queue_barrier", "dispatch_queue_get_qos_class",
                "dispatch_queue_create_with_target$V2", "dispatch_queue_attr_make_with_qos_class",
                "dispatch_queue_attr_make_initially_inactive", "dispatch_queue_attr_make_with_autorelease_frequency"}

local BARRIERS = {"dispatch_queue_create", "dispatch_resume", "dispatch_source_set_event_handler", "dispatch_block_create",
                  "dispatch_block_create_with_qos_class"}

local INVERSES = {"__invert_f2", "__invert_f3", "__invert_f4", "__invert_d2", "__invert_d3", "__invert_d4"}

local ANSWERED = {
    {"cancel", "concurrent", "held=yes ran=yes alone=no second=no returned=yes"},
    {"cancel", "serial", "held=yes ran=yes alone=yes second=no returned=yes"},
    {"registration", "concurrent", "held=yes ran=yes alone=no second=no returned=yes"},
    {"registration", "serial", "held=yes ran=yes alone=yes second=no returned=yes"},
    {"neverresumed", "concurrent", "held=yes ran=no alone=n/a second=n/a returned=yes"},
    {"neverresumed", "serial", "held=yes ran=no alone=n/a second=n/a returned=yes"},
    {"retargetbefore", "concurrent", "held=yes ran=yes alone=no second=yes returned=yes"},
    {"retargetbefore", "serial", "held=yes ran=yes alone=yes second=yes returned=yes"},
    {"retargetafter", "concurrent", "held=yes ran=yes alone=no second=yes returned=yes"},
    {"retargetafter", "serial", "held=yes ran=yes alone=yes second=yes returned=yes"},
    {"onqueue", "concurrent", "held=n/a ran=yes alone=yes second=no returned=yes"},
    {"onqueue", "serial", "held=n/a ran=yes alone=yes second=no returned=yes"}
}

local SWIFT_AVAILABILITY = "struct os_system_version_s { unsigned int major, minor, patch; };\n" ..
    "extern \"C\" int os_system_version_get_current_version(struct os_system_version_s *) __attribute__((weak_import));\n" ..
    "unsigned int major(void) { os_system_version_s v = {0, 0, 0}; os_system_version_get_current_version(&v); return v.major; }\n"

local LATE = "#include <math.h>\n#include <string.h>\n" ..
    "double both(double x) { return sin(x) + cos(x); }\n" ..
    "unsigned long copy(char *d, const char *s) { char b[8]; " ..
    "return strlcpy(b, s, sizeof b) + strlcat(d, b, 8); }\n"

local CALLER = "#include <cstdlib>\nvoid *call(unsigned long n) { return ::aligned_alloc(16, n); }\n"

local function run(folder, program, argv)
    local outfile, errfile = os.tmpfile(), os.tmpfile()
    local code, errors = os.execv(program, argv or {}, {try = true, curdir = folder, stdout = outfile, stderr = errfile, timeout = 120000})
    local ran = {code = code or -1, stdout = io.readfile(outfile) or "", stderr = io.readfile(errfile) or ""}
    os.tryrm(outfile)
    os.tryrm(errfile)
    if errors == "wait process timeout" then
        ran = {code = 1, stderr = "", stdout = "FAIL  " .. program .. " did not finish in 120 seconds, which a shim that " ..
                                              "calls itself or never wakes a waiter does\n"}
    end
    return ran
end

local function clang(folder, argv)
    return run(folder, "xcrun", table.join({"clang"}, argv))
end

local function tool(folder, name, argv)
    return run(folder, "xcrun", table.join({name}, argv)).stdout
end

local function lines(text)
    return text:split("\n", {plain = true, strict = true})
end

local function words(text)
    return text:split("%s+")
end

local function contains(list, wanted)
    return table.contains(list, wanted)
end

local function ending(text, suffix)
    for _, line in ipairs(lines(text)) do
        if line:endswith(suffix) then
            return line
        end
    end
    return ""
end

local function reported(ran)
    local found = {}
    for _, line in ipairs(lines(ran.stdout)) do
        if line:startswith("FAIL") then
            table.insert(found, line:sub(7))
        end
    end
    return found
end

local function outcome(name, ran)
    local found = reported(ran)
    if ran.code ~= 0 and #found == 0 then
        table.insert(found, string.format("the %s test failed without saying why: %s %s", name, tostring(ran.code), ran.stderr:sub(-300)))
    end
    return found
end

local function silent(name, ran)
    local found = reported(ran)
    if ran.code ~= 0 and ran.stdout == "" then
        table.insert(found, string.format("the %s test failed without saying why: %s", name, ran.stderr))
    end
    return found
end

local function stderrs(steps, failed_only)
    local parts = {}
    for _, step in ipairs(steps) do
        if not failed_only or step.code ~= 0 then
            table.insert(parts, step.stderr:sub(-300))
        end
    end
    return table.concat(parts, " ")
end

local function any_failed(steps)
    for _, step in ipairs(steps) do
        if step.code ~= 0 then
            return true
        end
    end
    return false
end

local function fixture(folder, name, as)
    os.cp(path.join(os.scriptdir(), "compat", name), path.join(folder, as or name))
end

local function aligned_failures(folder, shims)
    local found = {}
    os.cp(path.join(shims, "aligned_alloc.c"), path.join(folder, "shim.c"))
    fixture(folder, "aligned.c", "main.c")
    local built = clang(folder, {"-O2", "shim.c", "main.c", "-o", "aligned"})
    if built.code ~= 0 then
        return {"the aligned_alloc shim must compile: " .. built.stderr}, true
    end
    local ran = run(folder, path.join(folder, "aligned"))
    table.join2(found, reported(ran))
    if ran.code ~= 0 and #found == 0 then
        table.insert(found, "the aligned_alloc test failed without saying why: " .. ran.stderr)
    end

    local compiled = clang(folder, table.join(IOS6, {"-c", path.join(shims, "aligned_alloc.c"), "-o", "shim.o"}))
    if compiled.code ~= 0 then
        table.insert(found, "the aligned_alloc shim must compile for armv7 on iOS 6: " .. compiled.stderr)
        return found, true
    end
    local symbols = tool(folder, "nm", {"-m", "shim.o"})
    local line = ending(symbols, " _revenant_aligned_alloc")
    if not line:find("private external", 1, true) then
        table.insert(found, "aligned_alloc must be a hidden definition so the image exports nothing libc-named: " ..
                            (line ~= "" and line or symbols))
    end
    return found
end

local function clock_failures(folder, shims)
    fixture(folder, "clock.c")
    os.mkdir(path.join(folder, "listed"))
    io.writefile(path.join(folder, "listed", "marker"), "")
    local built = clang(folder, {"-O2", path.join(shims, "clock_gettime.c"), path.join(shims, "clock_gettime_nsec_np.c"),
                                 path.join(shims, "fdopendir.c"), "clock.c", "-o", "clock"})
    if built.code ~= 0 then
        return {"the clock_gettime and fdopendir shims must compile: " .. built.stderr:sub(-400)}
    end
    return silent("clock and directory", run(folder, path.join(folder, "clock"), {path.join(folder, "listed")}))
end

local function at_failures(folder, shims)
    fixture(folder, "at.c")
    os.mkdir(path.join(folder, "at-root"))
    local built = clang(folder, {"-O2", path.join(shims, "openat.c"), path.join(shims, "fchmodat.c"), path.join(shims, "unlinkat.c"),
                                 path.join(shims, "clock_gettime.c"), "at.c", "-o", "at"})
    if built.code ~= 0 then
        return {"the *at shims must compile: " .. built.stderr:sub(-400)}
    end
    return silent("*at", run(folder, path.join(folder, "at"), {path.join(folder, "at-root")}))
end

local function renamed_failures(folder, shims, headers)
    local found = {}
    for _, case in ipairs(CALLED) do
        local symbol, call, include = case[1], case[2], case[3]
        io.writefile(path.join(folder, symbol .. ".c"), string.format("#include <%s>\nint call(void) { %s }\n", include, call))
        local called = clang(folder, table.join(IOS6, {"-include", path.join(headers, symbol .. ".h"), "-c", symbol .. ".c", "-o", symbol .. ".o"}))
        if called.code ~= 0 then
            table.insert(found, string.format("a call to %s must compile for iOS 6 with the header: %s", symbol, called.stderr:sub(-300)))
        else
            local undefined = words(tool(folder, "nm", {"-u", symbol .. ".o"}))
            if contains(undefined, "_" .. symbol) or not contains(undefined, "_revenant_" .. symbol) then
                table.insert(found, string.format("a call to %s must reach revenant_%s, never the system's weak import: %s",
                                                  symbol, symbol, table.concat(undefined, " ")))
            end
            local shim = clang(folder, table.join(IOS6, {"-Wno-unguarded-availability", "-c", path.join(shims, symbol .. ".c"),
                                                         "-o", "shim-" .. symbol .. ".o"}))
            if shim.code ~= 0 then
                table.insert(found, string.format("the %s shim must compile for armv7 on iOS 6: %s", symbol, shim.stderr:sub(-300)))
            else
                local line = ending(tool(folder, "nm", {"-m", "shim-" .. symbol .. ".o"}), " _revenant_" .. symbol)
                if not line:find("private external", 1, true) then
                    table.insert(found, string.format("revenant_%s must be hidden: %s", symbol, line))
                end
            end
        end
    end
    return found
end

local function linked_failures(folder, shims, headers)
    local found = {}
    fixture(folder, "library.c")
    local sources = {}
    for _, symbol in ipairs(LINKED) do
        table.insert(sources, path.join(shims, symbol .. ".c"))
    end
    local built = clang(folder, table.join({"-O2", "-D_FORTIFY_SOURCE=2", "-fno-builtin-sin", "-fno-builtin-cos", "-fno-builtin-sinf",
                                            "-fno-builtin-cosf"}, sources, {"library.c", "-o", "library"}))
    if built.code ~= 0 then
        table.insert(found, "the compiler-called shims must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, silent("compiler-called shims", run(folder, path.join(folder, "library"))))
    end
    for _, symbol in ipairs(LINKED) do
        if os.isfile(path.join(headers, symbol .. ".h")) then
            table.insert(found, symbol .. " is called by the compiler, not by name, so no header may rename it")
        end
        local shim = clang(folder, table.join(IOS6, {"-Os", "-c", path.join(shims, symbol .. ".c"), "-o", "shim-" .. symbol .. ".o"}))
        local listing = tool(folder, "nm", {"-m", "shim-" .. symbol .. ".o"})
        local line = ending(listing, " _" .. symbol)
        if shim.code ~= 0 or not line:find("private external", 1, true) then
            table.insert(found, string.format("%s must compile for iOS 6 as a hidden definition: %s %s", symbol, shim.stderr:sub(-300), listing))
        end
        if contains(words(tool(folder, "nm", {"-u", "shim-" .. symbol .. ".o"})), "_" .. symbol) then
            table.insert(found, symbol .. " compiled for iOS 6 must not call itself")
        end
    end
    return found
end

local function ulock_failures(folder, shims)
    local found = {}
    fixture(folder, "ulock.c")
    local built = clang(folder, {"-O2", path.join(shims, "__ulock_wait.c"), path.join(shims, "__ulock_wake.c"), "ulock.c", "-o", "ulock"})
    if built.code ~= 0 then
        table.insert(found, "the __ulock shims must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, silent("__ulock", run(folder, path.join(folder, "ulock"))))
    end
    for _, symbol in ipairs({"__ulock_wait", "__ulock_wake"}) do
        local shim = clang(folder, table.join(IOS6, {"-Os", "-c", path.join(shims, symbol .. ".c"), "-o", "shim-" .. symbol .. ".o"}))
        local listing = tool(folder, "nm", {"-m", "shim-" .. symbol .. ".o"})
        local line = ending(listing, " _" .. symbol)
        if shim.code ~= 0 or not line:find("private external", 1, true) then
            table.insert(found, string.format("%s must compile for iOS 6 as a hidden definition: %s %s", symbol, shim.stderr:sub(-300), listing))
        end
    end
    return found
end

local function sources_of(shims, symbols)
    local sources = {}
    for _, symbol in ipairs(symbols) do
        table.insert(sources, path.join(shims, symbol .. ".c"))
    end
    return sources
end

local function lock_failures(folder, shims, locks, waits)
    local found = {}
    fixture(folder, "unfair.c")
    local built = clang(folder, table.join({"-O2", "-w", "-DREVENANT_COMPAT_SYSTEM=0"}, locks, waits, {"unfair.c", "-o", "unfair"}))
    if built.code ~= 0 then
        table.insert(found, "the os_unfair_lock shims must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, outcome("os_unfair_lock", run(folder, path.join(folder, "unfair"))))
    end

    fixture(folder, "names.c")
    built = clang(folder, table.join({"-O2", "-w", "-DREVENANT_COMPAT_SYSTEM=0", "-I", shims, "names.c"}, waits, {"-o", "names"}))
    if built.code ~= 0 then
        table.insert(found, "the port-name test must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, outcome("port names", run(folder, path.join(folder, "names"))))
    end
    return found
end

local function shared_lock_failures(folder, locks, waits)
    local found = {}
    local shared = path.join(folder, "shared")
    os.mkdir(shared)
    fixture(shared, "side.c")
    fixture(shared, "images.c")
    local steps = {clang(shared, table.join({"-O2", "-w", "-fvisibility=hidden", "-DREVENANT_COMPAT_SYSTEM=0", "-dynamiclib"}, locks, waits,
                                            {"-install_name", "@rpath/libshared.dylib", "-o", "libshared.dylib"}))}
    for _, side in ipairs({"one", "two"}) do
        table.insert(steps, clang(shared, {"-O2", "-w", "-fvisibility=hidden", "-DSIDE_lock=" .. side .. "_lock", "-DSIDE_unlock=" .. side .. "_unlock",
                                           "-dynamiclib", "side.c", "-L.", "-lshared", "-install_name", "@rpath/lib" .. side .. ".dylib",
                                           "-o", "lib" .. side .. ".dylib"}))
    end
    table.insert(steps, clang(shared, {"-O2", "images.c", "-L.", "-lone", "-ltwo", "-Wl,-rpath,@executable_path", "-o", "images"}))
    if any_failed(steps) then
        table.insert(found, "two images bound to one exported lock must link: " .. stderrs(steps))
        return found
    end
    local exports = tool(shared, "nm", {"-gm", "libshared.dylib"})
    for _, symbol in ipairs(PROCESS_WIDE) do
        if ending(exports, ") external _" .. symbol) == "" then
            table.insert(found, symbol .. " must be an exported definition, since every image of a process binds to one copy")
        end
    end
    if ending(exports, " external ___ulock_wait") ~= "" or ending(exports, " external ___ulock_wake") ~= "" then
        table.insert(found, "the copy of the locks must keep __ulock_wait and __ulock_wake to itself")
    end
    local imported = tool(shared, "nm", {"-m", "libone.dylib"})
    if not imported:find("_os_unfair_lock_lock (from libshared)", 1, true) then
        table.insert(found, "an image calling os_unfair_lock_lock must bind it to the one copy: " .. imported)
    end
    table.join2(found, outcome("two-image lock", run(shared, path.join(shared, "images"))))

    local forwarding = path.join(folder, "forwarding")
    os.mkdir(forwarding)
    fixture(forwarding, "forward.c")
    steps = {clang(forwarding, table.join({"-O2", "-w", "-fvisibility=hidden", "-dynamiclib"}, locks, waits,
                                          {"-install_name", "@rpath/libshared.dylib", "-o", "libshared.dylib"})),
             clang(forwarding, {"-O2", "-w", "forward.c", "-L.", "-lshared", "-Wl,-rpath,@executable_path", "-o", "forward"})}
    if any_failed(steps) then
        table.insert(found, "the forwarding lock test must link: " .. stderrs(steps))
    else
        table.join2(found, outcome("forwarded lock", run(forwarding, path.join(forwarding, "forward"))))
    end
    return found
end

local function later_failures(folder, shims, headers)
    local found = {}
    fixture(folder, "calls.c")
    local built = clang(folder, table.join({"-O2", "-w", "-DREVENANT_COMPAT_SYSTEM=0"}, sources_of(shims, LATER), {"calls.c", "-o", "calls"}))
    if built.code ~= 0 then
        table.insert(found, "the shims of later dispatch, clock and memory calls must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, outcome("later calls", run(folder, path.join(folder, "calls"))))
    end
    fixture(folder, "version.c")
    for _, system in ipairs({"0", "1"}) do
        built = clang(folder, {"-O2", "-w", "-DREVENANT_COMPAT_SYSTEM=" .. system, path.join(shims, "os_system_version_get_current_version.c"),
                               "version.c", "-framework", "CoreFoundation", "-o", "version" .. system})
        if built.code ~= 0 then
            table.insert(found, "the os_system_version_get_current_version shim must compile: " .. built.stderr:sub(-400))
        else
            table.join2(found, outcome("system version, the system's own call " .. (system == "1" and "used" or "left out"),
                                       run(folder, path.join(folder, "version" .. system))))
        end
    end
    io.writefile(path.join(folder, "availability.mm"), SWIFT_AVAILABILITY)
    local declared = run(folder, "xcrun", table.join({"clang++"}, IOS6, {"-include", path.join(headers, "os_system_version_get_current_version.h"),
                                                                        "-c", "availability.mm", "-o", "availability.o"}))
    local undefined = declared.code == 0 and words(tool(folder, "nm", {"-u", "availability.o"})) or {}
    if declared.code ~= 0 or not contains(undefined, "_revenant_os_system_version_get_current_version") then
        table.insert(found, "Swift's own declaration of os_system_version_get_current_version must compile with the header forced " ..
                            "in and reach the shim: " .. declared.stderr:sub(-300) .. " " .. table.concat(undefined, " "))
    end
    return found
end

local function submit_failures(folder, blocks, submits)
    local found = {}
    fixture(folder, "submits.c")
    for _, case in ipairs({{"submits", {"-DREVENANT_COMPAT_SYSTEM=0"}}, {"submits-system", {}},
                           {"submits-plain", {"-DREVENANT_COMPAT_SYSTEM=0", "-DSUBMIT_PLAIN"}}}) do
        local name = case[1]
        local built = clang(folder, table.join({"-O2", "-w", "-fblocks"}, case[2], blocks, submits, {"submits.c", "-o", name}))
        if built.code ~= 0 then
            table.insert(found, string.format("the shims that submit a block must compile%s: %s", name == "submits" and "" or " for " .. name,
                                              built.stderr:sub(-400)))
        else
            local said = outcome(name, run(folder, path.join(folder, name)))
            if name ~= "submits-plain" then
                table.join2(found, said)
            else
                local broke = false
                for _, line in ipairs(said) do
                    broke = broke or line:find("submit a barrier block as Darwin does", 1, true) ~= nil
                end
                if not broke then
                    table.insert(found, "the release's own calls must break a barrier block, or the barrier scenario proves nothing: " ..
                                        table.concat(said, "; "))
                end
            end
        end
    end
    return found
end

local function assert_failures(folder, asserts, locks, waits)
    fixture(folder, "asserts.c")
    local built = clang(folder, table.join({"-O2", "-w", "-DREVENANT_COMPAT_SYSTEM=0"}, asserts, locks, waits, {"asserts.c", "-o", "asserts"}))
    if built.code ~= 0 then
        return {"the os_unfair_lock assert shims must compile: " .. built.stderr:sub(-400)}
    end
    return outcome("os_unfair_lock assert", run(folder, path.join(folder, "asserts")))
end

local function queue_failures(folder, queues)
    fixture(folder, "queues.c")
    local built = clang(folder, table.join({"-O2", "-w", "-fblocks", "-DREVENANT_COMPAT_SYSTEM=0"}, queues, {"queues.c", "-o", "queues"}))
    if built.code ~= 0 then
        return {"the dispatch queue shims must compile: " .. built.stderr:sub(-400)}
    end
    return outcome("dispatch queue", run(folder, path.join(folder, "queues")))
end

local function barrier_failures(folder, barriers)
    local found = {}
    fixture(folder, "barriers.c")
    local steps = {}
    for _, control in ipairs({"", "1"}) do
        local flags = {"-DREVENANT_COMPAT_SYSTEM=0"}
        if control ~= "" then
            table.insert(flags, "-DREVENANT_COMPAT_NO_STATE=" .. control)
        end
        local name = "barriers" .. (control ~= "" and "-control" or "")
        table.insert(steps, clang(folder, table.join({"-O1", "-w", "-fblocks"}, flags, barriers, {"barriers.c", "-framework", "Foundation", "-o", name})))
    end
    if any_failed(steps) then
        table.insert(found, "the dispatch queue and barrier source shims must compile: " .. stderrs(steps))
        return found
    end
    table.join2(found, outcome("dispatch barrier source", run(folder, path.join(folder, "barriers"))))
    local control = run(folder, path.join(folder, "barriers-control"))
    local control_fails = reported(control)
    if control.code == 0 then
        table.insert(found, "the barrier source shims without their records must differ from Darwin on the late handler, " ..
                            "and they do not: " .. control.stdout)
    elseif #control_fails ~= 1 or not control_fails[1]:startswith("late: the shim runs the handler alone") then
        table.insert(found, "the barrier source shims without their records must fail on the late handler alone: " ..
                            (#control_fails > 0 and table.concat(control_fails, "; ") or control.stdout))
    end
    return found
end

local function source_handler_failures(folder)
    local found = {}
    fixture(folder, "sourcehandlers.c")
    local built = clang(folder, {"-O2", "-w", "-fblocks", "sourcehandlers.c", "-o", "sourcehandlers"})
    if built.code ~= 0 then
        return {"the dispatch source handler probe must compile: " .. built.stderr:sub(-400)}
    end
    for _, case in ipairs(ANSWERED) do
        local scenario, width, wanted = case[1], case[2], case[3]
        local handler = scenario == "registration" and "registration" or "cancellation"
        local answered = run(folder, path.join(folder, "sourcehandlers"), {scenario, width})
        local got = table.concat(words(answered.stdout:trim()), " ")
        local prefix = scenario .. " " .. width .. ":"
        if answered.code ~= 0 and not got:startswith(prefix) then
            table.insert(found, string.format("the %s case of a source's %s handler on a %s target queue must finish and " ..
                                              "say what it found, and it did not: %s %s", scenario, handler, width, tostring(answered.code),
                                              answered.stderr:sub(-300)))
        elseif got ~= prefix .. " " .. wanted then
            table.insert(found, string.format("Darwin's own calls answer \"%s\" for a source's %s handler on a %s target " ..
                                              "queue, where this measurement recorded \"%s\"", got:sub(#prefix + 1):trim(), handler, width, wanted))
        end
    end
    return found
end

local function system_failures(folder, shims)
    local found = {}
    fixture(folder, "system-random.c")
    local built = clang(folder, {"-O2", "-w", path.join(shims, "arc4random_buf.c"), "system-random.c", "-o", "system-random"})
    if built.code ~= 0 then
        table.insert(found, "the arc4random_buf shim must compile against the system's own: " .. built.stderr:sub(-400))
    else
        table.join2(found, outcome("system arc4random_buf", run(folder, path.join(folder, "system-random"))))
    end
    fixture(folder, "alloc.m")
    built = clang(folder, {"-O2", "-w", "-fobjc-arc", "-DREVENANT_COMPAT_SYSTEM=0", path.join(shims, "objc_allocWithZone.c"),
                           path.join(shims, "objc_opt_self.c"), "alloc.m", "-framework", "Foundation", "-o", "alloc"})
    if built.code ~= 0 then
        table.insert(found, "the objc_allocWithZone shim must compile: " .. built.stderr:sub(-400))
    else
        table.join2(found, outcome("objc_allocWithZone", run(folder, path.join(folder, "alloc"))))
    end
    return found
end

local function invert_failures(folder, shims)
    fixture(folder, "invert.c")
    local steps, objects = {}, {}
    for _, symbol in ipairs(INVERSES) do
        table.insert(steps, clang(folder, {"-O2", "-w", "-fvisibility=hidden", "-D" .. symbol .. "=revenant_invert_" .. symbol:sub(-2),
                                           "-c", path.join(shims, symbol .. ".c"), "-o", "ours-" .. symbol .. ".o"}))
        table.insert(objects, "ours-" .. symbol .. ".o")
    end
    table.insert(steps, clang(folder, table.join({"-O2", "-w", "invert.c"}, objects, {"-o", "invert"})))
    if any_failed(steps) then
        return {"the __invert shims must compile beside the system's: " .. stderrs(steps, true)}
    end
    return outcome("__invert", run(folder, path.join(folder, "invert")))
end

local function definition_failures(folder, shims, headers)
    local found = {}
    local symbols = table.join(PROCESS_WIDE, LATER, BLOCKS, SUBMITS, ASSERTS, QUEUES, table.slice(BARRIERS, 1, 3),
                               {"objc_allocWithZone", "objc_opt_self", "os_system_version_get_current_version"}, INVERSES)
    for _, symbol in ipairs(symbols) do
        local process_wide = contains(PROCESS_WIDE, symbol)
        local defined = os.isfile(path.join(headers, symbol .. ".h")) and "_revenant_" .. symbol or "_" .. symbol
        for _, target in ipairs({{"armv7", "6.0"}, {"arm64", "7.0"}}) do
            local architecture, release = target[1], target[2]
            local object = "ios-" .. symbol .. "-" .. architecture .. ".o"
            local shim = clang(folder, {"-target", architecture .. "-apple-ios" .. release, "-Wno-incompatible-sysroot", "-Os", "-fvisibility=hidden",
                                        "-c", path.join(shims, symbol .. ".c"), "-o", object})
            local listing = tool(folder, "nm", {"-m", object})
            local line = ending(listing, " " .. defined)
            if shim.code ~= 0 or line == "" or (line:find("private external", 1, true) ~= nil) == process_wide then
                table.insert(found, string.format("%s must compile for %s on iOS %s as %s definition: %s %s", symbol, architecture, release,
                                                  process_wide and "an exported" or "a hidden", shim.stderr:sub(-300), listing))
            else
                local undefined = words(tool(folder, "nm", {"-u", object}))
                local atomic, objc = false, false
                for _, name in ipairs(undefined) do
                    atomic = atomic or name:startswith("___atomic_")
                    objc = objc or name:startswith("_objc_") or name:startswith("_object_") or name:startswith("_class_") or name:startswith("_sel_")
                end
                if atomic then
                    table.insert(found, string.format("%s for %s must not call the atomic library functions iOS %s lacks: %s", symbol, architecture,
                                                      release, table.concat(undefined, " ")))
                end
                if objc and not tool(folder, "otool", {"-l", object}):find("string #1 -lobjc", 1, true) then
                    table.insert(found, symbol .. " calls the Objective-C runtime, so its object must ask the linker for libobjc")
                end
            end
        end
    end
    return found
end

local function late_failures(folder)
    io.writefile(path.join(folder, "late.c"), LATE)
    local late = clang(folder, {"-target", "armv7-apple-ios9.0", "-Wno-incompatible-sysroot", "-O2", "-D_FORTIFY_SOURCE=2", "-c", "late.c", "-o", "late.o"})
    local wanted = words(tool(folder, "nm", {"-u", "late.o"}))
    if late.code ~= 0 or not contains(wanted, "___sincos_stret") or not contains(wanted, "___strlcpy_chk") then
        table.sort(wanted)
        return {"code compiled for iOS 7 or later must call these by name, or the shims cover nothing: " .. late.stderr:sub(-300) ..
                " " .. table.concat(wanted, " ")}
    end
    return {}
end

local function caller_failures(folder, headers)
    io.writefile(path.join(folder, "caller.cpp"), CALLER)
    local called = run(folder, "xcrun", table.join({"clang++"}, IOS6, {"-Werror=unguarded-availability-new", "-include",
                                                                      path.join(headers, "aligned_alloc.h"), "-c", "caller.cpp", "-o", "caller.o"}))
    if called.code ~= 0 then
        return {"a call to aligned_alloc must compile for iOS 6 with unguarded availability an error once the header is included: " ..
                called.stderr:sub(-400)}
    end
    local undefined = words(tool(folder, "nm", {"-u", "caller.o"}))
    if contains(undefined, "_aligned_alloc") or not contains(undefined, "_revenant_aligned_alloc") then
        return {"the call must reach revenant_aligned_alloc, not the system's aligned_alloc: " .. table.concat(undefined, " ")}
    end
    return {}
end

function failures(opt)
    local compat = opt.compat or path.join(opt.modules, "..", "..", "toolchain", "src", "apple-compat")
    local shims = path.absolute(path.join(compat, "src"))
    local headers = path.absolute(path.join(compat, "include", "revenant"))
    local folder = fixtures.scratch()
    local found, stop = aligned_failures(folder, shims)
    if not stop then
        local locks = sources_of(shims, PROCESS_WIDE)
        local waits = sources_of(shims, {"__ulock_wait", "__ulock_wake"})
        local blocks = sources_of(shims, BLOCKS)
        local checks = {
            function (scratch) return clock_failures(scratch, shims) end,
            function (scratch) return at_failures(scratch, shims) end,
            function (scratch) return renamed_failures(scratch, shims, headers) end,
            function (scratch) return linked_failures(scratch, shims, headers) end,
            function (scratch) return ulock_failures(scratch, shims) end,
            function (scratch) return lock_failures(scratch, shims, locks, waits) end,
            function (scratch) return shared_lock_failures(scratch, locks, waits) end,
            function (scratch) return later_failures(scratch, shims, headers) end,
            function (scratch) return submit_failures(scratch, blocks, sources_of(shims, SUBMITS)) end,
            function (scratch) return assert_failures(scratch, sources_of(shims, ASSERTS), locks, waits) end,
            function (scratch) return queue_failures(scratch, sources_of(shims, QUEUES)) end,
            function (scratch) return barrier_failures(scratch, sources_of(shims, BARRIERS)) end,
            function (scratch) return source_handler_failures(scratch) end,
            function (scratch) return system_failures(scratch, shims) end,
            function (scratch) return invert_failures(scratch, shims) end,
            function (scratch) return definition_failures(scratch, shims, headers) end,
            function (scratch) return late_failures(scratch) end,
            function (scratch) return caller_failures(scratch, headers) end
        }
        local results = {}
        runjobs("compat", function (index)
            local scratch = path.join(folder, tostring(index))
            os.mkdir(scratch)
            results[index] = checks[index](scratch)
        end, {total = #checks, comax = os.default_njob()})
        for index = 1, #checks do
            table.join2(found, results[index])
        end
    end
    os.tryrm(folder)
    return found
end
