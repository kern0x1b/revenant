import("core.base.json")

local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})

local root = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))

local RELEASE = "6.1.3"

local STRANGERS = {
    SKOverlay = "the device's SKOverlay is SkankKit's, superclass SKLayer, and implements none of the 5 members StoreKit's SKOverlay declares (measured in the 6.1.3 inventory)",
}

local CLASSES = {
    "NSMutableDictionary", "NSMutableArray", "NSMutableString", "NSMutableData", "NSMutableSet",
    "NSNull", "NSCountedSet", "NSMutableIndexSet", "NSMutableCharacterSet", "NSPurgeableData",
}

local function skeleton_aliases()
    local found, files = {}, os.files(path.join(root, "build", "generated", "backports", "skeleton", "*.m"))
    assert(#files > 0, "cf_cast_test: no generated skeleton under build/generated/backports/skeleton: run the generator (./xmakew l -P . frameworks/Backports/tools/generate.lua) first; a check with nothing to read would pass for nothing")
    for _, file in ipairs(files) do
        for name in (io.readfile(file) or ""):gmatch("REVENANT_ALIAS_OF%(([%w_]+),") do
            found[name] = true
        end
    end
    return found
end

local function device_inventory()
    local file = path.join(dyld.root(), RELEASE, "classes_armv7.json")
    assert(os.isfile(file), "cf_cast_test: the iOS " .. RELEASE .. " class inventory " .. file .. " is missing")
    return json.decode(io.readfile(file)).classes
end

function main()
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(compiler and compiler ~= "", "cf_cast_test: REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")

    local aliases = skeleton_aliases()
    local inventory = device_inventory()
    local proxied, checked = {}, 0
    for name in pairs(aliases) do
        checked = checked + 1
        if inventory[name] and not STRANGERS[name] then
            table.insert(proxied, name .. " (" .. (inventory[name].image or "?") .. ")")
        end
    end
    for _, name in ipairs(CLASSES) do
        assert(inventory[name], "cf_cast_test: " .. name .. " is not in the iOS " .. RELEASE .. " inventory")
    end
    table.sort(proxied)
    assert(#proxied == 0, "the generated skeleton still aliases device-exported classes with a proxy: " .. table.concat(proxied, ", ")
           .. "; such a proxy makes a Swift as! cast of a system-created object trap")

    local fixture = path.join(root, "frameworks", "Backports", "tests", "Foundation", "cf_mutable_cast.swift")
    local out = path.join(os.projectdir(), "build", "cf_mutable_cast_probe")
    os.mkdir(path.directory(out))
    local sdkroot = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
    local status = os.execv(compiler, {"-O", fixture, "-o", out}, {try = true, envs = {SDKROOT = sdkroot}})
    assert(status == 0, "cf_cast_test: the Swift cast fixture does not compile")
    status = os.execv(out, {}, {try = true})
    assert(status == 0, "cf_cast_test: a Swift as!/as? cast of a system-created mutable collection failed")
    print("cf_cast: none of the " .. checked .. " proxies of the skeleton is a class the iOS " .. RELEASE .. " device exports (the strangers: SKOverlay); " .. #CLASSES .. " Swift casts of system-created collections succeed")
end
