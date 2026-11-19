local root = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))

local CLASSES = {
    "NSMutableDictionary", "NSMutableArray", "NSMutableString", "NSMutableData", "NSMutableSet",
    "NSNull", "NSCountedSet", "NSMutableIndexSet", "NSMutableCharacterSet", "NSPurgeableData",
}

local function skeleton_aliases()
    local found = {}
    for _, file in ipairs(os.files(path.join(root, "build", "generated", "backports", "skeleton", "*.m"))) do
        for name in (io.readfile(file) or ""):gmatch("REVENANT_ALIAS_OF%(([%w_]+),") do
            found[name] = true
        end
    end
    return found
end

function main()
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(compiler and compiler ~= "", "cf_cast_test: REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")

    local aliases = skeleton_aliases()
    local proxied = {}
    for _, name in ipairs(CLASSES) do
        if aliases[name] then
            table.insert(proxied, name)
        end
    end
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
    print("cf_cast: " .. #CLASSES .. " classes have no device proxy and their Swift casts succeed")
end
