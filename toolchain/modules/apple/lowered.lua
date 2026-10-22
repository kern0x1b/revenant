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
        elseif not container and line:match("const%s+[%a_][%w_]*%s*=") then
            found.globals[line:match("const%s+([%a_][%w_]*)%s*=")] = true
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

local function scan_adoption(file, found)
    for line in io.readfile(file):gmatch("[^\n]*") do
        local list = line:match("^@interface%s+[%w_]+[^<]*<([^>]+)>")
        if list then
            for name in list:gmatch("[%w_]+") do
                found.protocols[name] = true
            end
        end
    end
end

local function implemented_in(src)
    local folders = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        local found = {classes = {}, functions = {}, globals = {}, protocols = {}}
        for _, pattern in ipairs({"**.m", "**.mm", "**.c"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                scan_source(file, found)
            end
        end
        for _, pattern in ipairs({"**.m", "**.mm", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                scan_adoption(file, found)
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

local function statement_start(text, at, quiet)
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
        if quiet then
            return nil
        end
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
    local words = {}
    for word in text:gmatch("[%a_][%w_]*") do
        words[word] = true
    end
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
            local first = statement_start(text, position, true)
            if first and not text:match("^%s*%(", stop + 1) then
                lower(first, text:find("\n", stop, true) or #text)
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
    for name in pairs(implemented.protocols or {}) do
        local position = words[name] and 1 or #text + 1
        while true do
            local start, stop = text:find("@protocol%s+" .. name .. "[%s<]", position)
            if not start then
                break
            end
            local block_end = text:find("@end", stop, true) or #text
            local first = statement_start(text, start, true)
            if first then
                lower(first, text:find("\n", stop, true) or #text)
            end
            local members = (implemented.protocol_members or {})[name] or {}
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
            at = stop
            while true do
                local mark = text:find("\n@property", at, true)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local property = property_name(text:sub(mark + 1, declared_end))
                if property and members["-" .. property] then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
            position = block_end + 1
        end
    end
    for name in pairs(implemented.globals or {}) do
        local position = words[name] and 1 or #text + 1
        while true do
            local start, stop = text:find("%f[%w_]" .. name .. "%f[^%w_]", position)
            if not start then
                break
            end
            local first = statement_start(text, start, true)
            if first then
                local last = statement_end(text, stop)
                local segment = text:sub(first, last)
                if not segment:find("\n%s*#") and not segment:find("{", 1, true) then
                    lower(first, last)
                end
            end
            position = stop + 1
        end
    end
    for position, word in text:gmatch("()([%a_][%w_]*)%s*%(") do
        if implemented.functions[word] and not in_directive(text, position) then
            local start = statement_start(text, position, true)
            local stop = statement_end(text, position)
            local segment = start and text:sub(start, stop) or ""
            if start and not segment:find("\n%s*#") and not segment:find("{", 1, true) then
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

local function union_of(folders)
    local union = {classes = {}, functions = {}, globals = {}, protocols = {}}
    for _, found in pairs(folders) do
        for name in pairs(found.protocols) do
            union.protocols[name] = true
        end
        for class, members in pairs(found.classes) do
            union.classes[class] = union.classes[class] or {}
            for member in pairs(members) do
                union.classes[class][member] = true
            end
        end
        for name in pairs(found.functions) do
            union.functions[name] = true
        end
        for name in pairs(found.globals) do
            union.globals[name] = true
        end
    end
    return union
end

local corpora = {}

local function corpus_of(src)
    if not corpora[src] then
        local parts = {}
        for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
            for _, pattern in ipairs({"**.m", "**.mm", "**.h", "**.c"}) do
                for _, file in ipairs(os.files(path.join(folder, pattern))) do
                    table.insert(parts, io.readfile(file))
                end
            end
        end
        corpora[src] = table.concat(parts, "\n")
    end
    return corpora[src]
end

local function used_in(corpus, selector)
    if selector:find(":", 1, true) then
        local parts = {}
        for part in selector:gmatch("[%w_]+:") do
            table.insert(parts, part)
        end
        if #parts == 0 or not corpus:find(parts[1], 1, true) then
            return false
        end
        return corpus:find(table.concat(parts, "[^;]-"), 1) ~= nil
    end
    return corpus:find("%f[%w_]" .. selector .. "%f[^%w_]") ~= nil
end

local function method_keys(block)
    local keys, at = {}, 1
    while true do
        local mark = block:find("\n[%-%+]%s*%(", at)
        if not mark then
            return keys
        end
        local _, stop = block:find(";", mark + 1, true)
        local declaration = block:sub(mark + 1, stop or #block)
        local selector = selector_of(declaration)
        if selector then
            table.insert(keys, {key = declaration:match("^([%-%+])") .. selector, selector = selector})
        end
        at = mark + 1
    end
end

local function protocol_blocks(sdk, names)
    local blocks = {}
    for _, framework in ipairs(os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            local text = io.readfile(file)
            for position, name in text:gmatch("()@protocol%s+([%w_]+)[%s<]") do
                if names[name] and not blocks[name] then
                    blocks[name] = text:sub(position, text:find("@end", position, true) or #text)
                end
            end
        end
    end
    return blocks
end

function protocol_status(src, sdk, folders)
    folders = folders or implemented_in(src)
    local adopted = {}
    for _, found in pairs(folders) do
        for name in pairs(found.protocols) do
            adopted[name] = true
        end
    end
    local corpus = corpus_of(src)
    local typed = {}
    for name in corpus:gmatch("id%s*<%s*([%w_]+)%s*>") do
        typed[name] = true
    end
    local defined = {}
    for name in corpus:gmatch("\n@protocol%s+([%w_]+)[%s<]") do
        defined[name] = true
    end
    local candidates = {}
    for name in pairs(adopted) do
        candidates[name] = true
    end
    for name in pairs(typed) do
        candidates[name] = true
    end
    for name in pairs(defined) do
        candidates[name] = true
    end
    local blocks = protocol_blocks(sdk, candidates)
    local status = {backed = {}, uncalled = {}, members = {}}
    for name in pairs(candidates) do
        local members, used = {}, false
        for _, method in ipairs(blocks[name] and method_keys(blocks[name]) or {}) do
            if used_in(corpus, method.selector) then
                members[method.key] = true
                used = true
            end
        end
        status.members[name] = members
        if adopted[name] or defined[name] or used then
            status.backed[name] = true
        elseif typed[name] and blocks[name] then
            status.uncalled[name] = true
        end
    end
    return status
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
    local folders = implemented_in(src)
    local union = union_of(folders)
    local status = protocol_status(src, sdk, folders)
    union.protocols = status.backed
    union.protocol_members = status.members
    for _, framework in ipairs(os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            local text = changed[file] or io.readfile(file)
            local lowered = lowering_of(text, union)
            if lowered ~= text then
                changed[file] = lowered
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
