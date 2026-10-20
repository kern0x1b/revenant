local ROOT = path.join(os.scriptdir(), "..", "..")
local TOOLS = path.join(ROOT, "tools")
local FIXTURES = path.join(os.scriptdir(), "input", "fixtures")
local SPEC = path.join("packages", "a", "apple-backports", "spec")
local REGISTRY = path.join("packages", "a", "apple-backports", "registry")
local COMPARED = {"CoreNFC", "Foundation"}
local SWIFT_ONLY = "WiFiInfrastructure"
local NO_CONSTANT = "Accelerate"
local UNLISTED = "NotListed"
local COPIED = {"CoreNFC", "Foundation", "CoreFoundation", "Security", NO_CONSTANT, SWIFT_ONLY}

local files = import("gen.files", {rootdir = TOOLS, anonymous = true})
local strings = import("gen.strings", {rootdir = TOOLS, anonymous = true})
local doc = import("gen.doc_text", {rootdir = TOOLS, anonymous = true})
local tbd = import("gen.tbd", {rootdir = TOOLS, anonymous = true})
local probe = import("gen.probe", {rootdir = TOOLS, anonymous = true})
local input = import("gen.cmd_input", {rootdir = TOOLS, anonymous = true})

local failures = 0

local function check(ok, label)
    if not ok then
        failures = failures + 1
        print("FAIL " .. label)
    end
end

local function read(filepath)
    return files.read_text(filepath)
end

local function attempt(fn, ...)
    local args = {...}
    local ok, err = true, nil
    try {
        function ()
            fn(table.unpack(args))
        end,
        catch {
            function (errors)
                ok, err = false, tostring(errors)
            end
        }
    }
    return ok, err
end

local function lines_of(text)
    local out = {}
    for _, line in ipairs(strings.lines(text or "")) do
        if line ~= "" then
            table.insert(out, line)
        end
    end
    return out
end

local function fixture(kind, fw)
    local text = read(path.join(FIXTURES, kind, fw .. ".txt"))
    return text and lines_of(text) or nil
end

local function scratch_tree()
    local tree = import("workspace", {rootdir = path.join(ROOT, "modules"), anonymous = true}).fresh("input-test")
    for _, fw in ipairs(COPIED) do
        local spec = path.join(ROOT, SPEC, fw)
        if os.isdir(spec) then
            os.mkdir(path.join(tree, SPEC))
            os.cp(spec, path.join(tree, SPEC, fw))
        end
        local registry = path.join(ROOT, REGISTRY, fw)
        if os.isdir(registry) then
            os.mkdir(path.join(tree, REGISTRY))
            os.cp(registry, path.join(tree, REGISTRY, fw))
        end
        local single = path.join(ROOT, REGISTRY, fw .. ".json")
        if os.isfile(single) then
            os.mkdir(path.join(tree, REGISTRY))
            os.cp(single, path.join(tree, REGISTRY, fw .. ".json"))
        end
    end
    return tree
end

local function add_objc_constant(corpus, fw)
    local ledger = path.join(corpus, "ledger-w45", fw .. ".tsv")
    local text = read(ledger)
    if string.sub(text, -1) ~= "\n" then
        text = text .. "\n"
    end
    io.writefile(ledger, text .. "constant\tobjc\tTestObjcConstant\t26.2\t\tmissing\tcode+lift\tthe test's Objective-C constant\n")
end

local function scratch_corpus(tree)
    local corpus = path.join(tree, "corpus")
    os.cp(path.join(FIXTURES, "corpus"), corpus)
    os.cp(path.join(corpus, "ledger-w45", NO_CONSTANT .. ".tsv"), path.join(corpus, "ledger-w45", UNLISTED .. ".tsv"))
    add_objc_constant(corpus, UNLISTED)
    return corpus
end

