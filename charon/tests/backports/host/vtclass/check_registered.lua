-- check_registered.lua - The stand-in for what modules/apple/backports.lua:1811 prints in the gate.
--
--     xmake l check_registered.lua [--control]
--
-- A MAIN script: xmake calls main(...). Port of check-registered.py.
--
-- It answers one question with two halves, over the DELIVERY's own files: every class the VideoToolbox
-- value files implement, and every selector and property they implement, against the rows the registry
-- records. Then it prints
--
--     built, but no entry in registry   the .m files export a name the registry does not record
--     registered, but not built         the registry records a name no .m file exports
--
-- The first is the one the gate fails on, and for this family it was the whole family: sixteen VT*.m files
-- and zero rows. The second is the mirror of it, because a row for a member nobody implements is a row
-- that will stop describing the code the day it is deleted.
--
-- THIS IS A STAND-IN, not the gate. It reads the same two sides the gate reads - the symbols the built
-- objects carry and the rows in the registry json - and it cannot do what the gate does: it does not link
-- the dylib, so it compares NAMES and not whether the linker agrees. A name here that is not a real
-- definition would be caught by the gate, not by this.
--
-- --control copies the registry to a scratch directory under .agent-work, DELETES one row, and requires
-- this script to name the member that row described. A check that cannot be made to fail is not a check.
--
-- Needs no SDK: every input is in the worktree (the port's header, the value files and the registry).

local M = import("members", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})
local S = import("pystr", {rootdir = os.scriptdir()})
local J = import("registry_json", {rootdir = os.scriptdir()})

local function REGISTRY()
    return M.WORKTREE() .. "/packages/a/apple-backports/registry/VideoToolbox"
end

-- Python's open(path).read() for a file that must exist: a missing file is an uncaught exception (exit 1).
local function read_checked(path)
    if not os.isfile(path) then
        V.fail("FileNotFoundError: [Errno 2] No such file or directory: '" .. path .. "'")
    end
    return V.read_text(path)
end

