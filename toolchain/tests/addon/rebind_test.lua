import("fixtures")

local TRIPLE = "armv7-apple-ios6.0"
local AVFOUNDATION = "/System/Library/Frameworks/AVFoundation.framework/AVFoundation"
local SYSTEM = "/usr/lib/libSystem.B.dylib"
local SHIM = "/usr/lib/revenant/libSystemShim.dylib"
local PROVIDER = "/usr/lib/revenant/org.revenant.backports/libAVFoundationBackports.dylib"
local MARKED = "/usr/lib/revenant/org.revenant.backports/libMarked.dylib"
local UNMARKED = "/usr/lib/revenant/org.revenant.backports/libUnmarked.dylib"
local GETPID = "_getpid"
local AMBIENT = "_AVAudioSessionCategoryAmbient"
local DATA = "_AVAudioSessionMediaServicesWereLostNotification"
local FUNCTION = "_AVAudioSessionSilenceSecondaryAudioHint"
local FIELDS = {"flags", "type", "addend", "segment", "offset"}

local PREBUILT = [[
extern const char *AVAudioSessionMediaServicesWereLostNotification __attribute__((weak_import));
extern int AVAudioSessionSilenceSecondaryAudioHint(void);
extern const char *AVAudioSessionCategoryAmbient;
const char *use(void) {
    return AVAudioSessionSilenceSecondaryAudioHint() ? AVAudioSessionMediaServicesWereLostNotification : AVAudioSessionCategoryAmbient;
}
]]

local function built(folder, ld64, output, source, install, libraries)
    fixtures.run(folder, "xcrun", table.join({"clang", "-target", TRIPLE, "-Wno-incompatible-sysroot", "-fuse-ld=" .. ld64, "-nostdlib",
                                              "-dynamiclib", "-install_name", install}, libraries, {"-o", output, source}))
    return path.join(folder, output)
end

local function bindings(macho, data, found, stream, lazy)
    local named = {}
    for _, entry in ipairs(macho.bind_stream(data, found, stream, lazy)) do
        named[entry.name] = {library = found.libraries[entry.ordinal], flags = entry.flags, type = entry.type, addend = entry.addend,
                             segment = entry.segment, offset = entry.offset}
    end
    return named
end

local function described(entry)
    if not entry then
        return "absent"
    end
    local parts = {tostring(entry.library)}
    for _, field in ipairs(FIELDS) do
        table.insert(parts, field .. "=" .. tostring(entry[field]))
    end
    return table.concat(parts, " ")
end

local function crowded(macho, file)
    local data = io.readfile(file, {encoding = "binary"})
    local header_end = 28 + string.unpack("<I4", data, 21)
    for _, at in ipairs(macho.images(data)[1].command_at) do
        if string.unpack("<I4", data, at + 1) == 1 then
            io.writefile(file, data:sub(1, at + 96) .. string.pack("<I4", header_end) .. data:sub(at + 101), {encoding = "binary"})
            return
        end
    end
    raise("%s has no LC_SEGMENT whose first section can start at the end of its load commands", file)
end

