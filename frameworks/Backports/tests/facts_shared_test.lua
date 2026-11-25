local tools = path.join(os.scriptdir(), "..", "tools")
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local facts = import("facts", {rootdir = tools, anonymous = true})
local publics = import("public", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function fixture(folder, header)
    os.mkdir(path.join(folder, "System", "Library", "Frameworks", "Fixture.framework", "Headers"))
    io.writefile(path.join(folder, "SDKSettings.json"), '{"Version": "99.9"}')
    io.writefile(path.join(folder, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h"), header)
    return folder
end

local function home(folder)
    os.setenv("REVENANT_CACHE", folder)
end

local function name_of(folder)
    return path.filename(folder)
end

function main()
    local original_cache, original_store = os.getenv("REVENANT_CACHE"), os.getenv("REVENANT_STORE")
    local base = workspace.fresh("facts-shared")
    local store = path.join(base, "store")
    os.setenv("REVENANT_STORE", store)
    local sdk = fixture(path.join(base, "sdk"), "extern const int FixtureValue;\n")
    local homes = {path.join(base, "home-one"), path.join(base, "home-two")}

    home(homes[1])
    assert(sdkfiles.write_facts(sdk, "Fixture", {{kind = "class", name = "Thing"}}), "the first writer did not write the canonical file")
    local canonical = path.join(store, "backports", sdkfiles.cache_key(sdk), "Fixture.tsv")
    assert(os.isfile(canonical), "the canonical facts file is not in the shared store")
    assert(io.readfile(canonical):find("Thing", 1, true) ~= nil, "the canonical file has no row from the facts")

    home(homes[2])
    assert(sdkfiles.shared_file(sdk, "Fixture.tsv"), "the canonical file was not found for the second cache")
    local local_file = path.join(sdkfiles.cache_folder(sdk), "Fixture.tsv")
    assert(io.readfile(local_file) == io.readfile(canonical), "the second cache did not get the canonical content")
    assert(not sdkfiles.write_facts(sdk, "Fixture", {{kind = "class", name = "Other"}}), "the second writer wrote a file again")
    assert(io.readfile(canonical):find("Other", 1, true) == nil, "the canonical file was changed by the second writer")

    home(homes[1])
    assert(sdkfiles.write_shared(sdk, "install_names.tsv", "OnlyCanonical\t/System/Library/Frameworks/Fixture.framework/Fixture\n"),
           "the canonical install names were not written")
    local canonical_names = path.join(store, "backports", sdkfiles.cache_key(sdk), "install_names.tsv")
    local before_names = io.readfile(canonical_names)
    home(homes[2])
    local images = publics.install_names(sdk)
    assert(images.OnlyCanonical == "/System/Library/Frameworks/Fixture.framework/Fixture", "install names were not read from the canonical file")
    assert(io.readfile(canonical_names) == before_names, "the canonical install names were replaced")
    assert(not sdkfiles.write_shared(sdk, "install_names.tsv", "Other\t/path\n"), "install names were written twice for the same key")

    home(homes[1])
    sdkfiles.write_shared(sdk, "constant_intros.tsv", "OnlyCanonical\t1000\textern\n")
    home(homes[2])
    local intros = facts.constant_intros(sdk)
    assert(intros.OnlyCanonical and intros.OnlyCanonical.intro == 1000, "constant intros were not read from the canonical file")

    local changed = fixture(path.join(base, "sdk-changed"), "extern const int FixtureOther;\n")
    assert(sdkfiles.cache_key(changed) ~= sdkfiles.cache_key(sdk), "another SDK content got the same key")
    assert(sdkfiles.write_facts(changed, "Fixture", {{kind = "class", name = "Changed"}}), "the changed SDK wrote no canonical file")
    assert(io.readfile(path.join(store, "backports", sdkfiles.cache_key(changed), "Fixture.tsv")):find("Changed", 1, true) ~= nil,
           "the changed SDK's file is under the old key")
    assert(name_of(store) == "store", "the store is not the named one")

    os.setenv("REVENANT_CACHE", original_cache or "")
    os.setenv("REVENANT_STORE", original_store or "")
    os.tryrm(base)
    print("FACTS_SHARED_TEST passed")
end
