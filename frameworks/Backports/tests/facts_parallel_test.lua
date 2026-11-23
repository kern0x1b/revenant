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
    return intros, bytes, report.pids
end

local function assert_children(pids, count, what)
    assert(#pids == count, what .. " started " .. #pids .. " shard processes, wanted " .. count)
    local seen = {}
    for _, pid in ipairs(pids) do
        assert(pid ~= nil and pid > 0 and pid ~= os.getpid(), what .. " ran a shard in the process that asked (pid " .. tostring(pid) .. ")")
        assert(not seen[pid], what .. " ran two shards in the process " .. pid)
        seen[pid] = true
    end
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
    local sequential, reference, pids = computed(sdk, 1)
    assert_children(pids, 0, "one shard")
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
        local intros, bytes, children = computed(sdk, shards)
        assert_children(children, math.min(shards, FRAMEWORKS) > 1 and math.min(shards, FRAMEWORKS) or 0, shards .. " shards requested")
        assert(bytes == reference, shards .. " shards wrote another constant_intros.tsv than one shard:\n" .. bytes .. "\n---\n" .. reference)
        assert(describe(intros) == describe(sequential), shards .. " shards returned other constant intros than one shard:\n" .. describe(intros))
    end

    local default_intros, default_bytes, default_children = computed(sdk, nil)
    assert_children(default_children, 4, "the default shard count")
    assert(default_bytes == reference, "the default shard count wrote another constant_intros.tsv than one shard")
    assert(describe(default_intros) == describe(sequential), "the default shard count returned other constant intros than one shard")

    local cached_file = path.join(sdkfiles.cache_folder(sdk), "constant_intros.tsv")
    os.tryrm(cached_file)
    facts.constant_intros(sdk, {shards = 3})
    local cached_report = {pids = {1, 2, 3}}
    local from_cache = facts.constant_intros(sdk, {shards = 3, report = cached_report})
    assert_children(cached_report.pids, 0, "a read of the cache")
    assert(describe(from_cache) == describe(sequential), "the cached constant intros differ from the computed ones")
    os.tryrm(cached_file)

    local broken = fixture("facts-parallel-broken-sdk", nil, "DDFixture")
    local umbrella = path.join(broken, "System", "Library", "Frameworks", "DDFixture.framework", "Headers", "DDFixture.h")
    local cache = path.join(sdkfiles.cache_folder(broken), "constant_intros.tsv")
    for _, shards in ipairs({1, 3}) do
        local failure = failure_of(function () facts.constant_intros(broken, {shards = shards}) end)
        assert(failure ~= nil, shards .. " shards did not fail for a header that does not compile")
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
