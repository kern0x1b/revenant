-- The round trips of an sdk run (design-sdk-generator.md step 4), with --verify: off by default, they are heavy (a decls run over every
-- generated framework, a compile and a digester run over every Swift module). Two parts, under --out/verify:
--   headers: decls reads the generated headers tree (IR_FRAMEWORKS = --headers, IR_SDK = --sdk) one framework at a time; its rows go to
--            <framework>.decls.tsv (a "/" of a nested name is written "+"), and cmd_headers --compare checks them against the full IR's
--            rows of the framework: the counts and every difference by its cause.
--   swift:   cmd_roundtrip over every Swift module: the skeleton compiles under its own name and its digester dump compares with the
--            SDK's model.
-- Returns the exit status: 1 when a decls run fails (the message names the framework), or when a difference the run measures is not
-- in the known table tools/gen/verify-known.tsv at its count (known.lua), or a row of the table is not measured. Else 0. The detail
-- counts the header differences, the decls failures, the Swift round trip's result and the problems. A difference is a measurement;
-- it passes only when a row of the committed table names it.

local host = import("host", {anonymous = true})
local stream = import("stream", {anonymous = true})
local emit = import("emit", {anonymous = true})
local files = import("files", {anonymous = true})
local known = import("known", {anonymous = true})
local headers_cmd = import("cmd_headers", {anonymous = true})
local roundtrip = import("cmd_roundtrip", {anonymous = true})

-- decls' product for this repository (the lookup doc_text uses).
local function decls_of(tree)
    return (host.target_product(tree, path.join(tree, "tools", "found"), "decls"))
end

-- The frameworks decls lists under the generated headers tree, in decls' order (its --list lines: name, tab, root).
local function frameworks_of(args, decls)
    local names = {}
    local status, errors = stream.run("/usr/bin/env", {"IR_SDK=" .. args.sdk, "IR_FRAMEWORKS=" .. args.headers, decls, "--list"},
                                      function(line)
        table.insert(names, string.match(line, "^([^\t]+)"))
    end)
    assert(status == 0, "decls --list over the headers failed (exit status " .. tostring(status) .. "): " .. errors)
    return names
end

-- One framework's compare: decls over the generated tree, written, then cmd_headers' compare. Returns the causes (label -> count), or nil
-- and the reason decls failed.
local function compare_of(args, decls, name)
    local lines = {}
    local status, errors = stream.run("/usr/bin/env", {"IR_SDK=" .. args.sdk, "IR_FRAMEWORKS=" .. args.headers, decls, name},
                                      function(line)
        table.insert(lines, line)
    end)
    if status ~= 0 then
        return nil, string.format("decls failed on %s (exit status %s): %s", name, tostring(status), errors)
    end
    local file = path.join(args.out, "headers", (string.gsub(name, "/", "+")) .. ".decls.tsv")
    emit.file(file, table.concat(lines, "\n") .. "\n")
    local _, _, causes = headers_cmd.run({tree = args.tree, ir = args.ir, sdk = args.sdk, framework = name, compare = file})
    return causes
end

-- The known table's rows: the committed file, parsed. A run with --framework keeps the rows of that framework only, since it measures
-- nothing else.
local function known_rows_of(args)
    local file = path.join(args.tree, "tools", "gen", "verify-known.tsv")
    local text = files.read_text(file)
    assert(text, "verify needs the known table: " .. file)
    local rows, malformed = known.parse(text)
    assert(malformed == nil, file .. " line " .. tostring(malformed) .. " is not a key, a count and a cause, or names a key twice")
    if args.framework then
        local kept = {}
        for key, row in pairs(rows) do
            if string.find(key, "^headers " .. args.framework .. " ", 1) or string.find(key, "^swift " .. args.framework .. " ", 1) then
                kept[key] = row
            end
        end
        rows = kept
    end
    return rows
end

-- Returns the exit status and the detail (see the header).
function run(args)
    assert(args.sdk, "verify needs --sdk: the iPhoneOS SDK")
    assert(args.tree, "verify needs --tree: the repository (decls is its tools/found product)")
    assert(args.ir, "verify needs --ir: the full IR the headers are compared with")
    assert(args.headers, "verify needs --headers: the generated headers tree")
    assert(args.coordination, "verify needs --coordination: the folder heavy.sh sits in (the swift round trip's heavy jobs)")
    assert(args.out, "verify needs --out: the folder the round trips are written to")
    local rows = known_rows_of(args)
    local decls = decls_of(args.tree)
    os.mkdir(path.join(args.out, "headers"))
    -- --framework (the debugging command) names one framework, for the headers and the Swift module alike
    local frameworks = args.framework and {args.framework} or frameworks_of(args, decls)
    local measured, failed, first_failure, differences = {}, 0, nil, 0
    for _, name in ipairs(frameworks) do
        local causes, reason = compare_of(args, decls, name)
        if causes == nil then
            failed = failed + 1
            first_failure = first_failure or reason
            print("verify: " .. reason)
        else
            for label, count in pairs(causes) do
                measured["headers " .. name .. " " .. label] = count
                differences = differences + count
            end
        end
    end
    local swift_status, swift_detail, swift_measured = roundtrip.run({sdk = args.sdk, coordination = args.coordination,
                                                                      out = path.join(args.out, "swift"), framework = args.framework,
                                                                      tree = args.tree, headers = args.headers})
    for key, count in pairs(swift_measured) do
        measured[key] = count
    end
    local problems = known.problems(measured, rows)
    for _, line in ipairs(problems) do
        print("verify: " .. line)
    end
    local detail = string.format("headers: %d frameworks, %d differences, %d decls failures; swift: %s; %d problems (a difference not in the known table, or a row not measured)",
                                 #frameworks, differences, failed, tostring(swift_detail), #problems)
    if failed > 0 then
        return 1, detail .. " (first: " .. first_failure .. ")"
    end
    if #problems > 0 then
        return 1, detail
    end
    return swift_status, detail
end
