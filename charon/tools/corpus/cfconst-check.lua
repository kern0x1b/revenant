-- Reads each row of tools/corpus/cfconst.tsv back out of the dyld cache it names, and compares it with the initializer the row carries.
-- Usage: CHARON_ROOT=<worktree> xmake l tools/corpus/cfconst-check.lua
--
-- The cache is CACHE_ROOT/<release>/dyld_shared_cache_<arch> (CACHE_ROOT defaults to ~/.charon/dyld). Its symbols are read by
-- tools/corpus/cache-value.lua, which goes through the project's reader (modules/apple/dyld.lua). One call per cache: the rows that name
-- it are asked together, and cache-value answers with one line per symbol, or with dashes for a symbol no image of the cache exports.
--
-- A string row (@"..." or CFSTR("...")) is judged when its text is printable ASCII and the reader resolved the pointer: the text the cache
-- holds must equal the initializer's text. A number row is judged on the four bytes of the cache value: its float32 bits must equal the
-- number's. A struct row (a { n, n, ... } of integers) is judged field by field: the symbol is read as one word per field, at the
-- cache's pointer size (8 on arm64, 4 on armv7), and each word must equal its field. A row is reported by name, with what the cache held,
-- when it differs, when no image exports it, or when the reader gave no value.
--
-- Exits 1 when any row differs or is absent, or when no row was judged at all (a check that judged nothing proves nothing).

