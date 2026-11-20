local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local sdkfiles = import("sdk", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function header(sdk, text)
    io.writefile(path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h"), text)
end

local function describe(intros)
    local lines = {}
    for name, found in pairs(intros) do
        table.insert(lines, string.format("%s %s %s", name, tostring(found.intro), found.kind))
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

function main()
    local sdk = workspace.fresh("facts-cache-sdk")
    os.mkdir(path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers"))
    io.writefile(path.join(sdk, "SDKSettings.json"), '{"Version": "99.9"}')
    header(sdk, table.concat({
        "extern const int FixtureValue __attribute__((availability(ios, introduced=14.0)));",
        "enum FixtureKind { FixtureA = 1 } __attribute__((availability(ios, introduced=12.0)));",
        ""
    }, "\n"))

    local cache = path.join(sdkfiles.cache_folder(sdk), "constant_intros.tsv")
    os.tryrm(cache)
    local computed = facts.constant_intros(sdk)
    assert(computed.FixtureValue and computed.FixtureValue.kind == "extern", "the fixture's extern constant is not listed")
    assert(os.isfile(cache), "the constant intros were not cached")

    io.writefile(cache, io.readfile(cache) .. "OnlyInTheCache\t1000\textern\n")
    local cached = facts.constant_intros(sdk)
    assert(cached.OnlyInTheCache and cached.OnlyInTheCache.intro == 1000, "the constant intros were computed again, so the cache is not read")
    cached.OnlyInTheCache = nil
    assert(describe(cached) == describe(computed), "the cached constant intros differ from the ones computed:\n" .. describe(cached))

    local other = workspace.fresh("facts-cache-sdk-other")
    os.mkdir(path.join(other, "System", "Library", "Frameworks", "Fixture.framework", "Headers"))
    io.writefile(path.join(other, "SDKSettings.json"), '{"Version": "99.9"}')
    io.writefile(path.join(other, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h"),
        "extern const int FixtureValue __attribute__((availability(ios, introduced=6.0)));\n")
    local elsewhere = facts.constant_intros(other)
    assert(elsewhere.FixtureValue and tonumber(elsewhere.FixtureValue.intro) == 6000,"another SDK of the same version was given the constant intros of the first one: " .. describe(elsewhere))

    local other_cache = sdkfiles.cache_folder(other)
    local sdk_cache = sdkfiles.cache_folder(sdk)
    os.tryrm(other)
    os.tryrm(cache)
    os.tryrm(other_cache)
    os.tryrm(sdk_cache)
    os.tryrm(sdk)
    print("FACTS_CACHE_TEST passed")
end
