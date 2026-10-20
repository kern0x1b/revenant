local json = import("core.base.json")

local COVERED = "measured by the host differential, tests/backports/host/realityfoundation, the check at main.swift:%s: %s"
local DECLARATION = "the declaration in packages/runtimes/swift-runtime/files/, which tests/backports/host/swiftregistry holds to a name, and the interface line it was read from. No check in this series measures it"
local CLAIMS = {"host differential", "the differential"}

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function differential()
    return path.join(os.scriptdir(), "main.swift")
end

local function quoted_subjects(line)
    local found = {}
    local pos = 1
    while true do
        local s, e = line:find("check(", pos, true)
        if not s then
            break
        end
        local i = e + 1
        i = i + #line:match("^%s*", i)
        if line:sub(i, i) == '"' then
            local j, closed = i + 1, false
            local buf = {}
            while j <= #line do
                local c = line:sub(j, j)
                if c == "\\" then
                    table.insert(buf, line:sub(j, j + 1))
                    j = j + 2
                elseif c == '"' then
                    closed = true
                    break
                else
                    table.insert(buf, c)
                    j = j + 1
                end
            end
            if closed then
                table.insert(found, (table.concat(buf):gsub('\\"', '"')))
                pos = j + 1
            else
                pos = e + 1
            end
        else
            pos = e + 1
        end
    end
    return found
end

function subjects(file)
    local out = {}
    if not os.isfile(file) then
        return out
    end
    local number = 0
    for line in io.lines(file) do
        number = number + 1
        for _, found in ipairs(quoted_subjects(line)) do
            table.insert(out, {number, found})
        end
    end
    return out
end

function tokens(api)
    local body = api:match("([^%.]*)$")
    body = (body:gsub("%(.*", ""))
    body = (body:gsub(":.*", ""))
    body = trim(body)
    if body == "" then
        return {}
    end
    local words = {body}
    local dot = api:find(".", 1, true)
    if dot then
        table.insert(words, api:sub(dot + 1))
    end
    if body:sub(-2) == "()" then
        table.insert(words, body:sub(1, -3))
    end
    local out, seen = {}, {}
    for _, word in ipairs(words) do
        if not seen[word] and #word > 3 then
            seen[word] = true
            table.insert(out, word)
        end
    end
    return out
end

function first_hit(api, checks)
    for _, token in ipairs(tokens(api)) do
        for _, check in ipairs(checks) do
            if check[2]:lower():find(token:lower(), 1, true) then
                return {"covered", check[1], check[2]}
            end
        end
    end
    return nil
end

function what_this_row_should_say(hit)
    if hit[1] == "covered" then
        return string.format(COVERED, tostring(hit[2]), hit[3]:sub(1, 58))
    end
    return DECLARATION
end

local function claims_a_measurement(said)
    for _, claim in ipairs(CLAIMS) do
        if said:find(claim, 1, true) then
            return true
        end
    end
    return false
end

local function read_document(registry)
    return json.loadfile(registry)
end

local function implemented(document)
    local rows = {}
    for _, entry in ipairs(document.entries) do
        if entry.status == "implemented" then
            table.insert(rows, entry)
        end
    end
    return rows
end

local function run(registries, check_only, write)
    local checks = subjects(differential())
    local covered, declaration_only, wrong = 0, 0, 0
    for _, registry in ipairs(registries) do
        local document = read_document(registry)
        local entries = implemented(document)
        print(string.format("# %s: %d implemented rows, against %d check subjects in %s",
            path.filename(registry), #entries, #checks, path.filename(differential())))
        for _, entry in ipairs(entries) do
            local api = entry.api
            local hit = first_hit(api, checks)
            if hit then
                covered = covered + 1
                print(string.format("covered  %-64s by check at main.swift:%d  %s", api:sub(1, 64), hit[2], hit[3]:sub(1, 58)))
            else
                declaration_only = declaration_only + 1
                print(string.format("decl only %-64s -", api:sub(1, 64)))
            end
            if check_only or write then
                local said = entry.source or ""
                local should = what_this_row_should_say(hit or {"decl only", nil, nil})
                if write and said ~= should then
                    entry.source = should
                elseif check_only and said ~= should then
                    wrong = wrong + 1
                    print(string.format("  MISMATCH %s\n    says: %s\n    should be: %s", api:sub(1, 64), said:sub(1, 110), should:sub(1, 110)))
                end
                if check_only and said ~= should and claims_a_measurement(said) and hit == nil then
                    print("  AND IT CLAIMS A MEASUREMENT for a row the differential does not name")
                end
            end
        end
        print("")
        if write then
            io.writefile(registry, json.encode(document) .. "\n")
            print(string.format("# wrote the sources %s", path.filename(registry)))
        end
    end
    print(string.format("# covered %d, declaration only %d", covered, declaration_only))
    if check_only and wrong > 0 then
        print(string.format("# %d row(s) whose source is not what this loop decides - see MISMATCH above", wrong))
        return 1
    end
    return 0
end

function restate(file, sentence)
    local document = read_document(file)
    for _, entry in ipairs(implemented(document)) do
        entry.source = sentence
    end
    io.writefile(file, json.encode(document) .. "\n")
    return 0
end

function edit_first(file)
    local document = read_document(file)
    for _, entry in ipairs(implemented(document)) do
        entry.source = "HAND EDITED BY THE CONTROL: the host differential measures every one of these"
        break
    end
    io.writefile(file, json.encode(document) .. "\n")
    return 0
end

function main(command, ...)
    local registries = {...}
    if command == "report" or command == "check" or command == "write" then
        if #registries == 0 then
            io.stderr:write("usage: coverage.lua report|check|write <registry.json>...\n")
            os.exit(1)
        end
        if not os.isfile(differential()) then
            io.stderr:write("coverage.lua: no differential at " .. differential() .. "\n")
            os.exit(1)
        end
        os.exit(run(registries, command == "check", command == "write"))
    elseif command == "restate" then
        os.exit(restate(...))
    elseif command == "edit-first" then
        os.exit(edit_first(...))
    end
    io.stderr:write("usage: coverage.lua report|check|write <registry.json>... | restate <registry.json> <sentence> | edit-first <registry.json>\n")
    os.exit(2)
end
