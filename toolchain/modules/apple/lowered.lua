local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local MEMBERS = {
    {
        member = "os_unfair_lock",
        header = {
            name = "os",
            directory = {"usr", "include", "os"},
            file = "lock.h",
            find = "#define OS_UNFAIR_LOCK_AVAILABILITY \\\n\t\t__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))",
            replace = "#define OS_UNFAIR_LOCK_AVAILABILITY",
        },
    },
    {
        member = "NSJSONWritingSortedKeys",
        header = {
            name = "Foundation",
            directory = {"System", "Library", "Frameworks", "Foundation.framework", "Headers"},
            file = "NSJSONSerialization.h",
            find = "NSJSONWritingSortedKeys API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0)) = (1UL << 1),",
            replace = "NSJSONWritingSortedKeys = (1UL << 1),",
        },
        overlay = {
            file = {"stdlib", "public", "Darwin", "Foundation", "JSONEncoder.swift"},
            find = "        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)\n        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
            replace = "        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
        },
    },
}

local BOUNDARIES = {";", "*/", "}", "@end"}
local WINDOW = 8192

local function directory_of(sdk, header)
    local parts = {sdk}
    table.join2(parts, header.directory)
    return path.join(table.unpack(parts))
end

local function replaced(text, lowering, where, member)
    local start, stop = text:find(lowering.find, 1, true)
    if not start then
        raise("%s declares %s without the availability the backports lower", where, member)
    end
    return text:sub(1, start - 1) .. lowering.replace .. text:sub(stop + 1)
end

local function write_if_changed(file, text)
    if os.isfile(file) and io.readfile(file) == text then
        return
    end
    io.writefile(file, text)
end

local function selector_of(declaration)
    local text = declaration:gsub("%b()", "")
    local parts = {}
    for word in text:gmatch("([%w_]+):") do
        table.insert(parts, word .. ":")
    end
    if #parts > 0 then
        return table.concat(parts)
    end
    return text:match("^%s*[%-%+]%s*([%a_][%w_]*)")
end

local function scan_source(file, found)
    local container, pending = nil, nil
    for line in io.readfile(file):gmatch("[^\n]*") do
        local class = line:match("^@implementation%s+([%w_]+)")
        if class then
            container = class
            found.classes[class] = found.classes[class] or {}
        elseif line:match("^@end") then
            container = nil
        elseif container and not pending and line:match("^[%-%+]%s*%(") then
            pending = line
        elseif pending then
            pending = pending .. " " .. line
        elseif not container and line:match("^[%a_]") and not line:match("^static") and not line:match(";%s*$") then
            local name = line:match("^[%a_][^=;(]-([%a_][%w_]*)%s*%(")
            if name then
                found.functions[name] = true
            end
        end
        if pending and (pending:find("{", 1, true) or pending:find(";", 1, true)) then
            local selector = selector_of(pending)
            if container and selector then
                found.classes[container][pending:match("^%s*([%-%+])") .. selector] = true
            end
            pending = nil
        end
    end
end

