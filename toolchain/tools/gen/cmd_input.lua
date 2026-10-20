local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local emit = import("emit", {anonymous = true})
local digest = import("digest", {anonymous = true})
local headers = import("headers", {anonymous = true})
local doc_text = import("doc_text", {anonymous = true})
local probe = import("probe", {anonymous = true})
local tbd = import("tbd", {anonymous = true})
local stream = import("stream", {anonymous = true})
local surface = import("surface", {anonymous = true})
local order = import("order", {anonymous = true})
local strings = import("strings", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local sdk_imports = import("sdk_imports", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})
local json = import("core.base.json")

local COLUMNS = {"kind", "api", "cls", "key", "introduced", "type", "availability", "hash", "value_status", "value", "host_value",
                 "value_source", "owned", "tbd", "shape", "measured"}
local STRING_TYPES = {NSString = true, CFStringRef = true}
local LINKAGE = {extern = true}
local NULLABILITY = {_Nonnull = true, __nonnull = true, _Nullable = true, __nullable = true}
local IOS_CACHE = {}

local function key_of(api)
    local key = string.gsub(api, "[^%w]+", "_")
    key = string.gsub(key, "^_+", "")
    return (string.gsub(key, "_+$", ""))
end

local function text_before(text, name)
    local from = 1
    while true do
        local s, e = string.find(text, name, from, true)
        if s == nil then
            return nil
        end
        local before, after = string.sub(text, s - 1, s - 1), string.sub(text, e + 1, e + 1)
        if not string.find(before, "[%w_]") and not string.find(after, "[%w_]") then
            return string.sub(text, 1, s - 1)
        end
        from = e + 1
    end
end

local function is_macro(word)
    return string.find(word, "AVAILABLE", 1, true) ~= nil or string.find(word, "DEPRECATED", 1, true) ~= nil
        or string.find(word, "OBSOLETED", 1, true) ~= nil or word == "__attribute__"
        or string.match(word, "^API_?%u[%u%d_]*$") ~= nil or string.match(word, "^NS_?%u[%u%d_]*$") ~= nil
        or string.match(word, "^OS_?%u[%u%d_]*$") ~= nil or string.match(word, "^CF_?%u[%u%d_]*$") ~= nil
        or string.match(word, "^__%u[%u%d_]*$") ~= nil
end

local function after_group(text, at)
    local depth = 0
    repeat
        local ch = string.sub(text, at, at)
        if ch == "(" then
            depth = depth + 1
        elseif ch == ")" then
            depth = depth - 1
        end
        at = at + 1
    until depth == 0 or at > #text
    return at
end

local function declared_type(before)
    local out, pos = {}, 1
    while true do
        local s, e = string.find(before, "[%a_][%w_]*", pos)
        if s == nil then
            break
        end
        table.insert(out, string.sub(before, pos, s - 1))
        local word = string.sub(before, s, e)
        pos = e + 1
        if is_macro(word) then
            local open = string.match(string.sub(before, e + 1), "^%s*()%(")
            if open ~= nil then
                pos = after_group(before, e + open)
            end
        else
            table.insert(out, word)
        end
    end
    table.insert(out, string.sub(before, pos))
    local text = string.gsub(table.concat(out), "%f[%w_][%u][%u%d]*_[%u%d_]+%f[^%w_]", " ")
    local words = {}
    for word in string.gmatch(text, "%S+") do
        local linkage = string.match(word, "^[%w_]*$") ~= nil and (string.find(word, "EXTERN", 1, true) ~= nil
                        or string.find(word, "EXPORT", 1, true) ~= nil)
        if not LINKAGE[word] and not NULLABILITY[word] and not linkage then
            table.insert(words, word)
        end
    end
    return table.concat(words, " ")
end

local function with_const(decl, const_typedefs)
    local words = {}
    for word in string.gmatch(decl, "%S+") do
        if word == "const" then
            return decl
        end
        table.insert(words, word)
    end
    for _, word in ipairs(words) do
        if const_typedefs[word] then
            return "const " .. decl
        end
    end
    return decl
end