function failures(opt)
    local dyld = import("apple.dyld", {rootdir = opt.modules, anonymous = true})
    local macho = import("apple.macho", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local release = path.join(folder, "libraries_armv7")
    local shim = path.join(folder, "shim")
    os.mkdir(release)
    os.mkdir(shim)
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder, _getpid"))
    io.writefile(path.join(shim, "libSystem.tbd"), fixtures.system_stub("_shim_fn", SHIM))
    io.writefile(path.join(folder, "libAVFoundation.tbd"), fixtures.system_stub(table.concat({AMBIENT, DATA, FUNCTION}, ", "), AVFOUNDATION))
    io.writefile(path.join(folder, "avf.c"), "extern int shim_fn(void);\nconst char *AVAudioSessionCategoryAmbient = \"AVAudioSessionCategoryAmbient\";\nint (*avf_probe)(void) = shim_fn;\n")
    built(folder, opt.ld64, "libraries_armv7/AVFoundation", "avf.c", AVFOUNDATION, {"-Lshim", "-lSystem"})
    io.writefile(path.join(folder, "sys.c"), "extern int shim_fn(void);\nint (*shim_probe)(void) = shim_fn;\nint getpid(void) { return 1; }\n")
    built(folder, opt.ld64, "libraries_armv7/libSystem", "sys.c", SYSTEM, {"-Lshim", "-lSystem"})
    io.writefile(path.join(folder, "provider.c"), "extern int getpid(void);\nconst char *AVAudioSessionMediaServicesWereLostNotification = \"AVAudioSessionMediaServicesWereLostNotification\";\n"
                                                  .. "int AVAudioSessionSilenceSecondaryAudioHint(void) { return getpid() != 0; }\n")
    local provider = built(folder, opt.ld64, "libAVFoundationBackports.dylib", "provider.c", PROVIDER, {"-L.", "-lSystem"})
    io.writefile(path.join(folder, "prebuilt.c"), PREBUILT)
    local prebuilt = fixtures.link(folder, opt.ld64, "prebuilt.dylib", TRIPLE, "prebuilt.c", {"-dynamiclib", "-lAVFoundation", "-Wl,-headerpad,0x1000"})
    local padding = {}
    for index = 1, 15 do
        io.writefile(path.join(folder, "libPad" .. index .. ".tbd"), fixtures.system_stub("_pad_" .. index, "/usr/lib/libPad" .. index .. ".dylib"))
        table.insert(padding, "-lPad" .. index)
    end
    local wide = fixtures.link(folder, opt.ld64, "wide.dylib", TRIPLE, "prebuilt.c", table.join({"-dynamiclib", "-lAVFoundation"}, padding, {"-Wl,-headerpad,0x1000"}))

    local before = fixtures.refusal(function () dyld.check(release, {prebuilt, provider}, nil, {release = true}) end) or ""
    if not before:find(FUNCTION, 1, true) or not before:find("revenant.rebind", 1, true) then
        table.insert(found, "a prebuilt importing what the release lacks must be refused, naming the import and revenant.rebind: " .. before)
    end
    if #table.orderkeys((dyld.rebind_plan(release, prebuilt, {}))) > 0 then
        table.insert(found, "with no library of the build that exports an import, the plan must move nothing")
    end
    local moves, libraries = dyld.rebind_plan(release, prebuilt, {provider})
    if moves[DATA] ~= PROVIDER or moves[FUNCTION] ~= PROVIDER or moves[AMBIENT] ~= nil then
        table.insert(found, "the plan must move each import the release lacks to the provider that exports it, and leave what the release exports: " .. table.concat(table.orderkeys(moves), " "))
    end

    local unlisted = path.join(folder, "unlisted.dylib")
    local unlisted_data = macho.read(prebuilt)
    local unlisted_image = macho.images(unlisted_data)[1]
    local symoff, nsyms, stroff = unlisted_image.symtab[1], unlisted_image.symtab[2], unlisted_image.symtab[3]
    for index = 0, nsyms - 1 do
        local strx = string.unpack("<I4", unlisted_data, symoff + index * 12 + 1)
        if macho.cstring(unlisted_data, stroff + strx) == FUNCTION then
            local at = symoff + index * 12 + 4
            unlisted_data = unlisted_data:sub(1, at) .. "\0" .. unlisted_data:sub(at + 2)
        end
    end
    io.writefile(unlisted, unlisted_data)
    local unlisted_before = fixtures.refusal(function () dyld.check(release, {unlisted, provider}, nil, {release = true}) end) or ""
    if not unlisted_before:find(FUNCTION, 1, true) then
        table.insert(found, "an import that only the bind stream names, no longer in the symbol table, must still be refused: " .. unlisted_before)
    end
    local unlisted_moves, unlisted_libraries = dyld.rebind_plan(release, unlisted, {provider})
    if unlisted_moves[FUNCTION] ~= PROVIDER then
        table.insert(found, "the plan must move an import that only the bind stream names: " .. table.concat(table.orderkeys(unlisted_moves), " "))
    end
    macho.rebind(unlisted, {[FUNCTION] = PROVIDER}, unlisted_libraries)
    local unlisted_after = macho.read(unlisted)
    local unlisted_found = macho.images(unlisted_after)[1]
    if (bindings(macho, unlisted_after, unlisted_found, unlisted_found.lazy_bind, true)[FUNCTION] or {}).library ~= PROVIDER then
        table.insert(found, "the rebind must move the bind of an import that is not in the symbol table to the provider")
    end

    local rebound = path.join(folder, "rebound.dylib")
    os.cp(prebuilt, rebound)
    macho.rebind(rebound, moves, libraries)
    local listing = fixtures.run(folder, "xcrun", {"otool", "-L", rebound})
    if not listing:find(PROVIDER, 1, true) or not listing:find(AVFOUNDATION, 1, true) then
        table.insert(found, "otool -L of the rebound image must name the provider and keep AVFoundation: " .. listing)
    end
    local before_data = macho.read(prebuilt)
    local before_image = macho.images(before_data)[1]
    local lazy_before = bindings(macho, before_data, before_image, before_image.lazy_bind, true)
    if not lazy_before[FUNCTION] then
        table.insert(found, "the strong function import is not bound lazily, so the lazy path is not exercised")
    end
    local function kept(label)
        local after_data = macho.read(rebound)
        local after_image = macho.images(after_data)[1]
        for _, stream in ipairs({{"bind", false}, {"lazy_bind", true}}) do
            local old = bindings(macho, before_data, before_image, before_image[stream[1]], stream[2])
            local new = bindings(macho, after_data, after_image, after_image[stream[1]], stream[2])
            for name, entry in pairs(old) do
                local now = new[name]
                local expected = {library = moves[name] or entry.library}
                for _, field in ipairs(FIELDS) do
                    expected[field] = entry[field]
                end
                if not now or described(now) ~= described(expected) then
                    table.insert(found, string.format("%s: %s binds %s as %s before and %s after the rebind", label, stream[1], name, described(entry), described(now)))
                end
            end
        end
    end
    kept("rebound")
    local stripped = path.join(folder, "stripped.dylib")
    os.cp(rebound, stripped)
    local unstrippable = fixtures.refusal(function () fixtures.run(folder, "xcrun", {"strip", "-S", "-x", stripped}) end)
    if unstrippable then
        table.insert(found, "the rebound image must strip, so its link edit data fills its __LINKEDIT and nothing is left between the streams: " .. unstrippable)
    end
    fixtures.run(folder, opt.ldid, {"-S", rebound})
    kept("signed")

    local signed = path.join(folder, "signed.dylib")
    os.cp(prebuilt, signed)
    fixtures.run(folder, opt.ldid, {"-S", signed})
    local signed_moves, signed_libraries = dyld.rebind_plan(release, signed, {provider})
    macho.rebind(signed, signed_moves, signed_libraries)
    local signed_stripped = path.join(folder, "signed_stripped.dylib")
    os.cp(signed, signed_stripped)
    local signed_unstrippable = fixtures.refusal(function () fixtures.run(folder, "xcrun", {"strip", "-S", "-x", signed_stripped}) end)
    if signed_unstrippable then
        table.insert(found, "a signed image must still strip after the rebind, so the old signature's padding is not left in __LINKEDIT: " .. signed_unstrippable)
    end

    local refused = fixtures.refusal(function () dyld.check(release, {rebound, provider}, nil, {release = true}) end)
    if refused then
        table.insert(found, "the rebound image must pass the import check against the release: " .. refused)
    end

    local tight = path.join(folder, "tight.dylib")
    os.cp(prebuilt, tight)
    crowded(macho, tight)
    local untouched = io.readfile(tight, {encoding = "binary"})
    local no_room = fixtures.refusal(function () macho.rebind(tight, moves, libraries) end) or ""
    if not no_room:find("no room in its header", 1, true) then
        table.insert(found, "an image whose header has no room for the load command must be refused: " .. no_room)
    end
    if io.readfile(tight, {encoding = "binary"}) ~= untouched then
        table.insert(found, "a refused rebind must leave the image as it was")
    end

    local wide_before_data = macho.read(wide)
    local wide_before_image = macho.images(wide_before_data)[1]
    local before_entry = bindings(macho, wide_before_data, wide_before_image, wide_before_image.lazy_bind, true)[FUNCTION]
    local wide_moves, wide_libraries = dyld.rebind_plan(release, wide, {provider})
    local wide_rebound = path.join(folder, "wide_rebound.dylib")
    os.cp(wide, wide_rebound)
    macho.rebind(wide_rebound, wide_moves, wide_libraries)
    local wide_after_data = macho.read(wide_rebound)
    local wide_after_image = macho.images(wide_after_data)[1]
    if not before_entry then
        table.insert(found, "the wide image must bind " .. FUNCTION .. " lazily, so the converted path is exercised")
    elseif bindings(macho, wide_after_data, wide_after_image, wide_after_image.lazy_bind, true)[FUNCTION] then
        table.insert(found, "a lazy bind whose provider ordinal does not fit one byte must leave the lazy stream, because it cannot keep its length")
    else
        local moved = bindings(macho, wide_after_data, wide_after_image, wide_after_image.bind, false)[FUNCTION]
        local expected = {library = PROVIDER}
        for _, field in ipairs(FIELDS) do
            expected[field] = before_entry[field]
        end
        if not moved or described(moved) ~= described(expected) then
            table.insert(found, "the converted bind must bind " .. FUNCTION .. " in the bind stream as " .. described(expected) .. ", and it binds as " .. described(moved))
        end
    end
    io.writefile(path.join(folder, "override.c"), "extern int getpid(void);\nint use_pid(void) { return getpid(); }\n")
    local overriding = fixtures.link(folder, opt.ld64, "override.dylib", TRIPLE, "override.c", {"-dynamiclib", "-Wl,-headerpad,0x1000"})
    io.writefile(path.join(folder, "marked.c"), "int getpid(void) { return 2; }\nconst char __revenant_override_getpid = 0;\n")
    local marked = built(folder, opt.ld64, "libMarked.dylib", "marked.c", MARKED, {"-L.", "-lSystem"})
    io.writefile(path.join(folder, "unmarked.c"), "int getpid(void) { return 3; }\nconst char __revenant_override_getppid = 0;\n")
    local unmarked = built(folder, opt.ld64, "libUnmarked.dylib", "unmarked.c", UNMARKED, {"-L.", "-lSystem"})
    local override_before = dyld.rebind_plan(release, overriding, {unmarked})
    if override_before[GETPID] ~= nil then
        table.insert(found, "an import the release exports must stay on the release when the provider exports it without the marker, or with the marker of another symbol: " .. tostring(override_before[GETPID]))
    end
    local override_moves, override_libraries = dyld.rebind_plan(release, overriding, {unmarked, marked})
    if override_moves[GETPID] ~= MARKED then
        table.insert(found, "an import the release exports must move to the provider that exports the symbol and its marker, past a provider without it: " .. tostring(override_moves[GETPID]))
    end
    local overridden = path.join(folder, "overridden.dylib")
    os.cp(overriding, overridden)
    macho.rebind(overridden, override_moves, override_libraries)
    local overridden_data = macho.read(overridden)
    local overridden_image = macho.images(overridden_data)[1]
    if (bindings(macho, overridden_data, overridden_image, overridden_image.lazy_bind, true)[GETPID] or {}).library ~= MARKED then
        table.insert(found, "the rebind must bind the overridden import to the provider that carries the marker")
    end
    local override_refused = fixtures.refusal(function () dyld.check(release, {overridden, marked}, nil, {release = true}) end)
    if override_refused then
        table.insert(found, "an image rebound to an override must pass the import check against the release: " .. override_refused)
    end
    os.tryrm(folder)
    return found
end
