local HERE = os.scriptdir()
local MODULES = path.join(HERE, "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})
local ledger_json = import("ledger_json", {rootdir = HERE, anonymous = true})

local SURFACE_COLUMNS = {"framework", "kind", "lang", "api", "introduced", "deprecated", "obsoleted",
                   "unavailable", "via", "getter", "registry", "owner-registry", "demand-rank",
                   "demand-severity", "demand-apps", "demand-telegram", "impl-lead", "impl-file-lead"}

function revenant_root()
    return path.absolute(path.join(HERE, "..", ".."))
end

function realpath(file)
    local pending = {}
    for part in path.absolute(file):gmatch("[^/]+") do
        table.insert(pending, part)
    end
    local resolved, hops = "", 0
    while #pending > 0 do
        local part = table.remove(pending, 1)
        if part == ".." then
            resolved = resolved:match("^(.*)/[^/]*$") or ""
        elseif part ~= "." and part ~= "" then
            local candidate = resolved .. "/" .. part
            if os.islink(candidate) and hops < 64 then
                hops = hops + 1
                local target = os.readlink(candidate)
                local parts = {}
                for piece in target:gmatch("[^/]+") do
                    table.insert(parts, piece)
                end
                for index = #parts, 1, -1 do
                    table.insert(pending, 1, parts[index])
                end
                if target:sub(1, 1) == "/" then
                    resolved = ""
                end
            else
                resolved = candidate
            end
        end
    end
    return resolved == "" and "/" or resolved
end

function short(file)
    if not file or file == "" then
        return ""
    end
    local home = os.getenv("HOME") or ""
    if home == "" then
        return file
    end
    local out, from = {}, 1
    while true do
        local at = file:find(home, from, true)
        if not at then
            table.insert(out, file:sub(from))
            break
        end
        table.insert(out, file:sub(from, at - 1))
        table.insert(out, "$HOME")
        from = at + #home
    end
    return table.concat(out)
end

function split_tab(line)
    local fields, from = {}, 1
    while true do
        local at = line:find("\t", from, true)
        if not at then
            table.insert(fields, line:sub(from))
            return fields
        end
        table.insert(fields, line:sub(from, at - 1))
        from = at + 1
    end
end

local function quoted_record(first, next_line)
    local fields, field = {}, {}
    local line, at = first, 1
    local quoted, started = false, false
    while true do
        if at > #line then
            if quoted then
                local more = next_line()
                if more == nil then
                    table.insert(fields, table.concat(field))
                    return fields
                end
                table.insert(field, "\n")
                line, at = more, 1
            else
                table.insert(fields, table.concat(field))
                return fields
            end
        else
            local char = line:sub(at, at)
            if quoted then
                if char == '"' then
                    if line:sub(at + 1, at + 1) == '"' then
                        table.insert(field, '"')
                        at = at + 1
                    else
                        quoted = false
                    end
                else
                    table.insert(field, char)
                end
            elseif char == "\t" then
                table.insert(fields, table.concat(field))
                field, started = {}, false
            elseif char == '"' and not started then
                quoted, started = true, true
            else
                table.insert(field, char)
                started = true
            end
            at = at + 1
        end
    end
end

function tsv_records(file)
    local iterator = io.lines(file)
    local function next_line()
        local line = iterator()
        if line ~= nil and line:sub(-1) == "\r" then
            line = line:sub(1, -2)
        end
        return line
    end
    return function ()
        while true do
            local line = next_line()
            if line == nil then
                return nil
            end
            if line ~= "" then
                if line:find('"', 1, true) then
                    return quoted_record(line, next_line)
                end
                return split_tab(line)
            end
        end
    end
end

function load_surface(file)
    local rows = {}
    local records = tsv_records(file)
    local head = records() or {}
    local same = #head == #SURFACE_COLUMNS
    for index, name in ipairs(SURFACE_COLUMNS) do
        same = same and head[index] == name
    end
    if not same then
        raise("surface tsv header changed shape: %s", table.concat(head, "\t"))
    end
    for fields in records do
        local row = {}
        for index = 1, math.min(#fields, #SURFACE_COLUMNS) do
            row[SURFACE_COLUMNS[index]] = fields[index]
        end
        table.insert(rows, row)
    end
    return rows
end

function walk(top, visit)
    local dirs, files = {}, {}
    for _, entry in ipairs(os.filedirs(path.join(top, "*"))) do
        if os.isdir(entry) then
            table.insert(dirs, path.filename(entry))
        else
            table.insert(files, path.filename(entry))
        end
    end
    local keep = visit(top, dirs, files)
    if keep == false then
        return
    end
    for _, name in ipairs(dirs) do
        local child = path.join(top, name)
        if not os.islink(child) then
            walk(child, visit)
        end
    end
end

function default_checkout(surface)
    local directory = path.directory(realpath(surface))
    for _ = 1, 6 do
        local candidate = path.join(directory, "toolchain")
        if os.isdir(path.join(candidate, "packages")) then
            return candidate
        end
        local parent = path.directory(directory)
        if parent == nil or parent == directory then
            break
        end
        directory = parent
    end
    return directory
end

local function present(value)
    if ledger_json.is_null(value) then
        return nil
    end
    return value
end

function read_package_registries(checkout)
    local entries = {}
    local packages = path.join(checkout, "packages")
    if not os.isdir(packages) then
        return entries
    end
    walk(packages, function (base, _, _)
        if path.filename(base) ~= "registry" then
            return true
        end
        local package = path.relative(path.directory(base), checkout)
        walk(base, function (folder, _, files)
            byteorder.sort(files)
            for _, name in ipairs(files) do
                if name:sub(-5) == ".json" then
                    local data
                    try {
                        function ()
                            data = ledger_json.decode(io.readfile(path.join(folder, name)))
                        end,
                        catch {
                            function ()
                                data = nil
                            end
                        }
                    }
                    if data ~= nil then
                        local list = data
                        if type(data) == "table" and not ledger_json.is_array(data) then
                            list = present(data.entries)
                        end
                        for _, entry in ipairs(list or {}) do
                            local api = present(entry.api)
                            if api and api ~= "" then
                                local status = entry.status
                                if status == nil then
                                    status = ""
                                end
                                local reason = entry.reason
                                if reason == nil then
                                    reason = ""
                                end
                                entries[api] = {present(status), present(reason), package}
                            end
                        end
                    end
                end
            end
        end)
        return false
    end)
    return entries
end

function built_tree(gate_dir)
    if not gate_dir or gate_dir == "" then
        return "no --gate given, so nothing here is measured against a build"
    end
    local record = path.join(gate_dir, "tree")
    if os.exists(record) then
        local fields = {}
        for line in io.lines(record) do
            local key, value = line:match("^([^\t]*)\t(.*)$")
            if key then
                fields[key] = value
            end
        end
        if fields.revision and fields.revision ~= "" and fields.revision ~= "unknown" then
            return fields.revision:sub(1, 12) .. (fields.dirty == "yes" and " (dirty)" or "")
        end
    end
    local when = "unknown"
    if os.exists(gate_dir) then
        when = os.date("%Y-%m-%d %H:%M", os.mtime(gate_dir))
    end
    return "built " .. when .. ", tree not recorded"
end

local function entry_of(found, protocol)
    return {instance = found.instance or {}, class = found.class or {},
            protocols = protocol and {} or (found.protocols or {}),
            superclass = (not protocol and found.superclass) or "", image = (not protocol and found.image) or ""}
end

function objc_inventory(source, architecture)
    local objc = import("apple.objc", {rootdir = path.join(revenant_root(), "modules"), anonymous = true})
    local found = architecture and objc.binary_inventory(source, architecture) or objc.inventory(source)
    assert(found, source .. " holds no readable Objective-C metadata")
    local classes, protocols = {}, {}
    for name, class in pairs(found.classes) do
        classes[name] = entry_of(class, false)
    end
    for name, protocol in pairs(found.protocols or {}) do
        protocols[name] = entry_of(protocol, true)
    end
    return classes, protocols
end

function cache_exports(cachefile)
    local dyld = import("apple.dyld", {rootdir = path.join(revenant_root(), "modules"), anonymous = true})
    local cache = dyld.load(cachefile)
    local names = {}
    for _, library in pairs(cache.libraries) do
        for name in pairs(library.exports) do
            if name ~= "" then
                names[name] = true
            end
        end
    end
    return names
end

function capture(program, arguments)
    local folder = workspace.fresh("api-ledger-run")
    local out, err = path.join(folder, "stdout"), path.join(folder, "stderr")
    local status = os.execv(program, arguments, {stdout = out, stderr = err, try = true})
    local stdout = os.isfile(out) and io.readfile(out) or ""
    local stderr = os.isfile(err) and io.readfile(err) or ""
    os.tryrm(folder)
    return stdout, stderr, status
end

function nm_exports(dylib)
    local stdout = capture("nm", {"-gU", dylib})
    local names = {}
    for line in stdout:gmatch("[^\n]+") do
        local fields = {}
        for field in line:gmatch("%S+") do
            table.insert(fields, field)
        end
        local name
        if #fields >= 3 and fields[1]:match("^[0-9a-fA-F]+$") then
            name = fields[3]
        elseif #fields >= 2 then
            name = fields[2]
        end
        if name and name:sub(1, 1) == "_" then
            names[name] = true
        end
    end
    return names
end

local function merge(into, found, framework)
    for name, entry in pairs(found) do
        local held = into[name]
        if held == nil then
            entry.library = framework
            entry.where = {}
            into[name] = entry
        else
            if held.superclass == "" and entry.superclass ~= "" then
                held.superclass = entry.superclass
            end
            for _, kind in ipairs({"instance", "class"}) do
                for selector in pairs(entry[kind]) do
                    if not held[kind][selector] then
                        held[kind][selector] = true
                        held.where[selector] = framework
                    end
                end
            end
            for protocol in pairs(entry.protocols) do
                held.protocols[protocol] = true
            end
        end
    end
end

function load_built_inventories(gate_dir)
    local classes, protocols, exports = {}, {}, {}
    local dylibs = {}
    for _, entry in ipairs(os.filedirs(path.join(gate_dir, "*"))) do
        local name = path.filename(entry)
        if name:sub(-6) == ".dylib" and name:sub(1, 3) == "lib" then
            table.insert(dylibs, name)
        end
    end
    byteorder.sort(dylibs)
    assert(#dylibs > 0, gate_dir .. " holds no lib*.dylib -- not a gate output directory")
    for _, name in ipairs(dylibs) do
        local framework = name:sub(4, -7)
        if framework:sub(-9) == "Backports" then
            framework = framework:sub(1, -10)
        end
        local file = path.join(gate_dir, name)
        local found_classes, found_protocols = objc_inventory(file, "armv7")
        merge(classes, found_classes, framework)
        merge(protocols, found_protocols, framework)
        for symbol in pairs(nm_exports(file)) do
            exports[symbol] = framework
        end
    end
    return classes, protocols, exports, #dylibs
end

local function blank(byte)
    return byte == 32 or (byte >= 9 and byte <= 13)
end

local function word(byte)
    return byte ~= nil and ((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 95)
end

local function skip_blank(text, at)
    while at <= #text and blank(text:byte(at)) do
        at = at + 1
    end
    return at
end

local function word_at(text, at)
    local finish = at
    while word(text:byte(finish)) do
        finish = finish + 1
    end
    return finish > at and text:sub(at, finish - 1) or nil, finish
end

function interfaces(text)
    local found = {}
    local from = 1
    while true do
        local at = text:find("@interface", from, true)
        if not at then
            return found
        end
        from = at + 1
        if at == 1 or text:sub(at - 1, at - 1) == "\n" then
            local after = at + #"@interface"
            local spaced = skip_blank(text, after)
            if spaced > after then
                local name, finish = word_at(text, spaced)
                if name then
                    local superclass = nil
                    local colon = skip_blank(text, finish)
                    if text:sub(colon, colon) == ":" then
                        superclass = word_at(text, skip_blank(text, colon + 1))
                    end
                    table.insert(found, {name, superclass or ""})
                end
            end
        end
    end
end

function header_superclasses(sdk)
    local out = {}
    local root = path.join(sdk, "System", "Library", "Frameworks")
    local entries = {}
    for _, entry in ipairs(os.filedirs(path.join(root, "*"))) do
        table.insert(entries, path.filename(entry))
    end
    byteorder.sort(entries)
    for _, entry in ipairs(entries) do
        local headers = path.join(root, entry, "Headers")
        if entry:sub(-10) == ".framework" and os.isdir(headers) then
            local declared, any = {}, false
            local names = {}
            for _, file in ipairs(os.filedirs(path.join(headers, "*"))) do
                table.insert(names, path.filename(file))
            end
            byteorder.sort(names)
            for _, name in ipairs(names) do
                if name:sub(-2) == ".h" then
                    local text = io.readfile(path.join(headers, name))
                    if text then
                        for _, pair in ipairs(interfaces(text)) do
                            if pair[2] ~= "" then
                                declared[pair[1]] = declared[pair[1]] or {}
                                declared[pair[1]][pair[2]] = true
                                any = true
                            end
                        end
                    end
                end
            end
            if any then
                out[entry:sub(1, -11)] = declared
            end
        end
    end
    return out
end

local LIFTED_PATTERNS = {
    "headers\\?/System\\?/Library\\?/Frameworks\\?/([A-Za-z0-9_.]+)%.framework",
    "headers\\?/System\\?/Library\\?/Private\\?/Frameworks\\?/([A-Za-z0-9_.]+)%.framework",
}

function lifted_frameworks(vfs)
    local found = {}
    local text = io.readfile(vfs) or ""
    for _, pattern in ipairs(LIFTED_PATTERNS) do
        for name in text:gmatch(pattern) do
            found[name] = true
        end
    end
    return found
end
