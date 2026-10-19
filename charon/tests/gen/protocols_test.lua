-- The generation set of the protocol objects and the files it emits (tools/gen/protocols.lua, generation_set of tools/gen.py@52253c0650), on a
-- fixture. A protocol is generated when the surface table lists it as an objc protocol, the 6.1.3 ledger lists it with a status other
-- than header-ok, and no registry row names it (the rule, rule_set). The set the build uses is the reviewed record (protocol-sets/<F>.tsv):
-- with the corpus, the rule must equal the record, and a difference is an error. Removing a registry row makes its protocol generated,
-- and the port must then emit its object, once the record names it.
-- The surface (the framework's declaration shard, computed by surface_model.lua), the corpus (the ledger), the registry, the record and
-- the snapshot are written as fixtures, in one folder under .agent-work/runs that is removed when the test ends.
-- Run: xmake l tests/gen/protocols_test.lua (exits 1 on any failure).

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local shards = import("surface_shards", {rootdir = os.scriptdir(), anonymous = true})
local FRAMEWORK = "FixtureKit"
local LEDGER_COLUMNS = {"kind", "lang", "api", "introduced", "header-introduced", "status", "needs", "reason"}
local PROTOCOL_COLUMNS = {"protocol", "introduced", "status", "reasons", "bases", "section", "kind", "instance", "selector", "decl", "in16"}
local RECORD_COLUMNS = {"protocol", "reviewed-by"}
-- The protocols of the fixture: one the registry row may name, one no registry row names, and one the port's headers
-- cover (header-ok).
local PROTOCOLS = {"FKProto", "FKRegistered", "FKHeaderOK"}

local function checks()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end, function() return count end
end

-- The names of a set, sorted and joined.
local function names_of(set)
    local out = {}
    for name in pairs(set) do
        table.insert(out, name)
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- Writes one fixture tree: the corpus (surface table and 6.1.3 ledger), the registry (a row for FKRegistered when with_registry), and the
-- snapshot (protocols.tsv). Returns the tree and the corpus.
local function write_fixture(dir, with_registry, record_status)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local corpus = path.join(dir, "corpus")
    local corpus_fixture = import("surface_corpus", {rootdir = os.scriptdir(), anonymous = true})
    corpus_fixture.write(corpus)
    local tree = path.join(dir, "tree")
    os.mkdir(tree)
    os.cp(TOOLS, path.join(tree, "tools"))
    os.cp(path.join(TOOLS, "..", "modules"), path.join(tree, "modules"))
    local surface_objc, ledger_rows, record_rows = {}, {}, {}
    for _, name in ipairs(PROTOCOLS) do
        table.insert(surface_objc, shards.objc_row("protocol", "c:objc(pl)" .. name, nil, nil, nil, "ios=7.0/-/-/0"))
        local status = name == "FKHeaderOK" and "header-ok" or "missing"
        table.insert(ledger_rows, {"protocol", "objc", name, "7.0", "7.0", status, "-", "fixture"})
        table.insert(record_rows, {name, "7.0", record_status or "sdk16 body", "", "NSObject", "required", "method", "yes", "reset", "- (void)reset", "-"})
    end
    shards.write(tree, FRAMEWORK, surface_objc, nil)
    emit.file(path.join(corpus, "ledger-w45", FRAMEWORK .. ".tsv"), tsv.table_text(LEDGER_COLUMNS, ledger_rows))
    if with_registry then
        emit.file(path.join(tree, layout.registry_dir(FRAMEWORK), "fixture.json"),
                  '{"entries": [{"api": "FKRegistered", "kind": "protocol"}]}\n')
    end
    local snap = layout.snap_dir(tree, FRAMEWORK)
    emit.file(path.join(snap, "protocols.tsv"), tsv.table_text(PROTOCOL_COLUMNS, record_rows))
    return tree, corpus
end

-- Writes the reviewed record of the fixture's protocol set: one row per protocol named.
local function write_record(tree, names)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local rows = {}
    for _, name in ipairs(names) do
        table.insert(rows, {name, "fixture"})
    end
    emit.file(layout.protocol_set_path(tree, FRAMEWORK), tsv.table_text(RECORD_COLUMNS, rows))
end

function main()
    local check, failures, count = checks()
    local protocols = import("gen.protocols", {rootdir = TOOLS, anonymous = true})
    local root = path.join(TOOLS, "..", ".agent-work", "runs", "protocols-test-" .. tostring(os.time()))
    os.mkdir(root)

    -- The registry names FKRegistered: the rule gives FKProto, and the record names it.
    local tree, corpus = write_fixture(path.join(root, "with"), true)
    write_record(tree, {"FKProto"})
    check(names_of(protocols.rule_set(tree, FRAMEWORK, corpus, "26.2")) == "FKProto",
          "with its registry row, the rule does not generate FKRegistered")
    local set = protocols.generation_set(tree, FRAMEWORK, corpus, "26.2")
    check(names_of(set) == "FKProto", "with the corpus, the set is the rule, which equals the record (got " .. names_of(set) .. ")")
    local files = protocols.protocol_files(tree, FRAMEWORK, corpus, "26.2")
    local objects = files["FixtureKitProtocols70.m"] or ""
    check(string.find(objects, "@protocol(FKProto),", 1, true) ~= nil, "the objects file names the generated protocol")
    check(string.find(objects, "FKRegistered", 1, true) == nil and string.find(objects, "FKHeaderOK", 1, true) == nil,
          "the objects file names no registered and no header-ok protocol")
    -- The build (no corpus) reads the same set from the record.
    check(names_of(protocols.generation_set(tree, FRAMEWORK, nil, "26.2")) == "FKProto", "without the corpus, the set is the record")

    -- The registry row of FKRegistered is removed: the rule generates it, and the record names it too: its object is emitted.
    tree, corpus = write_fixture(path.join(root, "without"), false)
    write_record(tree, {"FKProto", "FKRegistered"})
    check(names_of(protocols.rule_set(tree, FRAMEWORK, corpus, "26.2")) == "FKProto,FKRegistered",
          "without its registry row, the rule generates FKRegistered")
    set = protocols.generation_set(tree, FRAMEWORK, corpus, "26.2")
    check(names_of(set) == "FKProto,FKRegistered", "without its registry row, FKRegistered is in the set (got " .. names_of(set) .. ")")
    files = protocols.protocol_files(tree, FRAMEWORK, corpus, "26.2")
    objects = files["FixtureKitProtocols70.m"] or ""
    check(string.find(objects, "@protocol(FKRegistered),", 1, true) ~= nil,
          "the port emits the object of the protocol whose registry row was removed")

    -- A record that differs from the rule is an error with the corpus, naming the framework and the protocols on each side.
    local mismatch_tree, mismatch_corpus = write_fixture(path.join(root, "mismatch"), true)
    write_record(mismatch_tree, {"FKRegistered"})
    local raised, message = false, ""
    try {
        function() protocols.generation_set(mismatch_tree, FRAMEWORK, mismatch_corpus, "26.2") end,
        catch {
            function(e)
                raised = true
                message = tostring(e)
            end
        }
    }
    check(raised and string.find(message, FRAMEWORK, 1, true) ~= nil and string.find(message, "FKProto", 1, true) ~= nil,
          "a record that differs from the rule raises with the corpus, naming the framework and the protocol")

    -- A transcribed protocol has no declaration in the tree (the transcriber's header is not committed): a set that names one raises
    local transcribed_tree, transcribed_corpus = write_fixture(path.join(root, "transcribed"), true, "transcribed")
    write_record(transcribed_tree, {"FKProto"})
    raised, message = false, ""
    try {
        function() protocols.protocol_files(transcribed_tree, FRAMEWORK, transcribed_corpus, "26.2") end,
        catch {
            function(e)
                raised = true
                message = tostring(e)
            end
        }
    }
    check(raised and string.find(message, "FKProto", 1, true) ~= nil and string.find(message, "transcribed", 1, true) ~= nil,
          "a generation set that names a transcribed protocol raises, naming it")

    os.rm(root)
    local verdict = failures() == 0 and "OK" or ("FAIL " .. failures())
    print(string.format("protocols test: %s (%d checks)", verdict, count()))
    if failures() > 0 then
        os.exit(1)
    end
end