local function availability_of(text)
    local out, pos = {}, 1
    while true do
        local s, e = string.find(text, "[%w_]+", pos)
        if s == nil then
            break
        end
        local word = string.sub(text, s, e)
        local marked = string.find(word, "AVAILABLE", 1, true) or string.find(word, "DEPRECATED", 1, true)
                       or string.find(word, "OBSOLETED", 1, true)
        local open = string.match(string.sub(text, e + 1), "^%s*()%(")
        if marked and open then
            local at, depth = e + open, 0
            repeat
                local ch = string.sub(text, at, at)
                if ch == "(" then
                    depth = depth + 1
                elseif ch == ")" then
                    depth = depth - 1
                end
                at = at + 1
            until depth == 0 or at > #text
            table.insert(out, string.sub(text, s, at - 1))
            pos = at
        else
            pos = e + 1
        end
    end
    local joined = string.gsub(table.concat(out, " "), "%s+", " ")
    return (string.gsub(joined, "^%s*(.-)%s*$", "%1"))
end

local function base_of(decl)
    for word in string.gmatch(decl, "[%a_][%w_]*") do
        if word ~= "const" and word ~= "volatile" then
            return word
        end
    end
    return "NSString"
end

local function is_string(decl, typedefs)
    for word in string.gmatch(decl, "[%a_][%w_]*") do
        if STRING_TYPES[word] or typedefs[word] then
            return true
        end
    end
    return false
end

local function objc_escape(text)
    local out = {}
    for i = 1, #text do
        local byte = string.byte(text, i)
        local ch = string.sub(text, i, i)
        if ch == "\\" then
            table.insert(out, "\\\\")
        elseif ch == "\"" then
            table.insert(out, "\\\"")
        elseif ch == "\t" then
            table.insert(out, "\\t")
        elseif ch == "\n" then
            table.insert(out, "\\n")
        elseif byte >= 0x20 and byte < 0x7f then
            table.insert(out, ch)
        else
            table.insert(out, "\\uFFFD")
        end
    end
    return table.concat(out)
end

local function ios_constants(path)
    if IOS_CACHE[path] ~= nil then
        return IOS_CACHE[path].values, IOS_CACHE[path].conflicts
    end
    local values, conflicts, header = {}, {}, nil
    local status, err = stream.lines("gzip", {"-dc", path}, function (line)
        local cells = tsv.fields(line)
        if header == nil then
            header = {}
            for i, name in ipairs(cells) do
                header[name] = i
            end
            return
        end
        if cells[header.value_kind] == "cfstring" then
            local symbol = cells[header.symbol]
            local name = string.sub(symbol, 1, 1) == "_" and string.sub(symbol, 2) or symbol
            local value = cells[header.value]
            if values[name] ~= nil and values[name] ~= value then
                conflicts[name] = true
            end
            values[name] = values[name] or value
        end
    end)
    assert(status == 0, "gzip failed on " .. path .. ": " .. tostring(err))
    IOS_CACHE[path] = {values = values, conflicts = conflicts}
    return values, conflicts
end

local function measured_releases(path)
    local out = {}
    for _, line in ipairs(strings.lines(files.read_text(path) or "")) do
        local cells = tsv.fields(line)
        if #cells == 3 and string.sub(cells[2], 1, 1) == "_" and cells[2] ~= "_MIXED-RELEASES" then
            out[string.sub(cells[2], 2)] = cells[3]
        elseif #cells == 2 and cells[1] ~= "symbol" then
            out[cells[1]] = cells[2]
        end
    end
    return out
end

local function ledger_constants(tree, corpus, fw, sdk_release)
    local out = {}
    if surface.has_ledger(corpus, surface.ledger_6_1_3(), fw) then
        local text = files.read_text(surface.ledger_file(corpus, surface.ledger_6_1_3(), fw))
        for _, row in ipairs(tsv.records(text or "")) do
            if row.kind == "constant" and row.lang == "objc" and row.status == "missing" and row.needs == "code+lift" then
                table.insert(out, row)
            end
        end
    else
        for _, row in ipairs(surface.surface_rows(tree, corpus, sdk_release, fw)) do
            if row.kind == "constant" and row.lang == "objc" then
                table.insert(out, {api = row.api, kind = row.kind, lang = row.lang, introduced = row.introduced, status = "missing",
                                   needs = "code+lift"})
            end
        end
    end
    return out
end

