-- Captures the fixtures of the input light test (tests/gen/input_test.lua) from the real modules of a tree whose extractor is built
-- (xmake -P tools/found), with the SDK and the coordination corpus at hand. Run from the tree's root:
--   xmake l tests/gen/input/capture.lua <tree> <sdk> <corpus>
-- It writes tests/gen/input/fixtures under the tree: for each of the four frameworks the ledger's constant rows (corpus/ledger-w45),
-- the extractor's doc rows of those constants (decls --doc, their comment cells replaced by synthetic text: see synthetic_row), the exports
-- the SDK's .tbd gives, the host probe's values of those constants; and the iOS 26.2 cache rows of the same names (corpus/cache-26.2,
-- gzip). The fixtures hold no absolute path: the SDK and the corpus are read, not written.

local FRAMEWORKS = {"CoreNFC", "Foundation", "Accelerate", "WiFiInfrastructure"}
local SWIFT_ONLY = "WiFiInfrastructure"
local DOC_USR = 3  -- the doc row's cells: framework, kind, usr, ...

local function write_file(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "w"))
    handle:write(text)
    handle:close()
end

-- A doc row with its comment cells replaced by synthetic text of the same shape: the brief (cell 8) becomes one line of ours, and the
-- raw comment (cell 9) keeps its lines and their forms (a /*! block line for line, a /// line). The input test reads the USR and the
-- declaration only, so it sees the same rows; the SDK's comment text is not written into the fixtures. The extractor writes a line feed
-- as the two characters \n, and the cells are joined back the same way.
local BRIEF_CELL, RAW_CELL, NAME_CELL = 8, 9, 5
local ESCAPED_LINE_FEED = "\\n"

local function synthetic_row(tsv, line)
    local cells = tsv.fields(line)
    local name = cells[NAME_CELL]
    if cells[BRIEF_CELL] ~= "" then
        cells[BRIEF_CELL] = "Fixture brief of " .. name .. ", written for the input test."
    end
    if cells[RAW_CELL] ~= "" then
        local lines, pos = {}, 1
        while true do
            local at = string.find(cells[RAW_CELL], ESCAPED_LINE_FEED, pos, true)
            if at == nil then
                table.insert(lines, string.sub(cells[RAW_CELL], pos))
                break
            end
            table.insert(lines, string.sub(cells[RAW_CELL], pos, at - 1))
            pos = at + #ESCAPED_LINE_FEED
        end
        local content = 0
        for i, text in ipairs(lines) do
            local opens_block = string.sub(text, 1, 2) == "/*"
            local closes_block = string.find(text, "^%s*%*/$") ~= nil
            if not opens_block and not closes_block then
                content = content + 1
                local lead = string.match(text, "^(%s*%*%s*)") or string.match(text, "^(///%s*)") or ""
                lines[i] = lead .. "Fixture comment line " .. content .. " of " .. name .. "."
            end
        end
        cells[RAW_CELL] = table.concat(lines, ESCAPED_LINE_FEED)
    end
    return table.concat(cells, "\t")
end

function main(tree, sdk, corpus)
    tree = path.absolute(tree)
    local TOOLS = path.join(tree, "tools")
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local strings = import("gen.strings", {rootdir = TOOLS, anonymous = true})
    local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
    local probe = import("gen.probe", {rootdir = TOOLS, anonymous = true})
    local tbd = import("gen.tbd", {rootdir = TOOLS, anonymous = true})
    local doc_text = import("gen.doc_text", {rootdir = TOOLS, anonymous = true})
    local surface = import("gen.surface", {rootdir = TOOLS, anonymous = true})
    local fixtures = path.join(tree, "tests", "gen", "input", "fixtures")
    local decls = host.target_product(tree, path.join(tree, "tools", "found"), "decls")

    -- the ledger's constant rows, as the file holds them (the header line first), and the names they name
    local names, ledgers = {}, {}
    for _, fw in ipairs(FRAMEWORKS) do
        local lines = strings.lines(io.readfile(surface.ledger_file(corpus, surface.ledger_6_1_3(), fw)))
        local kind, api = nil, nil
        local out = {lines[1]}
        for index, cell in ipairs(tsv.fields(lines[1])) do
            if cell == "kind" then kind = index end
            if cell == "api" then api = index end
        end
        assert(kind ~= nil and api ~= nil, "the ledger of " .. fw .. " has no kind or api column")
        for i = 2, #lines do
            if lines[i] ~= "" and tsv.fields(lines[i])[kind] == "constant" then
                table.insert(out, lines[i])
                names[fw] = names[fw] or {}
                table.insert(names[fw], tsv.fields(lines[i])[api])
            end
        end
        ledgers[fw] = table.concat(out, "\n") .. "\n"
        write_file(path.join(fixtures, "corpus", "ledger-w45", (string.gsub(fw, "/", "_")) .. ".tsv"), ledgers[fw])
    end

    -- the names of the constants of the four frameworks: the iOS rows and the exports are kept for them
    local wanted = {}
    for _, fw in ipairs(FRAMEWORKS) do
        for _, api in ipairs(names[fw] or {}) do
            wanted[api] = true
        end
    end

    -- the doc rows, the exports and the host probe, per framework
    for _, fw in ipairs(FRAMEWORKS) do
        if fw ~= SWIFT_ONLY then
            local text = os.iorunv(decls, {"--doc", fw}, {envs = {IR_SDK = sdk}})
            local keep = {}
            local wanted_usr = {}
            for _, api in ipairs(names[fw] or {}) do
                wanted_usr["c:@" .. api] = true
            end
            for _, line in ipairs(strings.lines(text)) do
                if line ~= "" and wanted_usr[tsv.fields(line)[DOC_USR]] then
                    table.insert(keep, line)
                end
            end
            -- the SDK's rows stay out of the fixtures: they go to the tree's .agent-work (ignored by git) for a local comparison
            write_file(path.join(tree, ".agent-work", "runs", "capture", "doc", fw .. ".txt"), table.concat(keep, "\n") .. (#keep > 0 and "\n" or ""))
            local synthetic = {}
            for _, line in ipairs(keep) do
                table.insert(synthetic, synthetic_row(tsv, line))
            end
            write_file(path.join(fixtures, "doc", fw .. ".txt"), table.concat(synthetic, "\n") .. (#synthetic > 0 and "\n" or ""))
        end
        local symbols = tbd.exports(sdk, fw)
        local exported = {}
        for api in pairs(wanted) do
            if symbols[api] then
                table.insert(exported, api)
            end
        end
        table.sort(exported)
        write_file(path.join(fixtures, "exports", fw .. ".txt"), table.concat(exported, "\n") .. (#exported > 0 and "\n" or ""))
        if #(names[fw] or {}) > 0 and fw ~= SWIFT_ONLY then
            local values = probe.probe(tree, fw, names[fw])
            local rows = {}
            for _, api in ipairs(names[fw]) do
                local found = values[api] or {"missing", "-"}
                table.insert(rows, api .. "\t" .. found[1] .. "\t" .. found[2])
            end
            write_file(path.join(fixtures, "probe", fw .. ".tsv"), table.concat(rows, "\n") .. "\n")
        end
    end

    -- the iOS 26.2 cache rows of the names: the header, then the cfstring rows of those names (gzip)
    local table_text = os.iorunv("gzip", {"-dc", path.join(corpus, "cache-26.2", "constants-26.2.tsv.gz")})
    local kept = {}
    local header = nil
    for _, line in ipairs(strings.lines(table_text)) do
        local cells = tsv.fields(line)
        if header == nil then
            header = {}
            for index, cell in ipairs(cells) do
                header[cell] = index
            end
            table.insert(kept, line)
        elseif cells[header.value_kind] == "cfstring" then
            local symbol = cells[header.symbol]
            local name = string.sub(symbol, 1, 1) == "_" and string.sub(symbol, 2) or symbol
            if wanted[name] then
                table.insert(kept, line)
            end
        end
    end
    local plain = path.join(fixtures, "corpus", "cache-26.2", "constants-26.2.tsv")
    write_file(plain, table.concat(kept, "\n") .. "\n")
    os.vrunv("gzip", {"-f", plain})
    local constants = 0
    for _, fw in ipairs(FRAMEWORKS) do
        constants = constants + #(names[fw] or {})
    end
    print(string.format("capture: %d ledger constant rows over %d frameworks; %d iOS cache rows kept", constants, #FRAMEWORKS, #kept - 1))
end
