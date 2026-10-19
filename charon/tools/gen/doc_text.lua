-- The doc-time text of a framework's declarations: the doc comments and the declaration text, which the doc pages show and the
-- snapshot does not hold (ruling 2: the comments are re-derived from clang at doc time; ruling D8: so is the declaration text).
-- The source is the extractor's doc mode, `decls --doc <F>` (tools/found/decls.cc; design-foundation.md 5.9): one row per
-- declaration, ten cells, read through a pipe and never written to a file. The frameworks the extractor can run for are the ones its
-- `decls --list` names (read through the same kind of pipe). A framework it does not list has no rows: the pages keep their marked
-- text for it. A framework it lists whose rows cannot be produced (decls --doc fails) is an error: the doc command fails, and no page
-- takes marked text in its place. The extractor is the decls target of tools/found, which host.lua asks xmake for.
--
-- The cells of a row, in order: framework, kind, usr, container, name, side, the parameter names (separated by " | "), the brief of
-- the doc comment, its raw text as clang parses it, and the declaration as written. The extractor escapes a backslash, a tab, a
-- line feed and a carriage return as \\, \t, \n, \r in every cell, so a row is one line; decode() undoes that.

local stream = import("stream", {anonymous = true})
local host = import("host", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})
local swift_docs = import("swift_docs", {anonymous = true})

-- The program: `env` sets IR_SDK for the extractor, which stream.run starts under sh (its arguments are passed as they are).
local ENV = "/usr/bin/env"
local CELL_COUNT = 10
local CELL = {framework = 1, kind = 2, usr = 3, container = 4, name = 5, side = 6, params = 7, brief = 8, comment = 9, decl = 10}
local MEMBER_KINDS = {method = true, property = true}
local UNESCAPE = {["\\"] = "\\", t = "\t", n = "\n", r = "\r"}

-- Test seam: use(source) answers from source(fw, sdk) instead of the extractor. source returns the rows of fw as escaped lines, or nil
-- when the extractor does not list fw. For tests, which must not run the extractor.
local injected = nil

-- Replaces the extractor by source(fw, sdk), for the tests of the pages.
function use(source)
    injected = source
end

-- The extractor's binary for a tree: the decls target of tools/found, as xmake gives it when asked from the tree, so it is the product
-- of the tree's own configuration and build folder (build/macosx/arm64/release/decls under the tree, where xmake puts it). The binary
-- is built by xmake -P tools/found, run from the tree; one that is not built is an error, since nothing then says what is listed.
local binary_memo = {}

local function binary(tree)
    local root = path.absolute(tree)
    if binary_memo[root] == nil then
        local file, notes = host.target_product(root, path.join(root, "tools", "found"), "decls")
        -- the warning xmake prints after the object is the reason on a tree the extractor's project was never configured in
        local built = "(build it from the tree: xmake f -P tools/found -y && xmake -P tools/found)"
        assert(os.isfile(file), "the extractor is not built: " .. file .. " " .. built .. (notes ~= "" and ("; xmake said: " .. notes) or ""))
        binary_memo[root] = file
    end
    return binary_memo[root]
end

-- The frameworks the extractor lists for an SDK, as a set: `decls --list`, read once per tree and SDK.
local listed_cache = {}

local function listed(tree, sdk)
    local file = binary(tree)
    local key = file .. "\n" .. sdk
    if listed_cache[key] == nil then
        local names = {}
        local status, err = stream.run(ENV, {"IR_SDK=" .. sdk, file, "--list"}, function(line)
            local name = string.match(line, "^([^\t]*)")
            if name ~= "" then
                names[name] = true
            end
        end)
        assert(status == 0, "decls --list failed (status " .. status .. "): " .. host.tail(err, 300))
        listed_cache[key] = names
    end
    return listed_cache[key]
end

-- Whether the extractor lists a framework for the SDK: `decls --list` names it. Its doc mode runs for a listed framework only.
function available(tree, fw, sdk)
    if injected then
        return injected(fw, sdk) ~= nil
    end
    return listed(tree, sdk)[fw] == true
end

