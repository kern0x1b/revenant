local tools = path.join(os.scriptdir(), "..", "tools")
local facts = import("facts", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local HEADER = table.concat({
    "extern const int FixtureValue __attribute__((availability(ios, introduced=14.0)));",
    "enum FixtureKind { FixtureA = 1 } __attribute__((availability(ios, introduced=12.0)));",
    "__attribute__((objc_root_class)) @interface FixtureRoot",
    "- (void)hello __attribute__((availability(ios, introduced=13.0)));",
    "@end",
    ""
}, "\n")

local function framework_header(sdk)
    return path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers", "Fixture.h")
end

local function fixture(folder, header)
    os.mkdir(path.directory(framework_header(folder)))
    io.writefile(path.join(folder, "SDKSettings.json"), '{"Version": "99.9"}')
    io.writefile(framework_header(folder), header)
    return folder
end

local function bytes(file)
    return io.readfile(file, {encoding = "binary"})
end

local function in_home(home, sdk, scratch)
    os.setenv("REVENANT_CACHE", home)
    local version = sdkfiles.sdk_version(sdk)
    local folder = sdkfiles.cache_folder(sdk)
    os.mkdir(folder)
    facts.constant_intros(sdk)
    facts.extract(sdk, version, folder, scratch, "Fixture")
    return folder
end

function main()
    local original = os.getenv("REVENANT_CACHE")
    local base = workspace.fresh("facts-key-test")
    local first = fixture(path.join(base, "sdk-one"), HEADER)
    local second = path.join(base, "sdk-two")
    os.cp(first, second)
    local changed = path.join(base, "sdk-changed")
    os.cp(first, changed)
    io.writefile(framework_header(changed), (HEADER:gsub("introduced=14.0", "introduced=15.0")))
    local linked = path.join(base, "sdk-link")
    os.ln(first, linked)
    local homes = {path.join(base, "home-one"), path.join(base, "home-two")}
    local scratch = path.join(base, "scratch")
    os.mkdir(scratch)

    assert(sdkfiles.cache_key(first) == sdkfiles.cache_key(second), "the same SDK content in another folder gets another cache key: " .. sdkfiles.cache_key(first) .. " and " .. sdkfiles.cache_key(second))
    assert(sdkfiles.cache_key(first) == sdkfiles.cache_key(linked), "a link to the same SDK gets another cache key")
    assert(sdkfiles.cache_key(first) ~= sdkfiles.cache_key(changed), "an SDK of the same version with another header content gets the cache key of the first one")

    local folders = {in_home(homes[1], first, scratch), in_home(homes[2], second, scratch)}
    os.setenv("REVENANT_CACHE", original or "")
    assert(path.filename(folders[1]) == path.filename(folders[2]), "two cache homes with the same SDK content name the facts folder differently")
    assert(folders[1] ~= folders[2] and folders[1]:startswith(homes[1]) and folders[2]:startswith(homes[2]), "each home keeps its own facts folder")
    local names = {"Fixture.tsv", "constant_intros.tsv"}
    for _, name in ipairs(names) do
        local one, two = bytes(path.join(folders[1], name)), bytes(path.join(folders[2], name))
        assert(#one > 0, name .. " is empty: the fixture produced no facts")
        assert(one == two, name .. " differs between two cache homes with the same SDK content")
        for _, fragment in ipairs({base, first, second, homes[1], homes[2]}) do
            assert(not one:find(fragment, 1, true), name .. " holds the path " .. fragment)
        end
    end
    local rows = sdkfiles.read_rows(path.join(folders[1], "Fixture.tsv"))
    local found = {}
    for _, row in ipairs(rows) do
        found[row.kind .. " " .. row.name] = true
    end
    assert(found["class FixtureRoot"], "the fixture's class is not among the facts")

    local expected = {"ast.lua", "facts.lua", "public.lua", "sdk.lua"}
    local files = sdkfiles.facts_files()
    table.sort(files)
    assert(table.concat(files, ",") == table.concat(expected, ","), "the facts key covers " .. table.concat(files, ","))
    local problems = sdkfiles.facts_import_problems()
    assert(#problems == 0, "the files of the facts key import what the key does not cover:\n" .. table.concat(problems, "\n"))

    local leaky = path.join(base, "leaky")
    os.mkdir(leaky)
    for _, name in ipairs(expected) do
        os.cp(path.join(tools, name), path.join(leaky, name))
    end
    local source = io.readfile(path.join(leaky, "facts.lua"))
    local imports = {
        'local skeleton = import("skeleton", {rootdir = os.scriptdir(), anonymous = true})',
        'local chosen = "x"\nimport(chosen)',
        'import("core.base.hashset")',
        'local bare = import "skeleton"',
        'local aliased = import\naliased("skeleton")',
        'local loaded = dofile(path.join(os.scriptdir(), "skeleton.lua"))',
    }
    for _, line in ipairs(imports) do
        io.writefile(path.join(leaky, "facts.lua"), source .. "\n" .. line .. "\n")
        local leaks = sdkfiles.facts_import_problems(leaky)
        assert(#leaks >= 1, "the import check found nothing wrong with: " .. line)
    end
    io.writefile(path.join(leaky, "facts.lua"), source .. "\nlocal data = json.loadfile(\"x\")\nlocal text = \"import skeleton and dofile\"\n")
    assert(#sdkfiles.facts_import_problems(leaky) == 0, "the import check refuses json.loadfile or the word import inside a string")

    local identity = sdkfiles.clang_identity()
    assert(#identity == 1 and identity[1]:find("clang version", 1, true) and not identity[1]:find("InstalledDir", 1, true), "the clang identity is not its version text: " .. tostring(identity[1]))
    assert(sdkfiles.clang() == "/usr/bin/clang", "the clang of the key is not the one the facts run")
    local digester = sdkfiles.digester_identity()
    assert(#digester == 2 and #digester[2] == 64, "the digester identity is not a size and a sha256")

    os.tryrm(base)
    print("FACTS_KEY_TEST passed")
end
