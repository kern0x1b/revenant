local json = import("core.base.json")

local IDENT = "[%w_]"

local function is_ident(ch)
    return ch ~= "" and ch:match(IDENT) ~= nil
end

local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function lines_of(text)
    local out, start = {}, 1
    while true do
        local s, e = text:find("\n", start, true)
        if not s then
            table.insert(out, text:sub(start))
            return out
        end
        table.insert(out, text:sub(start, s - 1))
        start = e + 1
    end
end

local function strip_newlines(text)
    return (text:gsub("^\n+", ""):gsub("\n+$", ""))
end

local function load_registry(file)
    if not os.isfile(file) then
        raise("no registry at %s", file)
    end
    return json.loadfile(file)
end

local function declared_protocols(header)
    local names = {}
    for name in io.readfile(header):gmatch("@protocol%s+([%w_]+)%s*;") do
        names[name] = true
    end
    return names
end

local function implemented_protocols(doc)
    local rows = {}
    for _, row in ipairs(doc.entries) do
        if row.status == "implemented" and row.kind == "protocol" then
            table.insert(rows, row)
        end
    end
    return rows
end

function protocol_missing(registry, header)
    local declared = declared_protocols(header)
    for _, row in ipairs(implemented_protocols(load_registry(registry))) do
        if not declared[row.api] then
            print(row.api)
        end
    end
    return 0
end

function protocol_victim(registry, header)
    local declared = declared_protocols(header)
    for _, row in ipairs(implemented_protocols(load_registry(registry))) do
        if declared[row.api] then
            print(row.api)
            return 0
        end
    end
    raise("the control needs one implemented protocol row to remove")
end

