local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local FRAMEWORK = "FixKit"
local OUT = "packages/a/apple-backports"
local SHARD_COLUMNS = "kind,usr,container,name,side,type,params,attrs,availability,message,declhash"
local CONSTANT_HASH = "1111111111111111"

local function checks()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end
end

local function members(hashes)
    return {
        {cls = "FKThing", kind = "method", api = "-[FKThing reset]", text = "", hash = hashes.reset},
        {cls = "FKThing", kind = "method", api = "-[FKThing setLevel:]", text = "", hash = hashes.setLevel},
        {cls = "FKThing", kind = "method", api = "-[FKThing count]", text = "", hash = hashes.count},
    }
end

local function read(filepath)
    local files = import("gen.files", {rootdir = TOOLS, anonymous = true})
    return files.read_text(filepath)
end

local function shard_text(constant_declhash)
    return "#libclang=fixture\tsdk=fixture\tcolumns=" .. SHARD_COLUMNS .. "\n"
        .. "var\tc:@FKConst\t-\t\t-\tNSString *const\t-\t-\t-\t-\t" .. constant_declhash .. "\n"
end

local function constant_record()
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local columns = {}
    for _, name in ipairs(layout.constants().SPEC_COLUMNS) do
        table.insert(columns, name)
    end
    local function row(api)
        return {"constant", api, "-", api, "7.0", "NSString *const", "API_AVAILABLE(macos(10.9), ios(7.0))", "2222222222222222",
                "found", api, api, "ios-26.2-cache", "-", "exported", "ns", "7.0"}
    end
    return tsv.table_text(columns, {row("FKConst"), row("FKNoDecl")})
end

local function write_inputs(tree)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local snapshot = import("gen.spec", {rootdir = TOOLS, anonymous = true})
    emit.file(layout.shard_path(tree, FRAMEWORK), shard_text(CONSTANT_HASH))
    emit.file(path.join(tree, layout.registry_dir(FRAMEWORK), "ios.json"),
        '{"entries":[{"api":"-[FKThing reset]","kind":"method","status":"implemented","owner":"hand"},'
        .. '{"api":"-[FKThing setLevel:]","kind":"method","status":"implemented","owner":"hand"}]}\n')
    local registry = path.join(layout.registry_dir(FRAMEWORK), "ios.json")
    emit.file(layout.pins_path(tree, FRAMEWORK), snapshot.pins_text({
        {api = "-[FKThing reset]", key = "FKThing_reset", pinned = "bbbbbbbbbbbbbbbb", ["pinned-by"] = "bootstrap", registry = registry},
        {api = "-[FKThing setLevel:]", key = "FKThing_setLevel", pinned = "aaaaaaaaaaaaaaaa", ["pinned-by"] = "bootstrap", registry = registry},
    }))
    emit.file(layout.constant_record_path(tree, FRAMEWORK), constant_record())
end