local function use_fixtures()
    doc.use(function (fw)
        local rows = fixture("doc", fw)
        if rows == nil then
            return nil
        end
        return rows
    end)
    tbd.use(function (fw)
        local set = {}
        for _, name in ipairs(fixture("exports", fw) or {}) do
            set[name] = true
        end
        return set
    end)
    probe.use(function (fw)
        local values = {}
        for _, line in ipairs(lines_of(read(path.join(FIXTURES, "probe", fw .. ".tsv")))) do
            local cells = {}
            for cell in string.gmatch(line .. "\t", "([^\t]*)\t") do
                table.insert(cells, cell)
            end
            values[cells[1]] = {cells[2], cells[3]}
        end
        return values
    end)
end

local function stop_fixtures()
    doc.use(nil)
    tbd.use(nil)
    probe.use(nil)
end

function main()
    use_fixtures()
    local tree = scratch_tree()
    local corpus = scratch_corpus(tree)
    local args = function (fw)
        return {tree = tree, sdk = FIXTURES, coordination = corpus, framework = fw}
    end

    local records, rows = 0, 0
    for _, fw in ipairs(COMPARED) do
        check(input.run(args(fw)) == 0, "input writes " .. fw .. " (exit 0)")
        local written = read(path.join(tree, SPEC, fw, "constants.tsv"))
        local committed = read(path.join(ROOT, SPEC, fw, "constants.tsv"))
        check(written ~= nil and committed ~= nil, "input " .. fw .. ": a written and a committed record exist")
        if written and committed then
            check(written == committed, "input " .. fw .. ": the written record is byte-identical to the committed one")
            if written == committed then
                records = records + 1
                rows = rows + #lines_of(committed) - 1
            end
        end
    end

    check(input.run(args(SWIFT_ONLY)) == 0, "input of a Swift-only framework with no Objective-C constant exits 0")
    check(read(path.join(tree, SPEC, SWIFT_ONLY, "constants.tsv")) == nil, "a Swift-only framework with no Objective-C constant writes no record")

    local objc_corpus = path.join(tree, "corpus-objc")
    os.cp(corpus, objc_corpus)
    add_objc_constant(objc_corpus, SWIFT_ONLY)
    local ok, err = attempt(input.run, {tree = tree, sdk = FIXTURES, coordination = objc_corpus, framework = SWIFT_ONLY})
    local swift_named = not ok and string.find(err, "input " .. SWIFT_ONLY .. ": a Swift-only module", 1, true) ~= nil
    check(swift_named, "input names a Swift-only framework whose ledger lists an Objective-C constant")

    check(input.run(args(NO_CONSTANT)) == 0, "input of a framework with no constant exits 0")
    check(read(path.join(tree, SPEC, NO_CONSTANT, "constants.tsv")) == nil, "a framework with no constant writes no record")
    check(read(path.join(ROOT, SPEC, NO_CONSTANT, "constants.tsv")) == nil, "a framework with no constant has no committed record")

    local unlisted_ok, unlisted_err = attempt(input.run, args(UNLISTED))
    local unlisted_named = not unlisted_ok and string.find(unlisted_err, "does not list it", 1, true) ~= nil
    check(unlisted_named, "input names a framework the extractor does not list")

    local committed = read(path.join(ROOT, SPEC, "CoreNFC", "constants.tsv"))
    local mutant = string.gsub(committed, "\tfound\t", "\tmissing\t", 1)
    local detected = mutant ~= committed and mutant ~= read(path.join(tree, SPEC, "CoreNFC", "constants.tsv"))
    check(detected, "a mutant of the committed CoreNFC record differs from the written record")

    stop_fixtures()
    local named = (swift_named and 1 or 0) + (unlisted_named and 1 or 0)
    print(string.format("input test: %d records compared byte for byte (%d constant rows); %d named failures checked; mutant detected: %s",
        records, rows, named, tostring(detected)))
    check(records > 0, "the input test compared at least one record")
    check(rows > 0, "the input test compared at least one constant row")
    print("input test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        print("input test: the run tree is kept for the failure: " .. tree)
        os.exit(1)
    end
    os.rmdir(tree)
end
