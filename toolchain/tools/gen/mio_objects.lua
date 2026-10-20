local tsv = import("tsv", {anonymous = true})
local layout = import("layout", {anonymous = true})
local json = import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local FRAMEWORK = "ModelIO"

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

local function count_of(text, character)
    local count = 0
    for _ in string.gmatch(text, character) do
        count = count + 1
    end
    return count
end

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
    return sign, cls, first, count_of(sig, ":"), sig
end

local function parts_of(api)
    local sign, cls, first, count, sig = sel(api)
    if not sign then
        return nil
    end
    return {sign = sign, cls = cls, name = first .. (count > 0 and ":" or ""), selector = (string.gsub(sig, "%s", ""))}
end

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

local function header_selector(header)
    local bare = string.gsub(header, "%b()", " ")
    local selector = ""
    for name, rest in string.gmatch(bare, "([A-Za-z_][A-Za-z0-9_]*)(%s*:?)") do
        if string.find(rest, ":", 1, true) then
            selector = selector .. name .. ":"
        elseif selector == "" then
            selector = name
        end
    end
    return selector
end

local function member_selectors(block)
    local found = {}
    local at = 1
    while at <= #block do
        local starts_line = at == 1 or string.sub(block, at - 1, at - 1) == "\n"
        local last, sign = nil, nil
        if starts_line then
            local _, found_last, found_sign = string.find(block, "^%s*([%-+])%s*%([^%)]*%)%s*[A-Za-z_][A-Za-z0-9_]*", at)
            last, sign = found_last, found_sign
        end
        if last then
            local stop = string.find(block, "[{;]", at) or (#block + 1)
            table.insert(found, sign .. header_selector(string.sub(block, at, stop - 1)))
            at = last + 1
        else
            at = at + 1
        end
    end
    return found
end

local function class_of(block)
    local name, rest = string.match(block, "^@implementation%s+REVENANT_ALIAS_CLASS%(%s*([A-Za-z_][A-Za-z0-9_]*)%s*%)(.*)")
    if not name then
        name, rest = string.match(block, "^@implementation%s+([A-Za-z_][A-Za-z0-9_]*)(.*)")
    end
    if not name then
        return nil, false
    end
    return name, string.match(rest, "^%s*%(") ~= nil
end

local function defined_in_tree(folder)
    local owned, members = {}, {}
    if not os.isdir(folder) then
        return owned, members
    end
    local names = {}
    for _, file in ipairs(os.files(path.join(folder, "*.m"))) do
        table.insert(names, path.filename(file))
    end
    byteorder.sort(names)
    for _, name in ipairs(names) do
        local text = without_comments(read_bytes(path.join(folder, name)))
        for alias in string.gmatch("\n" .. text, "\nREVENANT_ALIAS%(%s*([A-Za-z_][A-Za-z0-9_]*)%s*%)") do
            owned[alias] = true
        end
        for _, block in ipairs(blocks_of(text)) do
            local cls, is_category = class_of(block)
            if cls then
                if not is_category then
                    owned[cls] = true
                end
                for _, selector in ipairs(member_selectors(block)) do
                    local key = cls .. "\t" .. selector
                    members[key] = members[key] or name
                end
            end
        end
    end
    return owned, members
end

local function load(filepath)
    local rows = {}
    for _, line in ipairs(tsv.lines(read_bytes(filepath))) do
        local fields = tsv.fields(line)
        if #fields >= 4 and (fields[2] == "class" or fields[2] == "method") and fields[4] ~= "" then
            table.insert(rows, {kind = fields[2], api = fields[3], band = fields[4], position = #rows + 1})
        end
    end
    return rows
end

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

local function headers_of(snap)
    if not os.isfile(path.join(snap, "hdr-map.json")) then
        return {}
    end
    return json.decode(read_bytes(path.join(snap, "hdr-map.json")))
end

function plan(tree, fw, sdk_release)
    local result = {files = {}, methods = 0, kept = 0, dropped = {}, tree_dropped = {}}
    if fw ~= FRAMEWORK then
        return result
    end
    assert(sdk_release, "the ModelIO objects need the SDK's release")
    local snap = layout.snap_dir(tree, fw)
    local rows_path = path.join(snap, "surface-rows-" .. sdk_release .. ".tsv")
    assert(os.isfile(rows_path), "no surface rows for SDK " .. sdk_release .. ": " .. rows_path)
    local rows = load(rows_path)
    local own_classes, have_members = defined_in_tree(path.join(tree, "..", layout.constants().SOURCES_ROOT, fw))
    local headers = headers_of(snap)

    local classes, methods = {}, {}
    for _, row in ipairs(rows) do
        if row.kind == "class" then
            classes[row.api] = row.band
        else
            table.insert(methods, row)
        end
    end
    result.methods = #methods

    local kept = {}
    for _, row in ipairs(methods) do
        local parts = parts_of(row.api)
        local rule = nil
        if not parts then
            rule = "not an ObjC selector"
        else
            for _, candidate in ipairs(DROP) do
                if rule == nil and candidate[2](parts.name) then
                    rule = candidate[1]
                end
            end
        end
        if rule then
            table.insert(result.dropped, {rule = rule, api = row.api})
        else
            table.insert(kept, row)
        end
    end
    result.kept = #kept

    local by_band, band_order = {}, {}
    for _, row in ipairs(kept) do
        local parts = parts_of(row.api)
        local file = have_members[parts.cls .. "\t" .. parts.sign .. parts.selector]
        if file then
            table.insert(result.tree_dropped, {cls = parts.cls, selector = parts.sign .. parts.selector, file = file, api = row.api})
        else
            if by_band[row.band] == nil then
                by_band[row.band] = {}
                table.insert(band_order, row.band)
            end
            table.insert(by_band[row.band], row)
        end
    end

    local own_band, bands, seen = {}, {}, {}
    for api, band in pairs(classes) do
        own_band[band] = own_band[band] or {}
        table.insert(own_band[band], api)
    end
    for _, band in ipairs(band_order) do
        seen[band] = true
    end
    for band in pairs(own_band) do
        seen[band] = true
    end
    for band in pairs(seen) do
        table.insert(bands, band)
    end
    table.sort(bands, band_before)

    for _, band in ipairs(bands) do
        local own = {}
        for _, cls in ipairs(own_band[band] or {}) do
            if not own_classes[cls] then
                table.insert(own, cls)
            end
        end
        byteorder.sort(own)

        local members = by_band[band] or {}
        local later_seen, later_all = {}, {}
        for _, member in ipairs(members) do
            local sign, cls = sel(member.api)
            if sign and classes[cls] ~= nil and own_classes[cls] and not later_seen[cls] then
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
            return a.position < b.position
        end)

        if #own > 0 or #ordered > 0 then
            local tag = string.gsub(band, "%.", "")
            local is_own = {}
            for _, cls in ipairs(own) do
                is_own[cls] = true
            end
            local emitted, emitted_seen = {}, {}
            for _, cls in ipairs(own) do
                emitted_seen[cls] = true
                table.insert(emitted, cls)
            end
            for _, cls in ipairs(later_all) do
                if not emitted_seen[cls] then
                    emitted_seen[cls] = true
                    table.insert(emitted, cls)
                end
            end
            byteorder.sort(emitted)

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

            local body = {"#import <ModelIO/ModelIO.h>"}
            for _, header in ipairs(header_lines) do
                table.insert(body, "#import <ModelIO/" .. header .. ">")
            end
            if unknown then
                table.insert(body, '#import "RevenantModelIO.h"')
            end
            for _, line in ipairs({
                "#import <objc/runtime.h>", "",
                "// The iOS " .. band .. " band of ModelIO, generated by tools/gen/mio_objects.lua from clang s own AST of",
                "// the " .. sdk_release .. " headers. One band per object: release-split refuses a file whose members first",
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
                if not is_own[cls] then
                    table.insert(body, "// " .. cls .. " arrived at " .. band .. ", so its later members are a CATEGORY: two objects cannot both hold")
                    table.insert(body, "// @implementation " .. cls .. ", and release-split wants one release per object.")
                    table.insert(body, "@implementation " .. cls .. " (Revenant" .. tag .. ")")
                    for _, stub in ipairs(stubs_of(cls, ordered)) do
                        table.insert(body, stub)
                    end
                    table.insert(body, "@end")
                    table.insert(body, "")
                end
            end
            result.files["MDIO" .. tag .. ".m"] = string.gsub(table.concat(body, "\n"), "%s+$", "") .. "\n"
        end
    end
    return result
end

function objects(tree, fw, sdk_release)
    return plan(tree, fw, sdk_release).files
end
