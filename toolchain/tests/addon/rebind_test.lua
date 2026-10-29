import("fixtures")

local TRIPLE = "armv7-apple-ios6.0"
local AVFOUNDATION = "/System/Library/Frameworks/AVFoundation.framework/AVFoundation"
local SYSTEM = "/usr/lib/libSystem.B.dylib"
local SHIM = "/usr/lib/revenant/libSystemShim.dylib"
local PROVIDER = "/usr/lib/revenant/org.revenant.backports/libAVFoundationBackports.dylib"
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
    fixtures.run(folder, opt.ldid, {"-S", rebound})
    kept("signed")

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
    os.tryrm(folder)
    return found
end