local function owned_constants(tree, fw)
    local out = {}
    for _, line in ipairs(strings.lines(files.read_text(path.join(layout.snap_dir(tree, fw), "owned.tsv")) or "")) do
        local cells = tsv.fields(line)
        if #cells == 2 and out[cells[1]] == nil then
            out[cells[1]] = cells[2]
        end
    end
    local found = {}
    for _, filepath in ipairs(files.glob(path.join(tree, "..", layout.registry_dir(fw), "*.json"))) do
        table.insert(found, {full = filepath, relative = path.join(layout.registry_dir(fw), path.filename(filepath))})
    end
    local single = path.join(tree, "..", layout.constants().REGISTRY, fw .. ".json")
    if os.isfile(single) then
        table.insert(found, {full = single, relative = path.join(layout.constants().REGISTRY, fw .. ".json")})
    end
    table.sort(found, function (a, b) return order.less(a.full, b.full) end)
    for _, file in ipairs(found) do
        local data = json.decode(files.read_text(file.full))
        for _, entry in ipairs(data.entries or data) do
            if entry.kind == "constant" and out[entry.api] == nil then
                out[entry.api] = "registry:" .. file.relative
            end
        end
    end
    return out
end

local function typedefs_of(tree, fws)
    local string_names, cf_names, const_names = {}, {}, {}
    for _, fw in ipairs(fws) do
        for _, r in ipairs(headers.shard_records(tree, fw)) do
            if r.kind == "typedef" then
                local name = string.match(r.usr or "", "([^@]+)$")
                local base = base_of(r.type or "")
                if name ~= nil and STRING_TYPES[base] then
                    string_names[name] = true
                    if base == "CFStringRef" then
                        cf_names[name] = true
                    elseif string.find(r.type or "", "%*%s*const%s*$") then
                        const_names[name] = true
                    end
                end
            end
        end
    end
    return string_names, cf_names, const_names
end

