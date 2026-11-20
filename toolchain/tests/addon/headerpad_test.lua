import("fixtures")

local TRIPLE = "armv7-apple-ios6.0"
local DEP_COUNT = 20
local PROVIDER = "/usr/lib/revenant/org.revenant.backports/lib" .. string.rep("x", 15000) .. ".dylib"
local IMPORT = "_mdep1"

local function room(macho, file)
    local data = macho.read(file)
    local image = macho.images(data)[1]
    local header_end = 28 + string.unpack("<I4", data, 21)
    local first = #data
    for _, section in ipairs(image.sections) do
        if section.offset > 0 and section.size > 0 then
            first = math.min(first, section.offset)
        end
    end
    for _, segment in ipairs(image.segments) do
        if segment.fileoff > 0 and segment.filesize > 0 then
            first = math.min(first, segment.fileoff)
        end
    end
    return first - header_end, image
end

local function rules_step(found)
    local app = io.readfile(path.join(os.scriptdir(), "..", "..", "rules", "app", "xmake.lua"))
    local library = io.readfile(path.join(os.scriptdir(), "..", "..", "rules", "library", "xmake.lua"))
    if not app:find('target:add("ldflags", "-Wl,-headerpad_max_install_names"', 1, true) then
        table.insert(found, "the app rule must link the executable with -Wl,-headerpad_max_install_names so a load command can be added after the link")
    end
    if not library:find('target:add("shflags", "-Wl,-headerpad_max_install_names"', 1, true) then
        table.insert(found, "the library rule must link each dylib with -Wl,-headerpad_max_install_names so the app can rebind it after the strip")
    end
end

local function build_step(opt, folder)
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub("dyld_stub_binder"))
    local links = {"-L."}
    for index = 1, DEP_COUNT do
        io.writefile(path.join(folder, "mdep" .. index .. ".c"), string.format("int mdep%d(void) { return %d; }\n", index, index))
        fixtures.link(folder, opt.ld64, "libmdep" .. index .. ".dylib", TRIPLE, "mdep" .. index .. ".c",
                      {"-dynamiclib", "-install_name", "/usr/lib/revenant/org.revenant.backports/libmdep" .. index .. ".dylib"})
        table.insert(links, "-lmdep" .. index)
    end
    io.writefile(path.join(folder, "payload.c"), "extern int mdep1(void);\nint use(void) { return mdep1(); }\n")
    local shared = {"-dynamiclib", "-install_name", "/usr/lib/payload.dylib"}
    local plain = fixtures.link(folder, opt.ld64, "plain.dylib", TRIPLE, "payload.c", table.join(shared, links))
    local padded = fixtures.link(folder, opt.ld64, "padded.dylib", TRIPLE, "payload.c",
                                 table.join(shared, links, {"-Wl,-headerpad_max_install_names"}))
    io.writefile(path.join(folder, "main.c"), "int main(void) { return 0; }\n")
    local plain_app = fixtures.link(folder, opt.ld64, "App-plain", TRIPLE, "main.c", links)
    local padded_app = fixtures.link(folder, opt.ld64, "App-padded", TRIPLE, "main.c",
                                     table.join(links, {"-Wl,-headerpad_max_install_names"}))
    return plain, padded, plain_app, padded_app
end

function failures(opt)
    local macho = import("apple.macho", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    rules_step(found)
    local plain, padded, plain_app, padded_app = build_step(opt, folder)

    local plain_room = room(macho, plain)
    local padded_room = room(macho, padded)
    if padded_room <= plain_room then
        table.insert(found, string.format("-headerpad_max_install_names must leave more header room: the padded dylib has %d bytes and the plain one has %d", padded_room, plain_room))
    end
    if room(macho, padded_app) <= room(macho, plain_app) then
        table.insert(found, "-headerpad_max_install_names must leave more header room in an executable too")
    end

    local libraries = {[PROVIDER] = {current = 1, compatibility = 1}}
    local moves = {[IMPORT] = PROVIDER}
    local plain_before = io.readfile(plain, {encoding = "binary"})
    local refused = fixtures.refusal(function () macho.rebind(plain, moves, libraries) end) or ""
    local needed, available = refused:match("needs (%d+) bytes of new load command, but only (%d+) bytes fit")
    if not needed or not available then
        table.insert(found, "a dylib whose load commands do not fit must be refused with the needed size and the measured header space: " .. refused)
    elseif tonumber(needed) <= plain_room or tonumber(available) ~= plain_room then
        table.insert(found, string.format("the refusal must name the measured header space %d and the size %d that cannot fit: %s", plain_room, needed, refused))
    end
    if io.readfile(plain, {encoding = "binary"}) ~= plain_before then
        table.insert(found, "a refused rebind must leave the image unchanged")
    end
    if needed and tonumber(needed) >= padded_room then
        table.insert(found, "the fixture must need more room than the plain dylib has and less than the padded one has")
    end

    local rebound = path.join(folder, "rebound.dylib")
    os.cp(padded, rebound)
    local failure = fixtures.refusal(function () macho.rebind(rebound, moves, libraries) end)
    if failure then
        table.insert(found, "a dylib linked with -headerpad_max_install_names must accept a rebind whose load command does not fit the default padding: " .. failure)
    else
        local image = macho.images(macho.read(rebound))[1]
        local provider = nil
        for index, install in ipairs(image.libraries) do
            if install == PROVIDER then
                provider = index
            end
        end
        if not provider then
            table.insert(found, "the rebind must add the provider's LC_LOAD_DYLIB to the dylib")
        end
    end

    os.tryrm(folder)
    return found
end
