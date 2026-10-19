-- surf-diff.lua: what a rewrite of the extractor lost, as sets, not as totals.
--
--     xmake l surf-diff.lua [--allow-empty-new] OLD.tsv NEW.tsv
--
-- A row is an (owner, kind, leaf member name) triple. The old extraction's owner column is wrong for every member of a
-- type nested in one - that is what the rewrite fixes - so a row that is in both files under a different owner is a
-- *move*, and it is paired by the leaf name **and** the line the interface declares it on, because a bare name has
-- several homes and only the line says which one moved.
--
-- The classes are sets, and they are checked against the sets they are supposed to partition:
--
--     |O| - |N| == |O\N| - |N\O|
--     O\N == moved + attribute + other
--     N\O == gained
--
-- Both files must have three tab-separated columns per row: owner, kind, name. A file of any other shape is a hard
-- error naming the file, the expected three and the count found - a wrong-shaped file read as the empty set would make
-- every identity below hold at zero.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})
local owners = import("lib.owners", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local COLUMNS = 3

-- the interfaces of the 26.2 SDK, the frameworks' first and then the stdlib's, each pattern in sorted order
local function interfaces()
    local env = os.getenv("APPLE_26_SDK")
    local sdk = (env and env ~= "") and env or path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon",
        ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
    local out = {}
    for _, pattern in ipairs({
        path.join(sdk, "System", "Library", "Frameworks", "*", "Modules", "*.swiftmodule", "arm64e-apple-ios.swiftinterface"),
        path.join(sdk, "usr", "lib", "swift", "*.swiftmodule", "arm64e-apple-ios.swiftinterface"),
    }) do
        local found = os.files(pattern)
        table.sort(found)
        for _, file in ipairs(found) do
            out[#out + 1] = file
        end
    end
    return out
end

-- The attribute and modifier words the leading noise of a declaration can hold, in the order the Python listed them.
-- Each item takes the text at pos and returns the position after it, or nil. The words with a trailing space need one
-- space; the others take the spaces that follow them, as their `\s*` does.
local function word(literal, spaces)
    return function(s, pos)
        if not text.startswith(s, literal, pos) then
            return nil
        end
        local after = pos + #literal
        if spaces then
            local _, e = string.find(s, "^%s*", after)
            return e + 1
        end
        return after
    end
end

local function concurrency(s, pos)
    if not text.startswith(s, "_Concurrency.", pos) then
        return nil
    end
    local name = string.match(s, "^[%w_]+", pos + 13)
    if not name then
        return nil
    end
    local _, e = string.find(s, "^%s*", pos + 13 + #name)
    return e + 1
end

local NOISE_WORDS = {
    word("public "), word("open "), word("package "), word("internal "), word("private "),
    word("fileprivate "), word("final "), word("indirect "), word("mutating "), word("static "),
    word("nonisolated "),
    word("@frozen", true), word("@inlinable", true), word("@usableFromInline", true),
    word("@_alwaysEmitIntoClient", true), word("@MainActor", true), word("@preconcurrency", true),
    concurrency, word("_disfavoredOverload", true), word("@backDeployed", true),
    word("convenience", true), word("required", true), word("mutating", true), word("override", true),
}

-- NOISE.sub('', s, count=1): the length of the leading noise of s, as the position the rest starts at. The Python
--     ^(?:@[\w.]+(?:\([^)]*\))?\s*|@\w+)*\s*(?:B)*
-- takes the greedy first alternative each time, and nothing follows the group that could fail, so no backtracking.
local function noise_end(s)
    local pos = 1
    while string.sub(s, pos, pos) == "@" do
        local _, e = string.find(s, "^@[%w_%.]+", pos)
        if not e then
            break
        end
        local after = e + 1
        local _, paren = string.find(s, "^%([^%)]*%)", after)
        if paren then
            after = paren + 1
        end
        local _, spaces = string.find(s, "^%s*", after)
        pos = spaces + 1
    end
    local _, spaces = string.find(s, "^%s*", pos)
    pos = spaces + 1
    local moved = true
    while moved do
        moved = false
        for _, item in ipairs(NOISE_WORDS) do
            local after = item(s, pos)
            if after then
                pos = after
                moved = true
                break
            end
        end
    end
    return pos
end

-- the first match of \b(WORDS)\s+(\w+), or \bWORD\b with no name when bare is set: the name, or "init"/"subscript"
local function keyword_name(s, kinds, bare)
    -- the leftmost position at which one of the kinds matches, and what that match names
    local best, best_name = nil, nil
    for _, kind in ipairs(kinds) do
        for _, at in ipairs(text.positions(s, kind)) do
            if best and at > best then
                break
            end
            if text.boundary(s, at) then
                local name = nil
                if bare then
                    if not text.is_word(s, at + #kind) then
                        name = bare
                    end
                else
                    local _, space = string.find(s, "^%s+", at + #kind)
                    name = space and string.match(s, "^[%w_]+", space + 1)
                end
                if name then
                    if not best or at < best then
                        best, best_name = at, name
                    end
                    break
                end
            end
        end
    end
    return best_name
end

local TYPE_KINDS = {"struct", "class", "enum", "protocol", "actor", "typealias"}

-- the member name a row names, whether the column holds a bare name or a whole declaration
local function leaf(raw)
    local s = text.strip(raw)
    local stripped = text.strip(string.sub(s, noise_end(s)))
    local name = keyword_name(stripped, {"case"}) or keyword_name(stripped, {"func"})
        or keyword_name(stripped, {"var"}) or keyword_name(stripped, {"let"})
    if not name and keyword_name(stripped, {"init"}, "init") then
        return "init"
    end
    name = name or keyword_name(stripped, {"subscript"}, "subscript") or keyword_name(stripped, TYPE_KINDS)
    if name then
        return name
    end
    local head = text.partition(stripped, "(")
    head = text.partition(head, ":")
    head = text.partition(head, "{")
    return text.strip(head)
end

-- A list of (owner, kind, leaf) rows, each once. A line that does not have exactly three tab-separated columns is a
-- **hard error**: the sets partition what was read, so a file of the wrong shape read as the empty set makes the
-- identity hold at 0 == 0 and the classes below it partition an empty |O\N| exactly.
local function read(file, allow_empty)
    local rows, seen, bad = {}, {}, {}
    local lines = text.split(io.readfile(file), "\n")
    for number, line in ipairs(lines) do
        if text.strip(line) ~= "" then
            local parts = text.split(line, "\t")
            if #parts ~= COLUMNS then
                bad[#bad + 1] = {number, #parts}
            else
                local row = {parts[1], parts[2], leaf(parts[3])}
                local key = row[1] .. "\t" .. row[2] .. "\t" .. row[3]
                if not seen[key] then
                    seen[key] = true
                    rows[#rows + 1] = row
                end
            end
        end
    end
    if #bad > 0 then
        local number, found = bad[1][1], bad[1][2]
        return nil, string.format(
            "%s: line %d has %d tab-separated column(s), the %d this diff reads are owner/kind/name; %d line(s) in all "
            .. "(first at line %d). Refusing to read the file as the empty set: the partition below would hold vacuously. "
            .. "Use the artifact that has three columns (see bridge/tools/surftool/README.md for what each one is).",
            file, number, found, COLUMNS, #bad, number)
    end
    if #rows == 0 and not allow_empty then
        return nil, string.format(
            "%s: no rows. A NEW file of no rows is a hard error, because |O\\N| - |N\\O| then holds at 0 == 0. "
            .. "Pass --allow-empty-new to mean it.", file)
    end
    return rows, nil
end

-- one pass over every interface: leaf name -> set of {owner, file, number, text, attributes above it}
local index_cache = nil

local function index()
    if index_cache then
        return index_cache
    end
    index_cache = {}
    local seen = {}
    for _, file in ipairs(interfaces()) do
        local attrs = 0
        local base = path.filename(file)
        for _, row in ipairs(owners.walk(text.split(io.readfile(file), "\n"))) do
            local stripped = text.strip(row.line)
            if stripped ~= "" and not text.startswith(stripped, "//") then
                if text.startswith(stripped, "@") then
                    attrs = attrs + 1
                else
                    local name = keyword_name(stripped, {"case", "func", "var", "let", "subscript"})
                        or keyword_name(stripped, TYPE_KINDS)
                    if not name and keyword_name(stripped, {"init"}, "init") then
                        name = "init"
                    end
                    if name then
                        local entry = {row.owner, base, row.number, string.sub(stripped, 1, 70), attrs}
                        local key = name .. "\t" .. tostring(row.owner) .. "\t" .. base .. "\t" .. row.number
                            .. "\t" .. entry[4] .. "\t" .. attrs
                        if not seen[key] then
                            seen[key] = true
                            index_cache[name] = index_cache[name] or {}
                            table.insert(index_cache[name], entry)
                        end
                    end
                    attrs = 0
                end
            end
        end
    end
    return index_cache
end

local function row_key(row)
    return row[1] .. "\t" .. row[2] .. "\t" .. row[3]
end

local function sorted_rows(set)
    local rows = {}
    for _, row in pairs(set) do
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b)
        for i = 1, 3 do
            if a[i] ~= b[i] then
                return a[i] < b[i]
            end
        end
        return false
    end)
    return rows
end

local function count_of(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

local function show(owner)
    return owner == nil and "None" or owner
end

function main(...)
    local all = {...}
    local args = {}
    local allow_empty = false
    for _, a in ipairs(all) do
        if a == "--allow-empty-new" then
            allow_empty = true
        else
            args[#args + 1] = a
        end
    end
    if #args ~= 2 then
        io.stderr:write("usage: surf-diff.lua [--allow-empty-new] OLD.tsv NEW.tsv   (three columns each: owner/kind/name)\n")
        os.exit(2)
    end
    local old_rows, old_error = read(args[1], false)
    if old_error then
        io.stderr:write(old_error .. "\n")
        os.exit(1)
    end
    local new_rows, new_error = read(args[2], allow_empty)
    if new_error then
        io.stderr:write(new_error .. "\n")
        os.exit(1)
    end
    if #old_rows == 0 then
        io.stderr:write(args[1] .. ": no rows either, so there is nothing to diff. Refusing.\n")
        os.exit(1)
    end

    local old, new = {}, {}
    for _, row in ipairs(old_rows) do
        old[row_key(row)] = row
    end
    for _, row in ipairs(new_rows) do
        new[row_key(row)] = row
    end
    local only_old, only_new = {}, {}
    for key, row in pairs(old) do
        if not new[key] then
            only_old[key] = row
        end
    end
    for key, row in pairs(new) do
        if not old[key] then
            only_new[key] = row
        end
    end
    local table_index = index()

    -- where each name sits in the NEW file, by (name, file, line) - the pairing that says "moved" is the same declaration
    -- at another owner, not merely the same name
    local new_leaves_by_line = {}
    for _, row in ipairs(new_rows) do
        for _, home in ipairs(table_index[row[3]] or {}) do
            local where = row[3] .. "\t" .. home[2] .. "\t" .. home[3]
            new_leaves_by_line[where] = new_leaves_by_line[where] or {}
            new_leaves_by_line[where][row[1]] = true
        end
    end

    -- one pass, and the three classes partition |O\N| exactly
    local moved, attribute, other = {}, {}, {}
    for key, row in pairs(only_old) do
        local owner, name = row[1], row[3]
        local homes = table_index[name] or {}
        local has_multi, has_available = false, false
        for _, home in ipairs(homes) do
            if string.find(home[4], "@available", 1, true) then
                has_available = true
                if home[5] > 1 then
                    has_multi = true
                end
            end
        end
        if has_multi then
            attribute[key] = row                    -- (c) a block with more than one attribute above it
        elseif has_available then
            other[key] = row                        -- an @available the old extractor dropped
        elseif #homes == 0 then
            other[key] = row                        -- no declaration of that name in the interfaces
        else
            local is_moved = false
            for _, home in ipairs(homes) do
                for home_owner in pairs(new_leaves_by_line[name .. "\t" .. home[2] .. "\t" .. home[3]] or {}) do
                    if home_owner ~= owner then
                        is_moved = true
                    end
                end
            end
            if is_moved then
                moved[key] = row                    -- (a) the same declaration, at another owner
            else
                other[key] = row                    -- the same name, but not the same declaration
            end
        end
    end

    local n_old, n_new = count_of(old), count_of(new)
    local n_only_old, n_only_new = count_of(only_old), count_of(only_new)
    local n_moved, n_attribute, n_other = count_of(moved), count_of(attribute), count_of(other)
    print(string.format("|O| = %d   surface rows in OLD", n_old))
    print(string.format("|N| = %d   surface rows in NEW", n_new))
    print(string.format("|O\\N| = %d   |O\\N| rows: moved %d  attribute %d  other %d",
        n_only_old, n_moved, n_attribute, n_other))
    print(string.format("|N\\O| = %d   |N\\O| rows: gained", n_only_new))
    for _, group in ipairs({{"moved", moved}, {"attribute", attribute}, {"other", other}}) do
        local label, set = group[1], group[2]
        local rows = sorted_rows(set)
        for i = 1, math.min(3, #rows) do
            local row = rows[i]
            local listed = {}
            local homes = {}
            for _, home in ipairs(table_index[row[3]] or {}) do
                homes[#homes + 1] = home
            end
            table.sort(homes, function(a, b)
                if a[2] ~= b[2] then
                    return a[2] < b[2]
                end
                return a[3] < b[3]
            end)
            for j = 1, math.min(2, #homes) do
                listed[#listed + 1] = string.format("%s:%d in %s", homes[j][2], homes[j][3], show(homes[j][1]))
            end
            print(string.format("  %s %s#%s %s", text.ljust(label, 10), row[1], text.ljust(row[3], 22),
                text.join("; ", listed)))
        end
    end

    local union = count_of(moved) + count_of(attribute) + count_of(other)
    local ok = (n_old - n_new == n_only_old - n_only_new) and union == n_only_old
    print(string.format("identity over surface rows (not gap rows): |O|-|N| = %d, |O\\N| - |N\\O| = %d, classes: %d + %d + %d = %d",
        n_old - n_new, n_only_old - n_only_new, n_moved, n_attribute, n_other, union))
    if not ok then
        io.stderr:write("# the classes do not add up\n")
        os.exit(1)
    end
end
