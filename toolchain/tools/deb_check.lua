local BACKPORTS = "./usr/lib/revenant/org.revenant.backports/"
local LINKED = {"libUIKitBackports.dylib", "libCoreDataBackports.dylib"}
local APPLICATION = {"./Applications/SwiftUIDemo.app/SwiftUIDemo", "./Applications/SwiftUIDemo.app/Info.plist"}

local function single(dir, name)
    local found = os.files(path.join(dir, name .. "_*_iphoneos-arm.deb"))
    if #found ~= 1 then
        raise("%d packages named %s are in %s, and there must be one", #found, name, dir)
    end
    return found[1]
end

local function unpack(deb, scratch)
    local folder = path.join(scratch, path.basename(deb))
    os.mkdir(folder)
    os.execv("ar", {"x", deb}, {curdir = folder})
    os.execv("tar", {"-xzf", path.join(folder, "control.tar.gz"), "-C", folder})
    local control = io.readfile(path.join(folder, "control"))
    local listing = os.iorunv("tar", {"-tzf", path.join(folder, "data.tar.gz")})
    return control, listing
end

local function field(control, name)
    local value = ("\n" .. control):match("\n" .. name .. ": ([^\n]*)")
    if not value then
        raise("the control file names no %s", name)
    end
    return value
end

local function members(listing)
    local found = {}
    for entry in listing:gmatch("[^\n]+") do
        if not entry:endswith("/") then
            found[entry] = true
        end
    end
    return found
end

function main(dir, demo, platform)
    dir = path.absolute(dir or "build")
    local scratch = path.join(dir, ".deb-check")
    os.tryrm(scratch)
    os.mkdir(scratch)

    local demo_control, demo_listing = unpack(single(dir, demo), scratch)
    local platform_control, platform_listing = unpack(single(dir, platform), scratch)

    local name = field(platform_control, "Package")
    if name ~= platform then
        raise("the %s package names itself %s", platform, name)
    end
    local wanted = string.format("%s (= %s)", platform, field(platform_control, "Version"))
    local depends = {}
    for _, dependency in ipairs(field(demo_control, "Depends"):split(",")) do
        depends[dependency:trim()] = true
    end
    if not depends[wanted] then
        raise("%s depends on %s, and not on %s", demo, field(demo_control, "Depends"), wanted)
    end

    local files = members(platform_listing)
    local count = 0
    for entry in pairs(files) do
        if not (entry:startswith(BACKPORTS) and entry:sub(#BACKPORTS + 1):match("^lib%w+Backports%.dylib$")) then
            raise("%s carries %s, and it may carry only the Backports libraries under %s", platform, entry, BACKPORTS)
        end
        count = count + 1
    end
    for _, library in ipairs(LINKED) do
        if not files[BACKPORTS .. library] then
            raise("%s carries no %s, and the demo links it", platform, library)
        end
    end

    local shipped = members(demo_listing)
    for _, entry in ipairs(APPLICATION) do
        if not shipped[entry] then
            raise("%s carries no %s", demo, entry)
        end
    end

    os.tryrm(scratch)
    print("%s depends on %s; %s carries %d Backports libraries, among them %s", demo, wanted, platform, count, table.concat(LINKED, ", "))
end