-- Python: re.findall(r'^@implementation\s+(\w+)', text, re.M), as a list of names.
-- Hand-matched: each "@implementation" that opens a line (position 1, or just after a "\n"), then one or
-- more whitespace bytes (\s takes newlines too), then the maximal word run, which must hold a byte.
-- findall resumes after the word.
local function implementation_names(text)
    local names = {}
    local start = 1
    while true do
        local at = string.find(text, "@implementation", start, true)
        if at == nil then
            break
        end
        local opens_line = (at == 1) or string.byte(text, at - 1) == 10
        local stop = at + #"@implementation"
        local name_at = S.skip_space(text, stop)
        local matched = false
        if opens_line and name_at > stop then
            local word_end = S.skip_word(text, name_at)
            if word_end > name_at then
                names[#names + 1] = string.sub(text, name_at, word_end - 1)
                start = word_end
                matched = true
            end
        end
        if not matched then
            start = at + 1
        end
    end
    return names
end

-- Python's built_names(): (entries, accessors). entries is the set of (kind, registry name) the value
-- files' classes carry, from members_of(); it is returned as a map keyed by kind and name, with the
-- {kind, name} pair as the value.
local function built_names()
    local classes = {}
    local paths = V.sort_bytes(os.files(M.VT_DIR() .. "/*.m"))
    for _, path in ipairs(paths) do
        for _, name in ipairs(implementation_names(V.read_text(path))) do
            classes[name] = true
        end
    end
    local entries = {}
    local accessors = {}
    for _, class_name in ipairs(V.sorted_keys(classes)) do
        local what = M.members_of(class_name)
        for _, entry in ipairs(what.entries) do
            entries[entry[1] .. "\0" .. entry[2]] = entry
        end
        for selector, value in pairs(what.accessors) do
            accessors[selector] = value
        end
    end
    return entries, accessors
end

-- Python's registered_names(registry_dir): every api the registry records, split by its kind, as sets
-- (maps from api to true). A row without an api is recorded as "", as row.get("api", "") gives.
local function registered_names(registry_dir)
    local out = {class = {}, method = {}, property = {}}
    local paths = V.sort_bytes(os.files(registry_dir .. "/*.json"))
    for _, path in ipairs(paths) do
        local tree = J.parse_tree(V.read_text(path))
        local rows = tree.entries or {}
        for _, row in ipairs(rows) do
            local api = row.api or ""
            local kind = row.kind or ""
            if out[kind] ~= nil then
                out[kind][api] = true
            end
        end
    end
    return out
end

-- Python's bare(name): a selector with its parentheses and its leading sign, and a property with its class.
local function bare(name)
    name = S.strip(name)
    if S.starts_with(name, "-[") or S.starts_with(name, "+[") then
        -- head, _, rest = name[2:].partition(" "); "%s %s" % (head, rest.rstrip("]"))
        local inner = string.sub(name, 3)
        local space = string.find(inner, " ", 1, true)
        local head, rest
        if space == nil then
            head, rest = inner, ""
        else
            head, rest = string.sub(inner, 1, space - 1), string.sub(inner, space + 1)
        end
        local trimmed = (rest:gsub("%]+$", ""))
        return head .. " " .. trimmed
    end
    if S.contains(name, ".") then
        return S.last_piece(name, ".")
    end
    return name
end

-- The part of a string before its first ':', as Python's s.split(":")[0].
local function before_colon(text)
    return (string.match(text, "^([^:]*)"))
end

-- Python's report(label, lines): prints the count and the first twenty lines in sorted order, and returns
-- the number of lines.
local function report(label, lines)
    if #lines == 0 then
        print("  " .. label .. ": nothing")
        return 0
    end
    print(string.format("  %s: %d", label, #lines))
    local sorted = {}
    for i, line in ipairs(lines) do
        sorted[i] = line
    end
    V.sort_bytes(sorted)
    for i = 1, math.min(20, #sorted) do
        print("      " .. sorted[i])
    end
    if #sorted > 20 then
        print(string.format("      … and %d more", #sorted - 20))
    end
    return #lines
end

-- The built entries as {kind, name} pairs sorted by kind and then name (Python's sorted(set of tuples)).
local function sorted_pairs(map)
    local list = {}
    for _, pair in pairs(map) do
        list[#list + 1] = pair
    end
    table.sort(list, function(a, b)
        if a[1] ~= b[1] then
            return V.byte_less(a[1], b[1])
        end
        return V.byte_less(a[2], b[2])
    end)
    return list
end

-- The registry's rows as {kind, api} pairs sorted by kind and then api.
local function sorted_registry_pairs(registry)
    local list = {}
    for kind, set in pairs(registry) do
        for api in pairs(set) do
            list[#list + 1] = {kind, api}
        end
    end
    table.sort(list, function(a, b)
        if a[1] ~= b[1] then
            return V.byte_less(a[1], b[1])
        end
        return V.byte_less(a[2], b[2])
    end)
    return list
end

-- The number of initialisers the header declares, counted a second way: grep-like, with no reference to
-- members.lua. Python: len(re.findall(r'^[+-]\s*\([^)]*instancetype[^)]*\)\s*init\w*[:\w]*', header, re.M)).
-- Hand-matched: each sign that opens a line; then '(' after whitespace; the text up to the FIRST ')' must
-- contain "instancetype"; then whitespace, then "init", then the maximal run of word bytes and ':' (the
-- \w* and [:\w]* together). findall resumes after that run.
local function initialiser_count(text)
    local count = 0
    local i = 1
    local n = #text
    while i <= n do
        local b = string.byte(text, i)
        local opens_line = (i == 1) or string.byte(text, i - 1) == 10
        local matched = false
        if opens_line and (b == 43 or b == 45) then
            local open = S.skip_space(text, i + 1)
            if S.byte_at(text, open) == 40 then
                local close = string.find(text, ")", open + 1, true)
                if close ~= nil and S.contains(string.sub(text, open + 1, close - 1), "instancetype") then
                    local init_at = S.skip_space(text, close + 1)
                    if string.sub(text, init_at, init_at + 3) == "init" then
                        local j = init_at + 4
                        while S.is_word(string.byte(text, j)) or string.byte(text, j) == 58 do
                            j = j + 1
                        end
                        count = count + 1
                        i = j
                        matched = true
                    end
                end
            end
        end
        if not matched then
            i = i + 1
        end
    end
    return count
end

function main(...)
    local args = {...}
    local control = false
    for _, arg in ipairs(args) do
        if arg == "--control" then
            control = true
        end
    end

    local entries, _accessors = built_names()
    local registry = registered_names(REGISTRY())
    local registered = {}
    for kind, set in pairs(registry) do
        for api in pairs(set) do
            registered[kind .. "\0" .. api] = true
        end
    end

    local counts = {}
    for _, pair in pairs(entries) do
        counts[pair[1]] = (counts[pair[1]] or 0) + 1
    end
    local parts = {}
    for _, kind in ipairs(V.sorted_keys(counts)) do
        parts[#parts + 1] = string.format("%d %s", counts[kind], kind)
    end
    print(string.format("built: %d entries - %s", V.count_entries(entries), table.concat(parts, ", ")))
    print(string.format("registered: %d class, %d method, %d property rows",
        V.count_entries(registry.class), V.count_entries(registry.method), V.count_entries(registry.property)))

    local built_list = sorted_pairs(entries)
    local unregistered = {}
    for _, pair in ipairs(built_list) do
        if not registered[pair[1] .. "\0" .. pair[2]] then
            unregistered[#unregistered + 1] = string.format("built, but no entry in registry: %s (%s)",
                pair[2], pair[1])
        end
    end
    local orphan = {}
    for _, pair in ipairs(sorted_registry_pairs(registry)) do
        if entries[pair[1] .. "\0" .. pair[2]] == nil then
            orphan[#orphan + 1] = string.format("registered, but not built: %s (%s)", pair[2], pair[1])
        end
    end

    -- A SECOND COUNT, INDEPENDENT of members_of(): grep over the header, the same question by another rule.
    local header = read_checked(M.VT_DIR() .. "/CharonVideoToolbox.h")
    local grepped = initialiser_count(header)
    local declared = V.count_entries(registry.method)
    print(string.format("  initialisers: the header says %d, the registry records %d", grepped, declared))
    if grepped ~= declared then
        print(string.format("FAIL a shared blind spot: %d initialisers in the header, %d rows. Two counts of one "
            .. "fact disagree, so one of them is wrong and neither can be trusted.", grepped, declared))
        os.exit(1)
    end

    -- THE TWO CHEAP CHECKS, on a selector's SHAPE: a row that is a strict prefix of another selector of the
    -- same class has its argument list cut short, and a selector with a colon that does not end in one is
    -- cut off mid-keyword.
    local problems = {}
    local method_rows = V.sorted_keys(registry.method)
    for _, api in ipairs(method_rows) do
        local head = bare(api)
        for _, other in ipairs(method_rows) do
            if other ~= api then
                local candidate = bare(other)
                if S.starts_with(candidate, head) and candidate ~= head
                        and before_colon(candidate) == before_colon(head) then
                    problems[#problems + 1] = string.format(
                        "%s is a STRICT PREFIX of %s - the argument list is cut short", api, other)
                end
            end
        end
        if S.contains(head, ":") and not S.ends_with(head, ":") then
            problems[#problems + 1] = api .. " has a colon and does not end in one - the selector is cut off "
                .. "mid-keyword"
        end
        if not S.contains(head, ":") and not S.is_word_string(head) then
            problems[#problems + 1] = api .. " is neither a keyword list nor a unary name"
        end
    end
    if #problems > 0 then
        for i = 1, math.min(20, #problems) do
            print("FAIL " .. problems[i])
        end
        print(string.format("FAIL %d selector shape problems", #problems))
        os.exit(1)
    end
    print("  selector shapes: no row is a strict prefix of another, and every selector ends in ':' per "
        .. "keyword or is a unary name")

    local missing = report("built, but no entry in registry", unregistered)
    local extra = report("registered, but not built", orphan)

    if control then
        local scratch = M.WORKTREE() .. "/.agent-work/runs/vtclass/registry-control"
        if os.isdir(scratch) then
            os.rm(scratch)
        end
        os.cp(REGISTRY(), scratch)
        local found = os.files(scratch .. "/ios26.json")
        if #found == 0 then
            V.fail("IndexError: list index out of range")
        end
        local victim = V.sort_bytes(found)[1]
        local data = J.parse_tree(V.read_text(victim))
        local rows = data.entries
        if rows == nil then
            V.fail("KeyError: 'entries'")
        end
        if #rows == 0 then
            V.fail("IndexError: pop from empty list")
        end
        local removed = table.remove(rows, 1)
        V.write_file(victim, J.write_tree(data))
        local after = registered_names(scratch)
        if removed.kind == nil or removed.api == nil then
            V.fail("KeyError: 'kind'")
        end
        local target_api = removed.api
        local scratch_registered = {}
        for kind, set in pairs(after) do
            for api in pairs(set) do
                scratch_registered[kind .. "\0" .. api] = true
            end
        end
        -- the comparison is RE-RUN against the scratch copy, because asserting that the row is absent from
        -- the copy I deleted it from proves nothing
        local scratch_missing = {}
        for _, pair in ipairs(built_list) do
            if not scratch_registered[pair[1] .. "\0" .. pair[2]] then
                scratch_missing[#scratch_missing + 1] = string.format(
                    "built, but no entry in registry: %s (%s)", pair[2], pair[1])
            end
        end
        print(string.format("  control: removed %s from %s on a scratch copy", target_api,
            S.basename(victim)))
        local named = false
        for _, line in ipairs(scratch_missing) do
            if S.contains(line, target_api) then
                named = true
            end
        end
        if not named then
            print(string.format("FAIL the control did NOT change the answer: with %s missing, the script "
                .. "reports %d built without a row and does not name it", target_api, #scratch_missing))
            os.exit(1)
        end
        print("  control: with that row gone the same question answers differently, and names it:")
        for _, line in ipairs(scratch_missing) do
            print("      " .. line)
        end
        return
    end

    if missing > 0 or extra > 0 then
        print("registry stand-in: NOT clean")
        os.exit(1)
    end
    print("registry stand-in: nothing built without a row, and no row without an implementation")
end