function protocol_count(registry)
    print(#implemented_protocols(load_registry(registry)))
    return 0
end

local function facts_problems(doc, package)
    local lines = {}
    for _, row in ipairs(doc.entries) do
        if row.status == "implemented" then
            local api, facts = row.api, row.facts
            if facts == nil or facts == "" then
                table.insert(lines, string.format("%-46s no facts pointer at all", api))
            else
                local file = path.join(package, facts)
                if not os.isfile(file) then
                    table.insert(lines, string.format("%-46s points at %s, which does not exist", api, facts))
                else
                    local text = io.readfile(file)
                    if not names_identifier(text, api) then
                        if text:find(api, 1, true) then
                            table.insert(lines, string.format("%-46s points at %s, which names it only inside a longer identifier", api, facts))
                        else
                            table.insert(lines, string.format("%-46s points at %s, which never mentions it", api, facts))
                        end
                    end
                end
            end
        end
    end
    return lines
end

function names_identifier(text, api)
    local start = 1
    while true do
        local s, e = text:find(api, start, true)
        if not s then
            return false
        end
        if not is_ident(text:sub(s - 1, s - 1)) and not is_ident(text:sub(e + 1, e + 1)) then
            return true
        end
        start = e + 1
    end
end

function facts_broken(registry, package)
    for _, line in ipairs(facts_problems(load_registry(registry), package)) do
        print(line)
    end
    return 0
end

function facts_count(registry)
    local n = 0
    for _, row in ipairs(load_registry(registry).entries) do
        if row.status == "implemented" then
            n = n + 1
        end
    end
    print(n)
    return 0
end

local function mentions(lines, needle)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then
            return true
        end
    end
    return false
end

function facts_control(registry, factsroot, package)
    local doc = load_registry(registry)
    local rows = {}
    for _, row in ipairs(doc.entries) do
        if row.status == "implemented" and row.facts ~= nil and row.facts ~= "" then
            table.insert(rows, row)
        end
    end
    if #rows < 3 then
        raise("the control needs three implemented rows with a pointer")
    end
    local missing_row, pointerless = rows[1], rows[2]
    missing_row.facts = "facts/Metal/NoSuchFile.md"
    pointerless.facts = nil

    local files = os.files(path.join(factsroot, "**.md"))
    table.sort(files)
    local substring_row, found = nil, nil
    for _, candidate in ipairs(rows) do
        local longer = candidate.api .. "CommandEncoder"
        for _, file in ipairs(files) do
            local text = io.readfile(file)
            if text:find(longer, 1, true) and not names_identifier(text, candidate.api) then
                substring_row, found = candidate, file
                break
            end
        end
        if substring_row then
            break
        end
    end
    if not substring_row then
        raise("the control needs a row named only inside a longer identifier somewhere")
    end
    substring_row.facts = path.relative(found, package)

    local lines = facts_problems(doc, package)
    if not mentions(lines, missing_row.api) then
        raise("the control's missing-file row was not named")
    end
    print("  ok   the self-test's NEGATIVE 1: a pointer to a file that does not exist is named")
    if not mentions(lines, pointerless.api) then
        raise("the control's pointer-less row was not named")
    end
    print("  ok   the self-test's NEGATIVE 2: an implemented row with no pointer is named")
    local sub_line = nil
    for _, line in ipairs(lines) do
        if line:find(substring_row.api, 1, true) and line:find("longer identifier", 1, true) then
            sub_line = line
        end
    end
    if not sub_line then
        raise("the control's substring row was not named inside a longer identifier")
    end
    print("  ok   the self-test's NEGATIVE 3: a row named only inside a longer identifier is named")
    return 0
end

function review(file, base, tip)
    local raw = io.readfile(file) or ""
    local commits = {}
    local start = 1
    while true do
        local s = raw:find("\30", start, true)
        local chunk = strip_newlines(raw:sub(start, (s or #raw + 1) - 1))
        if chunk ~= "" then
            local a = chunk:find("\31", 1, true)
            local b = a and chunk:find("\31", a + 1, true)
            if not b then
                raise("a git log record has fewer than two separators")
            end
            table.insert(commits, {chunk:sub(1, a - 1), chunk:sub(a + 1, b - 1), chunk:sub(b + 1)})
        end
        if not s then
            break
        end
        start = s + 1
    end
    if #commits == 0 then
        print(string.format("no commits in %s..%s", base, tip))
        return 0
    end
    local tip_sha = commits[#commits][1]
    for _, commit in ipairs(commits) do
        local sha, subject, body = commit[1], commit[2], commit[3]
        local short = sha:sub(1, 9)
        if starts(subject, "Self-review:") or starts(subject, "Self-review ") then
            print(string.format("%s: the SUBJECT is a Self-review line, which is never a subject", short))
        end
        local lines = lines_of(body)
        local n = 0
        for _, line in ipairs(lines) do
            if starts(line, "Self-review:") then
                n = n + 1
            end
        end
        if n > 1 then
            print(string.format("%s: %d Self-review lines in one body, and it is one line", short, n))
        end
        if n == 1 and sha ~= tip_sha then
            print(string.format("%s: carries a Self-review line and is not the tip, so it should not", short))
            if not starts(lines[1], "Self-review:") then
                print(string.format("%s: and its Self-review line is not the FIRST line of the body", short))
            end
        end
    end
    return 0
end

function main(command, ...)
    local known = {
        ["protocol-missing"] = protocol_missing,
        ["protocol-victim"] = protocol_victim,
        ["protocol-count"] = protocol_count,
        ["facts-broken"] = facts_broken,
        ["facts-count"] = facts_count,
        ["facts-control"] = facts_control,
        ["review"] = review,
    }
    local fn = known[command or ""]
    if not fn then
        io.stderr:write("usage: checks.lua protocol-missing|protocol-victim <registry> <header> | protocol-count <registry> | facts-broken <registry> <package> | facts-count <registry> | facts-control <registry> <factsroot> <package> | review <gitlog> <base> <tip>\n")
        os.exit(2)
    end
    os.exit(fn(...))
end
