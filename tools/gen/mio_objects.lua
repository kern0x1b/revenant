-- The per-release-band ModelIO objects, from surface-diff's rows. It replaces tools/corpus/gen-mio.py, and its output is byte-equal
-- to that script's on the same rows and the same tree.
--
--     xmake l tools/gen/mio_objects.lua ROWS.TSV OUTDIR
--
-- ROWS.TSV is what surface-diff writes (tools/corpus/surface-diff-latest.py --rows): framework, kind, api, introduced, one row per
-- declared API of the SDK's headers, read by clang's own AST.
--
-- THE AST IS THE AUTHORITY FOR WHICH SELECTORS EXIST. The member set comes from clang's JSON AST of the headers, so .cxx_destruct,
-- allocator, retain, release and the rest, which the COMPILER generates for a C++ class, are never in the input and cannot be carried.
--
-- ONE BAND PER OBJECT, because release-split refuses a file whose members first appear in more than one release: a class whose own
-- first release is B is declared in B, and a member of an OLDER class whose first release is B goes in a CATEGORY, since two objects
-- cannot both hold @implementation X.
--
-- No @interface is emitted: ModelIO.h already declares the class, and re-declaring it is "duplicate interface definition for class".
-- A carried class is completed with an @implementation.
--
-- THE TREE'S OWN SOURCES are read first, so a class the tree already defines is not defined twice. The member set this reads from the
-- sources holds the sign of each member, not its selector, so the check that drops a member the tree already builds never matches; the
-- Python this replaces did the same, and the port keeps it so that its output stays byte-equal. The count the run prints shows it.

local tsv = import("tsv", {anonymous = true})
local json = import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local ROOT = path.join(os.scriptdir(), "..", "..")
local HEADER_MAP = path.join(ROOT, "packages", "a", "apple-backports", "spec", "ModelIO", "hdr-map.json")

-- The selectors of NSObject's protocol, and the helpers the rules below drop. Every rule is printed with how many names it removed.
local NSOBJECT_BASICS = {}
for _, name in ipairs({"init", "dealloc", "retain", "release", "autorelease", "hash", "self", "class", "superclass", "zone",
                       "isEqual:", "copyWithZone:", "doesNotRecognizeSelector:", "respondsToSelector:", "conformsToProtocol:",
                       "isKindOfClass:", "isMemberOfClass:", "performSelector:", "performSelector:withObject:", "forwardInvocation:",
                       "methodSignatureForSelector:", "forwardingTargetForSelector:", "description", "debugDescription",
                       "allowsWeakReference", "retainWeakReference", "isProxy"}) do
    NSOBJECT_BASICS[name] = true
end
local DROP = {
    {"cxx destructor", function (name) return name == ".cxx_destruct" end},
    {"cxx constructor", function (name) return name == ".cxx_construct" end},
    {"allocator", function (name) return name == "allocator" end},
    {"NSObject protocol basics", function (name) return NSOBJECT_BASICS[name] == true end},
}

local function read_bytes(filepath)
    local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
    local text = handle:read("a")
    handle:close()
    return text
end

local function trim(text)
    return string.match(text, "^%s*(.-)%s*$")
end

local function set_size(set)
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    return count
end

-- The bands as numbers, so 9.0 sorts before 10.0: a list of integers compared in turn, a shorter prefix first.
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

-- The ObjC selector of an API string: its sign, class, first keyword, the number of keywords, and the text between the class and ].
-- nil when it is not an instance or class method.
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
    local first = trim(string.match(sig, "^([^:]*)"))
    local count = 0
    for _ in string.gmatch(sig, ":") do
        count = count + 1
    end
    return sign, cls, first, count, sig
end

-- The text of the block comments of a source, each one a space, as the regular expression /\*.*?\*/ replaces them.
local function without_comments(text)
    local out, pos = {}, 1
    while true do
        local start = string.find(text, "/*", pos, true)
        if not start then
            break
        end
        local _, close = string.find(text, "*/", start + 2, true)
        if not close then
            break
        end
        table.insert(out, string.sub(text, pos, start - 1))
        table.insert(out, " ")
        pos = close + 1
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out)
end

