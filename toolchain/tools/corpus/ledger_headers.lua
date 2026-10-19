import("core.base.bytes")

local HERE = os.scriptdir()
local byteorder = import("byteorder", {rootdir = path.join(HERE, "..", "..", "modules"), anonymous = true})
local surface_walk = import("surface_walk", {rootdir = HERE, anonymous = true})
local ledger_json = import("ledger_json", {rootdir = HERE, anonymous = true})
local ledger_inputs = import("ledger_inputs", {rootdir = HERE, anonymous = true})
local ledger_classify = import("ledger_classify", {rootdir = HERE, anonymous = true})

local TARGET = ledger_classify.target()
local INCLUDE_TOP = "include"
local STORAGE_KINDS = {VarDecl = true, FunctionDecl = true}
local TYPEDEF_KIND = "TypedefDecl"
local INTERNAL_LINKAGE = "internal-linkage"
local EXTERNAL_LINKAGE = "external-linkage"
local NAMED_KINDS = {constant = true, ["function"] = true, enum = true, protocol = true, struct = true}
local TOOL_FILES = {"ledger_headers.lua", "ledger_json.lua", "surface_walk.lua"}

local function partition(text)
    local at = text:find(" ", 1, true)
    if not at then
        return text, ""
    end
    return text:sub(1, at - 1), text:sub(at + 1)
end

local function quoted(text)
    local found = {}
    for token in text:gmatch("'([^']*)'") do
        table.insert(found, token)
    end
    return found
end

local function last_word_before_quote(text)
    local before = text:match("^[^']*")
    local last
    for word in before:gmatch("%S+") do
        last = word
    end
    if last == nil then
        raise("list index out of range")
    end
    return last
end

local function has(text, needle)
    return text:find(needle, 1, true) ~= nil
end

function new_storage()
    return {flags = {}, flag_order = {}, typedefs = {}, typedef_order = {}}
end

