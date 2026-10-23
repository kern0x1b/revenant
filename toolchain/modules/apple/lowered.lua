local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
local json = import("core.base.json")
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..")})
local runtime_guards = import("runtime_guards", {rootdir = os.scriptdir(), anonymous = true})

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

local MODULE_DIR = os.scriptdir()

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
        local class = line:match("^@implementation%s+REVENANT_ALIAS_CLASS%(([%w_]+)%)") or line:match("^@implementation%s+([%w_]+)")
        if class then
            container = class
            found.classes[class] = found.classes[class] or {}
        elseif line:match("^@end") then
            container = nil
        elseif container and not pending and line:match("^[%-%+]%s*%(") then
            pending = line
        elseif pending then
            pending = pending .. " " .. line
        elseif not container and line:match("^[%a_]") and not line:match("^static") and not line:match("^typedef") and not line:match(";%s*$") then
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
        local open, close = text:find("%b()", stop)
        local available = name:find("AVAILABLE", 1, true) and not name:find("UNAVAILABLE", 1, true)
        local since = name:find("DEPRECATED", 1, true) and close and text:sub(stop, close):find("API_TO_BE_DEPRECATED", 1, true)
        if (available or since) and open == stop then
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

local function property_getter(declaration)
    return declaration:match("getter%s*=%s*([%a_][%w_]*)")
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

local function statement_close(text, at)
    local depth = 0
    for position = at, #text do
        local char = text:sub(position, position)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
        elseif char == ";" and depth == 0 then
            return position
        end
    end
    return #text
end

local function declared_name(declaration)
    local macro = declaration:match("^%s*typedef%s+[%u_][%w_]*%s*(%b())")
    if macro then
        local last = macro:sub(2, -2):match("([^,]*)$")
        return last:match("^%s*([%a_][%w_]*)%s*$")
    end
    local bare = (declaration:gsub("%f[%w_][%u_][%w_]*%s*%b()", " "))
    bare = (bare:gsub("%f[%w_][%u%d]+_[%u%d_]*%f[^%w_]", " "))
    return bare:match("([%a_][%w_]*)%s*;%s*$")
end

local NOT_TYPE_NAMES = {typedef = true, void = true, id = true, int = true, char = true, long = true, short = true,
    float = true, double = true, unsigned = true, signed = true, const = true, struct = true, enum = true, union = true,
    bool = true, endif = true, int8_t = true, int16_t = true, int32_t = true, int64_t = true, uint8_t = true,
    uint16_t = true, uint32_t = true, uint64_t = true}