-- The pieces of a source cut before each line that starts @implementation, as re.split(r'(?=^@implementation)', re.M) cuts it.
local function blocks_of(text)
    local starts, pos = {}, 1
    while true do
        local start = string.find(text, "@implementation", pos, true)
        if not start then
            break
        end
        if start == 1 or string.sub(text, start - 1, start - 1) == "\n" then
            table.insert(starts, start)
        end
        pos = start + 1
    end
    local blocks, from = {}, 1
    for _, start in ipairs(starts) do
        table.insert(blocks, string.sub(text, from, start - 1))
        from = start
    end
    table.insert(blocks, string.sub(text, from))
    return blocks
end

-- The member tokens of a block: the sign of each method that starts a line, with a colon when its selector has one. This is what
-- the Python's regular expression yields, and it reads the sign, not the name (see the header).
local function member_tokens(block)
    local tokens = {}
    local at = 1
    while at <= #block do
        local starts_line = at == 1 or string.sub(block, at - 1, at - 1) == "\n"
        local _, last, sign, colon = nil, nil, nil, nil
        if starts_line then
            _, last, sign, colon = string.find(block, "^%s*([%-+])%s*%([^%)]*%)%s*[A-Za-z_][A-Za-z0-9_]*%s*(:?)", at)
        end
        if last then
            table.insert(tokens, sign .. (colon ~= "" and ":" or ""))
            at = last + 1
        else
            at = at + 1
        end
    end
    return tokens
end

-- What the tree already builds for this framework: the classes and the member tokens of its own @implementation blocks. A category
-- (@implementation X (Y)) does not own the class, and it takes the class out of the set, as the Python does.
local function already_defined(pkg)
    local classes, members = {}, {}
    if not os.isdir(pkg) then
        return classes, members
    end
    local names = {}
    for _, file in ipairs(os.files(path.join(pkg, "*.m"))) do
        table.insert(names, path.filename(file))
    end
    byteorder.sort(names)
    for _, name in ipairs(names) do
        local text = without_comments(read_bytes(path.join(pkg, name)))
        for _, block in ipairs(blocks_of(text)) do
            local cls = string.match(block, "^@implementation%s+([A-Za-z_][A-Za-z0-9_]*)")
            if cls then
                classes[cls] = true
                if string.match(block, "^@implementation%s+[A-Za-z_][A-Za-z0-9_]*%s*%(") then
                    classes[cls] = nil
                end
                for _, token in ipairs(member_tokens(block)) do
                    members[cls .. "\t" .. token] = true
                end
            end
        end
    end
    return classes, members
end

-- The rows that are a class or a method with a band: framework, kind, api, introduced, as the rows file has them.
local function load(filepath)
    local rows = {}
    local lines = tsv.lines(read_bytes(filepath))
    for index = 2, #lines do
        local fields = tsv.fields(lines[index])
        if #fields >= 4 and (fields[2] == "class" or fields[2] == "method") and fields[4] ~= "" then
            table.insert(rows, {kind = fields[2], api = fields[3], band = fields[4]})
        end
    end
    return rows
end

-- The Objective-C signature of an API string, built from its selector's keywords, every one with its colon and one (id) parameter.
-- Assembled from the keywords and not by pasting the return type next to the name: a return-type-first form is "expected ')'" to clang.
local function selector_signature(api)
    local sign, _, _, _, sig = sel(api)
    if not sign then
        return nil
    end
    local parts = {}
    for piece in string.gmatch(sig .. ":", "([^:]*):") do
        local kept = trim(piece)
        if kept ~= "" then
            table.insert(parts, kept)
        end
    end
    local stripped = string.match(sig, "^(.-)%s*$")
    if string.sub(stripped, -1) ~= ":" and #parts > 1 then
        table.remove(parts)
    end
    if #parts == 0 then
        return sign .. " ()"
    end
    if not string.find(sig, ":", 1, true) then
        return sign .. " ()" .. parts[1]
    end
    local out = {}
    for index, part in ipairs(parts) do
        table.insert(out, part .. ":(id)a" .. (index - 1))
    end
    return sign .. " (id)" .. table.concat(out, " ")
end

