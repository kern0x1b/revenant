-- The registry rows for exactly what the ModelIO objects build. It replaces tools/corpus/mio-rows.py, and its output is byte-equal to
-- that script's on the same rows.
--
--     xmake l tools/gen/mio_rows.lua ROWS.TSV SDK_RELEASE
--
-- SDK_RELEASE is the release the rows were read from; the rows name it, so it is passed and not written here.
--
-- ROWS.TSV is surface-diff's rows (tools/corpus/surface-diff-latest.py --rows). The file it writes, mio-rows.tsv, sits beside it.
--
-- Two authorities, and they are different on purpose:
--   - WHICH selectors exist comes from clang's AST (surface-diff's rows), so a compiler-generated helper can never become a row;
--   - minimum comes from the AST's OWN ios introduced, per member, because a class's band does not decide a member's band and
--     release-split splits on the member.
--
-- The band is never taken from the object a member happens to sit in. A member with no usable band is counted and printed, and the
-- count must be ZERO: a non-zero count means the AST lookup missed and every such row would be filed under the band of its file.

local tsv = import("tsv", {anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

-- The NSObject basics this file drops. Its own list, shorter than mio_objects' DROP list, as the Python had it.
local NS_BASICS = {}
for _, name in ipairs({"init", "dealloc", "retain", "release", "autorelease", "hash", "self", "class", "superclass", "zone",
                       "isEqual:", "copyWithZone:", "description", "debugDescription", "allowsWeakReference",
                       "retainWeakReference", "isProxy"}) do
    NS_BASICS[name] = true
end

local FACTS = "facts/ModelIO/Surface.md"
local HEADER = {"api", "kind", "introduced", "minimum", "reason", "effect", "source", "facts"}

local function read_bytes(filepath)
    local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
    local text = handle:read("a")
    handle:close()
    return text
end

-- The sign, the class, and the first keyword with its colon when the selector has one. nil when it is not a method.
local function sel(api)
    local sign, rest = string.match(api, "^([%-+])%[(.*)%]$")
    if not sign then
        return nil
    end
    local cls = string.match(rest, "^([A-Za-z_][A-Za-z0-9_]*)")
    if not cls then
        return nil
    end
    local sig = string.match(rest, "^[A-Za-z_][A-Za-z0-9_]*%s*(.*)$")
    local first = string.match(string.match(sig, "^([^:]*)"), "^%s*(.-)%s*$")
    return sign, cls, first .. (string.find(sig, ":", 1, true) and ":" or "")
end

-- The version of a band as a list of numbers, so 9.0 sorts before 10.0; a shorter prefix sorts first.
local function band_before(a, b)
    local left, right = {}, {}
    for number in string.gmatch(a, "%d+") do table.insert(left, tonumber(number)) end
    for number in string.gmatch(b, "%d+") do table.insert(right, tonumber(number)) end
    for index = 1, math.max(#left, #right) do
        if left[index] ~= right[index] then
            if left[index] == nil then return true end
            if right[index] == nil then return false end
            return left[index] < right[index]
        end
    end
    return false
end

local function count_dots(text)
    local count = 0
    for _ in string.gmatch(text, "%.") do
        count = count + 1
    end
    return count
end

-- The rows of an input as {kind, api, band}, for a class or a method that has a band.
local function load(filepath)
    local rows = {}
    local lines = tsv.lines(read_bytes(filepath))
    for index = 2, #lines do
        local fields = tsv.fields(lines[index])
        if #fields >= 4 and (fields[2] == "class" or fields[2] == "method") and fields[4] ~= "" then
            table.insert(rows, {kind = fields[2], api = fields[3], band = fields[4], position = #rows + 1})
        end
    end
    return rows
end

-- Sorts rows by their band, then by their api, keeping the input order for a tie, as a stable sort does.
local function sorted_by_band(rows)
    local ordered = table.join(rows)
    table.sort(ordered, function (a, b)
        if a.band ~= b.band then
            return band_before(a.band, b.band)
        end
        if a.api ~= b.api then
            return byteorder.less(a.api, b.api)
        end
        return a.position < b.position
    end)
    return ordered
end

-- The tab-separated text of a row list: the header, then one line per row.
local function row_text(cells)
    return table.concat(cells, "\t") .. "\n"
end

function main(rows_path, release)
    assert(rows_path and release, "usage: xmake l tools/gen/mio_rows.lua ROWS.TSV SDK_RELEASE")
    local rows = load(rows_path)
    local classes, methods = {}, {}
    for _, row in ipairs(rows) do
        if row.kind == "class" then
            table.insert(classes, row)
        else
            table.insert(methods, row)
        end
    end

    local dropped, kept = {}, {}
    for _, row in ipairs(methods) do
        local _, _, name = sel(row.api)
        local key = name or row.api
        if NS_BASICS[key] then
            table.insert(dropped, row.api)
        else
            table.insert(kept, row)
        end
    end

    local out = {row_text(HEADER)}
    local fallbacks = 0
    for _, row in ipairs(sorted_by_band(classes)) do
        out[#out + 1] = row_text({
            row.api, "class", row.band, row.band,
            "iOS 6.1.3 has no ModelIO.framework at all, so the class is carried: a hard reference to one is a LOAD-FAIL and carrying it is what stops the kill",
            "the class the release does not have, so a caller that allocates one gets this port s own; what it DOES is the carried surface below and nothing beyond it",
            "clang s own AST of the " .. release .. " headers as read by tools/corpus/surface-diff-latest.py --rows; the ios introduced on the node is the band, and release-split places the object",
            FACTS,
        })
    end
    for _, row in ipairs(sorted_by_band(kept)) do
        local kind = string.match(string.gsub(row.api, "%]+$", ""), ":$") and "selector" or "method"
        out[#out + 1] = row_text({
            row.api, kind, row.band, row.band,
            "carried so a caller naming it is CALLABLE; the answer is the honest one for a machine with no GPU, no asset library and no provider",
            "the member implemented in the band object the generator wrote from the AST; an object answer is nil, a BOOL is NO and a number is 0, and nothing is invented",
            "clang s own AST of the " .. release .. " headers; the member list is the AST s ObjCMethodDecl list, so a compiler helper such as .cxx_destruct can never become a row",
            FACTS,
        })
        if row.band == "" or count_dots(row.band) ~= 1 then
            fallbacks = fallbacks + 1
        end
    end

    local directory = string.match(rows_path, "^(.*)/") or rows_path
    local out_path = directory .. "/mio-rows.tsv"
    io.writefile(out_path, table.concat(out), {encoding = "binary"})

    print(string.format("  rows written: %d  (1 header + %d classes + %d members)", #out, #classes, #kept))
    print(string.format("  dropped by the NSObject-basics rule: %d   e.g. %s", #dropped, dropped[1] or ""))
    print(string.format("  members with no usable AST band (must be 0): %d", fallbacks))

    local bands, seen = {}, {}
    for index = 2, #out do
        local band = string.match(out[index], "^[^\t]*\t[^\t]*\t([^\t]*)\t")
        if band and not seen[band] then
            seen[band] = true
            table.insert(bands, band)
        end
    end
    table.sort(bands, band_before)
    local quoted = {}
    for _, band in ipairs(bands) do
        table.insert(quoted, "'" .. band .. "'")
    end
    print("  bands present: [" .. table.concat(quoted, ", ") .. "]")
    print("  file: " .. out_path)
end
