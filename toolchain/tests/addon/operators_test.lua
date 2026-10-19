import("fixtures")

local RUNTIME = [=[
#include <cstdlib>
#include <new>
[[gnu::weak]] void *operator new(std::size_t size) { if (void *p = std::malloc(size)) return p; std::abort(); }
[[gnu::weak]] void *operator new[](std::size_t size) { return ::operator new(size); }
[[gnu::weak]] void operator delete(void *p) noexcept { std::free(p); }
[[gnu::weak]] void operator delete[](void *p) noexcept { ::operator delete(p); }
]=]

local CLIENT = "int *kept;\nint *make(int n) { kept = new int(n); delete kept; kept = new int[n]; delete[] kept; return kept; }\n"

local REPLACEMENT = [[
#include <cstdlib>
#include <new>
void *operator new(std::size_t size) { return std::malloc(size); }
int *kept;
int *make(int n) { kept = new int(n); delete kept; return kept; }
]]

local WEAK_DEFINES = 0x8000
local BINDS_TO_WEAK = 0x10000

local function operator_bindings(macho, file)
    local data = macho.read(file)
    local image = macho.images(data)[1]
    local found = {}
    for _, binding in ipairs(macho.weak_bindings(data, image)) do
        if binding.name:find("^__Zn[wa]") or binding.name:find("^__Zd[la]") then
            found[binding.name] = binding
        end
    end
    return found, image.flags
end

local function link(folder, opt, output, source, extra)
    fixtures.run(folder, opt.clang .. "++", table.join({"-target", "armv7-apple-ios6.0", "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                                                       "-fuse-ld=" .. opt.ld64, "-nostdlib++", "-dynamiclib", "-O2"},
                                                      extra or {}, {source, "-o", output}))
    return path.join(folder, output)
end

function failures(opt)
    local macho = import("apple.macho", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local list = path.join(opt.modules, "..", "packages", "l", "libcxx", "operators-not-weak.exp")
    io.writefile(path.join(folder, "runtime.cpp"), RUNTIME)
    io.writefile(path.join(folder, "client.cpp"), CLIENT)
    io.writefile(path.join(folder, "replacement.cpp"), REPLACEMENT)
    os.mkdir(path.join(folder, "weak"))
    os.mkdir(path.join(folder, "ordinary"))
    local weak = link(folder, opt, "weak/libruntime.dylib", "runtime.cpp", {"-install_name", "@rpath/libruntime.dylib"})
    local ordinary = link(folder, opt, "ordinary/libruntime.dylib", "runtime.cpp",
                          {"-install_name", "@rpath/libruntime.dylib", "-Wl,-force_symbols_not_weak_list," .. list})

    local bindings, flags = operator_bindings(macho, ordinary)
    if #table.keys(bindings) > 0 or flags & (WEAK_DEFINES | BINDS_TO_WEAK) ~= 0 then
        table.insert(found, "a runtime linked with operators-not-weak.exp must neither define nor bind operator new and delete weakly, and stay out of dyld's coalescing")
    end
    if fixtures.run(folder, "xcrun", {"nm", "-gm", ordinary}):find("weak external", 1, true) then
        table.insert(found, "operators-not-weak.exp must leave no weak operator new or delete in the runtime")
    end
    local _, weak_flags = operator_bindings(macho, weak)
    if weak_flags & WEAK_DEFINES == 0 then
        table.insert(found, "the fixture runtime without the list must define its operators weakly, or the check above proves nothing")
    end

    local client = link(folder, opt, "libclient.dylib", "client.cpp", {"-Lordinary", "-lruntime"})
    bindings, flags = operator_bindings(macho, client)
    if #table.keys(bindings) > 0 or flags & BINDS_TO_WEAK ~= 0 then
        table.insert(found, "a client of the runtime must bind operator new and delete two-level, never weakly")
    end
    local weak_client = link(folder, opt, "libweakclient.dylib", "client.cpp", {"-Lweak", "-lruntime"})
    bindings = operator_bindings(macho, weak_client)
    if not (bindings.__Znwm and bindings.__Znwm.bound) then
        table.insert(found, "a client of a runtime with weak operators binds them weakly, or the client check proves nothing")
    end

    local replaced = link(folder, opt, "libreplaced.dylib", "replacement.cpp", {"-Lordinary", "-lruntime"})
    bindings = operator_bindings(macho, replaced)
    if bindings.__Znwm and bindings.__Znwm.overrides then
        table.insert(found, "an image replacing operator new against a runtime that defines it ordinarily is not marked as overriding")
    end
    if not fixtures.run(folder, "xcrun", {"nm", "-gmU", replaced}):find("external[^\n]*__Znwm\n") then
        table.insert(found, "an image replacing operator new must still link and export its own definition")
    end
    local replaced_weak = link(folder, opt, "libreplacedweak.dylib", "replacement.cpp", {"-Lweak", "-lruntime"})
    bindings = operator_bindings(macho, replaced_weak)
    if not (bindings.__Znwm and bindings.__Znwm.overrides) then
        table.insert(found, "against a runtime that defines operator new weakly, ld marks a replacement as overriding it process-wide")
    end
    os.tryrm(folder)
    return found
end
