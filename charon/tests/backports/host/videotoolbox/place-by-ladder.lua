local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})

local HERE = os.scriptdir()
local WORKTREE = path.join(HERE, "..", "..", "..", "..")
local PACKAGE = path.join(WORKTREE, "packages", "a", "apple-backports")
local TABLE = path.join(HERE, "ladder.tsv")
local OBJECTS = path.join(PACKAGE, "VideoToolbox")
local REGISTRY = path.join(PACKAGE, "registry", "VideoToolbox")

local IMPORTS = "#import <Foundation/Foundation.h>\n#import <CoreMedia/CoreMedia.h>\n#import <VideoToolbox/VideoToolbox.h>\n"

local NULL = { kind = "null" }

local SHORT_ESCAPES = { [0x22] = '\\"', [0x5C] = "\\\\", [0x08] = "\\b", [0x0C] = "\\f", [0x0A] = "\\n", [0x0D] = "\\r", [0x09] = "\\t" }
local SIMPLE_ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function new_object()
    return { kind = "object", keys = {}, vals = {} }
end

local function obj_set(object, key, value)
    if object.vals[key] == nil then
        object.keys[#object.keys + 1] = key
    end
    object.vals[key] = value
end

local function obj_get(object, key)
    return object.vals[key]
end

local function must_get(object, key)
    local value = object.vals[key]
    if value == nil then
        raise("KeyError: " .. lib.py_repr(key))
    end
    return value
end

local function parse_json(text)
    local pos = 1

    local function fail(what)
        raise(string.format("place-by-ladder.lua: JSON %s at byte %d", what, pos))
    end

    local function skip()
        pos = text:find("[^ \t\r\n]", pos) or (#text + 1)
    end

    local value

    local function read_string()
        pos = pos + 1
        local parts = {}
        while true do
            local stop = text:find('["\\]', pos)
            if not stop then
                fail("unterminated string")
            end
            parts[#parts + 1] = text:sub(pos, stop - 1)
            if text:sub(stop, stop) == '"' then
                pos = stop + 1
                break
            end
            local escape = text:sub(stop + 1, stop + 1)
            pos = stop + 2
            if escape == "u" then
                local digits = text:sub(pos, pos + 3)
                if not digits:find("^%x%x%x%x$") then
                    fail("bad \\u escape")
                end
                local code = tonumber(digits, 16)
                pos = pos + 4
                if code >= 0xD800 and code <= 0xDBFF and text:sub(pos, pos + 1) == "\\u" then
                    local lowDigits = text:sub(pos + 2, pos + 5)
                    local low = lowDigits:find("^%x%x%x%x$") and tonumber(lowDigits, 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        pos = pos + 6
                    end
                end
                parts[#parts + 1] = utf8.char(code)
            else
                local decoded = SIMPLE_ESCAPES[escape]
                if not decoded then
                    fail("bad escape")
                end
                parts[#parts + 1] = decoded
            end
        end
        return table.concat(parts)
    end

    local function read_number()
        local lexeme = text:match("^%-?%d+", pos)
        if not lexeme then
            fail("bad number")
        end
        local at = pos + #lexeme
        local fraction = text:match("^%.%d+", at) or ""
        at = at + #fraction
        local exponent = text:match("^[eE][%+%-]?%d+", at) or ""
        at = at + #exponent
        pos = at
        if fraction ~= "" or exponent ~= "" then
            raise("place-by-ladder.lua: a float, which this reader does not write back; nothing in the registry is one")
        end
        if lexeme == "-0" then
            lexeme = "0"
        end
        return { kind = "int", text = lexeme }
    end

    local function read_array()
        pos = pos + 1
        local items = {}
        skip()
        if text:sub(pos, pos) == "]" then
            pos = pos + 1
            return { kind = "array", items = items }
        end
        while true do
            skip()
            items[#items + 1] = value()
            skip()
            local separator = text:sub(pos, pos)
            pos = pos + 1
            if separator == "]" then
                return { kind = "array", items = items }
            elseif separator ~= "," then
                fail("expected , or ]")
            end
        end
    end

    local function read_object()
        pos = pos + 1
        local object = new_object()
        skip()
        if text:sub(pos, pos) == "}" then
            pos = pos + 1
            return object
        end
        while true do
            skip()
            if text:sub(pos, pos) ~= '"' then
                fail("expected a key")
            end
            local key = read_string()
            skip()
            if text:sub(pos, pos) ~= ":" then
                fail("expected :")
            end
            pos = pos + 1
            skip()
            obj_set(object, key, value())
            skip()
            local separator = text:sub(pos, pos)
            pos = pos + 1
            if separator == "}" then
                return object
            elseif separator ~= "," then
                fail("expected , or }")
            end
        end
    end

    value = function()
        local first = text:sub(pos, pos)
        if first == "{" then
            return read_object()
        elseif first == "[" then
            return read_array()
        elseif first == '"' then
            return read_string()
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return NULL
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        return read_number()
    end

    local data = value()
    skip()
    if pos <= #text then
        fail("data after the value")
    end
    return data
end

local function encode_string(s)
    local out = { '"' }
    for _, code in utf8.codes(s, true) do
        if SHORT_ESCAPES[code] then
            out[#out + 1] = SHORT_ESCAPES[code]
        elseif code >= 0x20 and code <= 0x7E then
            out[#out + 1] = string.char(code)
        elseif code < 0x10000 then
            out[#out + 1] = string.format("\\u%04x", code)
        else
            local rest = code - 0x10000
            out[#out + 1] = string.format("\\u%04x\\u%04x", 0xD800 + (rest >> 10), 0xDC00 + (rest & 0x3FF))
        end
    end
    out[#out + 1] = '"'
    return table.concat(out)
end

local function encode(value, depth)
    if value == NULL then
        return "null"
    elseif value == true then
        return "true"
    elseif value == false then
        return "false"
    elseif type(value) == "string" then
        return encode_string(value)
    elseif value.kind == "int" then
        return value.text
    elseif value.kind == "array" then
        if #value.items == 0 then
            return "[]"
        end
        local inner = string.rep(" ", depth + 1)
        local items = {}
        for i, item in ipairs(value.items) do
            items[i] = inner .. encode(item, depth + 1)
        end
        return "[\n" .. table.concat(items, ",\n") .. "\n" .. string.rep(" ", depth) .. "]"
    elseif value.kind == "object" then
        if #value.keys == 0 then
            return "{}"
        end
        local inner = string.rep(" ", depth + 1)
        local members = {}
        for i, key in ipairs(value.keys) do
            members[i] = inner .. encode_string(key) .. ": " .. encode(value.vals[key], depth + 1)
        end
        return "{\n" .. table.concat(members, ",\n") .. "\n" .. string.rep(" ", depth) .. "}"
    end
    raise("place-by-ladder.lua: a value this writer does not know")
end

local function ladder_table(text)
    local found = {}
    for _, row in ipairs(lib.ladder_rows(text)) do
        found[row.name] = lib.strip(row.release)
    end
    return found
end

local function measured_from_table(text)
    local found = {}
    for _, row in ipairs(lib.ladder_rows(text)) do
        local release = lib.strip(row.release)
        if release ~= "" and release ~= "-" then
            found[row.name] = release
        end
    end
    return found
end

local function measured(text)
    local found = {}
    for _, line in ipairs(lib.file_lines(text)) do
        local parts = lib.split_text(line, "\t")
        if #parts == 3 and lib.starts_with(parts[1], "VideoToolboxConstants") and lib.starts_with(parts[2], "_kVT") then
            local rungs = {}
            for _, rung in ipairs(lib.split_text(parts[3], ",")) do
                if rung ~= "" and rung ~= "none" then
                    rungs[#rungs + 1] = rung
                end
            end
            if #rungs > 0 then
                local best = rungs[1]
                for i = 2, #rungs do
                    if lib.tuple_less(lib.release_key(rungs[i]), lib.release_key(best)) then
                        best = rungs[i]
                    end
                end
                found[string.sub(parts[2], 2)] = best
            end
        end
    end
    return found
end

local keys_of = lib.keys_sorted

local function check_against(splitText)
    local fresh = measured(splitText)
    local committed = measured_from_table(lib.read_text(TABLE))
    local added, gone, moved = {}, {}, {}
    for name in pairs(fresh) do
        if committed[name] == nil then
            added[#added + 1] = name
        end
    end
    for name in pairs(committed) do
        if fresh[name] == nil then
            gone[#gone + 1] = name
        end
    end
    for name in pairs(fresh) do
        if committed[name] ~= nil and fresh[name] ~= committed[name] then
            moved[#moved + 1] = name
        end
    end
    lib.sort_bytes(added)
    lib.sort_bytes(gone)
    lib.sort_bytes(moved)
    for _, name in ipairs(gone) do
        print("  GONE from the split: " .. name)
    end
    for _, name in ipairs(added) do
        print(string.format("  NEW in the split: %s -> %s", name, fresh[name] or "(no held cache exports it)"))
    end
    for _, name in ipairs(moved) do
        print(string.format("  MOVED: %s %s -> %s", name, committed[name] or "(none)", fresh[name] or "(none)"))
    end
    if #added == 0 and #gone == 0 and #moved == 0 then
        print(string.format("  the committed table equals the split file, %d constants", #keys_of(fresh)))
        return 0
    end
    print(string.format("FAIL the split and the committed table disagree: %d new, %d gone, %d moved", #added, #gone, #moved))
    return 1
end

local function is_release(s)
    if type(s) ~= "string" or s == "" then
        return false
    end
    local pos = 1
    while true do
        local digits = s:match("^%d+", pos)
        if not digits then
            return false
        end
        pos = pos + #digits
        if pos > #s then
            return true
        end
        if s:sub(pos, pos) ~= "." then
            return false
        end
        pos = pos + 1
    end
end

local function object_name(release)
    return "VideoToolboxConstants" .. string.gsub(release, "%.", "_") .. ".m"
end

local function place(ladder, objects, registry)
    local lines, comment = {}, nil
    for _, file in ipairs(lib.files_matching(objects, "VideoToolboxConstants*.m")) do
        local text = lib.read_text(file)
        local start = string.find(text, "// The string constants", 1, true)
        if start then
            local stop = string.find(text, "\nconst CFStringRef", 1, true)
            if not stop then
                raise("ValueError: substring not found in " .. file)
            end
            comment = (string.sub(text, start, stop - 1):gsub("\n+$", ""))
            local cut = string.find(comment, "\n\n// This file holds", 1, true)
            if cut then
                comment = string.sub(comment, 1, cut - 1)
            end
        end
        for _, line in ipairs(lib.split_text(text, "\n")) do
            local name = line:match("^const CFStringRef ([%w_]+) =")
            if name then
                lines[name] = line
            end
        end
    end

    local tableAll = ladder_table(lib.read_text(TABLE))
    local linesNames, tableNames = keys_of(lines), keys_of(tableAll)
    local difference, inLines, inTable = {}, {}, {}
    for _, name in ipairs(linesNames) do
        inLines[name] = true
        if tableAll[name] == nil then
            difference[#difference + 1] = name
        end
    end
    for _, name in ipairs(tableNames) do
        inTable[name] = true
        if lines[name] == nil then
            difference[#difference + 1] = name
        end
    end
    if #difference > 0 then
        lib.sort_bytes(difference)
        local first = {}
        for i = 1, math.min(5, #difference) do
            first[i] = difference[i]
        end
        raise(string.format("AssertionError: the objects define %d constants and the table measures %d; the difference is %s",
            #linesNames, #tableNames, lib.py_list(first)))
    end
    if comment == nil or comment == "" then
        raise("AssertionError: the objects carry no comment to put in the earliest one")
    end

    local registryFiles = lib.files_matching(registry, "*.json")
    local rowOrder, rows = {}, {}
    for _, file in ipairs(registryFiles) do
        local data = parse_json(lib.read_text(file))
        for _, row in ipairs(must_get(data, "entries").items) do
            if obj_get(row, "kind") == "constant" then
                local api = must_get(row, "api")
                if lines[api] ~= nil then
                    if rows[api] == nil then
                        rowOrder[#rowOrder + 1] = api
                    end
                    rows[api] = row
                end
            end
        end
    end
    local missingRows = {}
    for _, name in ipairs(linesNames) do
        if rows[name] == nil then
            missingRows[#missingRows + 1] = name
        end
    end
    if #missingRows > 0 then
        raise("AssertionError: a defined constant has no row: " .. lib.py_list(missingRows))
    end

    local groups, releases, first, moved = {}, {}, nil, 0
    for _, name in ipairs(linesNames) do
        local row = rows[name]
        local release = ladder[name]
        if release == nil or release == "" then
            release = must_get(row, "introduced")
        end
        if not is_release(release) then
            raise(string.format("AssertionError: %s would be placed at %s, which is not a release: the ladder says %s "
                .. "and the registry row says %s", name, lib.py_value(release and lib.py_repr(release)),
                lib.py_value(ladder[name] and lib.py_repr(ladder[name])),
                lib.py_value(obj_get(row, "introduced") and lib.py_repr(obj_get(row, "introduced")))))
        end
        if must_get(row, "introduced") ~= release then
            moved = moved + 1
            local header = must_get(row, "introduced")
            obj_set(row, "introduced", release)
            obj_set(row, "source", "the armv7 cache ladder (tools/release-split.lua), which first exports it at " .. release
                .. "; SDK 26.2, VideoToolbox/Headers, states " .. header)
        end
        if groups[release] == nil then
            groups[release] = {}
            releases[#releases + 1] = release
        end
        groups[release][#groups[release] + 1] = name
        if first == nil or lib.tuple_less(lib.release_key(release), lib.release_key(first)) then
            first = release
        end
    end
    local placedTotal = 0
    for _, release in ipairs(releases) do
        placedTotal = placedTotal + #groups[release]
    end
    if placedTotal ~= #tableNames then
        raise(string.format("AssertionError: the layout places %d constants and the table measures %d", placedTotal, #tableNames))
    end
    table.sort(releases, function(a, b)
        return lib.tuple_less(lib.release_key(a), lib.release_key(b))
    end)

    local fileOrder, files = {}, {}
    for _, file in ipairs(registryFiles) do
        local base = path.filename(file)
        local data = parse_json(lib.read_text(file))
        local kept = { kind = "array", items = {} }
        for _, row in ipairs(must_get(data, "entries").items) do
            local dropped = obj_get(row, "kind") == "constant" and lines[must_get(row, "api")] ~= nil
            if not dropped then
                kept.items[#kept.items + 1] = row
            end
        end
        obj_set(data, "entries", kept)
        files[base] = data
        fileOrder[#fileOrder + 1] = base
    end
    for _, name in ipairs(rowOrder) do
        local major = string.match(must_get(rows[name], "introduced"), "^[^.]*")
        local base = "ios" .. major .. ".json"
        if files[base] == nil then
            local data = new_object()
            obj_set(data, "framework", "VideoToolbox")
            obj_set(data, "entries", { kind = "array", items = {} })
            files[base] = data
            fileOrder[#fileOrder + 1] = base
        end
        local entries = must_get(files[base], "entries")
        entries.items[#entries.items + 1] = rows[name]
    end

    local bodies = {}
    for _, release in ipairs(releases) do
        local body = IMPORTS .. "\n"
        if release == first then
            body = body .. comment .. "\n\n"
            body = body .. string.format(
                "// This file holds the constants of iOS %s; every other release's are in\n"
                .. "// VideoToolboxConstants<release>.m, because an object carries the API of one release: the\n"
                .. "// release the cache ladder measures for the symbol (place-by-ladder.py), and the registry's\n"
                .. "// where no held cache exports it.\n\n", release)
        else
            body = body .. string.format(
                "// The string constants VideoToolbox's first held export of which is iOS %s. Where the values\n"
                .. "// come from, and why a value is not the constant's own name: the head of\n"
                .. "// %s. An object carries the API of one release.\n\n", release, object_name(first))
        end
        local sorted = lib.sort_bytes({ table.unpack(groups[release]) })
        local out = {}
        for _, name in ipairs(sorted) do
            out[#out + 1] = lines[name]
        end
        bodies[object_name(release)] = body .. table.concat(out, "\n") .. "\n"
    end

    for _, file in ipairs(lib.files_matching(objects, "VideoToolboxConstants*.m")) do
        if bodies[path.filename(file)] == nil then
            os.rm(file)
        end
    end
    for _, base in ipairs(fileOrder) do
        local data = files[base]
        local full = path.join(registry, base)
        if #must_get(data, "entries").items == 0 then
            os.rm(full)
        else
            lib.write_text(full, encode(data, 0) .. "\n")
        end
    end
    for name, body in pairs(bodies) do
        lib.write_text(path.join(objects, name), body)
    end

    print(string.format("placed %d constants in %d objects, %d rows moved to the ladder's release", #linesNames, #releases, moved))
    for _, release in ipairs(releases) do
        print(string.format("  %-7s %3d", release, #groups[release]))
    end
end

local function canonical_registry(directory)
    local out = {}
    for _, file in ipairs(lib.files_matching(directory, "*.json")) do
        local data = parse_json(lib.read_text(file))
        local rows = {}
        for _, row in ipairs(must_get(data, "entries").items) do
            rows[#rows + 1] = encode(row, 0)
        end
        lib.sort_bytes(rows)
        local head = new_object()
        for _, key in ipairs(data.keys) do
            if key ~= "entries" then
                obj_set(head, key, data.vals[key])
            end
        end
        out[path.filename(file)] = { head = encode(head, 0), rows = rows }
    end
    return out
end

local function same_rows(committedDir, placedDir)
    local committed, placed = canonical_registry(committedDir), canonical_registry(placedDir)
    local names, failures, total = {}, {}, 0
    for name in pairs(committed) do
        names[#names + 1] = name
    end
    for name in pairs(placed) do
        if committed[name] == nil then
            failures[#failures + 1] = name .. " is in the placed registry and not in the committed one"
        end
    end
    lib.sort_bytes(names)
    for _, name in ipairs(names) do
        local a, b = committed[name], placed[name]
        if b == nil then
            failures[#failures + 1] = name .. " is in the committed registry and not in the placed one"
        else
            total = total + #a.rows
            if a.head ~= b.head then
                failures[#failures + 1] = name .. ": its keys other than entries differ"
            elseif #a.rows ~= #b.rows then
                failures[#failures + 1] = string.format("%s: %d rows committed and %d placed", name, #a.rows, #b.rows)
            else
                for i = 1, #a.rows do
                    if a.rows[i] ~= b.rows[i] then
                        failures[#failures + 1] = name .. ": a row differs, first at sorted row " .. i
                        break
                    end
                end
            end
        end
    end
    if #failures > 0 then
        for _, line in ipairs(failures) do
            print("FAIL " .. line)
        end
        return 1
    end
    print(string.format("registry: %d rows in %d files, the same rows in the same files as committed, order aside",
        total, #names))
    return 0
end

function main(...)
    local args = { ... }
    local objects, registry = OBJECTS, REGISTRY
    local positional, check, sameRows = nil, nil, nil
    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "--check" then
            check = args[i + 1]
            if not check then
                raise("place-by-ladder.lua: --check needs a split file")
            end
            i = i + 1
        elseif arg == "--same-rows" then
            sameRows = { args[i + 1], args[i + 2] }
            if not sameRows[1] or not sameRows[2] then
                raise("place-by-ladder.lua: --same-rows needs COMMITTED REGISTRY directories")
            end
            i = i + 2
        elseif arg == "--into" then
            objects, registry = args[i + 1], args[i + 2]
            if not objects or not registry then
                raise("place-by-ladder.lua: --into needs OBJECTS and REGISTRY")
            end
            i = i + 2
        else
            positional = arg
        end
        i = i + 1
    end
    if check then
        os.exit(check_against(lib.read_text(check)))
    end
    if sameRows then
        os.exit(same_rows(sameRows[1], sameRows[2]))
    end
    local ladder
    if positional then
        ladder = measured(lib.read_text(positional))
    else
        ladder = measured_from_table(lib.read_text(TABLE))
    end
    place(ladder, objects, registry)
end
