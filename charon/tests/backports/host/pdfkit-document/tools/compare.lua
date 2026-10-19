-- compare.lua - the comparison of the host's facts with the port's, and the red control that runs it on a mutated port.
--
--     xmake l tools/compare.lua <host.txt> <port.txt> <catalyst.txt> <mutation> <tc-fixtures> <scratch directory>
--
-- The host side and the port side print one key=value line per fact; the Catalyst side (color.m, a third binary) prints the
-- appearance keys and the annotation colour keys, which override the port's answers for those keys and only those. The
-- verdict is the same code for the plain comparison and for every red control: a control that plants a value in a scratch
-- copy of the port's answers must make THIS comparison go red on that key, or the comparison is blind.
--
-- mutation: "" for the plain comparison; "auto" to plant the first key the two sides agree on; or a key's own name.
-- tc-fixtures: the names of the fixtures whose content stream sets a non-zero Tc (tools/tc-fixtures.lua), space separated.
-- The planted copy is written to <scratch directory>/planted.txt.
--
-- Python's repr() of a string is written by py_repr below, and Python's float() by py_float; the lists and dicts Python
-- prints are walked in the order Python keeps them (the file order of a fact's first line).

-- Python's str.split(sep) with the empty pieces kept.
local function split(text, separator)
    local pieces = {}
    local start = 1
    while true do
        local s, e = text:find(separator, start, true)
        if not s then
            pieces[#pieces + 1] = text:sub(start)
            return pieces
        end
        pieces[#pieces + 1] = text:sub(start, s - 1)
        start = e + 1
    end
end

-- Python's str.strip(): whitespace off both ends.
local function strip(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Python's str.split() with no argument: the whitespace-separated words, empty ones dropped.
local function words(text)
    local out = {}
    for word in text:gmatch("%S+") do
        out[#out + 1] = word
    end
    return out
end

-- Python's open(path).read() in text mode: "\r\n" and "\r" become "\n".
local function read_text(file)
    local handle = assert(io.open(file, "rb"))
    local text = handle:read("a")
    handle:close()
    text = text:gsub("\r\n", "\n")
    text = text:gsub("\r", "\n")
    return text
end

-- The lines of a text, each WITH its line end, as Python's `for line in file` gives them (the last may have none).
local function lines_keep(text)
    local lines = {}
    local start = 1
    while start <= #text do
        local stop = text:find("\n", start, true)
        if not stop then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, stop)
        start = stop + 1
    end
    return lines
end

-- Byte order, which is Python's order for these strings.
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

-- Python's repr() of a str (or None for a nil): single quotes, or double quotes when the text has a single quote and no
-- double one, with the backslash and the quote escaped.
local function py_repr(value)
    if value == nil then
        return "None"
    end
    local quote = "'"
    if value:find("'", 1, true) and not value:find('"', 1, true) then
        quote = '"'
    end
    local escaped = value:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    if quote == "'" then
        escaped = escaped:gsub("'", "\\'")
    end
    return quote .. escaped .. quote
end

-- Python's repr() of a list of str.
local function py_list_repr(items)
    local shown = {}
    for i, item in ipairs(items) do
        shown[i] = py_repr(item)
    end
    return "[" .. table.concat(shown, ", ") .. "]"
end

-- Python's float() of a str: whitespace is allowed, nan and inf are read, and a hexadecimal form is refused. nil where
-- Python raises ValueError.
local function py_float(text)
    local s = strip(text)
    local lower = s:lower()
    if lower == "nan" or lower == "+nan" or lower == "-nan" then
        return 0.0 / 0.0
    elseif lower == "inf" or lower == "+inf" or lower == "infinity" or lower == "+infinity" then
        return math.huge
    elseif lower == "-inf" or lower == "-infinity" then
        return -math.huge
    end
    if s:find("[xX]") then
        return nil
    end
    local value = tonumber(s)
    if value == nil then
        return nil
    end
    return value + 0.0
end

-- read(path, side): the facts of one file. `order` is the keys in the order each first appears, `values` the value of
-- each. A line is read only when it has an "=", is not the "side=" line, and is not a `.image` fact. The side's prefix is
-- taken off a key that carries it.
local function read_facts(file, side)
    local facts = { order = {}, values = {} }
    for _, line in ipairs(lines_keep(read_text(file))) do
        line = line:gsub("\n$", "")
        if line ~= "" and line:sub(1, 5) ~= "side=" and line:find("=", 1, true) then
            local eq = line:find("=", 1, true)
            local key, value = line:sub(1, eq - 1), line:sub(eq + 1)
            local prefix = side .. "."
            if key:sub(1, #prefix) == prefix then
                key = key:sub(#prefix + 1)
            end
            if key:sub(-6) ~= ".image" then
                if facts.values[key] == nil then
                    facts.order[#facts.order + 1] = key
                end
                facts.values[key] = value
            end
        end
    end
    return facts
end

-- Python's `name in dict` is facts.values[name] ~= nil.
local function has(facts, key)
    return facts.values[key] ~= nil
end

-- Python's `name.endswith(suffix)` for any suffix in `suffixes`.
local function ends_with_any(key, suffixes)
    for _, suffix in ipairs(suffixes) do
        if key:sub(-#suffix) == suffix and #key >= #suffix then
            return suffix
        end
    end
    return nil
end

local function starts_with(key, prefix)
    return key:sub(1, #prefix) == prefix
end

-- A fact's value as Python prints it in an f-string: None for a missing one.
local function shown(value)
    if value == nil then
        return "None"
    end
    return value
end

local CATALYST_NAMESPACES = { "appearance.", ".colours." }

local BOUNDARY_TC_REASON = "the host's rect carries a character-spacing term this row has measured and not reproduced: "
    .. "non-zero, exactly linear in Tc, per-glyph distribution unexplained; the port applies Tc after every "
    .. "glyph but the last, which makes the total exact and each glyph exact to within 0.0002pt"

local BOUNDARY_LINERULE_REASON = "the line rule changed this run's text - a trimmed leading space, collapsed spaces, or a control byte - "
    .. "and what that does to the pen is measured only in part; the string, the ranges and every other key of "
    .. "this fixture are still compared"

local BOUNDARY_LINERULE_FIXTURES = { "cgfixture-gap.pdf", "cgfixture-inline.pdf", "cgfixture-lead.pdf", "cgfixture-tab.pdf" }

local EXPECTED_DIVERGENT = { "documentAttribute.supported", "page0.pageIndex.supported", "view.window.supported" }

local NOT_COMPARED = {
    { "dataRepresentation.length", "the port's own bytes against the host's REWRITTEN document, and a "
        .. "count of two different documents is not a fact either side can agree on" },
}

local function merge_catalyst(port, catalyst)
    for _, key in ipairs(catalyst.order) do
        if port.values[key] == nil then
            port.order[#port.order + 1] = key
        end
        port.values[key] = catalyst.values[key]
    end
end

-- The copy of the file the value is planted in: every line whose key is `key` is replaced by `name=planted`, and the rest
-- are copied as they are. Returns how many lines were replaced.
local function plant_copy(source, prefix, key, planted, scratch)
    local replaced = 0
    local out = {}
    for _, line in ipairs(lines_keep(read_text(source))) do
        local eq = line:find("=", 1, true)
        local name = eq and line:sub(1, eq - 1) or line
        local bare = name
        if starts_with(name, prefix) then
            bare = name:sub(#prefix + 1)
        end
        if strip(bare) == key then
            out[#out + 1] = name .. "=" .. planted .. "\n"
            replaced = replaced + 1
        else
            out[#out + 1] = line
        end
    end
    if replaced > 0 then
        local handle = assert(io.open(scratch, "wb"))
        handle:write(table.concat(out))
        handle:close()
    end
    return replaced
end

function main(host_file, port_file, colour_file, mutation, tc_text, scratch_dir)
    mutation = mutation or ""
    tc_text = tc_text or ""
    local host = read_facts(host_file, "host")
    local port_raw = read_facts(port_file, "port")
    local port = read_facts(port_file, "port")
    local catalyst = read_facts(colour_file, "portcolor")

    -- The Catalyst side may only print the namespaces it exists for: a third binary whose answers reached a document fact
    -- would be a silent override.
    local unwanted = {}
    for _, key in ipairs(catalyst.order) do
        local inside = false
        for _, namespace in ipairs(CATALYST_NAMESPACES) do
            if key:find(namespace, 1, true) then
                inside = true
            end
        end
        if not inside then
            unwanted[#unwanted + 1] = key
        end
    end
    if #unwanted > 0 then
        local first = {}
        for i = 1, math.min(4, #unwanted) do
            first[i] = unwanted[i]
        end
        print(string.format("MERGE REFUSED: the Catalyst side printed %d key(s) outside the namespaces it exists for, so"
            .. " overriding the port's answers with them would reach facts it was not built for: %s",
            #unwanted, py_list_repr(first)))
        os.exit(1)
    end
    if #catalyst.order == 0 then
        print("MERGE REFUSED: the Catalyst side printed nothing, so every appearance key would be compared"
            .. " against a port side that has no UIColor to answer it")
        os.exit(1)
    end
    local colour_keys = 0
    for _, key in ipairs(catalyst.order) do
        if key:find(".colours.", 1, true) then
            colour_keys = colour_keys + 1
        end
    end
    if colour_keys == 0 then
        print("MERGE REFUSED: the Catalyst side printed no annotation colour key, so -[PDFAnnotation"
            .. " backgroundColor, -interiorColor, -fontColor and -font would be compared against a port side"
            .. " that cannot compile UIColor or UIFont at all - which is the same silent gap the appearance"
            .. " guard above exists for")
        os.exit(1)
    end
    merge_catalyst(port, catalyst)
    local catalyst_facts = #catalyst.order

    -- THE RED CONTROL: one value planted in a scratch copy, on a key the two sides agree on, or the key named.
    if mutation ~= "" then
        if mutation == "plant" then
            print("MUTATION has no key to plant: --mutation was given a flag and no key, and a control"
                .. " that plants nothing must fail rather than report a clean run")
            os.exit(1)
        end
        local agreeing = {}
        for _, key in ipairs(host.order) do
            if has(port, key) and host.values[key] == port.values[key] and not ends_with_any(key,
                    { "documentAttribute.supported", "page0.pageIndex.supported" }) then
                agreeing[#agreeing + 1] = key
            end
        end
        table.sort(agreeing, byte_less)
        local key
        if mutation == "auto" then
            if #agreeing == 0 then
                print("MUTATION has no key to plant: the two sides agree on nothing, so there is no"
                    .. " agreeing key to change and the control cannot run")
                os.exit(1)
            end
            key = agreeing[1]
        else
            key = mutation
            if not has(host, key) or not has(port, key) then
                print(string.format("MUTATION was asked for %s and the two sides do not both print it: host=%s port=%s",
                    py_repr(key), has(host, key) and "yes" or "no", has(port, key) and "yes" or "no"))
                os.exit(1)
            end
            if host.values[key] ~= port.values[key] then
                print(string.format("MUTATION was asked for %s, which the two sides do NOT agree on (host=%s port=%s), so"
                    .. " mutating it would prove nothing about the comparison seeing a difference it should have seen",
                    py_repr(key), py_repr(host.values[key]), py_repr(port.values[key])))
                os.exit(1)
            end
        end

        local planted
        local parts = split(host.values[key], ",")
        local numbers = nil
        if #parts == 4 then
            numbers = {}
            for i, part in ipairs(parts) do
                numbers[i] = py_float(part)
                if numbers[i] == nil then
                    numbers = nil
                    break
                end
            end
        end
        if numbers then
            numbers[1] = numbers[1] + 1.0
            local shown_numbers = {}
            for i, x in ipairs(numbers) do
                shown_numbers[i] = string.format("%g", x)
            end
            planted = table.concat(shown_numbers, ",")
        else
            planted = host.values[key] .. "-PLANTED"
        end

        -- WHICH FILE the key is planted in: the one that printed it.
        local in_port = has(port_raw, key)
        local source_file, source_prefix, source_index
        if in_port then
            source_file, source_prefix = port_file, "port."
        else
            source_file, source_prefix = colour_file, "portcolor."
        end
        os.iorunv("/bin/mkdir", {"-p", scratch_dir})
        local scratch = scratch_dir .. "/planted.txt"
        local replaced = plant_copy(source_file, source_prefix, key, planted, scratch)
        if replaced == 0 then
            print(string.format("MUTATION REFUSED: %s is in no line of the file it should be planted in, and a"
                .. " control that plants nothing must fail rather than report a clean run", py_repr(key)))
            os.exit(1)
        end
        if in_port then
            port = read_facts(scratch, "port")
        else
            local planted_colour = read_facts(scratch, "portcolor")
            merge_catalyst(port, planted_colour)
        end
        local was = port_raw.values[key]
        if was == nil then
            was = catalyst.values[key]
        end
        print(string.format("MUTATION planted on %s, a key the two sides agreed on (host=%s port=%s), now port=%s in a"
            .. " scratch copy at %s", py_repr(key), py_repr(host.values[key]), py_repr(was), py_repr(port.values[key]),
            scratch))
        if port.values[key] == host.values[key] then
            print(string.format("MUTATION failed: %s was planted and still agrees, so the comparison is blind",
                py_repr(key)))
            os.exit(1)
        end
    end

    -- THE COMPARISON.
    local tc_fixtures = words(tc_text)
    local boundary_names = {}
    for _, name in ipairs(tc_fixtures) do
        boundary_names[#boundary_names + 1] = name
    end
    for _, name in ipairs(BOUNDARY_LINERULE_FIXTURES) do
        boundary_names[#boundary_names + 1] = name
    end

    local union, seen = {}, {}
    for _, key in ipairs(host.order) do
        if not seen[key] then
            seen[key] = true
            union[#union + 1] = key
        end
    end
    for _, key in ipairs(port.order) do
        if not seen[key] then
            seen[key] = true
            union[#union + 1] = key
        end
    end
    table.sort(union, byte_less)

    local compared, differences, skipped, divergent, boundary = 0, 0, 0, 0, 0
    for _, key in ipairs(union) do
        local hv, pv = host.values[key], port.values[key]
        local boundary_hit = false
        for _, name in ipairs(boundary_names) do
            if starts_with(key, name) and key:find(".bounds", 1, true) then
                boundary_hit = true
                break
            end
        end
        if boundary_hit then
            boundary = boundary + 1
            if hv ~= nil and pv ~= nil and hv ~= pv then
                local linerule = false
                for _, name in ipairs(BOUNDARY_LINERULE_FIXTURES) do
                    if starts_with(key, name) then
                        linerule = true
                    end
                end
                local reason = linerule and BOUNDARY_LINERULE_REASON or BOUNDARY_TC_REASON
                print(string.format("  stated boundary  %s  host=%s port=%s  -  %s", key, hv, pv, reason))
            end
        elseif ends_with_any(key, EXPECTED_DIVERGENT) then
            divergent = divergent + 1
            if hv ~= nil and pv ~= nil and hv ~= pv then
                print(string.format("  expected to differ  %s  host=%s port=%s  (the port implements what the host lacks)",
                    key, hv, pv))
            end
        elseif (function()
            for _, entry in ipairs(NOT_COMPARED) do
                if key:sub(-#entry[1]) == entry[1] then
                    print(string.format("  not compared  %s  host=%s  port=%s  -  %s", key, shown(hv), shown(pv), entry[2]))
                    return true
                end
            end
            return false
        end)() then
            skipped = skipped + 1
        elseif hv == nil or pv == nil then
            print(string.format("  MISSING   %s  host=%s port=%s", key, shown(hv), shown(pv)))
            differences = differences + 1
        else
            local done = false
            if key:find(".page0.", 1, true) then
                local a, b = {}, {}
                for _, part in ipairs(split(hv, ",")) do
                    a[#a + 1] = py_float(part)
                end
                for _, part in ipairs(split(pv, ",")) do
                    b[#b + 1] = py_float(part)
                end
                local a_ok, b_ok = #a > 0, #b > 0
                for _, x in ipairs(a) do
                    if x == nil then a_ok = false end
                end
                for _, y in ipairs(b) do
                    if y == nil then b_ok = false end
                end
                if a_ok and b_ok and #a == 4 and #b == 4 then
                    compared = compared + 1
                    local near = true
                    for i = 1, 4 do
                        if not (math.abs(a[i] - b[i]) <= 0.001) then
                            near = false
                        end
                    end
                    print(string.format("  %s %s  host=%s port=%s%s", near and "agree  " or "DIFFER ", key, hv, pv,
                        near and "" or "   (tolerance 0.001)"))
                    if not near then
                        differences = differences + 1
                    end
                    done = true
                end
            end
            if not done then
                if starts_with(hv, "NOT-COMPARED") or starts_with(pv, "NOT-COMPARED") then
                    skipped = skipped + 1
                    print(string.format("  not compared  %s  host=%s  port=%s", key, hv, pv))
                else
                    compared = compared + 1
                    print(string.format("  %s %s  host=%s port=%s", hv == pv and "agree  " or "DIFFER ", key,
                        py_repr(hv), py_repr(pv)))
                    if hv ~= pv then
                        differences = differences + 1
                    end
                end
            end
        end
    end
    print(string.format("COMPARED %d MISMATCHES %d  (not compared: %d, expected to differ: %d, of which %d compared from"
        .. " the Catalyst side, stated boundary: %d)", compared, differences, skipped, divergent, catalyst_facts, boundary))
    local unaccounted = #union - compared - skipped - divergent - boundary
    if unaccounted ~= 0 then
        print(string.format("  %d key(s) both sides printed were neither compared, skipped nor expected to differ: the"
            .. " extraction is short, so this is not a verdict", unaccounted))
        os.exit(1)
    end
    os.exit(differences > 0 and 1 or 0)
end