-- The cells of one row, unescaped (the inverse of the extractor's escaping). A row has no raw tab, so its cells are the pieces
-- between the tabs.
function decode(line)
    local cells = {}
    local pos = 1
    repeat
        local tab = string.find(line, "\t", pos, true)
        table.insert(cells, (string.gsub(string.sub(line, pos, tab and tab - 1 or #line), "\\(.)", UNESCAPE)))
        pos = tab and tab + 1
    until pos == nil
    return cells
end

-- The side of a member as the shard reader gives it (headers.lua shard_facts, design-foundation.md 3.5): a class method (USR class
-- part "(cm)") and a class property ("(cpy)") are "+", every other member "-". The extractor's own side column is not used for a
-- property, so the rows match the spec's api.
local function side_of(kind, usr)
    if kind == "method" and string.find(usr, "(cm)", 1, true) then
        return "+"
    end
    if kind == "property" and string.find(usr, "(cpy)", 1, true) then
        return "+"
    end
    return "-"
end

-- The api a member row has, as the spec writes it: its side, "[", its owner class (or protocol) and its name, "]". The owner is the
-- one the USR names ("c:objc(cs)Class(im)sel", "c:objc(pl)Protocol(cm)sel"). A row that is not a method or property has none.
local function api_of(kind, usr, name)
    if not MEMBER_KINDS[kind] then
        return nil
    end
    local owner = string.match(usr, "^c:objc%(%a+%)([^%(]+)")
    if owner == nil then
        return nil
    end
    return side_of(kind, usr) .. "[" .. owner .. " " .. name .. "]"
end

-- The doc-time fields of one row: its kind, its api (members only), its comment (the raw text, or the brief when the raw text is
-- empty: from_brief says which), its declaration text and its parameter names.
local function entry_of(cells)
    local raw, brief = cells[CELL.comment], cells[CELL.brief]
    return {
        kind = cells[CELL.kind],
        api = api_of(cells[CELL.kind], cells[CELL.usr], cells[CELL.name]),
        comment = raw ~= "" and raw or brief,
        from_brief = raw == "" and brief ~= "",
        decl = cells[CELL.decl],
        params = cells[CELL.params],
    }
end

-- The doc-time rows of a framework, or nil and a reason when the extractor does not list the framework (its pages keep the marked
-- text). A listed framework whose doc mode fails is an error, with the extractor's message: no rows are returned for it. The result
-- has two maps, both built in the rows' order: usr, from each USR to its row (a USR
-- the extractor writes twice keeps its first row), and api, from "kind api" ("method -[Class selector]") to the first row of a member.
-- A row is {kind, api (members only, else nil), comment, from_brief, decl, params}: comment is the raw comment text, or the brief
-- when the raw text is empty (from_brief says so); "" when the declaration has no doc comment of the forms the extractor keeps.
function rows(tree, fw, sdk)
    if not available(tree, fw, sdk) then
        return nil, "the extractor does not list it"
    end
    local usr, api = {}, {}
    local function take(line)
        local cells = decode(line)
        assert(#cells == CELL_COUNT, "a doc row of " .. fw .. " has " .. #cells .. " cells, not " .. CELL_COUNT)
        local key = cells[CELL.usr]
        if key ~= "-" and usr[key] == nil then
            local entry = entry_of(cells)
            usr[key] = entry
            if entry.api ~= nil and api[entry.kind .. " " .. entry.api] == nil then
                api[entry.kind .. " " .. entry.api] = entry
            end
        end
    end
    local status, err = 0, ""
    if injected then
        -- a source returns the framework's rows, and a failure message when the extractor lists it but its doc mode fails
        local lines, failure = injected(fw, sdk)
        if failure ~= nil then
            status, err = 1, failure
        end
        for _, line in ipairs(lines) do
            take(line)
        end
    elseif (sdk_modules.module_of(sdk, fw) or {}).kind == "swift" then
        -- a Swift-only module has no C header, so the extractor's doc mode has no declarations for it: its rows are its Swift interface's
        -- (swift_docs.lua)
        for _, line in ipairs(swift_docs.lines(tree, sdk, fw)) do
            take(line)
        end
    else
        status, err = stream.run(ENV, {"IR_SDK=" .. sdk, binary(tree), "--doc", fw}, take)
    end
    assert(status == 0, "doc " .. fw .. ": the extractor lists it, but its doc rows cannot be produced: decls --doc exits with status "
           .. status .. (err ~= "" and (": " .. host.tail(err, 300)) or ""))
    return {usr = usr, api = api}
end
