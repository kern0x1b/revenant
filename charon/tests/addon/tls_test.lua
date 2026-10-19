import("fixtures")

local CXX = [[
struct Tracked { int value; Tracked() : value(1) {} ~Tracked() { value = 0; } };
thread_local Tracked tracked;
thread_local int counter = 7;
int touch(void) { return tracked.value + counter; }
]]

local C = "_Thread_local int counter = 7;\nint touch(void) { return counter; }\n"

local function compile(folder, opt, triple, source, object, extra)
    return fixtures.run(folder, opt.clang, table.join({"-target", triple, "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w", "-c"},
                                                      extra or {}, {source, "-o", object}))
end

local function refused(action)
    return fixtures.refusal(action) or ""
end

local function probe_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "probe.c"), C)
    for _, case in ipairs({
            {"armv7-apple-ios6.0", false}, {"armv7s-apple-ios8.4", false}, {"armv7-apple-ios9.0", true},
            {"arm64-apple-ios7.0", false}, {"arm64-apple-ios8.0", true}}) do
        local native = refused(function () compile(folder, opt, case[1], "probe.c", "probe.o") end)
        if case[2] and native ~= "" then
            table.insert(found, case[1] .. " has native thread-local variables and the compiler refused one: " .. native)
        elseif not case[2] and not native:find("thread-local storage is not supported", 1, true) then
            table.insert(found, case[1] .. " has no dyld support for thread-local variables, and the compiler did not refuse one natively")
        end
        if not case[2] then
            local emulated = refused(function () compile(folder, opt, case[1], "probe.c", "probe.o", {"-femulated-tls"}) end)
            if emulated ~= "" then
                table.insert(found, case[1] .. " must compile a thread-local variable with -femulated-tls: " .. emulated)
            end
        end
    end
    return found
end

local function object_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "tracked.cpp"), CXX)
    compile(folder, opt, "armv7-apple-ios6.0", "tracked.cpp", "tracked.o", {"-femulated-tls", "-nostdinc++", "-fno-exceptions"})
    local symbols = fixtures.run(folder, "xcrun", {"nm", "-m", "tracked.o"})
    for _, wanted in ipairs({"___emutls_get_address", "___cxa_thread_atexit"}) do
        if not symbols:find("(undefined) external " .. wanted, 1, true) then
            table.insert(found, "a thread_local with a destructor compiled for iOS 6.0 must import " .. wanted)
        end
    end
    if symbols:find("_tlv_", 1, true) then
        table.insert(found, "emulated TLS for iOS 6.0 must not reach dyld's _tlv_ entry points, which iOS 6 lacks and iOS 7-8 stub out on armv7")
    end
    local listing = fixtures.run(folder, "xcrun", {"otool", "-l", "tracked.o"})
    if listing:find("__thread_vars", 1, true) then
        table.insert(found, "emulated TLS must leave no __thread_vars section for a dyld that cannot read it")
    end
    local version = listing:match("LC_VERSION_MIN_IPHONEOS.-version (%S+)")
    if version ~= "6.0" then
        table.insert(found, "the object must record the iOS 6.0 it was compiled for, not " .. tostring(version))
    end
    return found
end

local function private_copy_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "alone.c"), C)
    local errors = refused(function ()
        fixtures.run(folder, opt.clang, {"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                         "-femulated-tls", "-fuse-ld=" .. opt.ld64, "-dynamiclib", "alone.c", "-o", "libalone.dylib"})
    end)
    if not errors:find("___emutls_get_address", 1, true) then
        table.insert(found, "an image linked without the shared emulated TLS runtime must fail naming ___emutls_get_address: " .. errors)
    end
    return found
end

local function sdk_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "arc.m"), "@interface Probe @end\nint main(void) { __weak id weak = 0; return weak != 0; }\n")
    io.writefile(path.join(folder, "blocks.c"), "int main(void) { int k = 2; int (^b)(int) = ^(int x) { return x * k; }; return b(1) - 2; }\n")
    local common = {"-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w", "-fuse-ld=" .. opt.ld64, "-v"}
    local function linked(argv)
        local out, err = os.iorunv(opt.clang, table.join(common, argv), {curdir = folder})
        return (out or "") .. (err or "")
    end
    local arc = linked({"-target", "armv7-apple-ios4.0", "-fobjc-arc", "-Xclang", "-fobjc-runtime-has-weak", "-lobjc", "arc.m", "-o", "arc"})
    for _, wanted in ipairs({"libarclite_iphoneos.a", "-lcrt1.3.1.o", "-lgcc_s.1"}) do
        if not arc:find(wanted, 1, true) then
            table.insert(found, "an ARC executable for armv7 iOS 4.0 must link " .. wanted)
        end
    end
    local blocks = linked({"-target", "armv7-apple-ios3.0", "blocks.c", "-lBlocksRuntime", "-lobjc", "-o", "blocks"})
    for _, wanted in ipairs({"-lcrt1.o", "-lgcc_s.1"}) do
        if not blocks:find(wanted, 1, true) then
            table.insert(found, "an executable for armv7 iOS 3.0 must link " .. wanted)
        end
    end
    if not fixtures.run(folder, "xcrun", {"nm", "-m", "blocks"}):find("__Block_copy", 1, true) then
        table.insert(found, "a block for armv7 iOS 3.0 must take _Block_copy from the SDK's BlocksRuntime")
    end
    local six = linked({"-target", "armv7-apple-ios6.0", "blocks.c", "-o", "six"})
    if not six:find("libclang_rt.ios.a", 1, true) then
        table.insert(found, "an executable for armv7 iOS 6.0 must link the compiler's own libclang_rt.ios.a")
    end
    return found
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    for _, check in ipairs({probe_failures, object_failures, private_copy_failures, sdk_failures}) do
        table.join2(found, check(folder, opt))
    end
    os.tryrm(folder)
    return found
end
