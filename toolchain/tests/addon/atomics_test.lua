import("fixtures")

local WIDE = [[
struct wide { int a, b, c; };
static _Atomic(struct wide) shared;
int bump(void) {
    struct wide seen = __c11_atomic_load(&shared, 5);
    struct wide next = seen;
    next.a += 1;
    return __c11_atomic_compare_exchange_strong(&shared, &seen, next, 5, 5);
}
]]

local function compile(folder, opt, triple, output)
    return fixtures.run(folder, opt.clang, {"-target", triple, "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w", "-c", "wide.c", "-o", output})
end

local function compiler_failures(folder, opt)
    local found = {}
    io.writefile(path.join(folder, "wide.c"), WIDE)
    for _, triple in ipairs({"armv6-apple-ios3.0", "armv7-apple-ios6.0", "armv7s-apple-ios6.0", "armv7-apple-ios7.0"}) do
        local errors = fixtures.refusal(function () compile(folder, opt, triple, "wide.o") end)
        if errors then
            table.insert(found, triple .. " must compile an atomic wider than the processor updates in one instruction: " .. errors)
        else
            local symbols = fixtures.run(folder, "xcrun", {"nm", "-m", "wide.o"})
            for _, wanted in ipairs({"___atomic_load", "___atomic_compare_exchange"}) do
                if not symbols:find("(undefined) external " .. wanted, 1, true) then
                    table.insert(found, triple .. " must call " .. wanted .. " for a 12-byte atomic")
                end
            end
            local version = fixtures.run(folder, "xcrun", {"otool", "-l", "wide.o"}):match("LC_VERSION_MIN_IPHONEOS.-version (%S+)")
            if version ~= triple:match("ios(%d+%.%d+)$") then
                table.insert(found, triple .. " must record the release it was compiled for, not " .. tostring(version))
            end
        end
    end
    return found
end

local function builtins_failures(folder, opt)
    local found = {}
    local archives = os.files(path.join(path.directory(path.directory(opt.clang)), "lib", "clang", "*", "lib", "darwin", "libclang_rt.ios.a"))
    if #archives == 0 then
        table.insert(found, "the llvm package has no libclang_rt.ios.a")
    elseif fixtures.run(folder, "xcrun", {"nm", "-g", archives[1]}):find("___atomic_load", 1, true) then
        table.insert(found, "the iOS builtins carry __atomic_load, which gives every image its own locks for memory the images share")
    end
    return found
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    for _, check in ipairs({compiler_failures, builtins_failures}) do
        table.join2(found, check(folder, opt))
    end
    os.tryrm(folder)
    return found
end