local function implemented_in(src)
    local folders = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        local found = {classes = {}, functions = {}}
        for _, pattern in ipairs({"**.m", "**.mm", "**.c"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                scan_source(file, found)
            end
        end
        folders[path.filename(folder)] = found
    end
    return folders
end

local function availability(text)
    local found, position = {}, 1
    while true do
        local start, stop, name = text:find("([%u_][%u%d_]*)%s*%(", position)
        if not start then
            return found
        end
        if name:find("AVAILABLE", 1, true) and not name:find("UNAVAILABLE", 1, true) then
            local _, close = text:find("%b()", stop)
            table.insert(found, {start = start, stop = close})
            position = close + 1
        else
            position = stop + 1
        end
    end
end

local function without_availability(text)
    local pieces, position = {}, 1
    for _, macro in ipairs(availability(text)) do
        table.insert(pieces, text:sub(position, macro.start - 1))
        position = macro.stop + 1
    end
    table.insert(pieces, text:sub(position))
    return table.concat(pieces)
end

local function directive_end(text, at)
    local stop = text:find("\n", at, true) or #text
    while stop < #text and text:sub(stop - 1, stop - 1) == "\\" do
        stop = text:find("\n", stop + 1, true) or #text
    end
    return stop
end

local function statement_start(text, at)
    local low = math.max(1, at - WINDOW)
    local window = text:sub(low, at - 1)
    local best = nil
    for _, boundary in ipairs(BOUNDARIES) do
        local i = 1
        while true do
            local _, stop = window:find(boundary, i, true)
            if not stop then
                break
            end
            best = math.max(best or 0, low + stop)
            i = stop + 1
        end
    end
    local directive, i = nil, 1
    while true do
        local found = window:find("\n#", i, true)
        if not found then
            break
        end
        directive = found
        i = found + 1
    end
    if directive then
        best = math.max(best or 0, directive_end(text, low + directive) + 1)
    end
    if best then
        return best
    end
    if low > 1 then
        raise("no statement boundary within %d bytes before offset %d of a header", WINDOW, at)
    end
    return 1
end

local function in_directive(text, at)
    local low = math.max(1, at - WINDOW)
    local window = text:sub(low, at - 1)
    local line = window:match(".*\n()")
    local start = line and window:sub(line) or window
    return start:match("^%s*#") ~= nil
end

local function pieces_of(text, start, stop)
    local pieces, from, at = {}, start, start
    while true do
        local mark = text:find("\n%s*#", at)
        if not mark or mark >= stop then
            break
        end
        table.insert(pieces, {from, mark - 1})
        from = directive_end(text, mark + 1) + 1
        at = from
    end
    table.insert(pieces, {from, stop})
    return pieces
end

local function statement_end(text, at)
    local _, stop = text:find(";", at, true)
    return stop or text:find("\n", at, true) or #text
end

local function merged_ranges(ranges)
    table.sort(ranges, function (a, b)
        if a.start ~= b.start then
            return a.start < b.start
        end
        return a.stop < b.stop
    end)
    local merged = {}
    for _, range in ipairs(ranges) do
        local last = merged[#merged]
        if last and range.start <= last.stop then
            last.stop = math.max(last.stop, range.stop)
        else
            table.insert(merged, {start = range.start, stop = range.stop})
        end
    end
    return merged
end

local function property_name(declaration)
    local text = declaration:gsub("%b()", "")
    local name = nil
    for word in text:gmatch("[%a_][%w_]*") do
        if word ~= "property" and not word:match("^[%u%d_]+$") then
            name = word
        end
    end
    return name
end

local function lowering_of(text, implemented)
    local ranges = {}
    local function lower(start, stop)
        if stop >= start then
            table.insert(ranges, {start = start, stop = stop})
        end
    end
    for position, class in text:gmatch("()@interface%s+([%w_]+)") do
        local members = implemented.classes[class]
        if members then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            if not text:match("^%s*%(", stop + 1) then
                lower(statement_start(text, position), text:find("\n", stop, true) or #text)
            end
            local block_end = text:find("@end", stop, true) or #text
            local at = stop
            while true do
                local mark = text:find("\n[%-%+]%s*%(", at)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local selector = selector_of(declaration)
                if selector and members[declaration:match("^([%-%+])") .. selector] then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
        end
    end
    for position, class in text:gmatch("()@interface%s+([%w_]+)") do
        local members = implemented.classes[class]
        if members then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            local block_end = text:find("@end", stop, true) or #text
            local at = stop
            while true do
                local mark = text:find("\n@property", at, true)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local name = property_name(text:sub(mark + 1, declared_end))
                if name and (members["-" .. name] or members["-set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"]) then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
        end
    end
    for position, word in text:gmatch("()([%a_][%w_]*)%s*%(") do
        if implemented.functions[word] and not in_directive(text, position) then
            local start, stop = statement_start(text, position), statement_end(text, position)
            local segment = text:sub(start, stop)
            if not segment:find("\n%s*#") and not segment:find("{", 1, true) then
                lower(start, stop)
            end
        end
    end
    local edits = {}
    for _, range in ipairs(merged_ranges(ranges)) do
        local segment = text:sub(range.start, range.stop)
        local excerpt = (segment:sub(1, 160):gsub("\n", " "))
        if segment:find("\n%s*#") then
            raise("a backported declaration spans a preprocessor line: %s", excerpt)
        end
        local lowered = without_availability(segment)
        if #availability(lowered) > 0 then
            raise("an availability macro of a backported declaration cannot be lowered: %s", excerpt)
        end
        if lowered ~= segment then
            table.insert(edits, {start = range.start, stop = range.stop, text = lowered})
        end
    end
    for index = #edits, 1, -1 do
        local edit = edits[index]
        text = text:sub(1, edit.start - 1) .. edit.text .. text:sub(edit.stop + 1)
    end
    return text
end

function lower_header(text, implemented)
    return lowering_of(text, implemented)
end

local built = {}

function overlay(sdk, out, src)
    src = src or path.join(os.projectdir(), "frameworks", "Backports", "src")
    local key = table.concat({sdk, out, src}, "|")
    if not built[key] then
        built[key] = build_overlay(sdk, out, src)
    end
    return built[key]
end

function build_overlay(sdk, out, src)
    local changed = {}
    for _, entry in ipairs(MEMBERS) do
        local header = entry.header
        local file = path.join(directory_of(sdk, header), header.file)
        changed[file] = replaced(changed[file] or io.readfile(file), header, "the iPhoneOS SDK at " .. sdk .. " in " .. header.file, entry.member)
    end
    for folder, implemented in pairs(implemented_in(src)) do
        local dir = path.join(sdk, "System", "Library", "Frameworks", folder .. ".framework", "Headers")
        if os.isdir(dir) then
            for _, file in ipairs(os.files(path.join(dir, "*.h"))) do
                local text = changed[file] or io.readfile(file)
                local lowered = lowering_of(text, implemented)
                if lowered ~= text then
                    changed[file] = lowered
                end
            end
        end
    end
    local roots = {}
    for file, text in pairs(changed) do
        local copy = path.join(out, path.relative(file, sdk))
        os.mkdir(path.directory(copy))
        write_if_changed(copy, text)
        local dir = path.directory(file)
        roots[dir] = roots[dir] or {}
        table.insert(roots[dir], string.format([[{"name": "%s", "type": "file", "external-contents": "%s"}]], path.filename(file), copy))
    end
    local dirs = {}
    for dir in pairs(roots) do
        table.insert(dirs, dir)
    end
    byteorder.sort(dirs)
    local entries = {}
    for _, dir in ipairs(dirs) do
        table.insert(entries, string.format([[    {"name": "%s", "type": "directory", "contents": [%s]}]], dir, table.concat(roots[dir], ", ")))
    end
    local vfs = path.join(out, "vfs.yaml")
    write_if_changed(vfs, string.format([[
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
%s
  ]
}
]], table.concat(entries, ",\n")))
    return vfs
end

function swift_overlays(root)
    for _, entry in ipairs(MEMBERS) do
        local lowering = entry.overlay
        if lowering then
            local file = path.join(root, table.unpack(lowering.file))
            io.writefile(file, replaced(io.readfile(file), lowering, "the Swift overlay " .. file, entry.member))
        end
    end
end