local function typedef_declarations(text)
    local found, position = {}, 1
    while true do
        local start = text:find("%f[%w_]typedef%f[^%w_]", position)
        if not start then
            return found
        end
        local stop = statement_close(text, start)
        local statement = (text:sub(start, stop):gsub("\n%s*#[^\n]*", "\n"))
        local body = (statement:gsub("%b{}", ""))
        local name = body:match("%(%^%s*([%a_][%w_]*)%s*%)") or declared_name(without_availability(body))
        if name and (NOT_TYPE_NAMES[name] or name:find("^__")) then
            name = nil
        end
        local lead = statement_start(text, start, true) or start
        local words = {}
        for word in statement:gmatch("%f[%w_]([%a_][%w_]*)") do
            words["$" .. word] = true
        end
        table.insert(found, {start = lead, stop = stop, name = name, annotated = #availability(text:sub(lead, stop)) > 0, words = words})
        position = stop + 1
    end
end

local function apply_ranges(text, merged)
    local edits = {}
    for _, range in ipairs(merged) do
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

local function constant_end(text, at)
    local depth = 0
    for position = at, #text do
        local char = text:sub(position, position)
        if char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
        elseif depth == 0 and (char == "," or char == ";" or char == "}") then
            return position - 1
        end
    end
    return #text
end

local function lowering_of(text, implemented)
    local words, hits = {}, {}
    local globals, functions = implemented.globals or {}, implemented.functions or {}
    for position, word in text:gmatch("()([%a_][%w_]*)") do
        words[word] = true
        if globals[word] then
            table.insert(hits, {position = position, word = word, kind = "global"})
        end
        if functions[word] then
            table.insert(hits, {position = position, word = word, kind = "function"})
        end
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
            if first and not text:match("^%s*%(", stop + 1) and not (implemented.weak_classes and implemented.weak_classes[class]) then
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
                local declaration = text:sub(mark + 1, declared_end)
                local name = property_name(declaration)
                local getter = property_getter(declaration) or name
                if name and (members["-" .. getter] or members["-" .. name] or members["-set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"]) then
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
                local declaration = text:sub(mark + 1, declared_end)
                local property = property_name(declaration)
                local getter = property_getter(declaration) or property
                if property and (members["-" .. getter] or members["-" .. property]) then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
            position = block_end + 1
        end
    end
    for _, hit in ipairs(hits) do
        if hit.kind == "global" then
            local start, stop = hit.position, hit.position + #hit.word - 1
            local first = statement_start(text, start, true)
            local last = first and statement_end(text, stop)
            local segment = first and text:sub(first, last) or ""
            if first and not segment:find("\n%s*#") and not segment:find("{", 1, true) then
                lower(first, last)
            elseif text:match("^%s*API_AVAILABLE%(", stop + 1) or text:match("^%s*=", stop + 1) then
                local ending = constant_end(text, start)
                if not text:sub(start, ending):find("\n%s*#") then
                    lower(start, ending)
                end
            end
        elseif text:find("^%s*%(", hit.position + #hit.word) and not in_directive(text, hit.position) then
            local start = statement_start(text, hit.position, true)
            local stop = statement_end(text, hit.position)
            local segment = start and text:sub(start, stop) or ""
            if start and not segment:find("\n%s*#") and not segment:find("{", 1, true) then
                lower(start, stop)
            end
        end
    end
    if implemented.types then
        for _, declaration in ipairs(typedef_declarations(text)) do
            if declaration.annotated and declaration.name and implemented.types[declaration.name] then
                for _, piece in ipairs(pieces_of(text, declaration.start, declaration.stop)) do
                    lower(piece[1], piece[2])
                end
            end
        end
    end
    local merged = merged_ranges(ranges)
    local uses = {}
    for _, range in ipairs(merged) do
        for word in text:sub(range.start, range.stop):gmatch("%f[%w_]([%a_][%w_]*)") do
            uses["$" .. word] = true
        end
    end
    return apply_ranges(text, merged), uses
end

function lower_header(text, implemented)
    return (lowering_of(text, implemented))
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

local function usage_index(corpus, keyed, unary)
    local index, sets, count = {}, {}, 0
    for statement in corpus:gmatch("[^;]+") do
        local bracket = statement:find("[", 1, true) or statement:find("@selector", 1, true) or statement:find(".", 1, true)
        local found = nil
        for token in statement:gmatch("[%a_][%w_]*:?") do
            local hit
            if token:sub(-1) == ":" then
                hit = keyed[token]
            else
                hit = bracket and unary[token]
            end
            if hit then
                found = found or {}
                found[token] = true
            end
        end
        if found then
            count = count + 1
            sets[count] = found
            for token in pairs(found) do
                index[token] = index[token] or {}
                table.insert(index[token], count)
            end
        end
    end
    return {index = index, sets = sets}
end

local function usage_of(usage, selector)
    local parts = {}
    if selector:find(":", 1, true) then
        for part in selector:gmatch("[%w_]+:") do
            table.insert(parts, part)
        end
    else
        parts[1] = selector
    end
    local rarest = nil
    for _, part in ipairs(parts) do
        local ids = usage.index[part]
        if not ids then
            return false
        end
        if not rarest or #ids < #usage.index[rarest] then
            rarest = part
        end
    end
    for _, id in ipairs(usage.index[rarest]) do
        local set = usage.sets[id]
        local all = true
        for _, part in ipairs(parts) do
            if not set[part] then
                all = false
                break
            end
        end
        if all then
            return true
        end
    end
    return false
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
            local position = text:find("@protocol", 1, true)
            while position do
                local name = text:match("^@protocol%s+([%w_]+)[%s<]", position)
                if name and names[name] and not blocks[name] then
                    blocks[name] = text:sub(position, text:find("@end", position, true) or #text)
                end
                position = text:find("@protocol", position + 1, true)
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
    local methods, keyed, unary = {}, {}, {}
    for name in pairs(candidates) do
        methods[name] = blocks[name] and method_keys(blocks[name]) or {}
        for _, method in ipairs(methods[name]) do
            if method.selector:find(":", 1, true) then
                for part in method.selector:gmatch("[%w_]+:") do
                    keyed[part] = true
                end
            else
                unary[method.selector] = true
            end
        end
    end
    local usage = usage_index(corpus, keyed, unary)
    local implemented_any = {}
    for _, found in pairs(folders) do
        for _, class_members in pairs(found.classes) do
            for key in pairs(class_members) do
                implemented_any[key:sub(2)] = true
            end
        end
    end
    local status = {backed = {}, uncalled = {}, members = {}}
    for name in pairs(candidates) do
        local members, used = {}, false
        for _, method in ipairs(methods[name]) do
            if implemented_any[method.selector] or usage_of(usage, method.selector) then
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

function members_file()
    return path.absolute(path.join(MODULE_DIR, "..", "..", "..", "frameworks", "Backports", "tools", "lowered-members.txt"))
end

local MEMBERS_HEADER = table.concat({
    "# The lowered API set of frameworks/Backports/src: the members, protocols and signature types the lowering reads.",
    "# Generated by frameworks/Backports/tools/lowered_members.lua; do not edit. The test",
    "# frameworks/Backports/tests/lowered_members_test.lua fails when this file no longer matches the sources.",
}, "\n") .. "\n"

function serialize(set, header)
    local lines = {}
    for class, members in pairs(set.classes) do
        table.insert(lines, "class " .. class)
        for key in pairs(members) do
            table.insert(lines, "member " .. class .. " " .. key)
        end
    end
    for name in pairs(set.functions) do
        table.insert(lines, "function " .. name)
    end
    for name in pairs(set.globals) do
        table.insert(lines, "global " .. name)
    end
    for name in pairs(set.protocols) do
        table.insert(lines, "protocol " .. name)
        for key in pairs((set.protocol_members or {})[name] or {}) do
            table.insert(lines, "protocol_member " .. name .. " " .. key)
        end
    end
    for name in pairs(set.types or {}) do
        table.insert(lines, "type " .. name)
    end
    byteorder.sort(lines)
    return (header or MEMBERS_HEADER) .. table.concat(lines, "\n") .. "\n"
end

function parse(text)
    local set = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for line in text:gmatch("[^\n]+") do
        if not line:find("^#") then
            local kind, first, second = line:match("^(%S+) (%S+) ?(%S*)$")
            if kind == "class" then
                set.classes[first] = set.classes[first] or {}
            elseif kind == "member" then
                set.classes[first] = set.classes[first] or {}
                set.classes[first][second] = true
            elseif kind == "function" then
                set.functions[first] = true
            elseif kind == "global" then
                set.globals[first] = true
            elseif kind == "protocol" then
                set.protocols[first] = true
                set.protocol_members[first] = set.protocol_members[first] or {}
            elseif kind == "protocol_member" then
                set.protocol_members[first] = set.protocol_members[first] or {}
                set.protocol_members[first][second] = true
            elseif kind == "type" then
                set.types[first] = true
            else
                raise("the lowered member list has an unknown line: %s", line)
            end
        end
    end
    return set
end

function read_members(file)
    return parse(io.readfile(file or members_file()))
end

local function frameworks_in(folder, found)
    for _, framework in ipairs(os.dirs(path.join(folder, "*.framework"))) do
        table.insert(found, framework)
        frameworks_in(path.join(framework, "Frameworks"), found)
    end
    return found
end

local function framework_headers(sdk)
    local files = {}
    for _, framework in ipairs(frameworks_in(path.join(sdk, "System", "Library", "Frameworks"), {})) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            table.insert(files, file)
        end
    end
    return files
end

local function member_headers(sdk)
    local changed = {}
    for _, entry in ipairs(MEMBERS) do
        local header = entry.header
        local file = path.join(directory_of(sdk, header), header.file)
        changed[file] = replaced(changed[file] or io.readfile(file), header, "the iPhoneOS SDK at " .. sdk .. " in " .. header.file, entry.member)
    end
    return changed
end

local function lowered_types(sdk, set)
    local changed = member_headers(sdk)
    local declared, queue, queued = {}, {}, {}
    local function enqueue(name)
        if not queued["$" .. name] then
            queued["$" .. name] = true
            table.insert(queue, name)
        end
    end
    for _, file in ipairs(framework_headers(sdk)) do
        local text = changed[file] or io.readfile(file)
        local _, used = lowering_of(text, set)
        for key in pairs(used) do
            enqueue(key:sub(2))
        end
        for _, declaration in ipairs(typedef_declarations(text)) do
            if declaration.name then
                declared[declaration.name] = declared[declaration.name] or {}
                table.insert(declared[declaration.name], declaration)
            end
        end
    end
    local types, visited = {}, {}
    while #queue > 0 do
        local name = table.remove(queue)
        if declared[name] and not visited[name] then
            visited[name] = true
            for _, declaration in ipairs(declared[name]) do
                if declaration.annotated then
                    types[name] = true
                end
                for key in pairs(declaration.words) do
                    enqueue(key:sub(2))
                end
            end
        end
    end
    return types
end

local function identifiers_in(src)
    local used = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                for word in io.readfile(file):gmatch("[%a_][%w_]*") do
                    used[word] = true
                end
            end
        end
    end
    return used
end

function members_of(src, sdk)
    local folders = implemented_in(src)
    local set = union_of(folders)
    local used = identifiers_in(src)
    for name in pairs(later_constants(sdk)) do
        if used[name] then
            set.globals[name] = true
        end
    end
    local status = protocol_status(src, sdk, folders)
    set.protocols = status.backed
    set.protocol_members = {}
    for name in pairs(status.backed) do
        set.protocol_members[name] = status.members[name]
    end
    set.types = lowered_types(sdk, merge_sets(set, read_device_members()))
    return set
end

local DEVICE_RELEASE = "6.0"

local DEVICE_HEADER = table.concat({
    "# The members the iOS 6.0 release implements and the SDK annotates later, from that release's dyld cache inventory.",
    "# Generated by frameworks/Backports/tools/device_members.lua; do not edit. The test",
    "# frameworks/Backports/tests/device_members_test.lua checks this file against the inventory where the inventory is present.",
}, "\n") .. "\n"

function inventory_file()
    return path.join(workspace.home(), "dyld", DEVICE_RELEASE, "classes_armv7.json")
end

function device_members_file()
    return path.absolute(path.join(MODULE_DIR, "..", "..", "..", "frameworks", "Backports", "tools", "device-members.txt"))
end

function device_text(set)
    return serialize(set, DEVICE_HEADER)
end

function read_device_members(file)
    return parse(io.readfile(file or device_members_file()))
end

function merge_sets(a, b)
    local out = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for _, set in ipairs({a, b}) do
        for class, members in pairs(set.classes or {}) do
            out.classes[class] = out.classes[class] or {}
            for key in pairs(members) do
                out.classes[class][key] = true
            end
        end
        for name in pairs(set.functions or {}) do
            out.functions[name] = true
        end
        for name in pairs(set.globals or {}) do
            out.globals[name] = true
        end
        for name in pairs(set.protocols or {}) do
            out.protocols[name] = true
        end
        for name, members in pairs(set.protocol_members or {}) do
            out.protocol_members[name] = out.protocol_members[name] or {}
            for key in pairs(members) do
                out.protocol_members[name][key] = true
            end
        end
        for name in pairs(set.types or {}) do
            out.types[name] = true
        end
    end
    return out
end

function read_all_members()
    local set = merge_sets(read_members(), read_device_members())
    set.weak_classes = {}
    for _, rows in pairs(runtime_guards.guards()) do
        for symbol in pairs(rows) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                set.weak_classes[class] = true
            elseif not symbol:find("^_OBJC_") then
                set.globals[symbol:sub(2)] = nil
                set.functions[symbol:sub(2)] = nil
            end
        end
    end
    return set
end

local function ios_later(text)
    local major, minor = nil, nil
    for found_major, found_minor in text:gmatch("%f[%w_]ios%(%s*(%d+)%.?(%d*)") do
        major, minor = tonumber(found_major), tonumber(found_minor) or 0
    end
    return major ~= nil and (major > 6 or (major == 6 and minor > 0))
end

function later_constants(sdk)
    local found = {}
    for _, file in ipairs(framework_headers(sdk)) do
        for line in io.readfile(file):gmatch("[^\n]*") do
            if line:find("API_AVAILABLE", 1, true) and ios_later(line) then
                local name = line:match("%*%s*const%s+([%a_][%w_]*)") or line:match("^%s*([%a_][%w_]*)%s+API_AVAILABLE")
                if name and line:find("=", 1, true) and not line:find("const", 1, true) then
                    found[name] = true
                end
            end
        end
    end
    return found
end

local function released_keys(released, class, cache)
    if cache[class] == nil then
        local info = released[class]
        if info then
            local keys = {}
            for _, selector in ipairs(info.instance or {}) do
                keys["-" .. selector] = true
            end
            for _, selector in ipairs(info["class"] or {}) do
                keys["+" .. selector] = true
            end
            cache[class] = keys
        else
            cache[class] = false
        end
    end
    return cache[class]
end

function device_members_in(text, released, cache)
    local set = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for position, class in text:gmatch("()@interface%s+([%w_]+)[%s:<]") do
        local keys = released_keys(released, class, cache)
        if keys then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            local block_end = text:find("@end", stop, true) or #text
            local lead = statement_start(text, position, true) or position
            if ios_later(text:sub(lead, text:find("\n", stop, true) or #text)) then
                set.classes[class] = set.classes[class] or {}
            end
            local at = stop
            while true do
                local mark = text:find("\n[%-%+]%s*%(", at)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local selector = selector_of(declaration)
                if selector and ios_later(declaration) then
                    local key = declaration:match("^([%-%+])") .. selector
                    if keys[key] then
                        set.classes[class] = set.classes[class] or {}
                        set.classes[class][key] = true
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
                local declaration = text:sub(mark + 1, declared_end)
                local name = property_name(declaration)
                if name and ios_later(declaration) then
                    local setter = "-set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"
                    local getter = property_getter(declaration) or name
                    for _, key in ipairs({"-" .. getter, "-" .. name, setter}) do
                        if keys[key] then
                            set.classes[class] = set.classes[class] or {}
                            set.classes[class][key] = true
                        end
                    end
                end
                at = mark + 1
            end
        end
    end
    return set
end

function device_members_of(sdk, inventory)
    local released = json.decode(io.readfile(inventory)).classes
    local cache = {}
    local merged = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for _, file in ipairs(framework_headers(sdk)) do
        local found = device_members_in(io.readfile(file), released, cache)
        for class, members in pairs(found.classes) do
            merged.classes[class] = merged.classes[class] or {}
            for key in pairs(members) do
                merged.classes[class][key] = true
            end
        end
    end
    return merged
end

local function input_digest(sdk, text)
    return hash.strhash128(table.concat({sdk, io.readfile(path.join(MODULE_DIR, "lowered.lua")), text}, "\0"))
end

function overlay(sdk, out, set)
    local text = set and serialize(set) or (io.readfile(members_file()) .. io.readfile(device_members_file()))
    local key = table.concat({sdk, out, hash.strhash128(text)}, "|")
    if built[key] then
        return built[key]
    end
    os.mkdir(out)
    local stamp = path.join(out, "input.digest")
    local digest = input_digest(sdk, text)
    local vfs = path.join(out, "vfs.yaml")
    if not (os.isfile(vfs) and os.isfile(stamp) and io.readfile(stamp) == digest) then
        vfs = build_overlay(sdk, out, set or read_all_members())
        io.writefile(stamp, digest)
    end
    built[key] = vfs
    return vfs
end

function build_overlay(sdk, out, set)
    local changed = member_headers(sdk)
    for _, file in ipairs(framework_headers(sdk)) do
        local text = changed[file] or io.readfile(file)
        local lowered = lowering_of(text, set)
        if lowered ~= text then
            changed[file] = lowered
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
        byteorder.sort(roots[dir])
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

local function swift_base(selector)
    local head = selector:match("^([%a_][%w_]*)")
    if not head then
        return nil
    end
    head = head:gsub("^stringBy(%u)", "%1")
    head = head:gsub("With%u.*$", "")
    head = head:gsub("For%u.*$", "")
    if head == "" then
        return nil
    end
    return head:sub(1, 1):lower() .. head:sub(2)
end

local function swift_init(key)
    local keyword = key:sub(2):match("^initWith([%w_]+):")
    if not keyword then
        return nil
    end
    local label, kind = keyword:match("^(.-)(String)$")
    if not label then
        label, kind = keyword:match("^(.-)(Data)$")
    end
    if not label or label == "" then
        return nil
    end
    return "init " .. label:sub(1, 1):lower() .. label:sub(2) .. ":" .. kind
end

function swift_names(set)
    local names = {}
    for class, members in pairs(set.classes) do
        local weak = set.weak_classes and set.weak_classes[class]
        local scope = class:startswith("NS") and class:sub(3) or class
        names["scoped " .. scope] = true
        for key in pairs(weak and {} or members) do
            local base = not key:sub(2):find("^init") and swift_base(key:sub(2))
            if base then
                names[base] = true
                names["scope " .. scope .. " " .. base] = true
            end
            local init = swift_init(key)
            if init then
                names[init] = true
                names["scope " .. scope .. " " .. init] = true
            end
        end
        if class:startswith("NS") and not weak then
            names["type " .. class] = true
            names["type " .. class:sub(3)] = true
        end
    end
    return names
end

local function type_opened(line)
    return line:match("^public%s+struct%s+([%a_][%w_]*)") or line:match("^public%s+class%s+([%a_][%w_]*)") or
           line:match("^public%s+enum%s+([%a_][%w_]*)") or line:match("^extension%s+([%a_][%w_]*)") or
           line:match("^struct%s+([%a_][%w_]*)") or line:match("^class%s+([%a_][%w_]*)") or
           line:match("^enum%s+([%a_][%w_]*)")
end

local function implemented_scope(scope, names)
    return scope ~= nil and names["type " .. scope] == true
end

local function lowered_by(line, names, types, scope)
    local name = line:match("public%s+var%s+([%a_][%w_]*)") or line:match("public%s+func%s+([%a_][%w_]*)")
    if name then
        if scope and names["scoped " .. scope] then
            return names["scope " .. scope .. " " .. name] or false
        end
        return names[name]
    end
    local label, rest = line:match("public%s+init%??%(%s*([%a_][%w_]*)%s+[%a_][%w_]*%s*:%s*(.*)$")
    if label then
        local kind = rest:match("^__shared%s+([%a_][%w_]*)") or rest:match("^([%a_][%w_]*)") or ""
        return names["init " .. label .. ":" .. kind]
    end
    local target = line:match("public%s+typealias%s+[%a_][%w_]*%s*=%s*([%a_][%w_%.]*)")
    if target then
        return types[(target:gsub("%.", ""))]
    end
    local declared = line:match("^%s*public%s+struct%s+([%a_][%w_]*)") or line:match("^%s*public%s+class%s+([%a_][%w_]*)") or
                     line:match("^%s*public%s+enum%s+([%a_][%w_]*)")
    if declared then
        return names["type " .. declared] or false
    end
    if line:match("^%s*public%s+static%s+func%s+[=<>!+%-*/&|^%%~]") then
        return implemented_scope(scope, names)
    end
    if not line:find("public", 1, true) and (line:match("^%s+[%a ]*func%s+[%a_]") or line:match("^%s+[%a ]*var%s+[%a_]")) then
        return implemented_scope(scope, names)
    end
    if line:match("^private%s+[%a ]*func%s") or line:match("^fileprivate%s+[%a ]*func%s") or line:match("^internal%s+[%a ]*func%s") then
        return true
    end
    return false
end

local function operator_extension(lines, at, names)
    local name = lines[at]:match("^extension%s+([%a_][%w_]*)%s*{")
    if not name or not names["type " .. name] then
        return false
    end
    for index = at + 1, #lines do
        if lines[index]:match("^}") then
            return false
        end
        if lines[index]:match("^%s*public%s+static%s+func%s+[=<>!+%-*/&|^%%~]") then
            return true
        end
    end
    return false
end

local function guarded_lines(file)
    local lines = {}
    local name = path.filename(file)
    for _, rows in pairs(runtime_guards.guards()) do
        for _, citation in pairs(rows) do
            local start = citation:find("Foundation/" .. name .. ":", 1, true)
            if start then
                for line in citation:sub(start):gmatch(":(%d+)") do
                    lines[tonumber(line)] = true
                end
            end
        end
    end
    return lines
end

function lower_swift_text(text, names, types, keep)
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    types = types or {}
    keep = keep or {}
    local kept, pending, scope = {}, nil, nil
    for index, line in ipairs(lines) do
        local major = line:match("^%s*@available%(.*iOS%s+(%d+)")
        if major and tonumber(major) >= 7 and not keep[index] then
            pending = #kept + 1
        elseif pending and (lowered_by(line, names, types, scope) or operator_extension(lines, index, names)) then
            kept[pending] = false
            pending = nil
        elseif not (line:match("^%s*@available%(") or line:match("^%s*///") or line:match("^%s*//") or line:match("^%s*@[%w_]+") or line:match("^%s*$")) then
            pending = nil
        end
        table.insert(kept, line)
        if line:match("^}") then
            scope = nil
        end
        scope = type_opened(line) or scope
    end
    local buffer = {}
    for _, line in ipairs(kept) do
        if line then
            table.insert(buffer, line .. "\n")
        end
    end
    table.insert(buffer, text:match("([^\n]*)$"))
    return table.concat(buffer)
end

function swift_overlays(root, set)
    for _, entry in ipairs(MEMBERS) do
        local lowering = entry.overlay
        if lowering then
            local file = path.join(root, table.unpack(lowering.file))
            io.writefile(file, replaced(io.readfile(file), lowering, "the Swift overlay " .. file, entry.member))
        end
    end
    set = set or read_all_members()
    local names, types = swift_names(set), set.types or {}
    for _, file in ipairs(os.files(path.join(root, "stdlib", "public", "Darwin", "Foundation", "*.swift"))) do
        local text = io.readfile(file)
        local lowered = lower_swift_text(text, names, types, guarded_lines(file))
        if lowered ~= text then
            io.writefile(file, lowered)
        end
    end
end
