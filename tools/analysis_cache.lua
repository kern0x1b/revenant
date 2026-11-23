local analysis = import("@addon.revenant.analysis_cache", {anonymous = true})

local root = path.absolute(path.directory(os.scriptdir()))

local USAGE = [=[usage: ./xmakew l -P . tools/analysis_cache.lua [sync | restore | publish | test]

restore  gives this checkout the Backports analysis it lacks: for each installed iPhoneOS SDK, the files of the facts folder
         (.cache/backports/<key>) and of the module cache (.cache/modcache/<key>) that the shared store holds under the same
         content key are cloned copy-on-write into this checkout's .cache; a file the checkout already has is left alone
publish  is the other way round: what this checkout holds under a key and the store lacks is cloned into the store, so that
         the next checkout, or the next worktree of a worker, starts warm
sync     (the default) is restore, then publish
test     runs the checks on fixtures

A key is the content of the SDK, the toolchain and the facts tools (frameworks/Backports/tools/sdk.lua), so a file stored under
it is the file any checkout would compute.]=]

local function sdkfiles()
    return import("sdk", {rootdir = path.join(root, "frameworks", "Backports", "tools"), anonymous = true})
end

local function report(verb, moved, source)
    local lines = analysis.lines_of(verb, moved, source)
    if #lines == 0 then
        print("analysis cache: nothing to %s", verb == "restored" and "restore" or "publish")
    end
    for _, line in ipairs(lines) do
        print("%s", line)
    end
end

local function write(file, text)
    os.mkdir(path.directory(file))
    io.writefile(file, text)
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
    local base = path.join(os.tmpdir(), "analysis-cache-" .. hash.uuid())
    local function opt(home)
        return {home = path.join(base, home), store = path.join(base, "store")}
    end
    local function text(home, ...)
        local file = path.join(base, home, ...)
        return os.isfile(file) and io.readfile(file) or nil
    end
    local function names(moved)
        local found = {}
        for folder, number in pairs(moved) do
            table.insert(found, folder .. "=" .. number)
        end
        table.sort(found)
        return table.concat(found, " ")
    end
    local folders = {"backports/k1", "modcache/m1", "backports/absent"}

    write(path.join(base, "one", "backports", "k1", "CoreFoundation.tsv"), "cf")
    write(path.join(base, "one", "backports", "k1", "constant_intros.tsv"), "ci")
    write(path.join(base, "one", "backports", "k1", ".hidden.tsv"), "hidden")
    write(path.join(base, "one", "modcache", "m1", "ab", "Foo.pcm"), "pcm")
    write(path.join(base, "one", "backports", "k1.lock"), "")
    write(path.join(base, "one", "backports", "k2", "Other.tsv"), "other key")

    check("publishing into an empty store moves every file of the listed folders", names(analysis.publish(folders, opt("one"))), "backports/k1=3 modcache/m1=1")
    check("a published file is in the store under the same key", text("store", "backports", "k1", "CoreFoundation.tsv"), "cf")
    check("a nested file of a module cache is published with its folder", text("store", "modcache", "m1", "ab", "Foo.pcm"), "pcm")
    check("a hidden file is published too", text("store", "backports", "k1", ".hidden.tsv"), "hidden")
    check("a folder that was not listed is not published", os.exists(path.join(base, "store", "backports", "k2")), false)
    check("the files of the folder arrive, and nothing beside them", #os.files(path.join(base, "store", "backports", "k1", "**")), 3)
    check("publishing the same content again moves nothing", names(analysis.publish(folders, opt("one"))), "")
    check("no staging folder is left behind", #os.dirs(path.join(base, "store", "backports", ".analysis-*")) + #os.dirs(path.join(base, "store", "modcache", ".analysis-*")), 0)

    check("restoring into an empty checkout brings every file", names(analysis.restore(folders, opt("two"))), "backports/k1=3 modcache/m1=1")
    check("a restored file has the stored content", text("two", "backports", "k1", "constant_intros.tsv"), "ci")
    check("restoring again moves nothing", names(analysis.restore(folders, opt("two"))), "")

    write(path.join(base, "three", "backports", "k1", "CoreFoundation.tsv"), "mine")
    write(path.join(base, "three", "backports", "k1", "Mine.tsv"), "only here")
    check("restoring into a partial folder adds only what is missing", names(analysis.restore(folders, opt("three"))), "backports/k1=2 modcache/m1=1")
    check("a file the checkout has is not overwritten", text("three", "backports", "k1", "CoreFoundation.tsv"), "mine")
    check("a file only the checkout has stays", text("three", "backports", "k1", "Mine.tsv"), "only here")
    check("a missing file arrives", text("three", "backports", "k1", "constant_intros.tsv"), "ci")
    check("publishing a partial folder adds only the file the store lacks", names(analysis.publish(folders, opt("three"))), "backports/k1=1")
    check("the store keeps its own file for a name both hold", text("store", "backports", "k1", "CoreFoundation.tsv"), "cf")
    check("the store gains the file it lacked", text("store", "backports", "k1", "Mine.tsv"), "only here")

    check("a restored file is a separate file, changing it leaves the store alone", (function ()
        io.writefile(path.join(base, "two", "backports", "k1", "CoreFoundation.tsv"), "changed")
        return text("store", "backports", "k1", "CoreFoundation.tsv")
    end)(), "cf")

    local stale = path.join(base, "four", "backports", ".analysis-stale")
    local fresh = path.join(base, "four", "backports", ".analysis-fresh")
    os.mkdir(stale)
    os.mkdir(fresh)
    os.vrunv("touch", {"-t", "200001010000", stale})
    analysis.restore(folders, opt("four"))
    check("a staging folder left long ago is removed", os.isdir(stale), false)
    check("a recent staging folder is left to the process that made it", os.isdir(fresh), true)

    local lines = analysis.lines_of("restored", {["backports/k1"] = 3, ["modcache/m1"] = 1}, "from the store")
    check("a report names the folder, the number of files and the source", table.concat(lines, "\n"),
          "analysis cache: restored 3 files of backports/k1 from the store (copy on write)\nanalysis cache: restored 1 files of modcache/m1 from the store (copy on write)")

    os.tryrm(base)
    print("analysis_cache: %d tests passed", count)
end

function main(command)
    if command == "test" then
        test_suite()
        return
    end
    if command and command ~= "sync" and command ~= "restore" and command ~= "publish" then
        raise("%s", USAGE)
    end
    local folders = analysis.folders(sdkfiles())
    if #folders == 0 then
        print("analysis cache: no iPhoneOS SDK is installed in the store, so there is no key to share")
        return
    end
    if command ~= "publish" then
        report("restored", analysis.restore(folders), "from the store")
    end
    if command ~= "restore" then
        report("published", analysis.publish(folders), "to the store")
    end
end