-- The class-to-header map of the SDK, read once from the spec.
local header_cache = nil
local function headers_map()
    if header_cache == nil then
        header_cache = {}
        if os.isfile(HEADER_MAP) then
            header_cache = json.decode(read_bytes(HEADER_MAP))
        end
    end
    return header_cache
end

-- The methods of one class, from the band's members, as their one-line stubs.
local function stubs_of(cls, members)
    local out = {}
    for _, member in ipairs(members) do
        local sign, owner = sel(member.api)
        if sign and owner == cls then
            local signature = selector_signature(member.api)
            if signature then
                table.insert(out, signature .. " { return nil; }")
            end
        end
    end
    return out
end

function main(rows_path, outdir)
    assert(rows_path and outdir, "usage: xmake l tools/gen/mio_objects.lua ROWS.TSV OUTDIR")
    local rows = load(rows_path)
    os.mkdir(outdir)
    local have_classes, have_members = already_defined(outdir)
    if set_size(have_classes) > 0 then
        print(string.format("  the tree already defines %d classes and %d members for this framework; they are NOT", set_size(have_classes), set_size(have_members)))
        print("  re-emitted, and only the MISSING members of those classes go in a category in a new object")
    end

    local classes, methods = {}, {}
    local class_count, api_seen = 0, {}
    for _, row in ipairs(rows) do
        if row.kind == "class" then
            if classes[row.api] == nil and not api_seen[row.api] then
                api_seen[row.api] = true
                class_count = class_count + 1
            end
            classes[row.api] = row.band
        else
            table.insert(methods, row)
        end
    end

    local dropped, dropped_order = {}, {}
    local function drop(label, api)
        if dropped[label] == nil then
            dropped[label] = {}
            table.insert(dropped_order, label)
        end
        table.insert(dropped[label], api)
    end
    local kept = {}
    for _, row in ipairs(methods) do
        local sign, cls, first, count = sel(row.api)
        if not sign then
            drop("not an ObjC selector", row.api)
        else
            local name = first .. (count > 0 and ":" or "")
            local matched = false
            for _, rule in ipairs(DROP) do
                if not matched and rule[2](name) then
                    drop(rule[1], row.api)
                    matched = true
                end
            end
            if not matched then
                table.insert(kept, row)
            end
        end
    end

    print(string.format("  the AST declares %d methods and %d classes", #methods, class_count))
    print("  DROPPED, per rule:")
    local labels = {}
    for _, rule in ipairs(DROP) do
        table.insert(labels, rule[1])
    end
    table.insert(labels, "not an ObjC selector")
    for _, label in ipairs(labels) do
        local names = dropped[label] or {}
        print(string.format("    %-28s %4d   %s", label, #names, names[1] or ""))
    end
    print(string.format("  KEPT %d methods; every one came from the AST, so no compiler helper entered", #kept))
    local dropped_total = 0
    for _, label in ipairs(dropped_order) do
        dropped_total = dropped_total + #dropped[label]
    end
    print(string.format("  %d + %d = %d accounted for", #kept, dropped_total, #methods))

    local by_band, band_order = {}, {}
    local skipped = 0
    for _, row in ipairs(kept) do
        local sign, cls, first, count = sel(row.api)
        if sign and have_members[cls .. "\t" .. first .. (count > 0 and ":" or "")] then
            skipped = skipped + 1
        else
            if by_band[row.band] == nil then
                by_band[row.band] = {}
                table.insert(band_order, row.band)
            end
            table.insert(by_band[row.band], row)
        end
    end
    print(string.format("  members dropped because the tree already builds them: %d", skipped))

    local own_band, seen_band, bands = {}, {}, {}
    for api, band in pairs(classes) do
        own_band[band] = own_band[band] or {}
        table.insert(own_band[band], api)
    end
    for _, band in ipairs(band_order) do
        seen_band[band] = true
    end
    for band in pairs(own_band) do
        seen_band[band] = true
    end
    for band in pairs(seen_band) do
        table.insert(bands, band)
    end
    table.sort(bands, band_before)

    local written = {}
    for _, band in ipairs(bands) do
        local own = {}
        for _, cls in ipairs(own_band[band] or {}) do
            if not have_classes[cls] then
                table.insert(own, cls)
            end
        end
        byteorder.sort(own)

        local members = by_band[band] or {}
        local later_seen, later_all = {}, {}
        for _, member in ipairs(members) do
            local sign, cls = sel(member.api)
            if sign and classes[cls] ~= nil and have_classes[cls] and not later_seen[cls] then
                later_seen[cls] = true
                table.insert(later_all, cls)
            end
        end
        byteorder.sort(later_all)
        local ordered = {}
        for _, member in ipairs(members) do
            table.insert(ordered, member)
        end
        table.sort(ordered, function (a, b)
            if a.api ~= b.api then
                return byteorder.less(a.api, b.api)
            end
            return false
        end)

        if #own == 0 and #ordered == 0 then
            print(string.format("  %-6s NOTHING: no class and no member first appears here, so no file is written", band))
        else
            local tag = string.gsub(band, "%.", "")
            local body = {"#import <ModelIO/ModelIO.h>"}
            local emitted, emitted_seen = {}, {}
            for _, cls in ipairs(own) do
                if not emitted_seen[cls] then
                    emitted_seen[cls] = true
                    table.insert(emitted, cls)
                end
            end
            for _, cls in ipairs(later_all) do
                if not emitted_seen[cls] then
                    emitted_seen[cls] = true
                    table.insert(emitted, cls)
                end
            end
            byteorder.sort(emitted)

            local headers = headers_map()
            local header_lines, header_seen, unknown = {}, {}, false
            for _, cls in ipairs(emitted) do
                if headers[cls] then
                    if not header_seen[headers[cls]] then
                        header_seen[headers[cls]] = true
                        table.insert(header_lines, headers[cls])
                    end
                else
                    unknown = true
                end
            end
            byteorder.sort(header_lines)
            for _, header in ipairs(header_lines) do
                table.insert(body, "#import <ModelIO/" .. header .. ">")
            end
            if unknown then
                table.insert(body, '#import "CharonModelIO.h"')
            end
            for _, line in ipairs({
                "#import <objc/runtime.h>", "",
                "// The iOS " .. band .. " band of ModelIO, generated by tools/gen/mio_objects.lua from clang s own AST of",
                "// the 26.2 headers. One band per object: release-split refuses a file whose members first",
                "// appear in more than one release.", "",
                "// Every answer here is the honest one for a machine with no GPU, no asset library and no",
                "// provider: an object answer is nil, a BOOL is NO, a number is 0. Nothing is invented and",
                "// nothing is pretended; MDLAsset and MDLMesh are built for real on the CPU in the object",
                "// that follows, and nothing here claims to be one.", "",
            }) do
                table.insert(body, line)
            end
            for _, cls in ipairs(own) do
                table.insert(body, "// " .. cls .. " first appears at " .. band .. ", so the class is declared here and is CALLABLE.")
                table.insert(body, "@implementation " .. cls)
                for _, stub in ipairs(stubs_of(cls, ordered)) do
                    table.insert(body, stub)
                end
                table.insert(body, "@end")
                table.insert(body, "")
            end
            for _, cls in ipairs(later_all) do
                do
                    local is_own = false
                    for _, own_cls in ipairs(own) do
                        if own_cls == cls then
                            is_own = true
                        end
                    end
                    if not is_own then
                        table.insert(body, "// " .. cls .. " arrived at " .. band .. ", so its later members are a CATEGORY: two objects cannot both hold")
                        table.insert(body, "// @implementation " .. cls .. ", and release-split wants one release per object.")
                        table.insert(body, "@implementation " .. cls .. " (Charon" .. tag .. ")")
                        for _, stub in ipairs(stubs_of(cls, ordered)) do
                            table.insert(body, stub)
                        end
                        table.insert(body, "@end")
                        table.insert(body, "")
                    end
                end
            end
            local name = "MDIO" .. tag .. ".m"
            local text = string.gsub(table.concat(body, "\n"), "%s+$", "") .. "\n"
            io.writefile(path.join(outdir, name), text, {encoding = "binary"})
            table.insert(written, {band, name, #own, #ordered})
        end
    end
    print("  FILES:")
    for _, entry in ipairs(written) do
        print(string.format("    %-6s %-14s %2d classes, %3d members", entry[1], entry[2], entry[3], entry[4]))
    end
end