local function differing(before, after)
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local a, b = tsv.lines(before), tsv.lines(after)
    local out = {}
    if #a ~= #b then
        table.insert(out, "line count " .. #a .. " -> " .. #b)
    end
    for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then
            table.insert(out, string.format("line %d: [%s] -> [%s]", i, tostring(a[i]), tostring(b[i])))
        end
    end
    return out
end

function main()
    local check, failures = checks()
    local gen = import("gen.cmd_gen", {rootdir = TOOLS, anonymous = true})
    local release_fixture = import("release_fixture", {rootdir = os.scriptdir(), anonymous = true})
    local snapshot = import("gen.spec", {rootdir = TOOLS, anonymous = true})
    local headers = import("gen.headers", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local root = path.join(os.scriptdir(), "..", "..", ".agent-work", "runs", "record-test-" .. tostring(os.time()) .. "-"
                           .. tostring(math.random(1000000)))
    local tree = path.join(root, "tree")
    os.mkdir(tree)
    local sdk = release_fixture.write(root, {FRAMEWORK})

    local current = members({reset = "bbbbbbbbbbbbbbbb", setLevel = "aaaaaaaaaaaaaaaa", count = "cccccccccccccccc"})
    headers.use(function() return {members = current, declared = {}, typedefs = {}, superclasses = {}} end)
    write_inputs(tree)
    local pins_path = layout.pins_path(tree, FRAMEWORK)
    local spec_path = layout.spec_path(tree, FRAMEWORK, "26.2")
    local constants_path = layout.constant_record_path(tree, FRAMEWORK)

    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK}) == 0, "gen with every pin and constant matching the shard succeeds")
    check(#snapshot.refused(tree, FRAMEWORK) == 0, "no pin and no constant is refused at the baseline")
    local pins_before = read(pins_path)
    local constants_before = read(constants_path)

    current = members({reset = "bbbbbbbbbbbbbbbb", setLevel = "aaaaaaaaaaaaaaaa", count = "c2c2c2c2c2c2c2c2"})
    snapshot.forget()
    check(#snapshot.refused(tree, FRAMEWORK) == 0, "an unpinned member whose declaration changed is not refused")
    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK}) == 0, "gen succeeds when only an unpinned member changed")
    local spec_text = read(spec_path) or ""
    check(string.find(spec_text, "c2c2c2c2c2c2c2c2", 1, true) ~= nil, "the unpinned member's new hash is in the generated spec")
    check(read(pins_path) == pins_before, "the pins are unchanged by an unpinned change")

    current = members({reset = "bbbbbbbbbbbbbbbb", setLevel = "a2a2a2a2a2a2a2a2", count = "c2c2c2c2c2c2c2c2"})
    snapshot.forget()
    local refused = snapshot.refused(tree, FRAMEWORK)
    check(#refused == 1 and refused[1].key == "FKThing_setLevel", "exactly the pinned member that changed is refused, by key")
    check(#refused == 1 and refused[1].old == "aaaaaaaaaaaaaaaa" and refused[1].new == "a2a2a2a2a2a2a2a2",
          "the refusal carries the pinned and the shard's declaration hash")
    if #refused == 1 then
        local message = gen.refusal(tree, FRAMEWORK, refused[1])
        check(string.find(message, "FKThing_setLevel", 1, true) ~= nil, "the refusal message names the key")
        check(string.find(message, "pinned declaration hash aaaaaaaaaaaaaaaa, the shard has a2a2a2a2a2a2a2a2", 1, true) ~= nil,
              "the refusal message gives both hashes")
        check(string.find(message, "--record", 1, true) ~= nil, "the refusal message gives the command to re-record")
    end
    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK}) == 1, "gen refuses a changed pinned member with exit status 1")
    check(read(pins_path) == pins_before, "a refusal leaves the pins as they were")
    check(string.find(read(spec_path) or "", "aaaaaaaaaaaaaaaa", 1, true) ~= nil
          and string.find(read(spec_path) or "", "a2a2a2a2a2a2a2a2", 1, true) == nil, "a refused framework writes nothing: the spec is the baseline's")

    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK, record = true}) == 0, "gen --record re-records the refused pin and succeeds")
    local registry = path.join(layout.registry_dir(FRAMEWORK), "ios.json")
    local diff = differing(pins_before, read(pins_path))
    local expected = string.format("-[FKThing setLevel:]\tFKThing_setLevel\ta2a2a2a2a2a2a2a2\trepin\t%s", registry)
    check(#diff == 1 and string.find(diff[1], expected, 1, true) ~= nil,
          "gen --record changes exactly the refused pin's row, to the new hash with pinned-by repin (got " .. table.concat(diff, "; ") .. ")")
    check(#snapshot.refused(tree, FRAMEWORK) == 0, "after the re-record nothing is refused")
    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK}) == 0, "gen succeeds after the re-record, with no --record")
    check(read(constants_path) == constants_before, "the constant record is unchanged by the member changes")

    local pins_mid = read(pins_path)
    emit.file(layout.shard_path(tree, FRAMEWORK), shard_text("3333333333333333"))
    snapshot.forget()
    refused = snapshot.refused(tree, FRAMEWORK)
    check(#refused == 0, "a constant whose shard declaration changed is not refused (got " .. #refused .. ")")
    check(gen.run({sdk = sdk, tree = tree, framework = FRAMEWORK}) == 0, "gen with a changed constant declaration still succeeds")
    check(read(constants_path) == constants_before, "gen leaves the constant record as input wrote it")
    check(read(pins_path) == pins_mid, "gen leaves the pins as they were")

    headers.use(nil)
    os.rm(root)
    print("record test: " .. (failures() == 0 and "OK" or ("FAIL " .. failures())))
    if failures() > 0 then
        os.exit(1)
    end
end