function scan_line(line, storage, with_typedefs)
    if line:sub(1, 2) ~= "|-" then
        return
    end
    local kind, rest = partition(line)
    kind = kind:sub(3)
    if kind == TYPEDEF_KIND and with_typedefs then
        local _, after = partition(rest)
        local tokens = quoted(after)
        if #tokens > 0 then
            local name = last_word_before_quote(after)
            if storage.typedefs[name] == nil then
                table.insert(storage.typedef_order, name)
            end
            storage.typedefs[name] = tokens[#tokens]
        end
        return
    end
    if not STORAGE_KINDS[kind] then
        return
    end
    local _, after = partition(rest)
    local name = last_word_before_quote(after)
    local tokens = quoted(after)
    local found = {has(after, EXTERNAL_LINKAGE) or has(after, " extern"),
                   has(after, INTERNAL_LINKAGE) or has(after, " static"),
                   has(after, " inline") or has(after, " implicit-inline"),
                   tokens[1] or "", tokens[#tokens] or ""}
    local seen = storage.flags[name]
    if seen == nil then
        storage.flags[name] = found
        table.insert(storage.flag_order, name)
    else
        storage.flags[name] = {seen[1] or found[1], seen[2] or found[2], seen[3] or found[3],
                               seen[4] ~= "" and seen[4] or found[4], seen[5] ~= "" and seen[5] or found[5]}
    end
end

function scan_storage(lines, flags, typedefs)
    local storage = {flags = flags, flag_order = {}, typedefs = typedefs or {}, typedef_order = {}}
    for _, line in ipairs(lines) do
        scan_line(line, storage, typedefs ~= nil)
    end
    return storage
end

function header_surface(framework, owns)
    local wrapper = new_storage()
    wrapper.surface = surface_walk.new(framework, {full = true, owns = owns})
    function wrapper:feed(lines)
        local storage = self
        if type(lines) == "function" then
            self.surface:feed(function ()
                local line = lines()
                if line ~= nil then
                    scan_line(line, storage, true)
                end
                return line
            end)
        else
            for _, line in ipairs(lines) do
                scan_line(line, storage, true)
            end
            self.surface:feed(lines)
        end
    end
    return wrapper
end

local libraries_memo = {}

local function include_library(sdk, framework)
    if libraries_memo[sdk] == nil then
        local by_name = {}
        for _, library in ipairs(surface_walk.include_libraries(sdk)) do
            by_name[library.name] = library.headers
        end
        libraries_memo[sdk] = by_name
    end
    return libraries_memo[sdk][framework]
end

local function include_owns(framework)
    if framework == INCLUDE_TOP then
        return function (file)
            return file:find("/usr/include/[^/]+$") ~= nil
        end
    end
    local marker = "/usr/include/" .. framework:match("^[^/]+/(.*)$") .. "/"
    return function (file)
        return file:find(marker, 1, true) ~= nil
    end
end

function walk(framework, sdk, vfs, failed)
    local command = surface_walk.clang_command(sdk, TARGET, true, vfs)
    local top = INCLUDE_TOP
    if framework == top or framework:sub(1, #top + 1) == top .. "/" then
        local headers = include_library(sdk, framework)
        if headers == nil then
            return nil, nil, nil
        end
        local surface = header_surface(framework, include_owns(framework))
        surface_walk.walk_imports(surface, command, headers, failed)
        local imports = {}
        for index, header in ipairs(headers) do
            imports[index] = header
        end
        return surface, imports, command
    end
    local headers_dir = surface_walk.framework_headers_dir(sdk, framework, TARGET, true)
    local found = headers_dir and surface_walk.header_files(headers_dir) or {}
    local umbrella = framework .. ".h"
    local imports = {}
    for _, header in ipairs(found) do
        if header == umbrella then
            table.insert(imports, framework .. "/" .. header)
        end
    end
    for _, header in ipairs(found) do
        if header ~= umbrella then
            table.insert(imports, framework .. "/" .. header)
        end
    end
    local surface = header_surface(framework)
    surface_walk.walk_imports(surface, command, imports, failed)
    return surface, imports, command
end

function naming_line(kind, api, slot)
    if kind == "protocol" then
        return string.format("id <%s> *revenantLedger%d = 0;", api, slot)
    end
    if kind == "function" then
        return string.format("__typeof__(%s) *revenantLedger%d = &%s;", api, slot, api)
    end
    if kind == "constant" then
        return string.format("__typeof__(%s) revenantLedger%d = %s;", api, slot, api)
    end
    return string.format("__typeof__(%s) revenantLedger%d;", api, slot)
end

local function stem(tag)
    return (tag:gsub("[^A-Za-z0-9_]", "_"))
end

function utf8_prefix(text, count)
    local at, seen = 1, 0
    while at <= #text and seen < count do
        local byte = text:byte(at)
        local size = 1
        if byte >= 0xf0 and byte <= 0xf4 then
            size = 4
        elseif byte >= 0xe0 and byte <= 0xef then
            size = 3
        elseif byte >= 0xc2 and byte <= 0xdf then
            size = 2
        end
        local good = at + size - 1 <= #text
        for index = at + 1, at + size - 1 do
            local next_byte = text:byte(index)
            if not next_byte or next_byte < 0x80 or next_byte > 0xbf then
                good = false
            end
        end
        at = at + (good and size or 1)
        seen = seen + 1
    end
    return text:sub(1, at - 1)
end

local function run(command, extra, opt)
    local arguments = {}
    for index = 2, #command do
        table.insert(arguments, command[index])
    end
    table.join2(arguments, extra)
    local status = os.execv(command[1], arguments, {stdout = opt.stdout or os.nuldev(), stderr = opt.stderr or os.nuldev(), try = true})
    return status
end

local function lines_of(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    if text == "" or text:sub(-1) == "\n" then
        table.remove(lines)
    end
    return lines
end

local function strip(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function compile_named_rows(imports, command, rows, workdir, tag)
    local verdict, order = {}, {}
    if #imports == 0 or #rows == 0 then
        return verdict, order
    end
    local source = path.join(workdir, "named-" .. stem(tag) .. ".m")
    local text, line_of, number = {}, {}, 0
    for _, header in ipairs(imports) do
        table.insert(text, string.format("#import <%s>\n", header))
        number = number + 1
    end
    table.insert(text, "\n")
    number = number + 1
    for index, row in ipairs(rows) do
        table.insert(text, naming_line(row[1], row[2], index - 1) .. "\n")
        number = number + 1
        line_of[tostring(number)] = index
    end
    io.writefile(source, table.concat(text))
    local errors = path.join(workdir, "named-" .. stem(tag) .. ".stderr")
    run(command, {"-fsyntax-only", "-ferror-limit=0", source}, {stderr = errors})
    local stderr = os.isfile(errors) and io.readfile(errors) or ""
    os.tryrm(errors)
    for _, row in ipairs(rows) do
        if verdict[row[2]] == nil then
            verdict[row[2]] = ""
            table.insert(order, row[2])
        end
    end
    for _, line in ipairs(lines_of(stderr)) do
        local number_text, _, level, message = strip(line):match("^[^:\n]+:(%d+):(%d+): (%a+): (.*)$")
        if level == "error" and line_of[number_text] then
            local api = rows[line_of[number_text]][2]
            if verdict[api] == "" then
                verdict[api] = utf8_prefix(message, 200)
            end
        end
    end
    return verdict, order
end

function dump_framework_macros(imports, command, workdir, tag)
    local macros, order = {}, {}
    if #imports == 0 then
        return macros, order
    end
    local source = path.join(workdir, "macros-" .. stem(tag) .. ".m")
    local text = {}
    for _, header in ipairs(imports) do
        table.insert(text, string.format("#import <%s>\n", header))
    end
    io.writefile(source, table.concat(text))
    local dropped = {["-Xclang"] = true, ["-ast-dump"] = true, ["-fsyntax-only"] = true}
    local preprocessing = {}
    for _, item in ipairs(command) do
        if not dropped[item] then
            table.insert(preprocessing, item)
        end
    end
    local output = path.join(workdir, "macros-" .. stem(tag) .. ".out")
    run(preprocessing, {"-E", "-dM", source}, {stdout = output})
    for line in io.lines(output) do
        local name, value = line:match("^#define%s+([A-Za-z_][A-Za-z0-9_]*)%s+(.*)$")
        if name then
            if macros[name] == nil then
                table.insert(order, name)
            end
            macros[name] = strip(value)
        end
    end
    os.tryrm(output)
    return macros, order
end

local tool_memo = nil

function tool_stamp()
    if tool_memo == nil then
        local text = {}
        for _, name in ipairs(TOOL_FILES) do
            table.insert(text, io.readfile(path.join(HERE, name)) or "")
        end
        tool_memo = hash.sha256(bytes(table.concat(text, "\0"))):sub(1, 12)
    end
    return tool_memo
end

function stamp_of(sdk, vfs)
    return {sdk = ledger_inputs.realpath(sdk), vfs = ledger_inputs.realpath(vfs), vfs_mtime = os.mtime(vfs), target = TARGET, tool = tool_stamp()}
end

local function same_stamp(cached, stamp)
    if type(cached) ~= "table" then
        return false
    end
    local count = 0
    for key, value in pairs(cached) do
        count = count + 1
        if stamp[key] == nil or stamp[key] ~= value then
            return false
        end
    end
    return count == 5
end

local function stamp_json(stamp)
    return ledger_json.object({{"sdk", stamp.sdk}, {"vfs", stamp.vfs}, {"vfs_mtime", stamp.vfs_mtime}, {"target", stamp.target}, {"tool", stamp.tool}})
end

local function strings_json(list)
    local copy = {}
    for index, item in ipairs(list) do
        copy[index] = item
    end
    return ledger_json.array(copy)
end

local function map_json(map, order, value_of)
    local pairs_list = {}
    for _, key in ipairs(order) do
        table.insert(pairs_list, {key, value_of and value_of(map[key]) or map[key]})
    end
    return ledger_json.object(pairs_list)
end

function cache_file_of(cache_dir, framework)
    return path.join(cache_dir, (framework:gsub("/", "_")) .. ".json")
end

function framework_index(framework, sdk, vfs, cache_dir, workdir, force)
    local cache_file = cache_file_of(cache_dir, framework)
    local stamp = stamp_of(sdk, vfs)
    if not force and os.exists(cache_file) then
        local cached
        try {
            function ()
                cached = ledger_json.decode(io.readfile(cache_file))
            end,
            catch {
                function ()
                    cached = nil
                end
            }
        }
        if type(cached) == "table" and same_stamp(cached.stamp, stamp) then
            return cached, true
        end
    end
    local failed = {}
    local surface, imports, command = walk(framework, sdk, vfs, failed)
    imports = imports or {}
    local index, encoded
    if surface == nil then
        index = {stamp = stamp, error = string.format("no header directory or usr/include library for %s in this SDK", framework),
                 rows = {}, flags = {}, compiled = {}, failed = failed, headers = 0}
        encoded = ledger_json.object({{"stamp", stamp_json(stamp)}, {"error", index.error}, {"rows", ledger_json.object()},
                                      {"flags", ledger_json.object()}, {"compiled", ledger_json.object()},
                                      {"failed", strings_json(failed)}, {"headers", 0}})
    elseif #surface.surface.order == 0 then
        index = {stamp = stamp, error = string.format("the walk read no declaration of %s at %s", framework, TARGET),
                 rows = {}, flags = {}, compiled = {}, failed = failed, headers = #imports}
        encoded = ledger_json.object({{"stamp", stamp_json(stamp)}, {"error", index.error}, {"rows", ledger_json.object()},
                                      {"flags", ledger_json.object()}, {"compiled", ledger_json.object()},
                                      {"failed", strings_json(failed)}, {"headers", #imports}})
    else
        local rows, row_pairs, named = {}, {}, {}
        for _, api in ipairs(surface.surface.order) do
            local held = surface.surface.rows[api]
            local detail = surface.surface.details[api] or {}
            local introduced = held.version
            if introduced ~= nil and #introduced == 0 then
                introduced = nil
            end
            local row = {held.kind, introduced, detail.unavailable and true or false, detail.unavailable_ios and true or false}
            rows[api] = row
            table.insert(row_pairs, {api, ledger_json.array({row[1], introduced and ledger_json.array(introduced) or ledger_json.null(), row[3], row[4]})})
            if NAMED_KINDS[held.kind] then
                local name = api
                if held.kind == "function" and api:sub(-2) == "()" then
                    name = api:sub(1, -3)
                end
                table.insert(named, {held.kind, name})
            end
        end
        table.sort(named, function (a, b)
            if a[1] ~= b[1] then
                return byteorder.less(a[1], b[1])
            end
            return byteorder.less(a[2], b[2])
        end)
        local compiled, compiled_order = compile_named_rows(imports, command, named, workdir, framework)
        local macros, macro_order = dump_framework_macros(imports, command, workdir, framework)
        index = {stamp = stamp, rows = rows, flags = surface.flags, typedefs = surface.typedefs, compiled = compiled, macros = macros,
                 failed = failed, headers = #imports}
        encoded = ledger_json.object({
            {"stamp", stamp_json(stamp)},
            {"rows", ledger_json.object(row_pairs)},
            {"flags", map_json(surface.flags, surface.flag_order, function (flags)
                return ledger_json.array({flags[1], flags[2], flags[3], flags[4], flags[5]})
            end)},
            {"typedefs", map_json(surface.typedefs, surface.typedef_order)},
            {"compiled", map_json(compiled, compiled_order)},
            {"macros", map_json(macros, macro_order)},
            {"failed", strings_json(failed)},
            {"headers", #imports}})
    end
    io.writefile(cache_file, ledger_json.encode(encoded))
    return index, false
end