local measured = import("gen.measured", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local root = os.getenv("CHARON_ROOT") or path.join(os.scriptdir(), "..", "..")
local cache_root = os.getenv("CACHE_ROOT") or path.join(os.getenv("HOME"), ".charon", "dyld")
local cache_value = path.join(os.scriptdir(), "cache-value.lua")

-- The file of a cache named "<release> <arch>", as the held ladder keeps it.
local function cache_file(cache)
    local release, arch = string.match(cache, "^(%S+) (%S+)$")
    assert(release ~= nil, "the cache named in the table is not '<release> <arch>': " .. cache)
    return path.join(cache_root, release, "dyld_shared_cache_" .. arch)
end

-- The pointer size of a cache, by its architecture, as cache-value reads it (a 64-bit architecture's name has "64" in it).
local function pointer_size_of(cache)
    local arch = string.match(cache, "^%S+ (%S+)$")
    return string.find(arch, "64") and 8 or 4
end

-- The integers of a struct initializer, "{ 0, 0, 0 }" -> {0, 0, 0}, or nil when it is not a braced list of integers.
local function fields_of(initializer)
    local body = string.match(initializer, "^{(.*)}$")
    if body == nil then
        return nil
    end
    local out = {}
    for field in string.gmatch(body .. ",", "([^,]*),") do
        local value = tonumber(field)
        local number = value and math.tointeger(value)
        if number == nil then
            return nil
        end
        table.insert(out, number)
    end
    return out
end

-- What a row's initializer says it holds: {kind = "string", text = ...}, {kind = "number", value = ...}, {kind = "struct", fields = ...},
-- or nil.
local function expected_of(initializer)
    local quoted = string.match(initializer, '^@"(.*)"$') or string.match(initializer, '^CFSTR%("(.*)"%)$')
    if quoted ~= nil then
        return {kind = "string", text = (string.gsub(string.gsub(quoted, '\\"', '"'), "\\\\", "\\"))}
    end
    if string.sub(initializer, 1, 1) == "{" then
        local fields = fields_of(initializer)
        return fields and {kind = "struct", fields = fields} or nil
    end
    local number = tonumber(initializer)
    if number ~= nil then
        return {kind = "number", value = number}
    end
    return nil
end

-- The symbol file cache-value reads: name, width, pointer and text flags. A struct is read as one word per field, so its width is the
-- field count times the cache's pointer size.
local function symbol_line(row, expected)
    if expected.kind == "string" then
        return string.format("%s\tp\tp\ts", row.name)
    elseif expected.kind == "number" then
        return string.format("%s\tp\t-\t-", row.name)
    end
    return string.format("%s\t%d\t-\t-", row.name, #expected.fields * pointer_size_of(row.cache))
end

-- Reads the values of one cache's rows. Returns name -> the reader's fields, or nil for a symbol no image exports.
local function read_cache(cache, rows)
    local file = cache_file(cache)
    -- the symbol file goes beside the worktree's other run output, not into the system temp directory
    local runs = path.join(root, ".agent-work", "runs")
    os.mkdir(runs)
    local symbols = path.join(runs, "cfconst-symbols-" .. string.gsub(cache, " ", "-") .. ".tsv")
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, symbol_line(row, row.expected))
    end
    io.writefile(symbols, table.concat(lines, "\n") .. "\n")
    local out, err = os.iorunv("xmake", {"l", cache_value, file, symbols}, {envs = {CHARON_ROOT = root}})
    os.rm(symbols)
    assert(out ~= nil and out ~= "", "the reader gave no output for " .. file .. ": " .. tostring(err))
    local found = {}
    for line in string.gmatch(out, "[^\n]+") do
        local fields = {}
        for field in string.gmatch(line .. "\t", "([^\t]*)\t") do
            table.insert(fields, field)
        end
        if fields[1] == "#cache" then
            assert(tonumber(fields[3]) == pointer_size_of(cache), "the reader's pointer size for " .. cache .. " is " .. fields[3])
        elseif fields[2] == "-" then
            found[fields[1]] = false
        else
            found[fields[1]] = fields
        end
    end
    return found
end

-- The words of a struct as the cache holds them: the hex column's bytes, one signed integer per pointer-sized field.
local function words_of(hex, pointer_size, count)
    local bytes = (string.gsub(hex, "%x%x", function (h) return string.char(tonumber(h, 16)) end))
    local out = {}
    for i = 1, count do
        local word = string.unpack(pointer_size == 8 and "<i8" or "<i4", bytes, 1 + (i - 1) * pointer_size)
        table.insert(out, word)
    end
    return out
end

function main()
    local rows = measured.constant_rows(root)
    local by_cache, caches = {}, {}
    for _, row in ipairs(rows) do
        row.expected = expected_of(row.initializer)
        if row.expected == nil then
            print(string.format("UNJUDGED\t%s\t%s\tthe initializer %s is not a string, a number or a braced list of integers", row.object, row.name, row.initializer))
        elseif row.expected.kind == "string" and string.find(row.expected.text, "[^\32-\126]") then
            print(string.format("UNJUDGED\t%s\t%s\tthe initializer is not printable ASCII, and the reader prints a non-ASCII byte as a dot", row.object, row.name))
        else
            if by_cache[row.cache] == nil then
                by_cache[row.cache] = {}
                table.insert(caches, row.cache)
            end
            table.insert(by_cache[row.cache], row)
        end
    end
    local judged, failed = 0, 0
    for _, cache in ipairs(caches) do
        local found = read_cache(cache, by_cache[cache])
        for _, row in ipairs(by_cache[cache]) do
            local fields = found[row.name]
            if not fields then
                print(string.format("ABSENT\t%s\t%s\tthe reader answered for no symbol of %s", row.object, row.name, cache))
                failed = failed + 1
            elseif fields == false then
                print(string.format("ABSENT\t%s\t%s\tno image of %s exports it", row.object, row.name, cache))
                failed = failed + 1
            elseif row.expected.kind == "string" then
                local text = fields[9]
                if fields[8] == "-" or text == "-" then
                    print(string.format("UNREAD\t%s\t%s\tthe reader gave no string for it in %s", row.object, row.name, cache))
                    failed = failed + 1
                elseif text ~= row.expected.text then
                    print(string.format("DIFFERS\t%s\t%s\texpected %q, %s holds %q", row.object, row.name, row.expected.text, cache, text))
                    failed = failed + 1
                else
                    judged = judged + 1
                end
            elseif row.expected.kind == "struct" then
                if fields[4] == "-" then
                    print(string.format("UNREAD\t%s\t%s\tthe reader gave no words for it in %s", row.object, row.name, cache))
                    failed = failed + 1
                else
                    local held = words_of(fields[4], pointer_size_of(cache), #row.expected.fields)
                    local differs = {}
                    for i, want in ipairs(row.expected.fields) do
                        if held[i] ~= want then
                            table.insert(differs, string.format("field %d expected %d, %s holds %d", i, want, cache, held[i]))
                        end
                    end
                    if #differs == 0 then
                        judged = judged + 1
                    else
                        print(string.format("DIFFERS\t%s\t%s\t%s", row.object, row.name, table.concat(differs, "; ")))
                        failed = failed + 1
                    end
                end
            else
                local bits = string.unpack("<I4", string.pack("<f", row.expected.value))
                local held = tonumber(fields[5])
                if held ~= bits then
                    print(string.format("DIFFERS\t%s\t%s\texpected %s (float32 bits %d), %s holds %d", row.object, row.name, row.initializer, bits, cache, held))
                    failed = failed + 1
                else
                    judged = judged + 1
                end
            end
        end
    end
    print(string.format("cfconst-check: %d rows judged, %d not judged, %d failed", judged, #rows - judged - failed, failed))
    assert(judged > 0, "cfconst-check judged no row, so it proves nothing")
    if failed > 0 then
        os.exit(1)
    end
end
