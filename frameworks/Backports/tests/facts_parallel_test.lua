local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local sdkfiles = import("sdk", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

local workspace = import("@addon.revenant.workspace", {anonymous = true})

local HEADERS = {
    AAFixture = {
        "extern const int Both;",
        "extern const int LateIntro;",
        "enum { OnlyNil = 1 };",
        "extern const int InEveryFramework __attribute__((availability(ios, introduced=3.0)));",
    },
    BBFixture = {
        "extern const int Both __attribute__((availability(ios, introduced=7.0)));",
        "extern const int LateIntro __attribute__((availability(ios, introduced=9.0)));",
        "extern const int InEveryFramework __attribute__((availability(ios, introduced=4.0)));",
    },
    CCFixture = {
        "enum Kind { Both = 1 } __attribute__((availability(ios, introduced=5.0)));",
        "enum Other { Member __attribute__((availability(ios, introduced=11.0))) = 1, Plain = 2 };",
        "extern const int InEveryFramework;",
    },
    DDFixture = {
        "extern const int EarlyIntro __attribute__((availability(ios, introduced=8.0)));",
        "extern const int InEveryFramework;",
    },
    EEFixture = {
        "extern const int EarlyIntro;",
        "enum { LastKind = 2 };",
        "enum { Plain = 3 };",
        "extern const int InEveryFramework;",
    },
    FFFixture = {
        "extern const int LastKind;",
        "extern const int EarlyIntro __attribute__((availability(ios, introduced=2.0)));",
        "extern const int InEveryFramework;",
    },
    GGFixture = {"extern const int GGOnly __attribute__((availability(ios, introduced=13.0)));"},
}

local function fixture(name, lines, broken)
    local sdk = workspace.fresh(name)
    io.writefile(path.join(sdk, "SDKSettings.json"), '{"Version": "99.9"}')
    local names = {}
    for framework in pairs(HEADERS) do
        table.insert(names, framework)
    end
    table.sort(names)
    for _, framework in ipairs(names) do
        local headers = path.join(sdk, "System", "Library", "Frameworks", framework .. ".framework", "Headers")
        os.mkdir(headers)
        io.writefile(path.join(headers, framework .. ".h"), table.concat(HEADERS[framework], "\n") .. "\n")
    end
    if broken then
        io.writefile(path.join(sdk, "System", "Library", "Frameworks", broken .. ".framework", "Headers", broken .. ".h"), '#error "the broken fixture header"\n')
    end
    return sdk
end

local function describe(intros)
    local lines = {}
    for name, found in pairs(intros) do
        table.insert(lines, string.format("%s %s %s", name, tostring(found.intro), found.kind))
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function computed(sdk, shards)
    local file = path.join(sdkfiles.cache_folder(sdk), "constant_intros.tsv")
    os.tryrm(file)
    local report = {}
    local intros = facts.constant_intros(sdk, {shards = shards, report = report})
    assert(os.isfile(file), "the constant intros of " .. tostring(shards) .. " shards were not cached")
    local bytes = io.readfile(file, {encoding = "binary"})
    os.tryrm(file)
    return intros, bytes, report.processes
end

local function failure_of(action)
    local failure
    try {
        function ()
            action()
        end,
        catch {
            function (raised)
                failure = tostring(raised)
            end
        }
    }
    return failure
end

function main()
    local before = {}
    for _, folder in ipairs(os.dirs(path.join(workspace.run(), "constant-intros.*"))) do
        before[folder] = true
    end
    local sdk = fixture("facts-parallel-sdk")
    local sequential, reference, processes = computed(sdk, 1)
    assert(processes == 0, "one shard started " .. tostring(processes) .. " processes, wanted none: it scans in the process that asked")
    local want = {
        Both = {intro = 7000, kind = "extern"}, EarlyIntro = {intro = 8000, kind = "extern"}, GGOnly = {intro = 13000, kind = "extern"},
        InEveryFramework = {intro = 3000, kind = "extern"}, LastKind = {intro = nil, kind = "extern"}, LateIntro = {intro = 9000, kind = "extern"},
        Member = {intro = 11000, kind = "enum"}, OnlyNil = {intro = nil, kind = "enum"}, Plain = {intro = nil, kind = "enum"},
    }
    for name, expected in pairs(want) do
        local found = sequential[name]
        assert(found and found.intro == expected.intro and found.kind == expected.kind,
               string.format("%s is %s %s in one shard, wanted %s %s", name, found and tostring(found.intro) or "missing", found and found.kind or "", tostring(expected.intro), expected.kind))
    end
    local names = 0
    for _ in pairs(sequential) do
        names = names + 1
    end
    assert(names == #table.keys(want), "the fixture has " .. #table.keys(want) .. " constants, one shard found " .. names .. ":\n" .. describe(sequential))

    local FRAMEWORKS = 7
    for _, shards in ipairs({0, 2, 3, 4, 7, 16}) do
        local intros, bytes, started = computed(sdk, shards)
        local wanted = math.min(shards, FRAMEWORKS) > 1 and math.min(shards, FRAMEWORKS) or 0
        assert(started == wanted, shards .. " shards requested started " .. tostring(started) .. " shard processes, wanted " .. wanted)
        assert(bytes == reference, shards .. " shards wrote another constant_intros.tsv than one shard:\n" .. bytes .. "\n---\n" .. reference)
        assert(describe(intros) == describe(sequential), shards .. " shards returned other constant intros than one shard:\n" .. describe(intros))
    end

    local default_intros, default_bytes, default_started = computed(sdk, nil)
    assert(default_started == 4, "the default is four shard processes, got " .. tostring(default_started))
    assert(default_bytes == reference, "the default shard count wrote another constant_intros.tsv than one shard")
    assert(describe(default_intros) == describe(sequential), "the default shard count returned other constant intros than one shard")

    local broken = fixture("facts-parallel-broken-sdk", nil, "DDFixture")
    local umbrella = path.join(broken, "System", "Library", "Frameworks", "DDFixture.framework", "Headers", "DDFixture.h")
    local cache = path.join(sdkfiles.cache_folder(broken), "constant_intros.tsv")
    for _, shards in ipairs({1, 3}) do
        local report = {}
        local failure = failure_of(function () facts.constant_intros(broken, {shards = shards, report = report}) end)
        assert(failure ~= nil, shards .. " shards did not fail for a header that does not compile")
        assert(report.processes == (shards > 1 and shards or 0), shards .. " shards requested started " .. tostring(report.processes) .. " shard processes before they failed")
        for _, part in ipairs({"clang failed to dump the declarations of " .. umbrella, "the broken fixture header", "-ast-dump"}) do
            assert(failure:find(part, 1, true), shards .. " shards failed without naming " .. part .. ":\n" .. failure)
        end
        assert(not os.isfile(cache), "the constant intros of a failed scan were cached by " .. shards .. " shards")
    end
    local leftovers = {}
    for _, folder in ipairs(os.dirs(path.join(workspace.run(), "constant-intros.*"))) do
        if not before[folder] then
            table.insert(leftovers, folder)
        end
    end
    assert(#leftovers == 0, "a failed or finished scan left its folder behind: " .. table.concat(leftovers, ", "))

    os.tryrm(sdkfiles.cache_folder(sdk))
    os.tryrm(sdkfiles.cache_folder(broken))
    os.tryrm(sdk)
    os.tryrm(broken)
    print("FACTS_PARALLEL_TEST passed")
end