local function refresh_measured(path, measured)
    local text = files.read_text(path)
    if text == nil then
        return
    end
    local out = {}
    for line in string.gmatch(text, "([^\n]*)\n") do
        local cells = tsv.fields(line)
        if #cells == #COLUMNS and cells[1] == "constant" and measured[cells[2]] ~= nil then
            cells[#COLUMNS] = measured[cells[2]]
            line = table.concat(cells, "\t")
        end
        table.insert(out, line)
    end
    emit.file(path, table.concat(out, "\n") .. "\n")
end

local function write_framework(args, fw, sdk_release)
    local tree, sdk = args.tree, args.sdk
    local names = sdk_info.names(sdk_release)
    local ledger = ledger_constants(tree, args.corpus, fw, sdk_release)
    local docs = {usr = {}}
    if #ledger > 0 then
        local record = sdk_modules.module_of(sdk, fw)
        assert(not (record and record.kind == "swift"), string.format(
            "input %s: a Swift-only module has no C or Objective-C header; its %d Objective-C constant(s) cannot be read from the SDK",
            fw, #ledger))
        local reason
        docs, reason = doc_text.rows(tree, fw, sdk)
        assert(docs ~= nil, string.format("input %s: %s, so its constants cannot be read", fw, reason))
    end
    local typedefs, cf_typedefs, const_typedefs = typedefs_of(tree, sdk_imports.closure(sdk, fw))
    local symbols, _, has_export_list = tbd.exports(sdk, fw)
    local owned = owned_constants(tree, fw)
    local enum_values = {}
    for _, r in ipairs(headers.shard_value_records(tree, fw)) do
        local name = r.kind == "enumconst" and string.match(r.usr, "@([^@]+)$")
        if name and enum_values[name] == nil then
            enum_values[name] = r.value
        end
    end
    local ios_path = path.join(args.corpus, names.ios_table)
    assert(os.isfile(ios_path), "input: the corpus has no iOS constants table for SDK release " .. sdk_release .. ": " .. ios_path)
    local ios, ios_conflicts = ios_constants(ios_path)
    local conflicting = 0
    for _ in pairs(ios_conflicts) do
        conflicting = conflicting + 1
    end
    local held = path.join(layout.snap_dir(tree, fw), "measured.held-caches.tsv")
    local measured = {}
    if args.measured and not args.all then
        measured = measured_releases(args.measured)
    elseif os.isfile(held) then
        measured = measured_releases(held)
    end

    local decls = {}
    for _, row in ipairs(ledger) do
        local doc = docs.usr["c:@" .. row.api]
        local before = doc and doc.decl and text_before(doc.decl, row.api)
        if before ~= nil then
            decls[row.api] = {decl = with_const(declared_type(before), const_typedefs), avail = availability_of(doc.decl)}
        end
    end
    local strings_to_probe = {}
    for _, row in ipairs(ledger) do
        local d = decls[row.api]
        if owned[row.api] == nil and d ~= nil and is_string(d.decl, typedefs) then
            table.insert(strings_to_probe, row.api)
        end
    end
    local host = #strings_to_probe > 0 and probe.probe(tree, fw, strings_to_probe) or {}

    local lines, differences = {table.concat(COLUMNS, "\t")}, {}
    for _, row in ipairs(ledger) do
        local api = row.api
        local d = decls[api] or {decl = "", avail = ""}
        local avail_column = d.avail ~= "" and d.avail or "-"
        local status, value = "-", "-"
        if owned[api] ~= nil then
            status, value = "owned:" .. owned[api], "-"
        elseif d.decl == "" and enum_values[api] ~= nil and enum_values[api] ~= "-" and enum_values[api] ~= "" then
            status, value = "found", enum_values[api]
        elseif d.decl == "" then
            status, value = "undeclared", "-"
        elseif not is_string(d.decl, typedefs) then
            status, value = "numeric", "-"
        else
            local found = host[api] or {"missing", "-"}
            status, value = found[1], found[2]
        end
        local host_value, source = value, "host-macos"
        if status == "found" and d.decl == "" then
            host_value, source = "-", "sdk-enum-value"
        end
        if status == "found" and ios[api] ~= nil then
            value, source = objc_escape(ios[api]), names.ios_value
            if value ~= host_value then
                table.insert(differences, {api, host_value, value})
            end
        elseif status ~= "found" and owned[api] == nil and ios[api] ~= nil and d.decl ~= "" and is_string(d.decl, typedefs) then
            status, value, host_value, source = "found", objc_escape(ios[api]), "-", names.ios_value .. " (no host value)"
        end
        if status ~= "found" then
            value, host_value = "-", "-"
        end
        local cls_shape = (base_of(d.decl) == "CFStringRef" or cf_typedefs[base_of(d.decl)]) and "cf" or "ns"
        local record = {kind = "constant", api = api, cls = "-", key = key_of(api), introduced = row.introduced,
                        type = d.decl ~= "" and d.decl or "-", availability = avail_column,
                        hash = digest.digest("constant", api, d.decl, d.avail), value_status = status, value = value,
                        host_value = host_value, value_source = source, owned = owned[api] or "-",
                        tbd = not has_export_list and "no-export-list" or (symbols[api] and "exported" or "not-exported"),
                        shape = cls_shape,
                        measured = measured[api] or "-"}
        local cells = {}
        for i, column in ipairs(COLUMNS) do
            cells[i] = record[column]
        end
        table.insert(lines, table.concat(cells, "\t"))
    end
    if #lines > 1 then
        emit.file(layout.constant_record_path(tree, fw), table.concat(lines, "\n") .. "\n")
    elseif args.measured and not args.all then
        refresh_measured(layout.constant_record_path(tree, fw), measured)
    end
    if args.measured and not args.all then
        local rows = {}
        for name, release in pairs(measured) do
            table.insert(rows, name .. "\t" .. release)
        end
        table.sort(rows, order.less)
        emit.file(path.join(layout.snap_dir(tree, fw), "measured.held-caches.tsv"),
                  "symbol\trelease\n" .. (#rows > 0 and table.concat(rows, "\n") .. "\n" or ""))
    end
    return #ledger, differences, conflicting
end

function run(args)
    assert(args.sdk, "input needs --sdk: the iPhoneOS SDK the declarations are read from")
    assert(args.corpus, "input needs --corpus: the corpus folder (the ledgers and the iOS constants table)")
    assert(os.isdir(args.sdk), "input: the --sdk folder is not found: " .. args.sdk)
    assert(os.isdir(args.corpus), "input: the --corpus folder is not found: " .. args.corpus)
    if args.measured and not args.all then
        assert(os.isfile(args.measured), "input: the --measured file is not found: " .. args.measured)
    end
    local sdk_release = sdk_info.discover(args.sdk).version
    local targets = args.all and surface.surface_frameworks(args.tree, args.corpus, sdk_release) or {args.framework}
    local written, without_ledger = 0, 0
    for _, fw in ipairs(targets) do
        if surface.has_ledger(args.corpus, surface.ledger_6_1_3(), fw) or surface.absent_frameworks(args.tree)[fw] ~= nil then
            local rows, differences, conflicting = write_framework(args, fw, sdk_release)
            written = written + 1
            print(string.format("input %s: %d constants, %d differ from the host (the iOS value wins), %d cache symbols with conflicting values",
                fw, rows, #differences, conflicting))
        else
            without_ledger = without_ledger + 1
        end
    end
    if args.all then
        print(string.format("input --all: %d built, %d without a ledger", written, without_ledger))
    else
        print(string.format("input: %d record(s) written, %d framework(s) without a ledger", written, without_ledger))
    end
    return written > 0 and 0 or 1
end
