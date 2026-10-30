import("core.base.json")
import("fixtures")

local function cache(file, architecture, exported, installed)
    installed = installed or "/usr/lib/libSystem.B.dylib"
    exported = table.wrap(exported)
    local strings = "\0" .. table.concat(exported, "\0") .. "\0"
    local image, header, segment = 0x100, 28, 56
    local symbols = image + header + segment + 24
    local symbol_table = symbols + 12 * #exported
    local name = symbol_table + #strings
    local size = name + #installed + 1
    local data = {}
    local function put(at, bytes)
        table.insert(data, {at, bytes})
    end
    put(0, ("dyld_v1" .. string.rep(" ", 8 - #architecture) .. architecture .. "\0"))
    put(16, string.pack("<I4I4I4I4", 0x40, 1, 0x60, 1))
    put(0x40, string.pack("<I8I8I8I4I4", 0, size, 0, 5, 5))
    put(0x60, string.pack("<I8I8I8I4", image, 0, 0, name))
    put(image, string.pack("<I4i4i4I4I4I4I4", 0xFEEDFACE, 12, 9, 6, 2, segment + 24, 0))
    put(image + header, string.pack("<I4I4c16I4I4I4I4i4i4I4I4", 0x1, segment, "__LINKEDIT", 0, size, 0, size, 1, 1, 0, 0))
    put(image + header + segment, string.pack("<I4I4I4I4I4I4", 0x2, 24, symbols, #exported, symbol_table, #strings))
    local offset = 1
    for index, symbol in ipairs(exported) do
        put(symbols + 12 * (index - 1), string.pack("<I4BBi2I4", offset, 0x0F, 1, 0, 0))
        offset = offset + #symbol + 1
    end
    put(symbol_table, strings)
    put(name, installed .. "\0")
    local bytes = string.rep("\0", size)
    for _, piece in ipairs(data) do
        bytes = bytes:sub(1, piece[1]) .. piece[2] .. bytes:sub(piece[1] + #piece[2] + 1)
    end
    io.writefile(file, bytes, {encoding = "binary"})
    return file
end

local function dylib(folder, ld64, name, triple, imported, extra)
    io.writefile(path.join(folder, name .. ".c"), string.format("extern int %s(void);\nint use(void) { return %s(); }\n", imported:sub(2), imported:sub(2)))
    return fixtures.link(folder, ld64, name .. ".dylib", triple, name .. ".c", table.join({"-dynamiclib"}, extra or {}))
end


local function public_path_step(dyld, folder, found)
    local private = "/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface"
    local public = "/System/Library/Frameworks/IOSurface.framework/IOSurface"
    local cacheobj = dyld.load(cache(path.join(folder, "public"), "armv7", {"_IOSurfaceCreate"}, private))
    if cacheobj.libraries[public] then
        table.insert(found, "the cache built for the public-path check holds " .. public .. " itself, so what exported_by answers proves nothing")
    end
    if dyld.exported_by(cacheobj, public, "_IOSurfaceCreate") then
        table.insert(found, "a cache that holds only the private path answers for the public one, so a symbol is placed where a client cannot bind it")
    end
    if not dyld.exported_by(cacheobj, private, "_IOSurfaceCreate") then
        table.insert(found, "a cache does not answer for the install name it itself holds")
    end
    local other = cache(path.join(folder, "public-later"), "armv7", {"_VTCompressionSessionCreate"}, "/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox")
    if not dyld.exported_by(dyld.load(other), "/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", "_VTCompressionSessionCreate") then
        table.insert(found, "a cache that holds VideoToolbox under Frameworks does not answer for the name it holds")
    end
end
local function reshaped(macho, file, change)
    local data = io.readfile(file, {encoding = "binary"})
    for _, at in ipairs(macho.images(data)[1].command_at) do
        local command = string.unpack("<I4", data, at + 1)
        if command == 0x22 or command == 0x80000022 then
            local offset, size = string.unpack("<I4I4", data, at + 41)
            local moved, resized = change(offset, size, #data)
            io.writefile(file, data:sub(1, at + 40) .. string.pack("<I4I4", moved, resized) .. data:sub(at + 49), {encoding = "binary"})
            return
        end
    end
    raise("%s has no LC_DYLD_INFO whose export trie can be moved", file)
end

local function malformed_trie_step(opt, dyld, found)
    local macho = import("apple.macho", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    local armv7 = cache(path.join(folder, "dyld_shared_cache_armv7"), "armv7", "_trie_exported")
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder"))
    io.writefile(path.join(folder, "trie.c"), "int trie_exported(void) { return 1; }\n")
    local install = "/usr/lib/revenant/trie-armv7.dylib"
    local good = fixtures.link(folder, opt.ld64, "trie-armv7.dylib", "armv7-apple-ios6.0", "trie.c", {"-dynamiclib", "-install_name", install})
    local cases = {
        {"an export trie cut short inside its first label", function (offset) return offset, 2 end, "is not terminated"},
        {"an export trie that starts past the end of its file", function (offset, size, length) return length + 16, size end, "runs past its"}
    }
    if fixtures.refusal(function () dyld.missing_imports(armv7, {good}) end) then
        table.insert(found, "an image whose export trie is well formed must parse")
    end
    for index, case in ipairs(cases) do
        local bad = path.join(folder, "bad" .. index .. ".dylib")
        os.cp(good, bad)
        reshaped(macho, bad, case[2])
        local errors = fixtures.refusal(function () dyld.missing_imports(armv7, {bad}) end) or ""
        if not errors:find(case[3], 1, true) or not errors:find(bad, 1, true) then
            table.insert(found, case[1] .. " must be refused as a malformed export trie that names the image: " .. errors)
        end
    end
    os.tryrm(folder)
end

function failures(opt)
    local dyld = import("apple.dyld", {rootdir = opt.modules, anonymous = true})
    local found = {}
    public_path_step(dyld, fixtures.scratch(), found)
    malformed_trie_step(opt, dyld, found)
    local folder = fixtures.scratch()
    local armv7 = cache(path.join(folder, "dyld_shared_cache_armv7"), "armv7", "_exported")
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder, _exported, _nested, ___divti3, _arrived, _objc_storeStrong, __availability_version_check"))
    io.writefile(path.join(folder, "libother.tbd"), fixtures.system_stub("_elsewhere", "/usr/lib/libother.dylib"))
    io.writefile(path.join(folder, "libgone.tbd"), fixtures.system_stub("_gone", "/usr/lib/libgone.dylib"))
    local clean = dylib(folder, opt.ld64, "clean-armv7", "armv7-apple-ios6.0", "_exported")
    local late = dylib(folder, opt.ld64, "late-armv7", "armv7-apple-ios6.0", "___divti3")
    local wide = dylib(folder, opt.ld64, "wide-arm64", "arm64-apple-ios7.0", "___divti3")
    local loads = dylib(folder, opt.ld64, "loads-armv7", "armv7-apple-ios6.0", "_exported", {"-lgone"})
    local cases = {
        {"an armv7 slice importing only what the cache exports, beside an arm64 slice importing what it does not", {clean, wide}, nil},
        {"an armv7 slice importing what the cache does not export", {late, wide}, "___divti3"},
        {"a binary with no slice an armv7 device loads", {wide}, "no slice a armv7 device loads"},
        {"a binary loading a library neither the device nor the build provides", {loads}, "loads /usr/lib/libgone"}
    }
    for index, case in ipairs(cases) do
        local merged = path.join(folder, "merged" .. index .. ".dylib")
        fixtures.run(folder, "xcrun", table.join({"lipo", "-create"}, case[2], {"-output", merged}))
        local missing = dyld.missing_imports(armv7, {merged})
        local described = {}
        for _, entry in ipairs(missing) do
            table.insert(described, entry[2])
        end
        local text = table.concat(described, "; ")
        if not case[3] and #missing > 0 then
            table.insert(found, case[1] .. " must pass: " .. text)
        elseif case[3] and not text:find(case[3], 1, true) then
            table.insert(found, case[1] .. " must be refused naming " .. case[3] .. ": " .. text)
        end
    end
    io.writefile(path.join(folder, "provider.c"), "int arrived(void) { return 1; }\n")
    local provider = fixtures.link(folder, opt.ld64, "libprovider.dylib", "armv7-apple-ios6.0", "provider.c",
                                   {"-dynamiclib", "-install_name", "/usr/lib/revenant/libprovider.dylib"})
    io.writefile(path.join(folder, "weak.c"), "extern int arrived(void) __attribute__((weak_import));\nint use(void) { return arrived ? arrived() : 0; }\n")
    local system_first = fixtures.link(folder, opt.ld64, "system-first.dylib", "armv7-apple-ios6.0", "weak.c", {"-dynamiclib", "-lprovider"})
    fixtures.run(folder, "xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-fuse-ld=" .. opt.ld64, "-nostdlib", "-L.",
                                   "-lprovider", "-lSystem", "-dynamiclib", "-o", "provider-first.dylib", "weak.c"})
    local provider_first = path.join(folder, "provider-first.dylib")
    local unprovided = fixtures.link(folder, opt.ld64, "unprovided.dylib", "armv7-apple-ios6.0", "weak.c", {"-dynamiclib"})
    local weak = fixtures.refusal(function () dyld.check(armv7, {system_first, provider}) end) or ""
    if not weak:find("_arrived (weakly bound to /usr/lib/libSystem.B.dylib, which does not export it, while /usr/lib/revenant/libprovider.dylib does", 1, true) then
        table.insert(found, "a weak import bound to a system library that lacks it, while a library of the build provides it, must be refused: " .. weak)
    end
    local recorded = {[path.filename(system_first)] = {_arrived = "weak.c's own test of the pointer"}}
    local guarded_order = fixtures.refusal(function () dyld.check(armv7, {system_first, provider}, nil, {runtime = {system_first}, guards = recorded}) end)
    if guarded_order then
        table.insert(found, "a weak import bound to the system library while a library of the build provides it, in a copy of the runtime's image whose guard table records it, must be reported, not refused: " .. guarded_order)
    end
    local warned_order = guarded_order and "" or table.concat(dyld.check(armv7, {system_first, provider}, nil, {runtime = {system_first}, guards = recorded}) or {}, "\n")
    if not guarded_order and (not warned_order:find("_arrived (weakly bound to /usr/lib/libSystem.B.dylib", 1, true) or not warned_order:find("weak.c's own test of the pointer", 1, true)) then
        table.insert(found, "the order a recorded guard excuses must still be reported, with the guard: " .. warned_order)
    end
    local unrecorded_order = fixtures.refusal(function () dyld.check(armv7, {system_first, provider}, nil, {runtime = {system_first}, guards = {}}) end) or ""
    if not unrecorded_order:find("_arrived (weakly bound to /usr/lib/libSystem.B.dylib", 1, true) then
        table.insert(found, "a copy of the runtime's image whose guard table records no guard for the import must still be refused for the order: " .. unrecorded_order)
    end
    local other_guard = {[path.filename(system_first)] = {_elsewhere = "a guard for another symbol"}}
    local other_order = fixtures.refusal(function () dyld.check(armv7, {system_first, provider}, nil, {runtime = {system_first}, guards = other_guard}) end) or ""
    if not other_order:find("_arrived (weakly bound to /usr/lib/libSystem.B.dylib", 1, true) then
        table.insert(found, "a guard recorded for another symbol of the image must not excuse this one's order: " .. other_order)
    end
    local exempted_order = fixtures.refusal(function () dyld.check(armv7, {system_first, provider}, nil, {exempt = {system_first}}) end)
    if exempted_order then
        table.insert(found, "a link order inside another package's image is that package's to answer for, and must be reported, not refused: " .. exempted_order)
    end
    local missing, _, _, _, ordering = dyld.missing_imports(armv7, {provider_first, provider})
    if #missing > 0 or #ordering > 0 then
        table.insert(found, "a weak import bound to the library of the build that provides it must pass")
    end
    if #dyld.missing_imports(armv7, {unprovided}) > 0 then
        table.insert(found, "a weak import the release lacks and nothing in the build provides must pass, as it runs behind a check")
    end
    local carried_bound = fixtures.refusal(function () dyld.check(armv7, {provider_first, provider}, nil, {release = true}) end)
    if carried_bound then
        table.insert(found, "a weak import bound to the carried library that exports it must pass a release check: " .. carried_bound)
    end
    local unsatisfied = fixtures.refusal(function () dyld.check(armv7, {unprovided}, nil, {release = true}) end) or ""
    if not unsatisfied:find("_arrived", 1, true) then
        table.insert(found, "a weak import nothing the process loads exports must be refused by a release check naming _arrived: " .. unsatisfied)
    end
    if fixtures.refusal(function () dyld.check(armv7, {unprovided}) end) then
        table.insert(found, "a weak import a version check can stand in front of must be reported and pass")
    end
    local released = fixtures.refusal(function () dyld.check(armv7, {unprovided}, nil, {release = true}) end) or ""
    if not released:find("_arrived", 1, true) or not released:find("revenant.waive.weak-imports", 1, true) then
        table.insert(found, "a released image that weakly imports a symbol the release lacks must be refused, naming the symbol and the waiver: " .. released)
    end
    if fixtures.refusal(function () dyld.check(armv7, {unprovided}, nil, {release = true, waived = "each call is behind a check"}) end) then
        table.insert(found, "a released image whose target waives weak-imports with a reason must pass")
    end
    local other = fixtures.link(folder, opt.ld64, "other.dylib", "armv7-apple-ios6.0", "weak.c", {"-dynamiclib"})
    local exempted = fixtures.refusal(function () dyld.check(armv7, {other}, nil, {release = true, exempt = {other}}) end)
    if exempted then
        table.insert(found, "a released build must not be refused for a weak import in a library another package provides: " .. exempted)
    end
    local relative = fixtures.refusal(function () dyld.check(armv7, {other}, folder, {release = true, exempt = {other}}) end)
    if relative then
        table.insert(found, "an exempt library must stay exempt when the check names images relative to a folder: " .. relative)
    end
    local mixed = fixtures.refusal(function () dyld.check(armv7, {unprovided, other}, nil, {release = true, exempt = {other}}) end) or ""
    if not mixed:find("unprovided.dylib", 1, true) or mixed:find("other.dylib", 1, true) then
        table.insert(found, "the program's own weak import must still be refused, and only it, when a provided library is exempt: " .. mixed)
    end
    local warned = table.concat(dyld.check(armv7, {unprovided, other}) or {}, "\n")
    if not warned:find("unprovided.dylib", 1, true) or not warned:find("other.dylib", 1, true) then
        table.insert(found, "the check's warnings must name the weak imports of every image the release lacks, not the first image's alone: " .. warned)
    end
    io.writefile(path.join(folder, "emitted.c"),
                 "extern void objc_storeStrong(void **, void *) __attribute__((weak_import));\nvoid use(void **slot) { if (objc_storeStrong) objc_storeStrong(slot, 0); }\n")
    local emitted = fixtures.link(folder, opt.ld64, "emitted.dylib", "armv7-apple-ios6.0", "emitted.c", {"-dynamiclib"})
    local refused = fixtures.refusal(function () dyld.check(armv7, {emitted}) end) or ""
    if not refused:find("_objc_storeStrong", 1, true) or not refused:find("arclite", 1, true) then
        table.insert(found, "a weak import of a symbol the compiler emits, which the release lacks and the image does not carry, must be refused naming what should carry it: " .. refused)
    end
    io.writefile(path.join(folder, "availability.c"),
                 "extern int _availability_version_check(unsigned, void *) __attribute__((weak_import));\n" ..
                 "int use(void *versions) { return _availability_version_check ? _availability_version_check(1, versions) : 0; }\n")
    local availability = fixtures.link(folder, opt.ld64, "availability.dylib", "armv7-apple-ios6.0", "availability.c", {"-dynamiclib"})
    local toolchain_refused = fixtures.refusal(function () dyld.check(armv7, {availability}, nil, {release = true}) end)
    if toolchain_refused then
        table.insert(found, "a released image must not be refused a weak import the toolchain's own code guards: " .. toolchain_refused)
    else
        local warned = table.concat(dyld.check(armv7, {availability}, nil, {release = true}) or {}, "\n")
        if not warned:find("__availability_version_check", 1, true) or not warned:find("compiler-rt", 1, true) then
            table.insert(found, "a weak import the toolchain's own code guards must be reported, naming the code that guards it: " .. warned)
        end
    end
    local copy = fixtures.link(folder, opt.ld64, "libcarried.dylib", "armv7-apple-ios6.0", "weak.c", {"-dynamiclib"})
    local recorded = {["libcarried.dylib"] = {_arrived = "weak.c: use tests arrived before calling it"}}
    local carried_refused = fixtures.refusal(function () dyld.check(armv7, {copy}, nil, {release = true, runtime = {copy}, guards = recorded}) end)
    if carried_refused then
        table.insert(found, "a carried runtime copy's weak import its guard table records must be reported, not refused: " .. carried_refused)
    else
        local warned = table.concat(dyld.check(armv7, {copy}, nil, {release = true, runtime = {copy}, guards = recorded}) or {}, "\n")
        if not warned:find("libcarried.dylib", 1, true) or not warned:find("guard table records", 1, true) then
            table.insert(found, "a carried runtime copy's recorded weak import must be named in a warning: " .. warned)
        end
    end
    local unrecorded = fixtures.refusal(function () dyld.check(armv7, {copy}, nil, {release = true, runtime = {copy}, guards = {}}) end) or ""
    if not unrecorded:find("_arrived", 1, true) or not unrecorded:find("records no guard", 1, true) then
        table.insert(found, "a carried runtime copy's weak import its guard table does not record must be refused as the program's own: " .. unrecorded)
    end
    local unreleased = fixtures.refusal(function () dyld.check(armv7, {copy}, nil, {runtime = {copy}, guards = {}}) end)
    if unreleased then
        table.insert(found, "an image that is not released is told of an unrecorded weak import, not refused it: " .. unreleased)
    end
    local guards = import("apple.runtime_guards", {rootdir = opt.modules, anonymous = true})
    local declared = guards.guards()
    local mach = {"_mach_port_destruct", "_mach_port_guard", "_mach_port_unguard"}
    for _, symbol in ipairs(mach) do
        if not declared["libswiftSystem.dylib"] or not declared["libswiftSystem.dylib"][symbol] then
            table.insert(found, "apple.runtime_guards must declare " .. symbol .. " for libswiftSystem.dylib, which swift-system carries")
        end
    end
    if not guards.declares("swift-system") then
        table.insert(found, "apple.runtime_guards must say the swift-system package declares rows of its own")
    end
    local own = fixtures.link(folder, opt.ld64, "libswiftSystem.dylib", "armv7-apple-ios6.0", "weak.c", {"-dynamiclib"})
    local recorded_own = {["libswiftSystem.dylib"] = {_arrived = "weak.c's own test of the pointer"}}
    local own_refused = fixtures.refusal(function () dyld.check(armv7, {own}, nil, {release = true, runtime = {own}, guards = recorded_own}) end)
    if own_refused then
        table.insert(found, "a weak import a package's rows record must be reported, not refused: " .. own_refused)
    else
        local own_warned = table.concat(dyld.check(armv7, {own}, nil, {release = true, runtime = {own}, guards = recorded_own}) or {}, "\n")
        if not own_warned:find("libswiftSystem.dylib", 1, true) or not own_warned:find("guard table records", 1, true) then
            table.insert(found, "a recorded weak import of a package's own library must be named in a warning: " .. own_warned)
        end
    end
    local own_unrecorded = fixtures.refusal(function () dyld.check(armv7, {own}, nil, {release = true, runtime = {own}, guards = declared}) end) or ""
    if not own_unrecorded:find("_arrived", 1, true) or not own_unrecorded:find("records no guard", 1, true) then
        table.insert(found, "a weak import a package's rows do not record must be refused as the program's own: " .. own_unrecorded)
    end
    local problems = table.concat(guards.compare({["libswiftCore.dylib"] = {"__availability_version_check", "_revenant_never_recorded"}},
        {imports = {["libswiftCore.dylib"] = {__availability_version_check = true, _revenant_never_recorded = true}}, exported = {},
         minimum = "6.1.3"}), "\n")
    if not problems:find("_revenant_never_recorded", 1, true) or problems:find("__availability_version_check", 1, true) then
        table.insert(found, "the guard table must refuse an unrecorded weak import and leave the toolchain's own guard to apple.compat: " .. problems)
    end

    local function first(list)
        local keys = {}
        for key in pairs(list) do
            table.insert(keys, key)
        end
        table.sort(keys)
        return keys[1]
    end
    local table_of = guards.guards()
    local library = first(table_of)
    local recorded = first(table_of[library])
    local at = {minimum = "6.1.3"}
    local strong_unexported = table.concat(guards.compare({[library] = {}},
        {imports = {[library] = {[recorded] = false}}, exported = {}, minimum = at.minimum}), "\n")
    if not strong_unexported:find(recorded, 1, true) or not strong_unexported:find("cannot be loaded", 1, true) then
        table.insert(found, "a row whose symbol the build imports strongly and nothing the process carries exports must be reported as a load failure: " .. strong_unexported)
    end
    local strong_exported = table.concat(guards.compare({[library] = {}},
        {imports = {[library] = {[recorded] = false}}, exported = {[recorded] = true}, minimum = at.minimum}), "\n")
    if #strong_exported ~= 0 then
        table.insert(found, "a row whose symbol the build imports strongly must be satisfied by a library the process carries, not reported: " .. strong_exported)
    end
    local not_imported = table.concat(guards.compare({[library] = {}},
        {imports = {[library] = {}}, exported = {}, minimum = at.minimum}), "\n")
    if not_imported:find(recorded, 1, true) then
        table.insert(found, "a row the build does not import at all is not a difference for the configuration that compiled its code out: " .. not_imported)
    end
    local unasked = table.concat(guards.compare({[library] = {}}, {}), "\n")
    if not unasked:find("imports were not given", 1, true) then
        table.insert(found, "a caller that gives no imports of its own must be told the comparison cannot be made: " .. unasked)
    end
    local cited = 0
    for _, each in pairs(table_of) do
        for symbol, source in pairs(each) do
            cited = cited + 1
            if type(source) ~= "string" or not source:find("%S") then
                table.insert(found, "apple.runtime_guards must cite a source for " .. symbol .. " in " .. library)
            end
        end
    end
    if cited < 50 then
        table.insert(found, "apple.runtime_guards' rows were read over: " .. cited .. " of the table's libraries, which is fewer than the table holds")
    end
    io.writefile(path.join(folder, "band.c"), "int band(void) { return 0; }\n")
    for _, case in ipairs({{"_exported", nil}, {"_arrived", "_arrived (re-exported from /usr/lib/libSystem.B.dylib, which does not export _arrived)"}}) do
        local list = path.join(folder, case[1] .. ".reexported")
        io.writefile(list, case[1] .. "\n")
        local band = fixtures.link(folder, opt.ld64, "band" .. case[1] .. ".dylib", "armv7-apple-ios6.0", "band.c", {"-dynamiclib", "-Wl,-reexported_symbols_list," .. list})
        local refused = ""
        for _, entry in ipairs(dyld.missing_imports(armv7, {band})) do
            refused = refused .. entry[2]
        end
        if case[2] and refused ~= case[2] then
            table.insert(found, "a library re-exporting a symbol the release's library lacks must be refused once, naming it: " .. refused)
        elseif not case[2] and refused ~= "" then
            table.insert(found, "a library re-exporting a symbol the release's library exports must pass: " .. refused)
        end
    end
    local libraries = path.join(folder, "home", "dyld", "2.2.1", "libraries_armv7")
    local device = path.join(libraries, "usr", "lib")
    os.mkdir(path.join(device, "system"))
    io.writefile(path.join(folder, "nested.c"), "int nested(void) { return 0; }\n")
    fixtures.link(folder, opt.ld64, path.join(device, "system", "libnested.dylib"), "armv7-apple-ios6.0", "nested.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/system/libnested.dylib"})
    io.writefile(path.join(folder, "other.c"), "int other(void) { return 0; }\n")
    fixtures.link(folder, opt.ld64, path.join(device, "libother.dylib"), "armv7-apple-ios6.0", "other.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/libother.dylib"})
    io.writefile(path.join(folder, "system.c"), "int exported(void) { return 0; }\nint elsewhere(void) { return 0; }\n")
    fixtures.link(folder, opt.ld64, path.join(device, "libSystem.B.dylib"), "armv7-apple-ios6.0", "system.c",
                  {"-dynamiclib", "-install_name", "/usr/lib/libSystem.B.dylib", "-Wl,-reexport_library," .. path.join(device, "system", "libnested.dylib")})
    local nested = dylib(folder, opt.ld64, "nested-armv7", "armv7-apple-ios6.0", "_nested")
    local bound = dylib(folder, opt.ld64, "bound-armv7", "armv7-apple-ios6.0", "_elsewhere", {"-lother"})
    local firmware = import("apple.firmware", {rootdir = opt.modules, anonymous = true})
    local function release(version, build)
        return {version = version, build = build, url = "https://example.invalid/" .. build .. ".ipsw", size = 1}
    end
    json.savefile(path.join(folder, "home", "firmware", "catalog.json"), {sources = firmware.sources(), devices = {
        {identifier = "iPhone3,1", platform = "s5l8930x", firmwares = {release("2.2.1", "5H11"), release("4.3.5", "8L1"), release("4.1", "8B117")}},
        {identifier = "iPhone5,1", platform = "s5l8950x", firmwares = {release("6.0", "10A405")}}
    }})
    local home = os.getenv("REVENANT_CACHE")
    os.setenv("REVENANT_CACHE", path.join(folder, "home"))
    local held = firmware.source("armv7", "2.0")
    local absent, absent_release = firmware.source("armv7", "4.0")
    local later = firmware.release_for("armv7s", "5.0")
    os.setenv("REVENANT_CACHE", home or "")
    if held ~= libraries then
        table.insert(found, "a 2.0 port must be checked against the libraries of 2.2.1, the earliest release not older than it, not " .. tostring(held))
    end
    if absent_release ~= "4.1" or not absent:endswith(path.join("4.1", "dyld_shared_cache_armv7")) then
        table.insert(found, "a 4.0 port must be checked against 4.1, the earliest armv7 release not older than 4.0, and told where its cache goes, not " .. absent)
    end
    if later ~= "6.0" then
        table.insert(found, "an armv7s port for 5.0 must be checked against 6.0, the first release on armv7s, not " .. tostring(later))
    end
    if #dyld.missing_imports(libraries, {clean}) > 0 then
        table.insert(found, "an import a device library exports must pass against the libraries folder")
    end
    local text = ""
    for _, entry in ipairs(dyld.missing_imports(libraries, {late})) do
        text = text .. entry[2]
    end
    if not text:find("___divti3", 1, true) then
        table.insert(found, "an import no device library exports must be refused against the libraries folder: " .. text)
    end
    local reexported = dyld.missing_imports(libraries, {nested})
    if #reexported > 0 then
        table.insert(found, "an import a library re-exports from another must pass: " .. reexported[1][2])
    end
    text = ""
    for _, entry in ipairs(dyld.missing_imports(libraries, {bound})) do
        text = text .. entry[2]
    end
    if not text:find("_elsewhere (bound to /usr/lib/libother.dylib, which only another library exports", 1, true) then
        table.insert(found, "an import bound to a library that does not export it must be refused even when another library does: " .. text)
    end
    local ladder = {}
    for _, rung in ipairs({{"4.0", {"_returned", "_removed"}}, {"4.3", {"_arrived"}}, {"5.0", {"_returned", "_arrived"}}}) do
        table.insert(ladder, {release = rung[1], architecture = "armv7",
                              source = cache(path.join(folder, "rungs", rung[1], "dyld_shared_cache_armv7"), "armv7", rung[2])})
    end
    io.writefile(path.join(folder, "sdk", "usr", "lib", "libSystem.tbd"), fixtures.system_stub("_returned, _arrived, _removed, _never"))
    os.setenv("REVENANT_CACHE", path.join(folder, "home"))
    local first = dyld.first_releases(ladder, path.join(folder, "sdk"), {"_returned", "_arrived", "_removed", "_never"})
    os.setenv("REVENANT_CACHE", home or "")
    if first._returned ~= "5.0" then
        table.insert(found, "a symbol 4.0 exports and 4.3 does not is the release's own from 5.0, where it is exported again, not " .. tostring(first._returned))
    end
    if first._arrived ~= "4.3" or first._removed ~= "4.0" or first._never ~= nil then
        table.insert(found, string.format("a symbol exported from 4.3 on is 4.3's, one only 4.0 exports is 4.0's, and one no rung exports has none, not %s, %s and %s",
                                          tostring(first._arrived), tostring(first._removed), tostring(first._never)))
    end
    local errors = fixtures.refusal(function () dyld.check(path.join(folder, "absent"), {clean}) end)
    if not errors or not errors:find("no shared cache", 1, true) then
        table.insert(found, "a check with no cache to read must refuse rather than pass")
    end
    os.tryrm(folder)
    return found
end
